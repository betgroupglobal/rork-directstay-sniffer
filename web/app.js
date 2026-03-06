const formEl = document.getElementById('search-form');
const statusEl = document.getElementById('status');
const listEl = document.getElementById('results');
const metaEl = document.getElementById('meta');
const buttonEl = document.getElementById('submitBtn');
const loaderEl = document.getElementById('loader');
const phaseLabelEl = document.getElementById('phaseLabel');
const meterBarEl = document.getElementById('meterBar');

const byId = (id) => document.getElementById(id);

const PHASES = {
  crawl: ['Mapping targets', 'Probing listings', 'Scoring direct links', 'Refining top matches'],
  airbnb: ['Querying provider', 'Normalizing listing URLs', 'Filtering valid stays', 'Assembling results'],
};

let progressTimer = null;
let progressValue = 8;
let phaseIndex = 0;

function stopProgress(success) {
  if (progressTimer) {
    clearInterval(progressTimer);
    progressTimer = null;
  }

  if (success) {
    progressValue = 100;
    meterBarEl.style.width = '100%';
    phaseLabelEl.textContent = 'Complete';
    setTimeout(() => {
      loaderEl.classList.remove('active');
      loaderEl.setAttribute('aria-hidden', 'true');
    }, 350);
    return;
  }

  loaderEl.classList.remove('active');
  loaderEl.setAttribute('aria-hidden', 'true');
}

function startProgress(mode) {
  stopProgress(false);
  const phases = PHASES[mode] || PHASES.crawl;
  progressValue = 8;
  phaseIndex = 0;

  loaderEl.classList.add('active');
  loaderEl.setAttribute('aria-hidden', 'false');
  meterBarEl.style.width = `${progressValue}%`;
  phaseLabelEl.textContent = phases[0];

  progressTimer = setInterval(() => {
    progressValue = Math.min(93, progressValue + 3 + Math.random() * 6);
    meterBarEl.style.width = `${Math.round(progressValue)}%`;

    if (Math.random() > 0.42 && phaseIndex < phases.length - 1) {
      phaseIndex += 1;
      phaseLabelEl.textContent = phases[phaseIndex];
    }
  }, 420);
}

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

formEl.addEventListener('submit', async (event) => {
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
  startProgress(mode);

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
    stopProgress(true);
  } catch (error) {
    stopProgress(false);
    statusEl.textContent = `Error: ${error.message}`;
  } finally {
    buttonEl.disabled = false;
    buttonEl.textContent = 'Search';
  }
});
