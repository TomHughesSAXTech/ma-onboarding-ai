const { CosmosClient } = require('@azure/cosmos');
const { v4: uuidv4 } = require('uuid');

const cosmosEndpoint = process.env.COSMOS_ENDPOINT;
const cosmosKey = process.env.COSMOS_KEY;
const cosmosClient = new CosmosClient({ endpoint: cosmosEndpoint, key: cosmosKey });
const database = cosmosClient.database('MAOnboarding');
const container = database.container('Sessions');

module.exports = async function (context, req) {
    try {
        const body = req.body;
        const sessionId = uuidv4();
        
        const sessionData = {
            id: sessionId,
            sessionId,
            type: body.type || 'ma-onboarding',
            createdAt: new Date().toISOString(),
            discoveryData: {},
            messages: [],
            status: 'active'
        };

        await container.items.create(sessionData);
        
        context.res = {
            status: 200,
            body: { sessionId }
        };
    } catch (error) {
        context.log.error('Error initializing session:', error);
        context.res = {
            status: 500,
            body: { error: 'Failed to initialize session' }
        };
    }
};
