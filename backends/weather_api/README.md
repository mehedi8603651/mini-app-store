# Weather Publisher API

AWS Lambda middle-server for the Weather mini-program. It exposes:

- `GET /health`
- `POST /forecast`
- `POST /geocoding`

The API validates mini-program input, calls the public Open-Meteo APIs, and
normalizes responses for the static Weather artifact. It contains no AWS or
Open-Meteo credentials.

## Test

```powershell
cd D:\mini-app-store\backends\weather_api
npm test
```

## Deploy

```powershell
.\deploy.ps1
```

The script creates or updates the `mini-app-store-weather-api` Lambda and HTTP
API in `ap-south-1`, applies conservative API throttling, and prints the
`backendBaseUrl` used by the current host endpoint configuration.
