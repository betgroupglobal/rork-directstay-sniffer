const formEl = document.getElementById('search-form');
const statusEl = document.getElementById('status');
const listEl = document.getElementById('results');
const metaEl = document.getElementById('meta');
const buttonEl = document.getElementById('submitBtn');
const directHuntBtnEl = document.getElementById('directHuntBtn');
const viewHuntResultsBtnEl = document.getElementById('viewHuntResultsBtn');
const loaderEl = document.getElementById('loader');
const phaseLabelEl = document.getElementById('phaseLabel');
const meterBarEl = document.getElementById('meterBar');
const terminalLogEl = document.getElementById('terminalLog');

const byId = (id) => document.getElementById(id);

const PHASES = {
  direct_hunter: ['Activating direct hunter', 'Sweeping source pages', 'Locking direct booking links', 'Ranking hunter matches'],
  crawl: ['Mapping targets', 'Probing listings', 'Scoring direct links', 'Refining top matches'],
  airbnb: ['Querying provider', 'Normalizing listing URLs', 'Filtering valid stays', 'Assembling results'],
};

const TERMINAL_STEPS = {
  direct_hunter: ['boot hunter profile', 'queue deep crawl batches', 'inspect booking path signals', 'drop OTA candidates', 'rank direct-owner pages'],
  crawl: ['seed search engine links', 'follow on-site listing links', 'extract listing metadata', 'score booking-page confidence', 'finalize result shortlist'],
  airbnb: ['send provider request', 'normalize listing records', 'validate response fields', 'compile mapped output'],
};

let progressTimer = null;
let terminalTimer = null;
let progressValue = 8;
let phaseIndex = 0;
let terminalStepIndex = 0;
let terminalUrlIndex = 0;
let terminalUrls = [];

let backgroundHuntInFlight = false;
let backgroundHuntReady = false;
let backgroundHuntItems = [];

function timestamp() {
  return new Date().toLocaleTimeString([], { hour12: false });
}

function pushTerminalLine(prefix, message) {
  if (!terminalLogEl) return;
  const line = document.createElement('div');
  line.className = 'term-line';

  const stamp = document.createElement('span');
  stamp.textContent = `[${timestamp()}] `;
  const prompt = document.createElement('b');
  prompt.textContent = prefix;
  const text = document.createElement('span');
  text.textContent = ` ${message}`;

  line.append(stamp, prompt, text);
  terminalLogEl.appendChild(line);

  while (terminalLogEl.children.length > 8) {
    terminalLogEl.removeChild(terminalLogEl.firstChild);
  }
  terminalLogEl.scrollTop = terminalLogEl.scrollHeight;
}

function buildTerminalUrls(base, endpoint, mode, payload) {
  const location = (payload?.location || '').trim();
  const urls = [`${base}${endpoint}`];
  if (!location) return urls;

  const directQuery = encodeURIComponent(`${location} direct booking holiday stay`);
  urls.push(`https://duckduckgo.com/html/?q=${directQuery}`);

  if (mode === 'direct_hunter') {
    const hunterQuery = encodeURIComponent(`${location} owner direct holiday rental official site`);
    urls.push(`https://duckduckgo.com/html/?q=${hunterQuery}`);
  }

  if (mode !== 'airbnb') {
    const redditQuery = encodeURIComponent(`${location} direct booking`);
    urls.push(`https://www.reddit.com/search/?q=${redditQuery}`);
  }

  if (mode === 'airbnb') {
    const providerQuery = encodeURIComponent(location);
    urls.push(`${base}/api/v1/airbnb/search?location=${providerQuery}`);
  }

  return urls;
}

function resetTerminal(mode, urls) {
  if (!terminalLogEl) return;
  terminalLogEl.innerHTML = '';
  terminalStepIndex = 0;
  terminalUrlIndex = 0;
  terminalUrls = urls;
  pushTerminalLine('$', 'runtime initialized');
  pushTerminalLine('>', `mode=${mode}`);
}

function refreshViewHuntButton() {
  viewHuntResultsBtnEl.disabled = !backgroundHuntReady;
  if (backgroundHuntInFlight) {
    viewHuntResultsBtnEl.textContent = 'Hunt Running...';
    viewHuntResultsBtnEl.disabled = true;
    return;
  }
  viewHuntResultsBtnEl.textContent = backgroundHuntReady ? 'View Hunt Results' : 'Await Hunt Results';
}

function stopProgress(success, silent = false) {
  if (progressTimer) {
    clearInterval(progressTimer);
    progressTimer = null;
  }
  if (terminalTimer) {
    clearInterval(terminalTimer);
    terminalTimer = null;
  }

  if (success) {
    progressValue = 100;
    meterBarEl.style.width = '100%';
    phaseLabelEl.textContent = 'Complete';
    pushTerminalLine('✓', 'scrape complete, rendering results');
    setTimeout(() => {
      loaderEl.classList.remove('active');
      loaderEl.setAttribute('aria-hidden', 'true');
    }, 350);
    return;
  }

  if (!silent) {
    pushTerminalLine('!', 'search interrupted before completion');
  }
  loaderEl.classList.remove('active');
  loaderEl.setAttribute('aria-hidden', 'true');
}

function startProgress(mode, context = {}) {
  stopProgress(false, true);
  const phases = PHASES[mode] || PHASES.crawl;
  const terminalSteps = TERMINAL_STEPS[mode] || TERMINAL_STEPS.crawl;
  progressValue = 8;
  phaseIndex = 0;

  loaderEl.classList.add('active');
  loaderEl.setAttribute('aria-hidden', 'false');
  meterBarEl.style.width = `${progressValue}%`;
  phaseLabelEl.textContent = phases[0];

  const crawlUrls = buildTerminalUrls(context.base || '', context.endpoint || '', mode, context.payload || {});
  resetTerminal(mode, crawlUrls);
  pushTerminalLine('>', phases[0]);
  if (crawlUrls.length) {
    pushTerminalLine('url', crawlUrls[0]);
    terminalUrlIndex = 1;
  }

  progressTimer = setInterval(() => {
    progressValue = Math.min(93, progressValue + 3 + Math.random() * 6);
    meterBarEl.style.width = `${Math.round(progressValue)}%`;

    if (Math.random() > 0.42 && phaseIndex < phases.length - 1) {
      phaseIndex += 1;
      phaseLabelEl.textContent = phases[phaseIndex];
      pushTerminalLine('>', phases[phaseIndex]);
    }
  }, 420);

  terminalTimer = setInterval(() => {
    const message = terminalSteps[terminalStepIndex % terminalSteps.length];
    terminalStepIndex += 1;
    pushTerminalLine('$', message);

    if (terminalUrls.length) {
      const url = terminalUrls[terminalUrlIndex % terminalUrls.length];
      terminalUrlIndex += 1;
      pushTerminalLine('url', url);
    }
  }, 780);
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

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function normalizeBaseUrl(rawBase) {
  return rawBase.trim().replace(/\/$/, '');
}

function getEndpointForMode(mode) {
  return mode === 'airbnb' ? '/api/v1/airbnb/search' : '/api/v1/crawl';
}

function applyDirectHunterDefaults(mode, payload) {
  if (mode !== 'direct_hunter') return;
  payload.direct_hunter = true;
  payload.crawl_depth = 1;
  payload.max_pages_per_source = Math.max(60, Number(payload.max_pages_per_source || 0));
  payload.exclude_ota = true;
  if (payload.whole_home !== true) payload.whole_home = true;
}

function setSearchState(isSearching, mode) {
  if (isSearching) {
    const searchingLabel = mode === 'direct_hunter' ? 'Hunting...' : 'Searching...';
    buttonEl.disabled = true;
    directHuntBtnEl.disabled = true;
    viewHuntResultsBtnEl.disabled = true;
    buttonEl.textContent = searchingLabel;
    directHuntBtnEl.textContent = searchingLabel;
    return;
  }
  buttonEl.disabled = false;
  directHuntBtnEl.disabled = backgroundHuntInFlight;
  buttonEl.textContent = 'API Search';
  directHuntBtnEl.textContent = backgroundHuntInFlight ? 'Hunting...' : 'Direct Hunt';
  refreshViewHuntButton();
}

function normalizeItems(body, mode) {
  let items = Array.isArray(body.results) ? body.results : [];
  if (mode === 'direct_hunter') {
    items = items.filter((item) => !isOtaLink(item.booking_url || item.url));
  }
  return items;
}

function buildItemMarkup(item, mode) {
  const link = item.booking_url || item.url || '';
  const title = item.title || link;
  const snippet = item.snippet || '';
  const shortDescription = (item.image_description || snippet || 'No description available.').trim();
  const priceText = (item.estimated_cost || item.price || item.price_text || 'Price unavailable').toString().trim();
  const sourceLabel = mode === 'airbnb' ? (item.source || 'airbnb') : (item.source || 'direct-hunter');
  const media = item.image_url
    ? `<img src="${escapeHtml(item.image_url)}" alt="${escapeHtml(item.image_description || title)}" loading="lazy" />`
    : '';

  return `
      ${media}
      <a href="${escapeHtml(link)}" target="_blank" rel="noopener noreferrer">${escapeHtml(title)}</a>
      <div class="result-description"><span>Description:</span> ${escapeHtml(shortDescription)}</div>
      <div class="result-price"><span>Price:</span> ${escapeHtml(priceText)}</div>
      <small>${escapeHtml(sourceLabel)}</small>
    `;
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
    li.innerHTML = buildItemMarkup(item, mode);
    listEl.appendChild(li);
  }
}

async function parseResponseBody(response) {
  try {
    return await response.json();
  } catch {
    return {};
  }
}

async function runSearchRequest(base, endpoint, payload, mode) {
  const response = await fetch(`${base}${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });

  const body = await parseResponseBody(response);
  if (!response.ok) {
    throw new Error(body.error || `Request failed (${response.status})`);
  }
  return normalizeItems(body, mode);
}

async function executeSearch(modeOverride) {
  const base = normalizeBaseUrl(byId('baseUrl').value);
  const mode = modeOverride || byId('mode').value;
  const endpoint = getEndpointForMode(mode);
  const payload = buildPayload();

  applyDirectHunterDefaults(mode, payload);

  if (!payload.location) {
    statusEl.textContent = 'Location is required.';
    return;
  }

  setSearchState(true, mode);
  statusEl.textContent = `Calling ${endpoint}...`;
  listEl.innerHTML = '';
  metaEl.textContent = '';
  startProgress(mode, { base, endpoint, payload });

  try {
    const items = await runSearchRequest(base, endpoint, payload, mode);
    metaEl.textContent = `${items.length} result(s)`;
    renderItems(items, mode);
    stopProgress(true);
  } catch (error) {
    stopProgress(false);
    statusEl.textContent = `Error: ${error.message}`;
  } finally {
    setSearchState(false, mode);
  }
}

async function runDirectHuntInBackground() {
  if (backgroundHuntInFlight) return;

  const base = normalizeBaseUrl(byId('baseUrl').value);
  const mode = 'direct_hunter';
  const endpoint = getEndpointForMode(mode);
  const payload = buildPayload();
  applyDirectHunterDefaults(mode, payload);

  if (!payload.location) {
    statusEl.textContent = 'Location is required.';
    return;
  }

  backgroundHuntInFlight = true;
  backgroundHuntReady = false;
  backgroundHuntItems = [];
  directHuntBtnEl.disabled = true;
  directHuntBtnEl.textContent = 'Hunting...';
  refreshViewHuntButton();

  statusEl.textContent = 'Direct Hunt started in background...';
  metaEl.textContent = 'Hunt in progress';
  startProgress(mode, { base, endpoint, payload });

  try {
    const items = await runSearchRequest(base, endpoint, payload, mode);
    backgroundHuntItems = items;
    backgroundHuntReady = true;
    metaEl.textContent = `${items.length} hunt result(s) ready`;
    statusEl.textContent = 'Direct Hunt complete. Click "View Hunt Results".';
    stopProgress(true);
  } catch (error) {
    stopProgress(false);
    statusEl.textContent = `Direct Hunt failed: ${error.message}`;
    metaEl.textContent = 'Hunt failed';
  } finally {
    backgroundHuntInFlight = false;
    directHuntBtnEl.disabled = false;
    directHuntBtnEl.textContent = 'Direct Hunt';
    refreshViewHuntButton();
  }
}

function showBackgroundHuntResults() {
  if (!backgroundHuntReady) {
    statusEl.textContent = 'Direct Hunt is not complete yet.';
    return;
  }
  renderItems(backgroundHuntItems, 'direct_hunter');
  metaEl.textContent = `${backgroundHuntItems.length} hunt result(s)`;
  statusEl.textContent = '';
}

formEl.addEventListener('submit', async (event) => {
  event.preventDefault();
  byId('mode').value = 'airbnb';
  await executeSearch('airbnb');
});

directHuntBtnEl.addEventListener('click', async () => {
  await runDirectHuntInBackground();
});

viewHuntResultsBtnEl.addEventListener('click', () => {
  showBackgroundHuntResults();
});

refreshViewHuntButton();
