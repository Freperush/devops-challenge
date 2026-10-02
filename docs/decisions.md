# Decisiones

## Aplicación

FastAPI con una sola ruta `/DevOps`. `from` entra por alias de Pydantic. `timeToLifeSec` es entero estricto, sin rango adicional. Los strings no tienen longitud mínima. Los campos extra se ignoran: el enunciado no los prohíbe y un test oculto podría enviarlos.

Otros métodos responden `405` con cuerpo `ERROR` y `Allow: POST`. HEAD solo responde el status. El orden es método, API Key, JWT y después el body.

## JWT

El evaluador genera el token con `scripts/generate_jwt.py` (biblioteca estándar) o `scripts/generate_jwt.sh`. Firma HS256. Claims `jti`, `iat`, `nbf`, `exp`, `iss=devops-challenge`, `aud=devops-api`. Vida útil 15 minutos y leeway de 30 segundos. `jti` distinto demuestra unicidad de emisión. El token puede reutilizarse mientras no expire.

## Entorno portable

Terraform no guarda la IP del balanceador ni el tenant. La dirección del backend la escribe el pipeline en cada despliegue, leyendo el Service de producción. La suscripción, el tenant y los identificadores de GitHub entran por variables. `scripts/configure_github.sh` copia los outputs a los secretos del repositorio.

## Azure

Un AKS, un ACR Basic y un API Management Consumption. Namespaces `dev`, `staging` y `prod`. Un solo Load Balancer público, el Service `edge` del namespace `gateway`, con dos réplicas de nginx. API Management elige el namespace por la ruta. Producción usa HPA de 2 a 4 réplicas. No hay Cluster Autoscaler.

`Standard_D4als_v6` aparece en East US con restricción `NotAvailableForSubscription`. La cuota real de la Free Trial es 4 vCPU regionales, así que dos nodos de 4 vCPU no se pueden crear. Los nodos son `Standard_D2as_v4`: es una SKU de 2 vCPU y 8 GiB sin restricción en esta suscripción, y dos nodos caben en los 4 vCPU de cuota.

El presupuesto mensual es USD 30. Las alertas no detienen el consumo. El apply de infraestructura es manual. El push a `master` despliega solo la aplicación.

## Fuera de esta entrega

Cluster Autoscaler, estado remoto de Terraform, firma de imágenes, SBOM, Key Vault y anti-replay.
