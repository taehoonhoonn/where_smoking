const http = require('http');
const url = require('url');

function testSearchAPI() {
  const query = encodeURIComponent('강남역');
  const apiUrl = `http://localhost:3000/api/v1/places/search?query=${query}`;
  const parsedUrl = url.parse(apiUrl);

  const options = {
    hostname: parsedUrl.hostname,
    port: parsedUrl.port,
    path: parsedUrl.path,
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
    },
  };

  console.log('Testing search API:', apiUrl);

  const req = http.request(options, (res) => {
    console.log(`Status: ${res.statusCode}`);
    console.log(`Headers:`, res.headers);

    let data = '';
    res.on('data', (chunk) => {
      data += chunk;
    });

    res.on('end', () => {
      console.log('Response body:', data);
      try {
        if (data.trim()) {
          const json = JSON.parse(data);
          console.log('Parsed JSON:', JSON.stringify(json, null, 2));
        } else {
          console.log('Empty response body');
        }
      } catch (err) {
        console.log('Failed to parse JSON:', err.message);
      }
    });
  });

  req.on('error', (err) => {
    console.error('Request error:', err.message);
  });

  req.setTimeout(5000, () => {
    console.log('Request timeout');
    req.destroy();
  });

  req.end();
}

testSearchAPI();