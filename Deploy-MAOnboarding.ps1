# Deploy-MAOnboarding.ps1
# Automated deployment script for M&A Onboarding AI system

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName = "rg-ma-onboarding",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectName = "maonboarding",
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubRepo = ""
)

# Color output functions
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error { Write-Host $args -ForegroundColor Red }

Write-Info "============================================"
Write-Info "  M&A Onboarding AI - Azure Deployment"
Write-Info "============================================"
Write-Info ""

# Check Azure CLI is installed
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Success "✓ Azure CLI version: $($azVersion.'azure-cli')"
} catch {
    Write-Error "✗ Azure CLI is not installed. Please install from: https://aka.ms/installazurecli"
    exit 1
}

# Login to Azure
Write-Info "Logging into Azure..."
$loginStatus = az account show 2>$null
if (!$loginStatus) {
    az login
}

$account = az account show | ConvertFrom-Json
Write-Success "✓ Logged in as: $($account.user.name)"
Write-Info "  Subscription: $($account.name)"

# Create Resource Group
Write-Info ""
Write-Info "Creating Resource Group..."
az group create --name $ResourceGroupName --location $Location --output none
Write-Success "✓ Resource Group '$ResourceGroupName' created in $Location"

# Deploy ARM Template
Write-Info ""
Write-Info "Deploying Azure Resources (this may take 10-15 minutes)..."
$deploymentName = "ma-onboarding-$(Get-Date -Format 'yyyyMMddHHmmss')"

$deployment = az deployment group create `
    --resource-group $ResourceGroupName `
    --name $deploymentName `
    --template-file "azure-deploy.json" `
    --parameters projectName=$ProjectName `
    --output json | ConvertFrom-Json

if ($deployment.properties.provisioningState -eq "Succeeded") {
    Write-Success "✓ Azure resources deployed successfully!"
} else {
    Write-Error "✗ Deployment failed. Check Azure Portal for details."
    exit 1
}

# Get deployment outputs
Write-Info ""
Write-Info "Retrieving deployment outputs..."
$outputs = $deployment.properties.outputs

$staticWebAppUrl = $outputs.staticWebAppUrl.value
$openAiEndpoint = $outputs.openAiEndpoint.value
$cosmosEndpoint = $outputs.cosmosDbEndpoint.value
$storageAccount = $outputs.storageAccountName.value

Write-Success "✓ Static Web App URL: https://$staticWebAppUrl"
Write-Success "✓ OpenAI Endpoint: $openAiEndpoint"
Write-Success "✓ Cosmos DB Endpoint: $cosmosEndpoint"
Write-Success "✓ Storage Account: $storageAccount"

# Get resource keys
Write-Info ""
Write-Info "Retrieving resource keys..."

$openAiKeys = az cognitiveservices account keys list `
    --name "$ProjectName-openai" `
    --resource-group $ResourceGroupName `
    --output json | ConvertFrom-Json

$cosmosKeys = az cosmosdb keys list `
    --name "$ProjectName-cosmos" `
    --resource-group $ResourceGroupName `
    --output json | ConvertFrom-Json

$storageKeys = az storage account keys list `
    --account-name $storageAccount `
    --resource-group $ResourceGroupName `
    --output json | ConvertFrom-Json

$signalrKeys = az signalr key list `
    --name "$ProjectName-signalr" `
    --resource-group $ResourceGroupName `
    --output json | ConvertFrom-Json

$staticWebAppKeys = az staticwebapp secrets list `
    --name "$ProjectName-webapp" `
    --resource-group $ResourceGroupName `
    --output json | ConvertFrom-Json

Write-Success "✓ All resource keys retrieved"

# Create local.settings.json for local development
Write-Info ""
Write-Info "Creating local.settings.json for API..."

$localSettings = @{
    IsEncrypted = $false
    Values = @{
        AzureWebJobsStorage = ""
        FUNCTIONS_WORKER_RUNTIME = "node"
        AZURE_OPENAI_ENDPOINT = $openAiEndpoint
        AZURE_OPENAI_KEY = $openAiKeys.key1
        AZURE_OPENAI_DEPLOYMENT = "gpt-4-turbo"
        COSMOS_ENDPOINT = $cosmosEndpoint
        COSMOS_KEY = $cosmosKeys.primaryMasterKey
        SIGNALR_CONNECTION = "Endpoint=$($outputs.signalRConnectionString.value);AuthType=azure"
        STORAGE_CONNECTION = "DefaultEndpointsProtocol=https;AccountName=$storageAccount;AccountKey=$($storageKeys[0].value);EndpointSuffix=core.windows.net"
    }
}

$localSettings | ConvertTo-Json -Depth 10 | Set-Content -Path "api/local.settings.json"
Write-Success "✓ local.settings.json created"

# Create .env file for React app
Write-Info ""
Write-Info "Creating .env file for React app..."

@"
REACT_APP_API_ENDPOINT=/api
"@ | Set-Content -Path ".env.local"

Write-Success "✓ .env.local created"

# Setup GitHub secrets if repo provided
if ($GitHubRepo) {
    Write-Info ""
    Write-Info "Setting up GitHub Secrets..."
    Write-Warning "Note: You need to have GitHub CLI installed and authenticated"
    
    $secrets = @{
        AZURE_STATIC_WEB_APPS_API_TOKEN = $staticWebAppKeys.properties.apiKey
        API_ENDPOINT = "https://$staticWebAppUrl/api"
        AZURE_OPENAI_ENDPOINT = $openAiEndpoint
        AZURE_OPENAI_KEY = $openAiKeys.key1
        AZURE_OPENAI_DEPLOYMENT = "gpt-4-turbo"
        COSMOS_ENDPOINT = $cosmosEndpoint
        COSMOS_KEY = $cosmosKeys.primaryMasterKey
        SIGNALR_CONNECTION = "Endpoint=$($outputs.signalRConnectionString.value);AuthType=azure"
        STORAGE_CONNECTION = "DefaultEndpointsProtocol=https;AccountName=$storageAccount;AccountKey=$($storageKeys[0].value);EndpointSuffix=core.windows.net"
    }
    
    foreach ($secret in $secrets.GetEnumerator()) {
        try {
            gh secret set $secret.Key --body $secret.Value --repo $GitHubRepo
            Write-Success "✓ Set secret: $($secret.Key)"
        } catch {
            Write-Warning "Could not set secret: $($secret.Key)"
        }
    }
}

# Deploy OpenAI model
Write-Info ""
Write-Info "Deploying GPT-4 Turbo model to Azure OpenAI..."

try {
    az cognitiveservices account deployment create `
        --name "$ProjectName-openai" `
        --resource-group $ResourceGroupName `
        --deployment-name "gpt-4-turbo" `
        --model-name "gpt-4" `
        --model-version "turbo-2024-04-09" `
        --model-format "OpenAI" `
        --scale-type "Standard" `
        --output none
    
    Write-Success "✓ GPT-4 Turbo model deployed"
} catch {
    Write-Warning "Model deployment may need to be done manually in Azure Portal"
}

# Summary
Write-Info ""
Write-Info "============================================"
Write-Success "  Deployment Complete!"
Write-Info "============================================"
Write-Info ""
Write-Success "Next Steps:"
Write-Info "1. Install dependencies:"
Write-Info "   npm install"
Write-Info "   cd api && npm install"
Write-Info ""
Write-Info "2. Run locally:"
Write-Info "   Terminal 1: cd api && func start"
Write-Info "   Terminal 2: npm start"
Write-Info ""
Write-Info "3. Deploy to GitHub:"
Write-Info "   git remote add origin $GitHubRepo"
Write-Info "   git push -u origin main"
Write-Info ""
Write-Success "Static Web App URL: https://$staticWebAppUrl"
Write-Info ""
Write-Warning "Important: Configure ConnectWise credentials in GitHub Secrets if using ConnectWise integration"

# Save deployment info
$deploymentInfo = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ResourceGroup = $ResourceGroupName
    Location = $Location
    ProjectName = $ProjectName
    StaticWebAppUrl = "https://$staticWebAppUrl"
    OpenAiEndpoint = $openAiEndpoint
    CosmosEndpoint = $cosmosEndpoint
    StorageAccount = $storageAccount
}

$deploymentInfo | ConvertTo-Json -Depth 10 | Set-Content -Path "deployment-info.json"
Write-Info "Deployment information saved to deployment-info.json"
