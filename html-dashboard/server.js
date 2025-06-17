const express = require('express');
const { BlobServiceClient } = require('@azure/storage-blob');
const app = express();
const port = 80;

// Load environment variables
const connectionString = process.env.AZURE_STORAGE_CONNECTION_STRING;
const containerName = process.env.AZURE_STORAGE_CONTAINER || 'weatherdata';

console.log("🚀 Starting dashboard API...");
console.log("📦 AZURE_STORAGE_CONNECTION_STRING:", connectionString ? "✅ Loaded" : "❌ MISSING");
console.log("📦 AZURE_STORAGE_CONTAINER:", containerName);

if (!connectionString || !containerName) {
  console.error("❌ Missing required storage environment variables.");
  process.exit(1);
}

const blobService = BlobServiceClient.fromConnectionString(connectionString);
const containerClient = blobService.getContainerClient(containerName);

app.get('/api/weather', async (req, res) => {
  try {
    // Try to get 'weather-log-latest.json'
    const blobName = 'weather-log-latest.json';
    const blobClient = containerClient.getBlockBlobClient(blobName);

    if (!(await blobClient.exists())) {
      // fallback to newest available blob
      console.warn("⚠️ 'weather-log-latest.json' not found. Searching for latest blob...");
      let latestBlob = null;
      let latestTime = 0;

      for await (const blob of containerClient.listBlobsFlat()) {
        const match = blob.name.match(/weather-log-(\d+)\.json/);
        if (match) {
          const timestamp = parseInt(match[1]);
          if (timestamp > latestTime) {
            latestTime = timestamp;
            latestBlob = blob.name;
          }
        }
      }

      if (!latestBlob) {
        return res.status(404).send({ error: "No logs available." });
      }

      const fallbackBlob = containerClient.getBlockBlobClient(latestBlob);
      const download = await fallbackBlob.download(0);
      const content = await streamToString(download.readableStreamBody);
      return res.json(JSON.parse(content));
    }

    // Normal case: blob exists
    const downloadResponse = await blobClient.download(0);
    const content = await streamToString(downloadResponse.readableStreamBody);
    res.json(JSON.parse(content));
  } catch (err) {
    console.error("❌ Failed to fetch blob:", err);
    res.status(500).send({ error: "Failed to retrieve weather data." });
  }
});

app.get('/health', (req, res) => {
  res.send("✅ CloudTopia Weather API is running");
});

function streamToString(readableStream) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    readableStream.on('data', (data) => chunks.push(data.toString()));
    readableStream.on('end', () => resolve(chunks.join('')));
    readableStream.on('error', reject);
  });
}

app.use(express.static('public'));
app.listen(port, () => {
  console.log(`🌤️ Weather dashboard is listening on port ${port}`);
});
