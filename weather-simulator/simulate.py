import os
import json
import time
import requests
from azure.storage.blob import BlobServiceClient
from datetime import datetime

# Load environment variables
connection_string = os.getenv("AZURE_STORAGE_CONNECTION_STRING")
container_name = os.getenv("AZURE_STORAGE_CONTAINER", "weatherdata")
dashboard_url = os.getenv("DASHBOARD_API_URL", "http://localhost/api/weather")  # fallback for local dev

if not connection_string or not container_name:
    raise EnvironmentError("❌ Missing Azure Blob Storage configuration.")

blob_service_client = BlobServiceClient.from_connection_string(connection_string)
container_client = blob_service_client.get_container_client(container_name)

def generate_weather_data():
    return {
        "Time": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S"),
        "Temp": 85,
        "Humidity": 65,
        "Wind": 15,
        "Pressure": 1012,
        "Status": "Clear",
        "Location": "SkyPlaza",
        "highalert": False
    }

while True:
    try:
        data = generate_weather_data()

        # Upload to Blob Storage
        blob_name = f"weather-log-{int(time.time())}.json"
        blob_client = container_client.get_blob_client(blob_name)
        blob_client.upload_blob(json.dumps(data), overwrite=True)
        print(f"✅ Uploaded: {blob_name}")

        # Post to dashboard
        response = requests.post(dashboard_url, json=data, timeout=5)
        if response.status_code == 200:
            print("✅ Sent to dashboard")
        else:
            print(f"⚠️ Dashboard responded: {response.status_code} - {response.text}")

    except Exception as e:
        print(f"❌ Error: {e}")

    time.sleep(4)
