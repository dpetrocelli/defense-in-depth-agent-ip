# Análisis de Costos - Bedrock Protected Mode

## Resumen Ejecutivo

Este documento detalla los costos estimados para la arquitectura "Bedrock Protected Mode" que protege prompts en cuentas de clientes.

**Costo mensual estimado (uso bajo/medio): ~$15-50 USD/mes**

---

## Componentes y Costos por Cuenta

### Cuenta Central (190045319446)

| Servicio | Recurso | Costo Estimado | Notas |
|----------|---------|----------------|-------|
| **KMS** | N/A (key en cuenta cliente) | $0 | - |
| **S3** | Bucket audit logs | ~$0.50-5/mes | Depende del volumen de logs |
| **SNS** | Topic alertas | ~$0.01-1/mes | Primeras 1M requests gratis |
| **Lambda** | Slack notifier (opcional) | ~$0-0.50/mes | Primeras 1M requests gratis |
| **Secrets Manager** | 2 secrets (prompts source) | ~$0.80/mes | $0.40/secret/mes |

**Subtotal Cuenta Central: ~$1.30-7.30/mes**

---

### Cuenta Cliente (875228160179)

| Servicio | Recurso | Costo Estimado | Notas |
|----------|---------|----------------|-------|
| **Bedrock Agent** | Nova Lite | Variable | Pay-per-use (ver detalle abajo) |
| **KMS** | 1 CMK | $1/mes | Fijo |
| **SSM Parameter Store** | 2 SecureString params | $0 | Standard tier es gratis |
| **CloudTrail** | Trail a S3 cross-account | ~$2-10/mes | Depende de eventos |
| **EventBridge** | 4 rules | ~$0-1/mes | AWS events son gratis |
| **IAM** | Roles y policies | $0 | IAM es gratis |

**Subtotal Cuenta Cliente (sin Bedrock): ~$3-12/mes**

---

## Detalle: Amazon Bedrock (Nova Lite)

### Pricing Nova Lite (us-east-1)

| Modelo | Input | Output |
|--------|-------|--------|
| Amazon Nova Lite | $0.00006/1K tokens | $0.00024/1K tokens |

### Ejemplos de Uso

#### Escenario 1: Uso Bajo (1,000 invocaciones/mes)
- Promedio: 500 tokens input + 200 tokens output por request
- **Input**: 1,000 × 500 tokens × $0.00006/1K = **$0.03**
- **Output**: 1,000 × 200 tokens × $0.00024/1K = **$0.05**
- **Total Bedrock: ~$0.08/mes**

#### Escenario 2: Uso Medio (10,000 invocaciones/mes)
- Promedio: 1,000 tokens input + 500 tokens output por request
- **Input**: 10,000 × 1,000 tokens × $0.00006/1K = **$0.60**
- **Output**: 10,000 × 500 tokens × $0.00024/1K = **$1.20**
- **Total Bedrock: ~$1.80/mes**

#### Escenario 3: Uso Alto (100,000 invocaciones/mes)
- Promedio: 2,000 tokens input + 1,000 tokens output por request
- **Input**: 100,000 × 2,000 tokens × $0.00006/1K = **$12.00**
- **Output**: 100,000 × 1,000 tokens × $0.00024/1K = **$24.00**
- **Total Bedrock: ~$36.00/mes**

---

## Detalle: CloudTrail

| Tipo de Evento | Precio |
|----------------|--------|
| Management events (1ra copia) | GRATIS |
| Management events (copias adicionales) | $2.00/100K eventos |
| Data events | $0.10/100K eventos |

**Estimación típica**:
- 500K management events/mes → $0 (1ra copia gratis)
- Data events SSM/KMS: ~100K/mes → $0.10/mes

---

## Detalle: S3 (Audit Logs)

| Componente | Precio (us-east-1) |
|------------|-------------------|
| Storage (Standard) | $0.023/GB/mes |
| PUT requests | $0.005/1K requests |
| GET requests | $0.0004/1K requests |

**Estimación típica**:
- 1GB logs/mes → $0.023
- 10K PUT requests → $0.05
- **Total S3: ~$0.10-1/mes**

---

## Detalle: EventBridge

| Tipo de Evento | Precio |
|----------------|--------|
| AWS management events | GRATIS |
| Custom events | $1.00/millón |
| Cross-account delivery | $1.00/millón |

**Estimación**:
- Las alertas son raras (solo intentos de acceso no autorizado)
- ~100 eventos/mes → prácticamente **$0**

---

## Detalle: SNS

| Componente | Precio |
|------------|--------|
| Publishes | $0.50/millón (primeras 1M gratis) |
| Email deliveries | $0 (primeras 1K gratis) |
| Lambda deliveries | $0 |

**Estimación**:
- ~100 alertas/mes → **$0** (dentro del free tier)

---

## Resumen de Costos Totales

### Escenario: Uso Bajo (1K invocaciones/mes)

| Cuenta | Servicio | Costo |
|--------|----------|-------|
| Central | S3 + SNS + Secrets | $2.00 |
| Cliente | KMS | $1.00 |
| Cliente | CloudTrail | $0.10 |
| Cliente | Bedrock (Nova Lite) | $0.08 |
| **TOTAL** | | **~$3.18/mes** |

### Escenario: Uso Medio (10K invocaciones/mes)

| Cuenta | Servicio | Costo |
|--------|----------|-------|
| Central | S3 + SNS + Secrets | $3.00 |
| Cliente | KMS | $1.00 |
| Cliente | CloudTrail | $0.50 |
| Cliente | Bedrock (Nova Lite) | $1.80 |
| **TOTAL** | | **~$6.30/mes** |

### Escenario: Uso Alto (100K invocaciones/mes)

| Cuenta | Servicio | Costo |
|--------|----------|-------|
| Central | S3 + SNS + Secrets | $7.00 |
| Cliente | KMS | $1.00 |
| Cliente | CloudTrail | $2.00 |
| Cliente | Bedrock (Nova Lite) | $36.00 |
| **TOTAL** | | **~$46.00/mes** |

---

## Comparación con Otros Modelos

Si usaras otro modelo en lugar de Nova Lite:

| Modelo | Input/1K tokens | Output/1K tokens | Costo 10K invocaciones* |
|--------|-----------------|------------------|------------------------|
| **Nova Lite** | $0.00006 | $0.00024 | **$1.80** |
| Nova Micro | $0.000035 | $0.00014 | $1.05 |
| Nova Pro | $0.0008 | $0.0032 | $24.00 |
| Claude 3 Haiku | $0.00025 | $0.00125 | $8.75 |
| Claude 3.5 Sonnet | $0.003 | $0.015 | $105.00 |

*Asumiendo 1K input + 500 output tokens por request

---

## Costos NO Incluidos

1. **Data Transfer** entre regiones (si aplica)
2. **Knowledge Bases** (si agregas RAG)
3. **Action Groups / Lambdas** adicionales
4. **CloudWatch Logs** (si habilitas logging del agent)

---

## Recomendaciones de Optimización

1. **Usa Nova Lite** para casos de uso simples - es el modelo más barato
2. **Deshabilita CloudWatch Logs** del agent (ya tenés CloudTrail para auditoría)
3. **Lifecycle policy en S3** para mover logs viejos a Glacier
4. **Batch requests** cuando sea posible para reducir overhead

---

## Conclusión

La arquitectura "Paranoid Mode" agrega un overhead de **~$3-5/mes** sobre el costo base de Bedrock, principalmente por:
- KMS Key: $1/mes (fijo)
- CloudTrail: $0.10-2/mes (variable)
- S3 Audit: $0.10-3/mes (variable)
- Secrets Manager: $0.80/mes (fijo)

Este es un costo muy bajo considerando la protección de IP que provee.
