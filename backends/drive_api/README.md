# Drive Publisher API

Bounded AWS test backend for the Drive mini-program:

- Cognito email sessions isolate files by user.
- A private encrypted S3 bucket stores file bytes.
- DynamoDB stores file metadata plus atomic user/global usage and daily quotas.
- API Gateway JWT authorization protects every file route.
- Lambda handles list, upload, download, rename, and delete operations.

This test service intentionally limits files to 3 MiB because synchronous
API Gateway/Lambda payloads are not a large-file transport. It also enforces
10 MiB and 20 files per user, 50 MiB and 100 files globally, 500 requests per
UTC day, and 3 requests/second API throttling. S3 remains private and retained
if the CloudFormation stack is deleted.

For production large-file support, add a future presigned direct-S3 transfer
session rather than increasing the synchronous Lambda limit.

## Test and deploy

```powershell
cd D:\mini-app-store\backends\drive_api
npm install
npm test
.\deploy.ps1
```

The deployment output contains the HTTPS `backendBaseUrl` to place in the
Drive mini-program's artifact-owned `publisher_backend.json`.
