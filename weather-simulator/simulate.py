import os
import json
import time
import requests
from azure.storage.blob import BlobServiceClient
from datetime import datetime, timedelta
import random
import math

# Load environment variables
connection_string = os.getenv("AZURE_STORAGE_CONNECTION_STRING")
container_name = os.getenv("AZURE_STORAGE_CONTAINER", "weatherdata")
dashboard_url = os.getenv("DASHBOARD_API_URL", "http://localhost/api/weather")

if not connection_string or not container_name:
    raise EnvironmentError("Missing Azure Blob Storage configuration.")

blob_service_client = BlobServiceClient.from_connection_string(connection_string)
container_client = blob_service_client.get_container_client(container_name)

# Internal simulation tracking
base_temp = 75.0
base_humidity = 60.0
base_wind = 10.0
base_pressure = 1012.0
minutes_passed = 0

def generate_weather_data(base_temp, base_humidity, base_wind, base_pressure, minutes_passed):
    cycle_fraction = (minutes_passed % 1440) / 1440
    angle = cycle_fraction * 2 * math.pi

    temp_variation = math.sin(angle) * 10
    humidity_variation = math.cos(angle) * 10
    pressure_variation = math.sin(angle + math.pi / 2) * 1.5
    wind_variation = random.uniform(-2, 2)

    temp = round(base_temp + temp_variation + random.uniform(-1, 1), 1)
    humidity = round(min(max(base_humidity + humidity_variation + random.uniform(-2, 2), 20), 100), 1)
    wind = round(max(base_wind + wind_variation, 0), 1)
    pressure = round(base_pressure + pressure_variation + random.uniform(-0.2, 0.2), 1)

    if humidity > 85 and temp < 75:
        status = "Rain"
        highalert = True
    elif wind > 25:
        status = "Windy"
        highalert = True
    elif temp > 95:
        status = "Hot"
        highalert = False
    else:
        status = "Clear"
        highalert = False

    time_stamp = (datetime.utcnow() + timedelta(minutes=minutes_passed)).strftime("%Y-%m-%d %H:%M:%S")

    return {
        "Time": time_stamp,
        "Temp": temp,
        "Humidity": humidity,
        "Wind": wind,
        "Pressure": pressure,
        "Status": status,
        "Location": "SkyPlaza",
        "highalert": highalert
    }

# Main loop
while True:
    try:
        data = generate_weather_data(base_temp, base_humidity, base_wind, base_pressure, minutes_passed)

        blob_name = f"weather-log-{int(time.time())}.json"
        blob_client = container_client.get_blob_client(blob_name)
        blob_client.upload_blob(json.dumps(data), overwrite=True)
        print(f"Uploaded: {blob_name}")

        response = requests.post(dashboard_url, json=data, timeout=5)
        if response.status_code == 200:
            print("Sent to dashboard")
        else:
            print(f"Dashboard responded: {response.status_code} - {response.text}")

    except Exception as e:
        print(f"Error: {e}")

    minutes_passed += 5
    time.sleep(4)
