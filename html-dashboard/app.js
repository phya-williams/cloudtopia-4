async function fetchData() {
  const response = await fetch('/api/weather'); // served via proxy below
  const logs = await response.json();

  const tableBody = document.querySelector('#weather-table tbody');
  tableBody.innerHTML = ''; // Clear previous data

  logs.slice(-10).reverse().forEach(log => {
    const row = document.createElement('tr');
    row.innerHTML = `
      <td>${log.timestamp}</td>
      <td>${log.temperature}°F</td>
      <td>${log.humidity}%</td>
      <td>${log.windSpeed} ${log.windDirection}</td>
      <td>${log.pressure} in</td>
      <td>${log.status}</td>
      <td>${log.location}</td>
    `;
    tableBody.appendChild(row);
  });
}

setInterval(fetchData, 4000);
