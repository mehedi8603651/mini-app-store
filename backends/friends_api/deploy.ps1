param(
  [string]$Region = 'ap-south-1',
  [string]$StackName = 'mini-app-store-friends-api',
  [ValidateRange(1, 10000)]
  [int]$DailyRequestLimit = 500,
  [ValidateRange(1, 500)]
  [int]$MaxFriendsPerUser = 100,
  [ValidateRange(1, 200)]
  [int]$MaxPendingRequests = 50
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildRoot = Join-Path $root '.build'
$zipPath = Join-Path $buildRoot 'friends-api.zip'

New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
Push-Location $root
try {
  npm ci --omit=dev --ignore-scripts
  if ($LASTEXITCODE -ne 0) { throw 'Failed to install Friends Lambda dependencies.' }
  npm test
  if ($LASTEXITCODE -ne 0) { throw 'Friends Lambda tests failed.' }
  if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
  tar.exe -a -c -f $zipPath index.mjs package.json package-lock.json node_modules
  if ($LASTEXITCODE -ne 0) { throw 'Failed to package the Friends Lambda.' }
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
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash.ToLowerInvariant()
$codeKey = "friends-api/$hash.zip"
aws s3 cp $zipPath "s3://$deploymentBucket/$codeKey" --region $Region --only-show-errors
if ($LASTEXITCODE -ne 0) { throw 'Failed to upload the Friends Lambda archive.' }

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
    "MaxFriendsPerUser=$MaxFriendsPerUser" `
    "MaxPendingRequests=$MaxPendingRequests"
if ($LASTEXITCODE -ne 0) { throw 'Friends CloudFormation deployment failed.' }

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
  socialTableName = $result.SocialTableName
  invitesTableName = $result.InvitesTableName
  quotaTableName = $result.QuotaTableName
  userPoolId = $result.UserPoolId
  userPoolClientId = $result.UserPoolClientId
  dailyRequestLimit = $DailyRequestLimit
  maxFriendsPerUser = $MaxFriendsPerUser
  maxPendingRequests = $MaxPendingRequests
} | ConvertTo-Json
