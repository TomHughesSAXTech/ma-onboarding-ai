// Azure Functions v2 programming model for Static Web Apps
module.exports = async function (context, req) {
    context.log('session-init called');
    
    const sessionId = 'test-' + Date.now();
    
    // V2 format: set context.res directly
    context.res = {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: { sessionId, message: 'Test response v2' }
    };
};
};
