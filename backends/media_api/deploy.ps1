param(
  [string]$Region = 'ap-south-1',
  [string]$FunctionName = 'mini-app-store-media-api',
  [string]$ApiName = 'mini-app-store-media-api'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildRoot = Join-Path $root '.build'
$zipPath = Join-Path $buildRoot 'media-api.zip'
$roleName = "$FunctionName-role"

New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
if (Test-Path -LiteralPath $zipPath) {
  Remove-Item -LiteralPath $zipPath -Force
}
Push-Location $root
try {
  tar.exe -a -c -f $zipPath index.mjs package.json package-lock.json
  if ($LASTEXITCODE -ne 0) {
    throw 'Failed to package the Media Lambda deployment archive.'
  }
} finally {
  Pop-Location
}

$accountId = aws sts get-caller-identity --query Account --output text
$roleArn = "arn:aws:iam::$accountId`:role/$roleName"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'
aws iam get-role --role-name $roleName --query Role.Arn --output text 2>$null | Out-Null
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
  aws iam create-role `
    --role-name $roleName `
    --assume-role-policy-document "file://$trustPath" | Out-Null
  aws iam attach-role-policy `
    --role-name $roleName `
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
  Start-Sleep -Seconds 10
}

$environmentPath = Join-Path $buildRoot 'lambda-environment.json'
@{
  Variables = @{ ALLOWED_ORIGIN = '*' }
} | ConvertTo-Json -Depth 3 | Set-Content -Encoding ascii $environmentPath

$ErrorActionPreference = 'SilentlyContinue'
aws lambda get-function `
  --function-name $FunctionName `
  --region $Region `
  --query Configuration.FunctionArn `
  --output text 2>$null | Out-Null
$functionLookupExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
if ($functionLookupExitCode -eq 0) {
  aws lambda update-function-configuration `
    --function-name $FunctionName `
    --region $Region `
    --runtime nodejs22.x `
    --handler index.handler `
    --timeout 10 `
    --memory-size 128 `
    --environment "file://$environmentPath" | Out-Null
  aws lambda wait function-updated --function-name $FunctionName --region $Region
  aws lambda update-function-code `
    --function-name $FunctionName `
    --region $Region `
    --zip-file "fileb://$zipPath" | Out-Null
  aws lambda wait function-updated --function-name $FunctionName --region $Region
} else {
  aws lambda create-function `
    --function-name $FunctionName `
    --region $Region `
    --runtime nodejs22.x `
    --handler index.handler `
    --role $roleArn `
    --timeout 10 `
    --memory-size 128 `
    --environment "file://$environmentPath" `
    --zip-file "fileb://$zipPath" | Out-Null
  aws lambda wait function-active-v2 --function-name $FunctionName --region $Region
}

$functionArn = aws lambda get-function `
  --function-name $FunctionName `
  --region $Region `
  --query Configuration.FunctionArn `
  --output text
$apiId = aws apigatewayv2 get-apis `
  --region $Region `
  --query "Items[?Name=='$ApiName'].ApiId | [0]" `
  --output text
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
  $policy = aws lambda get-policy `
    --function-name $FunctionName `
    --region $Region `
    --query Policy `
    --output text 2>$null
  $policyExitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorActionPreference
  if ($policyExitCode -ne 0 -or $policy -notmatch $statementId) {
    throw 'Failed to grant API Gateway permission to invoke the Media Lambda.'
  }
}

aws apigatewayv2 update-stage `
  --api-id $apiId `
  --stage-name '$default' `
  --region $Region `
  --default-route-settings ThrottlingBurstLimit=10,ThrottlingRateLimit=5 | Out-Null

$endpoint = aws apigatewayv2 get-api `
  --api-id $apiId `
  --region $Region `
  --query ApiEndpoint `
  --output text
[pscustomobject]@{
  region = $Region
  functionName = $FunctionName
  apiId = $apiId
  backendBaseUrl = "$endpoint/"
} | ConvertTo-Json
