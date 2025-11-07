const { CosmosClient } = require('@azure/cosmos');
const { BlobServiceClient } = require('@azure/storage-blob');

const cosmosEndpoint = process.env.COSMOS_ENDPOINT;
const cosmosKey = process.env.COSMOS_KEY;

const client = new CosmosClient({ endpoint: cosmosEndpoint, key: cosmosKey });
const database = client.database('MAOnboarding');
const container = database.container('Configurations');

module.exports = async function (context, req) {
  context.log('Saving configuration to Cosmos DB');

  const { config } = req.body || {};

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

    // Attempt blob backup if configured
    try {
      const connectionString = process.env.STORAGE_CONNECTION;
      if (connectionString) {
        const blobService = BlobServiceClient.fromConnectionString(connectionString);
        const containerName = process.env.CONFIG_BACKUP_CONTAINER || 'config-backups';
        const backups = blobService.getContainerClient(containerName);
        // Ensure container exists (no-op if already exists)
        try {
          await backups.createIfNotExists();
        } catch (e) {
          // ignore create race
        }
        const ts = new Date().toISOString().replace(/[:.]/g, '-');
        const blobName = `discovery_config-${ts}.json`;
        const blob = backups.getBlockBlobClient(blobName);
        const payload = Buffer.from(JSON.stringify(configDoc, null, 2));
        await blob.upload(payload, payload.length, {
          blobHTTPHeaders: { blobContentType: 'application/json' }
        });
        context.log(`Backup written to blob: ${containerName}/${blobName}`);
      } else {
        context.log('STORAGE_CONNECTION not set; skipping blob backup');
      }
    } catch (backupErr) {
      context.log.warn('Backup upload failed:', backupErr.message || backupErr);
    }

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
