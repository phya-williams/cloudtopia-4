async function fetchData() {
    const containerUrl = "https://<your_storage_account>.blob.core.windows.net/weatherdata?restype=container&comp=list";
    const response = await fetch(containerUrl);
    const xml = await response.text();
    // Optionally parse XML and fetch individual blob JSONs to display in table
}

setInterval(fetchData, 4000);
