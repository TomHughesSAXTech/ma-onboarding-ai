const { app } = require('@azure/functions');

app.http('sessionInit', {
    methods: ['POST'],
    authLevel: 'anonymous',
    handler: async (request, context) => {
        try {
            context.log('session-init called');
            
            const sessionId = 'test-' + Date.now();
            
            return {
                status: 200,
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ 
                    sessionId: sessionId,
                    message: 'Test response v4' 
                })
            };
        } catch (error) {
            context.log.error('Error:', error);
            return {
                status: 500,
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ error: error.message })
            };
        }
    }
});
};
