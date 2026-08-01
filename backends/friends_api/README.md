# Friends Publisher API

Bounded AWS test backend for the Friends mini-program.

The stack creates an isolated Cognito user pool, a DynamoDB social table, an
expiring invitation table, a UTC daily quota table, Lambda, and an API Gateway
HTTP API. Invitations expire after five minutes and only SHA-256 token hashes
are stored. Redeeming a token creates a pending request; a separate acceptance
transaction creates both friendship records.

Defaults:

- 500 API requests per UTC day
- 100 friends per user
- 50 pending incoming requests per user
- API Gateway rate 3 requests/second, burst 10

Deploy:

```powershell
cd D:\mini-app-store\backends\friends_api
.\deploy.ps1
```
