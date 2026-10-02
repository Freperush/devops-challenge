# DevOps challenge

## Cómo evaluar

HOST es el hostname de `terraform output -raw gateway_url` después del despliegue. La ruta es exactamente `/DevOps`.

Ejemplo, cuando el gateway ya existe: `https://<gateway>/DevOps`.

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

## Levantar en otra suscripción

No hay tenant, suscripción, IP ni nombres de Azure escritos en el código. Un entorno nuevo solo cambia `infra/terraform.tfvars` y los secretos que el script copia a GitHub.

1. Entra en la suscripción destino con `az login` y en el repositorio con `gh auth login`.
2. Copia `infra/terraform.tfvars.example` a `infra/terraform.tfvars`.
3. Rellena suscripción, tenant, correo de alertas y `jwt_secret`. Los identificadores de GitHub salen de `gh api user` y `gh repo view --json databaseId`.
4. `terraform -chdir=infra init` y `terraform -chdir=infra apply`. En una suscripción vacía esto crea también la identidad de GitHub. Si esa aplicación ya existe, impórtala al estado antes de aplicar.
5. Exporta `API_KEY` y `JWT_SECRET`, y ejecuta `bash scripts/configure_github.sh`.
6. Haz push a `master`. El pipeline construye la imagen, la despliega y apunta API Management a la IP que Azure acabe de asignar al balanceador.

Para destruirlo: `terraform -chdir=infra destroy`.

## Arquitectura

El cliente entra por API Management Consumption. El gateway valida la API Key y el JWT solo en `POST /DevOps` y reenvía el resto de métodos al backend, que responde `ERROR`. El Service `LoadBalancer` de producción reparte hacia los Pods. Dev y staging son namespaces del mismo clúster, con Service interno. La aplicación vuelve a validar API Key y JWT.

El tamaño de nodo es la variable `vm_size`. El valor por defecto, `Standard_D2as_v4`, cabe en una suscripción con cuota de 4 vCPU. El pipeline descubre la IP del balanceador en cada despliegue y actualiza el backend de API Management. La escalabilidad de la aplicación es el HPA de producción, de 2 a 4 Pods.

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
