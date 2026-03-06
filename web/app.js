const form = document.getElementById('search-form');
const statusEl = document.getElementById('status');
const listEl = document.getElementById('results');
const metaEl = document.getElementById('meta');
const buttonEl = document.getElementById('submitBtn');

const byId = (id) => document.getElementById(id);

function buildPayload() {
  const payload = {
    location: byId('location').value.trim(),
    max_results: Number(byId('maxResults').value || 30),
  };
  const optionalInt = ['guests', 'bedrooms', 'bathrooms'];
  for (const key of optionalInt) {
    const value = byId(key).value;
    if (value !== '') payload[key] = Number(value);
  }
  const checkIn = byId('checkIn').value;
  const checkOut = byId('checkOut').value;
  if (checkIn) payload.check_in = checkIn;
  if (checkOut) payload.check_out = checkOut;
  if (byId('petFriendly').checked) payload.pet_friendly = true;
  if (byId('wholeHome').checked) payload.whole_home = true;
  return payload;
}

function renderItems(items, mode) {
  listEl.innerHTML = '';
  if (!items.length) {
    statusEl.textContent = 'No results found.';
    return;
  }
  statusEl.textContent = '';
  for (const item of items) {
    const li = document.createElement('li');
    const link = item.booking_url || item.url;
    const title = item.title || link;
    const snippet = item.snippet || '';
    li.innerHTML = `
      <a href="${link}" target="_blank" rel="noopener noreferrer">${title}</a>
      <div>${snippet}</div>
      <small>${mode === 'crawl' ? (item.source || 'crawl') : (item.source || 'airbnb')}</small>
    `;
    listEl.appendChild(li);
  }
}

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  const base = byId('baseUrl').value.replace(/\/$/, '');
  const mode = byId('mode').value;
  const endpoint = mode === 'airbnb' ? '/api/v1/airbnb/search' : '/api/v1/crawl';
  const payload = buildPayload();

  if (!payload.location) {
    statusEl.textContent = 'Location is required.';
    return;
  }

  buttonEl.disabled = true;
  buttonEl.textContent = 'Searching...';
  statusEl.textContent = `Calling ${endpoint}...`;
  listEl.innerHTML = '';
  metaEl.textContent = '';

  try {
    const response = await fetch(`${base}${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    const body = await response.json();
    if (!response.ok) {
      throw new Error(body.error || `Request failed (${response.status})`);
    }
    const items = Array.isArray(body.results) ? body.results : [];
    metaEl.textContent = `${body.total ?? items.length} result(s)`;
    renderItems(items, mode);
  } catch (error) {
    statusEl.textContent = `Error: ${error.message}`;
  } finally {
    buttonEl.disabled = false;
    buttonEl.textContent = 'Search';
  }
});
