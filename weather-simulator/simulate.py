import time, json, random
from datetime import datetime
from azure.storage.blob import BlobServiceClient

conn_str = "your_connection_string"
container_name = "weatherdata"
blob_service = BlobServiceClient.from_connection_string(conn_str)
container_client = blob_service.get_container_client(container_name)

while True:
    now = datetime.utcnow().isoformat() + "Z"
    data = {
        "timestamp": now,
        "temperature": round(random.uniform(70, 100), 1),
        "humidity": random.randint(40, 90),
        "windSpeed": round(random.uniform(5, 25), 1),
        "windDirection": random.choice(["N", "S", "E", "W", "NE", "NW", "SE", "SW"]),
        "visibility": round(random.uniform(5, 10), 1),
        "pressure": round(random.uniform(28.5, 30.5), 1),
        "conditions": random.choice(["Sunny", "Cloudy", "Rain", "Storm", "Windy"]),
        "status": random.choice(["Clear", "Watch", "Warning"]),
        "location": "Sky Deck",
        "uploadedAt": now
    }
    blob_name = f"weather_{datetime.utcnow().timestamp()}.json"
    container_client.upload_blob(blob_name, json.dumps(data), overwrite=True)
    print(f"Uploaded: {blob_name}")
    time.sleep(4)
