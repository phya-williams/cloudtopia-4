const express = require('express');
const { BlobServiceClient } = require('@azure/storage-blob');
const app = express();
const port = 80;

const connectionString = process.env.AZURE_STORAGE_CONNECTION_STRING;
const containerName = process.env.AZURE_STORAGE_CONTAINER || 'weatherdata';
const blobName = 'weather-log-latest.json';

app.get('/api/weather', async (req, res) => {
  try {
    const blobService = BlobServiceClient.fromConnectionString(connectionString);
    const containerClient = blobService.getContainerClient(containerName);
    const blockBlobClient = containerClient.getBlockBlobClient(blobName);

    const downloadResponse = await blockBlobClient.download(0);
    const content = await streamToString(downloadResponse.readableStreamBody);
    res.setHeader('Content-Type', 'application/json');
    res.send(content);
  } catch (err) {
    console.error("Failed to fetch blob:", err.message);
    res.status(500).send({ error: "Failed to retrieve weather data." });
  }
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
app.listen(port, () => console.log(`🌦️ Weather dashboard API running on port ${port}`));
