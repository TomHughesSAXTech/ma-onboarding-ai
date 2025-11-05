# M&A Onboarding AI - Deployment Guide

## Overview
This AI-powered M&A onboarding system creates dynamic decision trees based on discovery conversations, integrating with Azure AI services and ConnectWise PSA.

## Architecture Components
- **Azure Static Web Apps**: Hosts the React frontend
- **Azure Functions**: Serverless API backend
- **Azure OpenAI**: Powers the AI conversation and decision logic
- **Azure Cosmos DB**: Stores session data and discovery information
- **Azure SignalR**: Real-time updates for collaborative sessions
- **Azure Blob Storage**: Stores exports and templates

## Prerequisites
1. Azure subscription with the following providers registered:
   - Microsoft.Web
   - Microsoft.CognitiveServices
   - Microsoft.DocumentDB
   - Microsoft.Storage
   - Microsoft.SignalRService

2. GitHub account for CI/CD

3. ConnectWise PSA instance (optional)

4. Azure CLI installed locally

## Step 1: Deploy Azure Resources

### Using Azure CLI:
```bash
# Login to Azure
az login

# Create resource group
az group create --name rg-ma-onboarding --location eastus

# Deploy ARM template
az deployment group create \
  --resource-group rg-ma-onboarding \
  --template-file azure-deploy.json \
  --parameters projectName=maonboarding

# Get deployment outputs
az deployment group show \
  --resource-group rg-ma-onboarding \
  --name azure-deploy \
  --query properties.outputs
```

### Using Azure Portal:
1. Go to Azure Portal > Create Resource > Template Deployment
2. Select "Build your own template"
3. Load `azure-deploy.json`
4. Fill in parameters
5. Review and create

## Step 2: Configure Azure OpenAI

1. Navigate to your Azure OpenAI resource
2. Go to Model deployments
3. Deploy GPT-4 Turbo model with name: `gpt-4-turbo`
4. Note the endpoint and key

## Step 3: Setup GitHub Repository

1. Create new GitHub repository
2. Push code to repository:
```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/YOUR_USERNAME/ma-onboarding-ai.git
git push -u origin main
```

## Step 4: Configure GitHub Secrets

Add these secrets in GitHub repository settings:

```yaml
AZURE_STATIC_WEB_APPS_API_TOKEN: [From Static Web App deployment]
API_ENDPOINT: https://[your-static-web-app].azurestaticapps.net/api
AZURE_OPENAI_ENDPOINT: [Your OpenAI endpoint]
AZURE_OPENAI_KEY: [Your OpenAI key]
AZURE_OPENAI_DEPLOYMENT: gpt-4-turbo
COSMOS_ENDPOINT: [Your Cosmos DB endpoint]
COSMOS_KEY: [Your Cosmos DB key]
SIGNALR_CONNECTION: [Your SignalR connection string]
STORAGE_CONNECTION: [Your Storage connection string]
CONNECTWISE_URL: [Optional - Your ConnectWise URL]
CONNECTWISE_COMPANY: [Optional - Your company identifier]
CONNECTWISE_PUBLIC_KEY: [Optional - ConnectWise public key]
CONNECTWISE_PRIVATE_KEY: [Optional - ConnectWise private key]
```

## Step 5: Local Development Setup

### Install dependencies:
```bash
# Frontend
npm install

# API Functions
cd api
npm install
```

### Create local.settings.json for API:
```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "",
    "FUNCTIONS_WORKER_RUNTIME": "node",
    "AZURE_OPENAI_ENDPOINT": "",
    "AZURE_OPENAI_KEY": "",
    "AZURE_OPENAI_DEPLOYMENT": "gpt-4-turbo",
    "COSMOS_ENDPOINT": "",
    "COSMOS_KEY": "",
    "SIGNALR_CONNECTION": "",
    "STORAGE_CONNECTION": ""
  }
}
```

### Run locally:
```bash
# Terminal 1 - Start API
cd api
func start

# Terminal 2 - Start React
npm start
```

## Step 6: ConnectWise Integration (Optional)

### Configure ConnectWise API:
1. Generate API keys in ConnectWise
2. Create custom fields for M&A tracking:
   - MA_Session_ID
   - MA_Category
   - MA_Risk_Level
   - MA_Dependencies

### Configure Ticket Templates:
Create service ticket templates in ConnectWise for:
- Infrastructure Migration
- Application Migration
- Data Migration
- Security Configuration
- Communication Setup

## Step 7: Customize Discovery Templates

Edit `discoveryQuestions` in `ChatInterface.js` to match your specific M&A process:

```javascript
const discoveryQuestions = {
  infrastructure: [
    // Add your custom questions
  ],
  // ... other categories
};
```

## Usage Guide

### Starting a Discovery Session:
1. Access the application URL
2. AI will guide through discovery phases
3. Decision tree updates in real-time
4. Export or generate execution plan

### Decision Tree Features:
- **Node Colors**:
  - Blue: Active/In Progress
  - Green: Completed
  - Yellow: Pending
  - Red: Risk/Blocker

- **Edge Types**:
  - Solid: Hard dependency
  - Dashed: Can be parallel
  - Red: Risk path

### Exporting Data:
- JSON export for archival
- PDF generation for reports
- Direct ConnectWise ticket creation

## Advanced Configuration

### Custom AI Prompts:
Edit `getSystemPrompt()` in `discovery-process.js` to customize AI behavior

### Adding New Discovery Categories:
1. Update `discoveryQuestions` object
2. Add category to `completionCriteria`
3. Update tree node generation logic

### Integrating with Other Systems:
The API supports webhook endpoints for integration:
```javascript
POST /api/webhooks/discovery
POST /api/webhooks/plan
```

## Monitoring and Maintenance

### Application Insights:
1. Enable Application Insights in Static Web App
2. Monitor API performance
3. Track user sessions

### Cosmos DB Optimization:
- Monitor RU consumption
- Set up automatic scaling
- Configure backup policies

### Cost Management:
- Azure OpenAI: ~$0.03 per 1K tokens
- Cosmos DB: ~$0.008 per RU/hour
- Static Web Apps: Standard tier ~$9/month
- SignalR: ~$50/month for Standard

## Troubleshooting

### Common Issues:

1. **CORS Errors**:
   - Check Static Web App configuration
   - Verify API routes in staticwebapp.config.json

2. **OpenAI Rate Limits**:
   - Implement retry logic
   - Consider caching responses

3. **Decision Tree Not Updating**:
   - Check SignalR connection
   - Verify Cosmos DB permissions

4. **ConnectWise Integration Failures**:
   - Validate API credentials
   - Check ticket template configuration

## Security Best Practices

1. Enable Azure AD authentication
2. Use managed identities for service connections
3. Implement API rate limiting
4. Enable audit logging
5. Regular security reviews

## Support and Updates

- Check for updates: https://github.com/YOUR_ORG/ma-onboarding-ai
- Report issues: Create GitHub issue
- Documentation: See /docs folder

## Next Steps

1. Customize for your organization's M&A process
2. Train team on using the system
3. Create standard operating procedures
4. Build library of decision tree templates
5. Integrate with additional systems (Pia.AI, etc.)

---

For questions or support, contact your IT Operations team.
