param(
  [string]$Region = 'ap-south-1',
  [string]$FunctionName = 'mini-app-store-weather-api',
  [string]$ApiName = 'mini-app-store-weather-api'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildRoot = Join-Path $root '.build'
$zipPath = Join-Path $buildRoot 'weather-api.zip'
$roleName = "$FunctionName-role"

New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
Compress-Archive -LiteralPath (Join-Path $root 'index.mjs') -DestinationPath $zipPath -Force

$accountId = aws sts get-caller-identity --query Account --output text
$roleArn = "arn:aws:iam::$accountId`:role/$roleName"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'
$existingRole = aws iam get-role --role-name $roleName --query Role.Arn --output text 2>$null
$roleLookupExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
if ($roleLookupExitCode -ne 0) {
  $trustPath = Join-Path $buildRoot 'lambda-trust.json'
  @'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "lambda.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
'@ | Set-Content -Encoding ascii $trustPath
  aws iam create-role --role-name $roleName --assume-role-policy-document "file://$trustPath" | Out-Null
  aws iam attach-role-policy `
    --role-name $roleName `
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
  Start-Sleep -Seconds 10
}

$ErrorActionPreference = 'SilentlyContinue'
$existingFunction = aws lambda get-function --function-name $FunctionName --region $Region --query Configuration.FunctionArn --output text 2>$null
$functionLookupExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
if ($functionLookupExitCode -eq 0) {
  aws lambda update-function-code `
    --function-name $FunctionName `
    --region $Region `
    --zip-file "fileb://$zipPath" | Out-Null
  aws lambda wait function-updated --function-name $FunctionName --region $Region
  aws lambda update-function-configuration `
    --function-name $FunctionName `
    --region $Region `
    --runtime nodejs22.x `
    --handler index.handler `
    --timeout 15 `
    --memory-size 256 `
    --environment 'Variables={ALLOWED_ORIGIN=*}' | Out-Null
  aws lambda wait function-updated --function-name $FunctionName --region $Region
} else {
  aws lambda create-function `
    --function-name $FunctionName `
    --region $Region `
    --runtime nodejs22.x `
    --handler index.handler `
    --role $roleArn `
    --timeout 15 `
    --memory-size 256 `
    --environment 'Variables={ALLOWED_ORIGIN=*}' `
    --zip-file "fileb://$zipPath" | Out-Null
  aws lambda wait function-active-v2 --function-name $FunctionName --region $Region
}

$functionArn = aws lambda get-function --function-name $FunctionName --region $Region --query Configuration.FunctionArn --output text
$apiId = aws apigatewayv2 get-apis --region $Region --query "Items[?Name=='$ApiName'].ApiId | [0]" --output text
if (-not $apiId -or $apiId -eq 'None') {
  $apiId = aws apigatewayv2 create-api `
    --name $ApiName `
    --protocol-type HTTP `
    --target $functionArn `
    --region $Region `
    --query ApiId `
    --output text
}

$statementId = 'AllowApiGatewayInvoke'
$ErrorActionPreference = 'SilentlyContinue'
aws lambda add-permission `
  --function-name $FunctionName `
  --region $Region `
  --statement-id $statementId `
  --action lambda:InvokeFunction `
  --principal apigateway.amazonaws.com `
  --source-arn "arn:aws:execute-api:$Region`:$accountId`:$apiId/*/*" 2>$null | Out-Null
$permissionExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
if ($permissionExitCode -ne 0) {
  $ErrorActionPreference = 'SilentlyContinue'
  $existingStatement = aws lambda get-policy --function-name $FunctionName --region $Region --query Policy --output text 2>$null
  $policyLookupExitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorActionPreference
  if ($policyLookupExitCode -ne 0 -or $existingStatement -notmatch $statementId) {
    throw 'Failed to grant API Gateway permission to invoke the Weather Lambda.'
  }
}

aws apigatewayv2 update-stage `
  --api-id $apiId `
  --stage-name '$default' `
  --region $Region `
  --default-route-settings ThrottlingBurstLimit=20,ThrottlingRateLimit=10 | Out-Null

$endpoint = aws apigatewayv2 get-api --api-id $apiId --region $Region --query ApiEndpoint --output text
[pscustomobject]@{
  region = $Region
  functionName = $FunctionName
  apiId = $apiId
  backendBaseUrl = "$endpoint/"
} | ConvertTo-Json
