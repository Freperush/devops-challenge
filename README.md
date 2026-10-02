# DevOps challenge

## Cómo evaluar

HOST: pendiente hasta el `terraform apply`. La URL final es `https://<gateway>/DevOps`.

En PowerShell, con el secreto recibido por canal privado:

```powershell
$env:JWT_SECRET = "<secreto-entregado-en-privado>"
$env:JWT = python scripts/generate_jwt.py
curl.exe -X POST `
  -H "X-Parse-REST-API-Key: 2f5ae96c-b558-4c7b-a590-a501ae1c3f6c" `
  -H "X-JWT-KWY: $env:JWT" `
  -H "Content-Type: application/json" `
  -d '{ "message": "This is a test", "to": "Juan Perez", "from": "Rita Asturia", "timeToLifeSec": 45 }' `
  https://<HOST>/DevOps
```

Respuesta esperada, HTTP 200:

```json
{"message": "Hello Juan Perez your message will be sent"}
```

Prueba negativa: `GET https://<HOST>/DevOps` devuelve el cuerpo `ERROR`.

Cada ejecución de `scripts/generate_jwt.py` emite un JWT nuevo (`jti` distinto). El token dura 15 minutos y puede reutilizarse mientras siga vigente. No hay prevención de replay.

## Arquitectura

El cliente entra por API Management Consumption. El gateway valida la API Key y el JWT solo en `POST /DevOps` y reenvía el resto de métodos al backend, que responde `ERROR`. El Service `LoadBalancer` de producción reparte hacia los Pods. Dev y staging son namespaces del mismo clúster, con Service interno. La aplicación vuelve a validar API Key y JWT.

La suscripción Free Trial de East US tiene 4 vCPU regionales. `Standard_D4als_v6` no está disponible para esta suscripción y dos nodos de 4 vCPU no caben en esa cuota. El clúster queda en dos nodos `Standard_D2as_v4`, sin Cluster Autoscaler. La escalabilidad dinámica de la aplicación es el HPA de producción (mínimo 2, máximo 4).

## Local

```powershell
python -m venv .venv
.\.venv\Scripts\pip.exe install -e ".[dev]"
$env:API_KEY = "2f5ae96c-b558-4c7b-a590-a501ae1c3f6c"
$env:JWT_SECRET = "cambia-este-secreto-de-al-menos-32-bytes"
.\.venv\Scripts\pytest.exe --cov=app --cov-branch --cov-fail-under=90
docker build -t devops-api:local .
docker run --rm -p 8080:8080 -e API_KEY -e JWT_SECRET devops-api:local
```

## CI/CD

- `ci.yml`: jobs `Build` y `Test` en cada push y pull request.
- `cd.yml`: push a `master` construye la imagen `sha-<commit>` en ACR y despliega en `prod`. `workflow_dispatch` redespliega un tag ya existente en `dev`, `staging` o `prod`. Rollback es volver a desplegar un tag anterior.
- El apply de Terraform es local y bajo demanda. El workflow de infraestructura solo hace plan, para no crear una segunda copia del clúster.

## Costo

Estimación de lista East US, 2 de octubre de 2026, para dos `Standard_D2as_v4` (USD 0,096/h cada una), un Load Balancer, una IP, dos discos de 64 GiB y ACR Basic: unos USD 0,24 por hora, USD 6 por 24 h, USD 12 por 48 h y USD 17 por 72 h. API Management Consumption no tiene cargo fijo. El budget de USD 30 avisa al 50, 80 y 100 % del costo real y al 100 % pronosticado. No apaga recursos. Hay que ejecutar `terraform destroy` al cerrar la evaluación.

## Limitaciones

- El tramo API Management hacia el balanceador es HTTP. El balanceador es público; la aplicación vuelve a exigir API Key y JWT.
- Los probes solo comprueban que el puerto 8080 acepte TCP.
- El secreto JWT no está en el repositorio.
