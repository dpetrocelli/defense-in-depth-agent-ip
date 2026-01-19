# CLAUDE.md - Bedrock Protected Mode

## Proyecto

Terraform module para desplegar **Amazon Bedrock Agents** en cuentas de clientes con protección total de la propiedad intelectual (prompts, instrucciones).

## El Problema a Resolver

- El Bedrock Agent DEBE vivir en la cuenta del cliente (su data no puede salir)
- Los prompts son propiedad intelectual nuestra que NO queremos exponer
- Necesitamos que el cliente pueda USAR el agent pero NO ver los prompts

## Arquitectura Multi-Cuenta

```
┌─────────────────────────────────────────────────────────────────┐
│  CUENTA CLIENTE: 875228160179                                   │
│  Profile: AdministratorAccess-875228160179                      │
│                                                                 │
│  Vive acá:                                                      │
│  - Bedrock Agent (Nova Lite)                                   │
│  - SSM Parameters (prompts encriptados con KMS)                │
│  - KMS Key (controlada por cuenta central)                     │
│  - CloudTrail + EventBridge (alertas a cuenta central)         │
│  - IAM Policies restrictivas                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Cross-Account Trust
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  CUENTA CENTRAL (ADMIN): 190045319446                          │
│  Profile: AdministratorAccess-190045319446                      │
│                                                                 │
│  Vive acá:                                                      │
│  - IAM Role "AgentAdmin" (para administrar el agent)           │
│  - S3 Bucket para audit logs (evidencia legal)                 │
│  - SNS Topic (recibe alertas de cuenta cliente)                │
│  - Secrets Manager (source of truth de prompts)                │
└─────────────────────────────────────────────────────────────────┘
```

## Capas de Seguridad (Paranoid Mode)

1. **KMS Key Blindada**: El cliente NO tiene ningún permiso, solo cuenta central + Bedrock service
2. **SSM SecureString**: Prompts encriptados, cliente no puede leer
3. **IAM Deny Explícito**: Cliente solo puede `InvokeAgent`, todo lo demás denegado
4. **CloudTrail + EventBridge**: Detecta cualquier intento de acceso no autorizado
5. **Alertas a SNS**: Notifica a cuenta central en tiempo real
6. **S3 Audit Logs**: Evidencia legal para el contrato

## Estructura del Repo

```
bedrock-protected-mode/
├── modules/
│   ├── central-account/      # Deploy en 190045319446
│   │   ├── iam.tf            # Role cross-account
│   │   ├── s3.tf             # Bucket audit
│   │   └── sns.tf            # Alertas
│   │
│   └── client-account/       # Deploy en 875228160179
│       ├── kms.tf            # KMS blindada
│       ├── ssm.tf            # Prompts encriptados
│       ├── bedrock.tf        # Agent (Nova Lite)
│       ├── iam.tf            # Policies restrictivas
│       └── monitoring.tf     # CloudTrail + EventBridge
│
├── environments/
│   ├── central/              # Parent para 190045319446
│   └── client/               # Parent para 875228160179
│
└── docs/
    ├── DEPLOYMENT.md         # Guía de deploy
    ├── SECURITY.md           # Arquitectura de seguridad
    └── CONTRACT_TEMPLATE.md  # Cláusulas legales
```

## Orden de Deploy

1. **Primero cuenta central** (190045319446):
   ```bash
   cd environments/central
   aws sso login --profile AdministratorAccess-190045319446
   terraform init && terraform apply
   ```

2. **Después cuenta cliente** (875228160179):
   ```bash
   cd environments/client
   aws sso login --profile AdministratorAccess-875228160179
   terraform init && terraform apply
   ```

## Foundation Model

Usamos **Amazon Nova Lite** (`amazon.nova-lite-v1:0`) - no requiere habilitación especial.

## Pendientes / TODOs

- [ ] Deploy y testing en ambas cuentas
- [ ] Validar que el agent funciona con Nova Lite
- [ ] Probar que las alertas llegan correctamente
- [ ] Testear los deny policies (intentar leer prompts como cliente)
- [ ] Agregar Action Groups si se necesitan (Lambda integrations)
- [ ] Considerar Knowledge Bases para RAG

## Git

- No incluir "Co-Authored-By" en commits
- Los prompts reales van en `environments/client/prompts/` (gitignored)
- Los secrets van en `terraform.tfvars` (gitignored)

## Comandos Útiles

```bash
# Login SSO
aws sso login --profile AdministratorAccess-190045319446
aws sso login --profile AdministratorAccess-875228160179

# Invocar el agent (después de deploy)
aws bedrock-agent-runtime invoke-agent \
  --agent-id AGENT_ID \
  --agent-alias-id ALIAS_ID \
  --session-id "test-001" \
  --input-text "Hola" \
  --profile AdministratorAccess-875228160179

# Testear que el cliente NO puede leer prompts (debe fallar)
aws ssm get-parameter \
  --name "/bedrock-protected/bedrock/system-prompt" \
  --with-decryption \
  --profile AdministratorAccess-875228160179
```
