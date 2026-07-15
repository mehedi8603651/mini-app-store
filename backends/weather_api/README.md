# Weather Publisher API

AWS Lambda middle-server for the Weather mini-program. It exposes:

- `GET /health`
- `POST /forecast`
- `POST /geocoding`

The API validates mini-program input, enforces an atomic UTC daily request
quota through DynamoDB, calls the public Open-Meteo APIs, and normalizes
responses for the static Weather artifact. It contains no AWS or Open-Meteo
credentials.

The quota applies only immediately before Open-Meteo calls from `POST
/forecast` and `POST /geocoding`. Health checks, CORS preflight, malformed
requests, and geocoding queries shorter than two characters do not consume it.
Quota storage failures fail closed with HTTP `503`; exhausted quotas return
HTTP `429` with `Retry-After` and `retryAfterUtc`.

## Test

```powershell
cd D:\mini-app-store\backends\weather_api
npm test
```

## Deploy

```powershell
.\deploy.ps1
```

The default daily limit is 1,000 requests. Override it explicitly when needed:

```powershell
.\deploy.ps1 -DailyRequestLimit 1000
```

The script creates or updates the `mini-app-store-weather-api` Lambda and HTTP
API in `ap-south-1`, provisions an on-demand DynamoDB quota table with TTL,
grants the Lambda only `dynamodb:UpdateItem`, applies conservative API
throttling, and prints the `backendBaseUrl` used by the current artifact.
