const { CosmosClient } = require('@azure/cosmos');

module.exports = async function (context, req) {
    context.log('Test hello called');
    
    try {
        const cosmosEndpoint = process.env.COSMOS_ENDPOINT;
        const cosmosKey = process.env.COSMOS_KEY;
        
        if (!cosmosEndpoint || !cosmosKey) {
            context.res = {
                status: 200,
                body: 'Missing Cosmos config'
            };
            return;
        }
        
        const client = new CosmosClient({ endpoint: cosmosEndpoint, key: cosmosKey });
        const db = client.database('MAOnboarding');
        
        context.res = {
            status: 200,
            body: `Cosmos connected: ${db.id}`
        };
    } catch (error) {
        context.res = {
            status: 200,
            body: `Error: ${error.message}`
        };
    }
};
