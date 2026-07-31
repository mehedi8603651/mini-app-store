param(
  [string]$Region = 'ap-south-1',
  [string]$StackName = 'mini-app-store-drive-api',
  [ValidateRange(1, 10000)]
  [int]$DailyRequestLimit = 500,
  [ValidateRange(1024, 4000000)]
  [int]$MaxFileBytes = 3145728
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildRoot = Join-Path $root '.build'
$zipPath = Join-Path $buildRoot 'drive-api.zip'

New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
Push-Location $root
try {
  npm ci --omit=dev --ignore-scripts
  if ($LASTEXITCODE -ne 0) { throw 'Failed to install Drive Lambda dependencies.' }
  npm test
  if ($LASTEXITCODE -ne 0) { throw 'Drive Lambda tests failed.' }
  if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
  tar.exe -a -c -f $zipPath index.mjs package.json package-lock.json node_modules
  if ($LASTEXITCODE -ne 0) { throw 'Failed to package the Drive Lambda.' }
} finally {
  Pop-Location
}

$accountId = aws sts get-caller-identity --query Account --output text
if ($LASTEXITCODE -ne 0 -or -not $accountId) { throw 'AWS credentials are unavailable.' }
$deploymentBucket = "mini-app-store-deploy-$accountId-$Region"
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'
aws s3api head-bucket --bucket $deploymentBucket 2>$null | Out-Null
$bucketExists = $LASTEXITCODE -eq 0
$ErrorActionPreference = $previousErrorActionPreference
if (-not $bucketExists) {
  if ($Region -eq 'us-east-1') {
    aws s3api create-bucket --bucket $deploymentBucket --region $Region | Out-Null
  } else {
    aws s3api create-bucket `
      --bucket $deploymentBucket `
      --region $Region `
      --create-bucket-configuration "LocationConstraint=$Region" | Out-Null
  }
  aws s3api put-public-access-block `
    --bucket $deploymentBucket `
    --public-access-block-configuration `
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true | Out-Null
  $encryptionPath = Join-Path $buildRoot 'deployment-bucket-encryption.json'
  @{
    Rules = @(
      @{
        ApplyServerSideEncryptionByDefault = @{ SSEAlgorithm = 'AES256' }
      }
    )
  } | ConvertTo-Json -Depth 5 | Set-Content -Encoding ascii $encryptionPath
  aws s3api put-bucket-encryption `
    --bucket $deploymentBucket `
    --server-side-encryption-configuration "file://$encryptionPath" | Out-Null
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash.ToLowerInvariant()
$codeKey = "drive-api/$hash.zip"
aws s3 cp $zipPath "s3://$deploymentBucket/$codeKey" --region $Region --only-show-errors
if ($LASTEXITCODE -ne 0) { throw 'Failed to upload the Drive Lambda archive.' }

aws cloudformation deploy `
  --template-file (Join-Path $root 'template.yaml') `
  --stack-name $StackName `
  --region $Region `
  --capabilities CAPABILITY_NAMED_IAM `
  --no-fail-on-empty-changeset `
  --parameter-overrides `
    "CodeBucket=$deploymentBucket" `
    "CodeKey=$codeKey" `
    "DailyRequestLimit=$DailyRequestLimit" `
    "MaxFileBytes=$MaxFileBytes"
if ($LASTEXITCODE -ne 0) { throw 'Drive CloudFormation deployment failed.' }

$outputs = aws cloudformation describe-stacks `
  --stack-name $StackName `
  --region $Region `
  --query 'Stacks[0].Outputs' `
  --output json | ConvertFrom-Json
$result = @{}
foreach ($output in $outputs) { $result[$output.OutputKey] = $output.OutputValue }
[pscustomobject]@{
  region = $Region
  stackName = $StackName
  backendBaseUrl = $result.BackendBaseUrl
  filesBucketName = $result.FilesBucketName
  filesTableName = $result.FilesTableName
  quotaTableName = $result.QuotaTableName
  userPoolId = $result.UserPoolId
  userPoolClientId = $result.UserPoolClientId
  dailyRequestLimit = $DailyRequestLimit
  maxFileBytes = $MaxFileBytes
} | ConvertTo-Json
