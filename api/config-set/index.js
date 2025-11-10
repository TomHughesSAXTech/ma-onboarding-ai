const { CosmosClient } = require('@azure/cosmos');
let BlobServiceClient;
try {
  ({ BlobServiceClient } = require('@azure/storage-blob'));
} catch (e) {
  // storage SDK not available locally; backup step will be skipped
}

const cosmosEndpoint = process.env.COSMOS_ENDPOINT;
const cosmosKey = process.env.COSMOS_KEY;

const client = new CosmosClient({ endpoint: cosmosEndpoint, key: cosmosKey });
const database = client.database('MAOnboarding');
const container = database.container('Configurations');

async function backupToBlob(context, configDoc) {
  try {
    const conn = process.env.STORAGE_CONNECTION || process.env.AZURE_STORAGE_CONNECTION_STRING;
    if (!BlobServiceClient || !conn) {
      context.log('[config-set] Storage backup skipped (no SDK or connection string)');
      return;
    }
    const service = BlobServiceClient.fromConnectionString(conn);
    const containerClient = service.getContainerClient('config-backups');
    try { await containerClient.createIfNotExists({ access: 'container' }); } catch {}
    const ts = new Date().toISOString().replace(/[:.]/g, '-');
    const blobName = `${ts}-discovery_config.json`;
    const blobClient = containerClient.getBlockBlobClient(blobName);
    const body = JSON.stringify(configDoc, null, 2);
    await blobClient.upload(body, Buffer.byteLength(body), { blobHTTPHeaders: { blobContentType: 'application/json' } });
    context.log(`[config-set] Backup written to blob ${blobName}`);
  } catch (err) {
    context.log.warn('[config-set] Backup to blob failed:', err.message);
  }
}

module.exports = async function (context, req) {
  context.log('Saving configuration to Cosmos DB');

  const { config } = req.body;

  if (!config) {
    context.res = {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
      body: { error: 'Configuration is required' }
    };
    return;
  }

  // Validate configuration structure
  if (!config.categories || !Array.isArray(config.categories)) {
    context.res = {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
      body: { error: 'Invalid configuration: categories array is required' }
    };
    return;
  }

  try {
    const configDoc = {
      id: 'discovery_config',
      data: config,
      updatedAt: new Date().toISOString()
    };

    // Upsert configuration (create or update)
    await container.items.upsert(configDoc);

    // best-effort backup to blob storage
    await backupToBlob(context, configDoc);

    context.res = {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
      body: { success: true, message: 'Configuration saved successfully' }
    };
  } catch (error) {
    context.log.error('Error saving configuration:', error);
    context.res = {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
      body: { error: 'Failed to save configuration' }
    };
  }
};
