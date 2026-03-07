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
  direct_hunter: ['Activating direct hunter', 'Sweeping source pages', 'Locking direct booking links', 'Ranking hunter matches'],
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

function isOtaLink(url) {
  return /(?:^|\.)airbnb\.|(?:^|\.)booking\.|(?:^|\.)vrbo\.|(?:^|\.)stayz\.|(?:^|\.)expedia\.|(?:^|\.)tripadvisor\.|(?:^|\.)agoda\.|(?:^|\.)wotif\./i.test(url || '');
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
    const shortDescription = (item.image_description || snippet || 'No description available.').trim();
    const priceText = (item.estimated_cost || item.price || item.price_text || 'Price unavailable').toString().trim();
    const sourceLabel = mode === 'airbnb' ? (item.source || 'airbnb') : (item.source || 'direct-hunter');
    const media = item.image_url ? `<img src="${item.image_url}" alt="${item.image_description || title}" loading="lazy" />` : '';
    li.innerHTML = `
      ${media}
      <a href="${link}" target="_blank" rel="noopener noreferrer">${title}</a>
      <div class="result-description"><span>Description:</span> ${shortDescription}</div>
      <div class="result-price"><span>Price:</span> ${priceText}</div>
      <small>${sourceLabel}</small>
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

  if (mode === 'direct_hunter') {
    payload.crawl_depth = Math.max(2, Number(payload.crawl_depth || 0));
    payload.max_pages_per_source = Math.max(35, Number(payload.max_pages_per_source || 0));
    payload.exclude_ota = true;
    if (payload.whole_home !== true) payload.whole_home = true;
  }

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
    let items = Array.isArray(body.results) ? body.results : [];
    if (mode === 'direct_hunter') {
      items = items.filter((item) => !isOtaLink(item.booking_url || item.url));
    }
    metaEl.textContent = `${items.length} result(s)`;
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
