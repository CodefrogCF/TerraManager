/* Evaluation-only browser workload. No credentials or collection bodies in reports. */
(() => {
  let mode, view, cursor, timer, source, socket, stopped = true, busy = false;
  let queue = Promise.resolve();
  let cache = {}, expected = new Map(), observations = new Map(), baselineRenders = 0;
  let counters, lastSignature = '';
  const overview = ['/api/v1/boxes', '/api/v1/animals', '/api/v1/reminders'];
  const details = ['/api/v1/animals/1', '/api/v1/animals/1/feedings',
    '/api/v1/animals/1/weights', '/api/v1/animals/1/shedding',
    '/api/v1/boxes', '/api/v1/animals'];
  const status = document.getElementById('status');

  async function request(path, headers = {}) {
    counters.requests++;
    const response = await fetch(path, {cache: 'no-store', credentials: 'same-origin', headers});
    counters.statuses[response.status] = (counters.statuses[response.status] || 0) + 1;
    if (response.status === 304) return null;
    const text = await response.text();
    counters.completedBodyBytes += new TextEncoder().encode(text).length;
    if (!response.ok) throw new Error('HTTP ' + response.status);
    return JSON.parse(text);
  }
  function findMarkers(value, result = new Set()) {
    if (Array.isArray(value)) value.forEach(item => findMarkers(item, result));
    else if (value && typeof value === 'object') {
      for (const [key, item] of Object.entries(value)) {
        if ((key === 'fedAt' || key === 'latestFeedingAt') && typeof item === 'string') {
          const timestamp = Date.parse(item);
          if (expected.has(timestamp)) result.add(timestamp);
        } else if (item && typeof item === 'object') findMarkers(item, result);
      }
    }
    return result;
  }
  async function refresh(domains = null) {
    let paths = [...overview, ...(view === 'detail-stack' ? details : [])];
    if (domains) {
      paths = [...new Set(paths)].filter(path =>
        (domains.has('animals') && path === '/api/v1/animals') ||
        (domains.has('reminders') && path === '/api/v1/reminders') ||
        (domains.has('feedings') && path.endsWith('/1/feedings')));
    }
    // Home fetches three lists in parallel. Detail requests model the existing
    // six-request navigation workload; this is not Flutter frame profiling.
    if (!domains) {
      const first = await Promise.all(overview.map(path => request(path)));
      first.forEach((data, index) => { cache[overview[index]] = data; });
      if (view === 'detail-stack') {
        for (const path of details) cache[path] = await request(path);
      }
    } else {
      await Promise.all(paths.map(async path => { cache[path] = await request(path); }));
    }
    const signature = JSON.stringify(cache);
    if (mode === 'polling' || signature !== lastSignature) {
      counters.domUpdates++;
      status.textContent = mode + ': refresh ' + counters.domUpdates +
        ', applied cursor ' + (cursor || 'initial') + ', requests ' + counters.requests;
      lastSignature = signature;
      const markers = findMarkers(cache);
      await new Promise(resolve => requestAnimationFrame(() => {
        for (const marker of markers) {
          if (!observations.has(marker)) observations.set(marker, Date.now() - expected.get(marker));
        }
        resolve();
      }));
    }
  }
  function update(message) {
    counters.signals++;
    queue = queue.then(async () => {
      if (stopped || (message.cursor === cursor && !message.reset)) return;
      const domains = message.reset ? null :
        new Set(message.events.flatMap(event => event.domains));
      await refresh(domains);
      cursor = message.cursor; // Application cursor advances after successful refresh.
    }).catch(() => { counters.errors++; });
    return queue;
  }
  async function poll(long) {
    if (stopped || busy) return;
    busy = true;
    try {
      if (mode === 'polling') await refresh();
      else {
        const message = await request('/evaluation/changes?after=' +
          encodeURIComponent(cursor) + (long ? '&wait=1' : ''), {'If-None-Match': '"' + cursor + '"'});
        if (message) await update(message);
      }
    } catch (_) { if (!stopped) counters.errors++; }
    finally { busy = false; }
    if (long && !stopped) timer = setTimeout(() => poll(true), 0);
  }
  function emptyCounters() {
    return {requests: 0, completedBodyBytes: 0, statuses: {}, domUpdates: 0,
      signals: 0, errors: 0};
  }

  window.evaluation = {
    async start(config) {
      if (!['polling', 'version-polling', 'long-polling', 'sse', 'websocket'].includes(config.mode))
        throw new Error('Unknown mode');
      if (!['overview', 'detail-stack'].includes(config.view)) throw new Error('Unknown view');
      mode = config.mode; view = config.view; stopped = false;
      counters = emptyCounters(); cache = {}; lastSignature = '';
      expected = new Map(); observations = new Map(); queue = Promise.resolve();
      const state = await request('/evaluation/state');
      if (state.kind !== 'disposable-transport-lab') throw new Error('Not an evaluation lab');
      cursor = state.cursor;
      await refresh();
      if (mode === 'sse') {
        await new Promise((resolve, reject) => {
          source = new EventSource('/evaluation/events?after=' + encodeURIComponent(cursor));
          source.addEventListener('open', resolve, {once: true});
          source.addEventListener('changes', event => update(JSON.parse(event.data)));
          source.addEventListener('session-expired', () => { counters.errors++; source.close(); });
          source.onerror = () => { counters.errors++; reject(new Error('SSE connection failed')); };
        });
      } else if (mode === 'websocket') {
        await new Promise((resolve, reject) => {
          const url = new URL('/evaluation/socket', location.href);
          url.protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
          url.searchParams.set('after', cursor);
          socket = new WebSocket(url);
          socket.onopen = resolve;
          socket.onmessage = event => update(JSON.parse(event.data));
          socket.onerror = () => { counters.errors++; reject(new Error('WebSocket failed')); };
        });
      } else if (mode === 'long-polling') void poll(true);
      else timer = setInterval(() => void poll(false), config.pollMs);
      await queue;
      baselineRenders = counters.domUpdates;
      counters = emptyCounters(); // Initial snapshot/login is warm-up, not idle traffic.
      return {cursor, fixture: state.fixture, initialDomUpdates: baselineRenders};
    },
    beginMeasurement() { counters = emptyCounters(); },
    expect(timestamp, startedAt) { expected.set(timestamp, startedAt); },
    async stop() {
      stopped = true; clearInterval(timer); clearTimeout(timer);
      if (source) source.close();
      if (socket) socket.close();
      await queue;
      return {...counters,
        observedChanges: observations.size, expectedChanges: expected.size,
        writeStartToLabDomMs: [...observations.values()],
        missingMarkers: [...expected.keys()].filter(marker => !observations.has(marker)),
      };
    },
  };
})();

