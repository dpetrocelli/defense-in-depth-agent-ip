# Bedrock Protected Mode

Terraform module para desplegar **Amazon Bedrock Agents** en cuentas de clientes con protección total de la propiedad intelectual (prompts, instrucciones, lógica).

## El Problema

Cuando desplegás un Bedrock Agent en la cuenta de un cliente:
- **La data del cliente debe quedarse en su cuenta** (compliance, seguridad)
- **Tus prompts son propiedad intelectual** que no querés exponer
- El cliente con acceso admin/root técnicamente podría ver todo

## La Solución: Arquitectura "Paranoid Mode"

```
┌─────────────────────────────────────────────────────────────────┐
│                    Cuenta del Cliente                           │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  KMS Key (tuya)                                           │ │
│  │  - Cliente: ❌ NADA                                       │ │
│  │  - Tu cuenta: ✅ Full access                              │ │
│  │  - Bedrock service role: ✅ Decrypt only                  │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  SSM Parameter (prompt encriptado con KMS)                │ │
│  │  - Cliente: ❌ ssm:GetParameter DENIED                    │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  Bedrock Agent                                            │ │
│  │  - Cliente: ✅ InvokeAgent ONLY                           │ │
│  │  - Cliente: ❌ GetAgent, UpdateAgent, etc.                │ │
│  │  - Logging: DISABLED o encriptado con tu KMS             │ │
│  │  - Tracing: DISABLED                                      │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  CloudWatch Logs (si existen)                             │ │
│  │  - Encriptados con tu KMS                                 │ │
│  │  - Cliente: ❌ logs:GetLogEvents DENIED                   │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  CloudTrail → EventBridge → SNS (a tu cuenta)            │ │
│  │                                                           │ │
│  │  Alertas si el cliente intenta:                          │ │
│  │  - kms:PutKeyPolicy                                       │ │
│  │  - iam:* en roles de Bedrock                              │ │
│  │  - ssm:GetParameter en /bedrock/*                         │ │
│  │  - bedrock:GetAgent                                       │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  SCP (si usas Organizations)                              │ │
│  │                                                           │ │
│  │  Deny:                                                    │ │
│  │  - kms:* en tu KMS key ARN                                │ │
│  │  - iam:* en roles que vos creaste                         │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
         Cross-Account Access │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Tu Cuenta                                 │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────────────────────┐    │
│  │  IAM Role       │    │  CI/CD Pipeline                 │    │
│  │  "AgentAdmin"   │    │                                 │    │
│  │                 │    │  - Actualiza prompts            │    │
│  │  Puede:         │    │  - Despliega nuevas versiones   │    │
│  │  - ssm:Put*     │    │  - Rota KMS keys si necesario   │    │
│  │  - kms:*        │    │                                 │    │
│  │  - bedrock:*    │    └─────────────────────────────────┘    │
│  └─────────────────┘                                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Capas de Protección

### 1. KMS Key con Policy Blindada
- El cliente NO tiene ningún permiso sobre la key
- Solo tu cuenta (cross-account) y el Bedrock service role pueden decrypt
- Imposible modificar sin tu autorización

### 2. SSM Parameters Encriptados
- Los prompts se guardan como `SecureString`
- Encriptados con tu KMS key
- Resource policy que deniega acceso al cliente

### 3. IAM Deny Explícito
- El cliente SOLO puede `bedrock:InvokeAgent`
- DENY explícito en:
  - `bedrock:GetAgent`
  - `bedrock:GetPrompt`
  - `ssm:GetParameter` (para `/bedrock/*`)
  - `kms:Decrypt`

### 4. Logging Protegido
- CloudWatch Logs deshabilitado O encriptado con tu KMS
- X-Ray/Tracing deshabilitado
- El cliente no puede ver logs de ejecución

### 5. Monitoreo y Alertas
- CloudTrail captura TODOS los intentos de acceso
- EventBridge rules detectan acciones sospechosas
- SNS notifica a TU cuenta en tiempo real
- Evidencia guardada para acciones legales

### 6. SCP (Opcional - AWS Organizations)
- Bloquea modificaciones a nivel de organización
- Ni siquiera root puede modificar tus recursos

## Nivel de Seguridad

| Escenario | ¿Puede ver el prompt? | Notas |
|-----------|----------------------|-------|
| Cliente normal usando el agent | ❌ No | Solo puede invocar |
| Cliente curioso en la consola | ❌ No | Access Denied |
| Cliente con IAM Admin | ❌ No | KMS key policy lo bloquea |
| Cliente con Root + modifica KMS policy | ⚠️ Sí | Pero te enterás por alertas |
| Cliente con Root + SCP activo | ❌ No | SCP lo bloquea |

## Alertas que Recibís

Cuando el cliente intenta acceder a recursos protegidos:

```
🚨 ALERTA: Intento de acceso no autorizado

Cuenta: 123456789012 (Cliente XYZ)
Tiempo: 2024-01-15 14:32:15 UTC
Usuario: arn:aws:iam::123456789012:user/admin
Acción: ssm:GetParameter
Recurso: /bedrock/agent/system-prompt
Resultado: ACCESS DENIED

────────────────────────────────────
Esta evidencia ha sido guardada en:
s3://tu-bucket/audit-logs/2024/01/15/...

Contrato: Sección 5.2 - Prohibición de
          ingeniería inversa
────────────────────────────────────
```

## Estructura del Módulo

```
bedrock-protected-mode/
├── README.md
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── kms.tf                 # KMS Key con policy blindada
├── ssm.tf                 # Prompts encriptados
├── bedrock.tf             # Agent + Alias
├── iam.tf                 # Roles y policies restrictivas
├── monitoring.tf          # CloudTrail + EventBridge + SNS
├── scp.tf                 # Service Control Policy (opcional)
├── examples/
│   └── complete/
│       ├── main.tf
│       └── terraform.tfvars.example
└── docs/
    ├── SECURITY.md        # Documentación para el cliente
    └── CONTRACT_TEMPLATE.md # Template de cláusulas legales
```

## Uso

```hcl
module "bedrock_protected" {
  source = "github.com/dpetrocelli/bedrock-protected-mode"

  # Tu cuenta (para cross-account access)
  admin_account_id = "111111111111"

  # Cuenta del cliente
  client_account_id = "222222222222"

  # Configuración del Agent
  agent_name        = "my-protected-agent"
  foundation_model  = "anthropic.claude-3-sonnet-20240229-v1:0"

  # Prompts (se encriptan automáticamente)
  system_prompt     = file("prompts/system.txt")
  instruction       = file("prompts/instruction.txt")

  # Alertas
  alert_email       = "security@tuempresa.com"
  slack_webhook_url = "https://hooks.slack.com/..."

  # Tags
  tags = {
    Client      = "ClienteXYZ"
    Environment = "production"
  }
}
```

## Requisitos

- Terraform >= 1.0
- AWS Provider >= 5.0
- Cuenta AWS del cliente con permisos para desplegar
- Tu cuenta AWS con IAM role para cross-account access

## Consideraciones Legales

Este módulo provee protección **técnica**. Para protección completa, combiná con:

1. **Contrato de servicio** con cláusulas de:
   - Prohibición de ingeniería inversa
   - Prohibición de acceso a componentes protegidos
   - Penalidades por incumplimiento

2. **NDA** específico para la propiedad intelectual

3. **Documentación de auditoría** que demuestre los intentos de acceso no autorizado

Ver [docs/CONTRACT_TEMPLATE.md](docs/CONTRACT_TEMPLATE.md) para templates.

## License

Propietary - All rights reserved.
