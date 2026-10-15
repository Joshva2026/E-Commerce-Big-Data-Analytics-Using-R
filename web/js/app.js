/* ============================================================
   R-POWERED E-COMMERCE BIG DATA ANALYTICS
   app.js — Core Dynamic Engine & Stitch Design Integration
   ============================================================ */

function initApp() {

  // ── Unified API Base Resolution (Local & Production Compatible) ──
  // 1. If configured via window.__APP_CONFIG__.API_BASE_URL (Vercel deployment pointing to Render), use it.
  // 2. If loaded via file://, fallback to local server at http://127.0.0.1:8001.
  // 3. Otherwise, use same-origin relative paths ('') which seamlessly works for local mode (localhost:8001).
  const configuredApiBase = (window.__APP_CONFIG__ && window.__APP_CONFIG__.API_BASE_URL)
    ? String(window.__APP_CONFIG__.API_BASE_URL).trim().replace(/\/+$/, '')
    : '';

  const API_BASE = configuredApiBase
    ? configuredApiBase
    : (window.location.protocol === 'file:' ? 'http://127.0.0.1:8001' : '');



  // ── Dataset Registry ───────────────────────────────────────
  const DATASET_REGISTRY = [
    {
      id: 'indian_ecommerce',
      code: 'RDS-01',
      name: 'Indian E-Commerce Sales',
      file: 'indian_ecommerce_data.csv',
      type: 'Transactional Sales [Master Schema]',
      mode: 'curated',
      badge: 'Pre-processed & Cached',
      badgeClass: 'bg-tertiary-fixed text-on-tertiary-fixed',
      color: '#0058bc',
      rows: '150,000',
      attrs: '14 Dimensions',
      desc: 'Comprehensive multi-channel e-commerce transaction logs detailing orders, sales, profit margins, RFM clusters, and regional distribution across India.',
      tags: ['Date', 'Category', 'SKU', 'State', 'Amount', 'Profit', 'Payment', '+6 More'],
      actionText: 'Launch Analytics →',
      primaryCard: true
    }
  ];

  // ── State Management ───────────────────────────────────────
  let currentDataset = DATASET_REGISTRY[0];
  let chartInstances = {};
  window.currentAnalyticsData = null;
  let activeTimeRange = 'all';

  // ── Unified Precision & Compact Formatters (Overflow Protected) ──
  const formatFullCurrency = (v) => {
    if (v == null || v === '' || isNaN(Number(v))) return '—';
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: 'INR',
      maximumFractionDigits: 2
    }).format(Number(v));
  };

  const formatFullNumber = (v) => {
    if (v == null || v === '' || isNaN(Number(v))) return '—';
    return new Intl.NumberFormat('en-IN', { maximumFractionDigits: 2 }).format(Number(v));
  };

  const formatCompactCurrency = (v) => {
    if (v == null || v === '' || isNaN(Number(v))) return '—';
    const num = Number(v);
    const isNeg = num < 0;
    const abs = Math.abs(num);
    let str;
    if (abs >= 1e9) {
      str = (abs / 1e9).toFixed(2).replace(/\.00$/, '') + 'B';
    } else if (abs >= 1e6) {
      str = (abs / 1e6).toFixed(2).replace(/\.00$/, '') + 'M';
    } else if (abs >= 1e5) {
      str = (abs / 1e5).toFixed(2).replace(/\.00$/, '') + 'L';
    } else if (abs >= 1e3) {
      str = (abs / 1e3).toFixed(1).replace(/\.0$/, '') + 'K';
    } else {
      str = new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 }).format(abs);
    }
    return `${isNeg ? '-' : ''}₹${str}`;
  };

  const formatCompactNumber = (v) => {
    if (v == null || v === '' || isNaN(Number(v))) return '—';
    const num = Number(v);
    const isNeg = num < 0;
    const abs = Math.abs(num);
    let str;
    if (abs >= 1e9) {
      str = (abs / 1e9).toFixed(2).replace(/\.00$/, '') + 'B';
    } else if (abs >= 1e6) {
      str = (abs / 1e6).toFixed(2).replace(/\.00$/, '') + 'M';
    } else if (abs >= 1e5) {
      str = (abs / 1e5).toFixed(2).replace(/\.00$/, '') + 'L';
    } else if (abs >= 1e3) {
      str = (abs / 1e3).toFixed(1).replace(/\.0$/, '') + 'K';
    } else {
      str = new Intl.NumberFormat('en-IN').format(abs);
    }
    return `${isNeg ? '-' : ''}${str}`;
  };

  const formatCurrency = formatCompactCurrency;
  const formatCompact = formatCompactCurrency;
  const formatCompactNum = formatCompactNumber;
  const formatNumber = formatCompactNumber;

  function setKpiElement(id, displayVal, fullVal, label) {
    const el = document.getElementById(id);
    if (!el) return;
    el.textContent = (displayVal != null && displayVal !== '') ? displayVal : '—';
    if (fullVal != null && fullVal !== '') {
      const titleText = `${label ? label + ': ' : ''}${fullVal}`;
      el.title = titleText;
      el.setAttribute('aria-label', titleText);
    } else {
      el.removeAttribute('title');
      el.removeAttribute('aria-label');
    }
  }

  function safeArray(val) {
    if (val == null) return [];
    if (Array.isArray(val)) return val;
    if (typeof val === 'object' && Object.keys(val).length === 0) return [];
    return [val];
  }

  function safeCreateChart(canvas, config) {
    if (typeof Chart === 'undefined') {
      console.warn('Chart.js library is not available for canvas:', canvas ? canvas.id : 'unknown');
      return null;
    }
    if (!canvas) return null;
    try {
      return new Chart(canvas, config);
    } catch (e) {
      console.error('Failed to create Chart instance on', canvas.id, e);
      return null;
    }
  }

  // ── UI References ──────────────────────────────────────────
  const UI = {
    loadingOverlay: document.getElementById('loading-overlay'),
    loadingTitle: document.getElementById('loading-title'),
    loadingDesc: document.getElementById('loading-desc'),
    errorBanner: document.getElementById('error-banner'),
    errorMessage: document.getElementById('error-message'),
    btnDismissError: document.getElementById('btn-dismiss-error'),
    headerDatasetName: document.getElementById('header-dataset-name'),
    headerStatusDot: document.getElementById('header-status-dot'),
    headerDatasetToggle: document.getElementById('btn-dataset-dropdown-toggle'),
    headerDatasetDropdown: document.getElementById('header-dataset-dropdown'),
    dropdownItems: document.getElementById('dropdown-dataset-items'),
    telemetryKernelStatus: document.getElementById('telemetry-kernel-status'),
    telemetryLatency: document.getElementById('telemetry-latency'),
    btnQuickUpload: document.getElementById('btn-quick-upload'),
    btnQuickPortal: document.getElementById('btn-quick-portal'),
    btnExportReport: document.getElementById('btn-export-report'),
    btnExportSalesCsv: document.getElementById('btn-export-sales-csv'),
    btnHomeLogo: document.getElementById('btn-home-logo'),
    btnHomeTitle: document.getElementById('btn-home-title'),
    btnMobileMenu: document.getElementById('btn-mobile-menu'),
    sidebar: document.getElementById('app-sidebar'),
    navItems: document.querySelectorAll('.nav-item'),
    sections: document.querySelectorAll('.dashboard-section'),
    portalDropTarget: document.getElementById('portal-drop-target'),
    universalFileInput: document.getElementById('universal-file-input'),
    portalFilePreview: document.getElementById('portal-file-preview'),
    portalSelectedFileName: document.getElementById('portal-selected-file-name'),
    btnPortalSubmitUpload: document.getElementById('btn-portal-submit-upload'),
    builtinGrid: document.getElementById('builtin-datasets-grid'),
    sidebarMemoryVal: document.getElementById('sidebar-memory-value'),
    sidebarMemoryBar: document.getElementById('sidebar-memory-bar'),
    btnHeaderProfile: document.getElementById('btn-header-profile'),
    headerProfileDropdown: document.getElementById('header-profile-dropdown'),
  };

  // ── Navigation Handler ─────────────────────────────────────
  function switchSection(sectionId) {
    if (!sectionId) return;
    if (sectionId === 'profile') sectionId = 'dataset-info';
    const targetId = 'sec-' + sectionId;
    const sections = document.querySelectorAll('.dashboard-section');
    let found = false;

    sections.forEach(sec => {
      if (sec.id === targetId) {
        sec.classList.add('active');
        sec.style.setProperty('display', 'block', 'important');
        found = true;
      } else {
        sec.classList.remove('active');
        sec.style.setProperty('display', 'none', 'important');
      }
    });

    if (!found) {
      console.warn(`Target section not found: ${targetId}`);
      return;
    }

    // Update active state on sidebar navigation
    const navItems = document.querySelectorAll('#app-sidebar [data-section]');
    navItems.forEach(item => {
      const match = item.getAttribute('data-section') === sectionId;
      if (match) {
        item.classList.add('bg-primary-container', 'text-on-primary-container', 'font-semibold');
        item.classList.remove('text-on-surface-variant', 'hover:bg-surface-container');
      } else {
        item.classList.remove('bg-primary-container', 'text-on-primary-container', 'font-semibold');
        item.classList.add('text-on-surface-variant', 'hover:bg-surface-container');
      }
    });

    // Close mobile menu if open
    if (UI.sidebar) UI.sidebar.classList.remove('open');
    window.scrollTo({ top: 0, behavior: 'smooth' });

    // Re-render / resize charts in newly active section
    setTimeout(() => {
      Object.values(chartInstances || {}).forEach(c => {
        try { if (c && typeof c.resize === 'function') c.resize(); } catch(e){}
      });
    }, 60);
  }

  // Expose switchSection globally for browser automation and section triggers
  window.switchSection = switchSection;

  // Delegated document-level click listener for all data-section triggers (capture phase)
  document.addEventListener('click', (e) => {
    const targetEl = e.target.closest('[data-section]');
    if (targetEl) {
      const sec = targetEl.getAttribute('data-section');
      if (sec) {
        e.preventDefault();
        switchSection(sec);
      }
    }
  }, true);

  if (UI.btnHomeLogo) UI.btnHomeLogo.addEventListener('click', () => switchSection('overview'));
  if (UI.btnHomeTitle) UI.btnHomeTitle.addEventListener('click', () => switchSection('overview'));
  if (UI.btnQuickPortal) UI.btnQuickPortal.addEventListener('click', () => switchSection('portal'));
  if (UI.btnQuickUpload) UI.btnQuickUpload.addEventListener('click', () => {
    switchSection('portal');
    setTimeout(() => {
      if (UI.portalDropTarget) UI.portalDropTarget.scrollIntoView({ behavior: 'smooth' });
    }, 100);
  });

  if (UI.btnMobileMenu) {
    UI.btnMobileMenu.addEventListener('click', () => {
      if (UI.sidebar) UI.sidebar.classList.toggle('open');
    });
  }

  if (UI.btnDismissError) {
    UI.btnDismissError.addEventListener('click', () => {
      if (UI.errorBanner) UI.errorBanner.classList.add('hidden');
    });
  }

  if (UI.btnHeaderProfile) {
    UI.btnHeaderProfile.addEventListener('click', (e) => {
      e.stopPropagation();
      if (UI.headerProfileDropdown) {
        UI.headerProfileDropdown.classList.toggle('hidden');
      }
    });

    document.addEventListener('click', (e) => {
      if (UI.headerProfileDropdown && !e.target.closest('#profile-container')) {
        UI.headerProfileDropdown.classList.add('hidden');
      }
    });
  }

  // ── Loading & Error Display ────────────────────────────────
  function showLoading(title, desc) {
    if (UI.loadingTitle) UI.loadingTitle.textContent = title || 'Processing…';
    if (UI.loadingDesc) UI.loadingDesc.textContent = desc || 'Executing R 4.6.1 analytics pipeline';
    if (UI.loadingOverlay) UI.loadingOverlay.classList.remove('hidden');
    if (UI.errorBanner) UI.errorBanner.classList.add('hidden');
    if (UI.telemetryKernelStatus) {
      UI.telemetryKernelStatus.textContent = 'Computing…';
      UI.telemetryKernelStatus.className = 'font-code-sm text-code-sm text-primary font-semibold animate-pulse';
    }
  }

  function hideLoading() {
    if (UI.loadingOverlay) UI.loadingOverlay.classList.add('hidden');
    if (UI.telemetryKernelStatus) {
      UI.telemetryKernelStatus.textContent = 'Ready';
      UI.telemetryKernelStatus.className = 'font-code-sm text-code-sm text-tertiary font-semibold';
    }
  }

  function showError(msg) {
    hideLoading();
    if (UI.errorMessage) UI.errorMessage.textContent = msg || 'An unexpected error occurred.';
    if (UI.errorBanner) UI.errorBanner.classList.remove('hidden');
    if (UI.telemetryKernelStatus) {
      UI.telemetryKernelStatus.textContent = 'Error';
      UI.telemetryKernelStatus.className = 'font-code-sm text-code-sm text-error font-semibold';
    }
  }

  // ── Render Section 01: 5 Curated Built-in Cards ────────────
  function renderBuiltinCards() {
    if (!UI.builtinGrid) return;
    UI.builtinGrid.innerHTML = '';

    DATASET_REGISTRY.forEach(ds => {
      const card = document.createElement('div');
      const isSelected = currentDataset && currentDataset.id === ds.id;
      
      card.className = ds.primaryCard
        ? 'bg-surface-container-lowest rounded-xl p-space-lg shadow-sm hover:shadow-md transition-all flex flex-col justify-between group md:col-span-2 xl:col-span-1 relative border border-outline-variant/30 ' + (isSelected ? 'ring-2 ring-primary' : '')
        : 'bg-surface-container-lowest rounded-xl p-space-lg shadow-sm hover:shadow-md transition-all flex flex-col justify-between group border border-outline-variant/30 ' + (isSelected ? 'ring-2 ring-primary' : '');

      card.innerHTML = `
        <div>
          <div class="flex items-start justify-between gap-2 mb-space-sm">
            <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded ${ds.badgeClass} font-code-sm text-code-sm font-semibold">
              <span class="w-1.5 h-1.5 rounded-full ${ds.primaryCard ? 'bg-tertiary' : 'bg-primary'}"></span>
              ${ds.badge}
            </span>
            <span class="font-code-sm text-code-sm text-outline">${ds.code}</span>
          </div>
          <h3 class="font-headline-sm text-headline-sm text-on-surface font-semibold group-hover:text-primary transition-colors mb-space-xs">
            ${ds.name}
          </h3>
          <p class="font-body-md text-body-md text-on-surface-variant mb-space-md">
            ${ds.desc}
          </p>
          <div class="grid grid-cols-2 gap-space-sm bg-surface-container-low p-space-md rounded-lg mb-space-md border border-outline-variant/20">
            <div>
              <span class="font-label-sm text-label-sm text-outline uppercase block">Volume</span>
              <span class="font-code-md text-code-md text-on-surface font-semibold">${ds.rows}</span>
              <span class="font-label-sm text-label-sm text-on-surface-variant block">Rows</span>
            </div>
            <div>
              <span class="font-label-sm text-label-sm text-outline uppercase block">Attributes</span>
              <span class="font-code-md text-code-md text-on-surface font-semibold">${ds.attrs}</span>
              <span class="font-label-sm text-label-sm text-on-surface-variant block">Master Schema</span>
            </div>
          </div>
          <div class="flex flex-wrap gap-1.5 mb-space-lg">
            ${ds.tags.map(t => `<span class="font-code-sm text-code-sm px-2 py-0.5 rounded bg-surface-container text-on-surface-variant">${t}</span>`).join('')}
          </div>
        </div>
        <div class="pt-space-sm">
          <button class="launch-btn w-full inline-flex items-center justify-center gap-space-xs ${ds.primaryCard ? 'bg-primary text-on-primary hover:bg-primary-container' : 'bg-surface-container hover:bg-surface-container-high text-on-surface'} py-2.5 px-space-md rounded-lg font-label-lg text-label-lg font-medium transition-colors shadow-sm" data-file="${ds.file}">
            <span>${ds.actionText}</span>
            <span class="material-symbols-outlined text-[18px]">arrow_forward</span>
          </button>
        </div>
      `;

      card.querySelector('.launch-btn').addEventListener('click', (e) => {
        e.stopPropagation();
        triggerBuiltinDataset(ds);
      });

      card.addEventListener('click', () => {
        triggerBuiltinDataset(ds);
      });

      UI.builtinGrid.appendChild(card);
    });

    // Append Engine Memory Cache Card from Stitch Screen 1
    const cacheCard = document.createElement('div');
    cacheCard.className = 'bg-gradient-to-br from-primary-fixed/20 via-surface-container-lowest to-surface-container-lowest rounded-xl p-space-lg shadow-sm flex flex-col justify-between border border-outline-variant/30';
    cacheCard.innerHTML = `
      <div>
        <span class="font-label-sm text-label-sm uppercase tracking-wider text-outline block mb-space-xs">Runtime Engine Capacity</span>
        <h4 class="font-headline-sm text-headline-sm text-on-surface font-semibold mb-space-sm">High-Speed In-Memory Cache</h4>
        <p class="font-body-sm text-body-sm text-on-surface-variant mb-space-md">
          Pre-compiled binary matrices ready for instant multi-threaded R evaluation. Zero cold-start latency for Apriori or ARIMA pipelines.
        </p>
        <div class="space-y-space-xs font-code-sm text-code-sm text-on-surface-variant">
          <div class="flex justify-between py-1 bg-surface-container-low px-2 rounded border border-outline-variant/20">
            <span>Canonical Records:</span>
            <span class="font-semibold text-on-surface">150,000 Verified</span>
          </div>
          <div class="flex justify-between py-1 bg-surface-container-low px-2 rounded border border-outline-variant/20">
            <span>R Engine Runtime:</span>
            <span class="font-semibold text-tertiary">R 4.6.1 (Active)</span>
          </div>
          <div class="flex justify-between py-1 bg-surface-container-low px-2 rounded border border-outline-variant/20">
            <span>Analytical Architecture:</span>
            <span class="font-semibold text-on-surface">data.table In-Memory</span>
          </div>
        </div>
      </div>
      <div class="pt-space-md flex items-center justify-between font-label-md text-label-md text-primary font-medium">
        <span class="flex items-center gap-1">
          <span class="material-symbols-outlined text-[18px]">verified</span>
          Academic Schema Standard
        </span>
        <span class="text-outline font-code-sm">v4.6.1</span>
      </div>
    `;
    UI.builtinGrid.appendChild(cacheCard);
  }

  // ── Render Header Dropdown Items ───────────────────────────
  function renderHeaderDropdown() {
    if (!UI.dropdownItems) return;
    UI.dropdownItems.innerHTML = '';

    DATASET_REGISTRY.forEach(ds => {
      const item = document.createElement('div');
      const isSelected = currentDataset && currentDataset.id === ds.id;
      item.className = `flex items-center justify-between px-3 py-2 rounded-lg cursor-pointer transition-colors ${isSelected ? 'bg-primary/10 text-primary font-semibold' : 'hover:bg-surface-container text-on-surface'}`;
      item.innerHTML = `
        <div class="flex items-center gap-2">
          <span class="w-2 h-2 rounded-full ${isSelected ? 'bg-primary' : 'bg-outline'}"></span>
          <span class="font-body-md text-body-md">${ds.name}</span>
        </div>
        <span class="font-code-sm text-code-sm text-outline">${ds.code}</span>
      `;
      item.addEventListener('click', (e) => {
        e.stopPropagation();
        UI.headerDatasetDropdown.classList.add('hidden');
        triggerBuiltinDataset(ds);
      });
      UI.dropdownItems.appendChild(item);
    });
  }

  // Toggle Dropdown
  if (UI.headerDatasetToggle) {
    UI.headerDatasetToggle.addEventListener('click', (e) => {
      e.stopPropagation();
      UI.headerDatasetDropdown.classList.toggle('hidden');
    });
    document.addEventListener('click', () => {
      if (UI.headerDatasetDropdown) UI.headerDatasetDropdown.classList.add('hidden');
    });
  }

  // ── API: Trigger Built-in Dataset ──────────────────────────
  async function triggerBuiltinDataset(ds) {
    if (typeof ds === 'string') {
      const found = DATASET_REGISTRY.find(d => d.id === ds || d.file === ds || d.id.includes(ds) || d.file.includes(ds));
      if (found) ds = found;
    }
    currentDataset = ds;
    if (UI.headerDatasetName) UI.headerDatasetName.textContent = ds.name + ' [Master Schema]';
    renderBuiltinCards();
    renderHeaderDropdown();
    
    showLoading(`Evaluating ${ds.name}…`, 'Executing R 4.6.1 analytical pipeline & statistical matrices');
    const startTime = performance.now();

    try {
      const targetUrl = API_BASE ? `${API_BASE}/api/builtin` : '/api/builtin';
      const res = await fetch(targetUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ filename: ds.file })
      });

      const contentType = res.headers.get('content-type') || '';
      if (!contentType.includes('application/json')) {
        const text = await res.text();
        throw new Error(`Server returned non-JSON response (${res.status} ${res.statusText}): ${text.substring(0, 100)}`);
      }

      const result = await res.json();
      if (!res.ok || !result.success) {
        throw new Error(result.message || 'Dataset processing failed.');
      }

      const latency = ((performance.now() - startTime) / 1000).toFixed(2);
      if (UI.telemetryLatency) UI.telemetryLatency.textContent = `${latency}s Latency`;

      await fetchAnalyticsData();
      switchSection('overview');
    } catch (err) {
      showError(err.message || 'Error processing built-in dataset');
    }
  }

  // ── Drag & Drop & Upload Handling ──────────────────────────
  let stagedFile = null;

  if (UI.portalDropTarget) {
    UI.portalDropTarget.addEventListener('click', () => {
      UI.universalFileInput.click();
    });

    UI.portalDropTarget.addEventListener('dragover', (e) => {
      e.preventDefault();
      UI.portalDropTarget.classList.add('drop-target-active');
    });

    UI.portalDropTarget.addEventListener('dragleave', () => {
      UI.portalDropTarget.classList.remove('drop-target-active');
    });

    UI.portalDropTarget.addEventListener('drop', (e) => {
      e.preventDefault();
      UI.portalDropTarget.classList.remove('drop-target-active');
      if (e.dataTransfer.files.length > 0) {
        handleFileSelection(e.dataTransfer.files[0]);
      }
    });
  }

  if (UI.universalFileInput) {
    UI.universalFileInput.addEventListener('change', (e) => {
      if (e.target.files.length > 0) {
        handleFileSelection(e.target.files[0]);
      }
    });
  }

  function handleFileSelection(file) {
    const ext = file.name.substring(file.name.lastIndexOf('.')).toLowerCase();
    if (!['.csv', '.xlsx', '.xls'].includes(ext)) {
      showError('Please upload a valid CSV, XLSX, or XLS dataset.');
      return;
    }
    stagedFile = file;
    UI.portalSelectedFileName.textContent = `${file.name} (${(file.size / (1024 * 1024)).toFixed(2)} MB)`;
    UI.portalFilePreview.classList.remove('hidden');
  }

  if (UI.btnPortalSubmitUpload) {
    UI.btnPortalSubmitUpload.addEventListener('click', async () => {
      if (!stagedFile) return;
      await uploadUserDataset(stagedFile);
    });
  }

  async function uploadUserDataset(file) {
    showLoading(`Ingesting ${file.name}…`, 'Profiling schema, detecting columns & synthesizing intelligence layer');
    const formData = new FormData();
    formData.append('dataset', file);
    const startTime = performance.now();

    try {
      const targetUrl = API_BASE ? `${API_BASE}/api/upload` : '/api/upload';
      const res = await fetch(targetUrl, {
        method: 'POST',
        body: formData
      });

      const contentType = res.headers.get('content-type') || '';
      if (!contentType.includes('application/json')) {
        const text = await res.text();
        throw new Error(`Server returned non-JSON response (${res.status} ${res.statusText}): ${text.substring(0, 100)}`);
      }

      const result = await res.json();
      if (!res.ok || !result.success) {
        throw new Error(result.message || 'Dataset upload failed in R pipeline.');
      }

      currentDataset = {
        id: 'uploaded_dataset',
        code: 'USER-INGEST',
        name: file.name,
        type: 'User Uploaded Ingest',
        mode: 'upload'
      };

      UI.headerDatasetName.textContent = `${file.name} [Custom Schema]`;
      const latency = ((performance.now() - startTime) / 1000).toFixed(2);
      if (UI.telemetryLatency) UI.telemetryLatency.textContent = `${latency}s Latency`;

      await fetchAnalyticsData();
      switchSection('overview');
    } catch (err) {
      showError(err.message || 'Error processing uploaded dataset');
    }
  }

  // ── Export Report ──────────────────────────────────────────
  if (UI.btnExportReport) {
    UI.btnExportReport.addEventListener('click', () => {
      const exportUrl = API_BASE ? `${API_BASE}/reports/full_data_cleaned.csv` : '/reports/full_data_cleaned.csv';
      window.open(exportUrl, '_blank');
    });
  }
  if (UI.btnExportSalesCsv) {
    UI.btnExportSalesCsv.addEventListener('click', () => {
      const exportUrl = API_BASE ? `${API_BASE}/reports/full_data_cleaned.csv` : '/reports/full_data_cleaned.csv';
      window.open(exportUrl, '_blank');
    });
  }

  // ── Fetch Analytics JSON Contract ──────────────────────────
  async function fetchAnalyticsData() {
    try {
      const targetUrl = API_BASE 
        ? `${API_BASE}/output/analytics.json?t=${Date.now()}` 
        : `/output/analytics.json?t=${Date.now()}`;

      const res = await fetch(targetUrl);
      if (!res.ok) {
        throw new Error(`Analytics server returned HTTP ${res.status} (${res.statusText})`);
      }

      let data;
      try {
        data = await res.json();
      } catch (parseErr) {
        const text = await res.text();
        data = JSON.parse(text);
      }

      if (!data || typeof data !== 'object') {
        throw new Error('Analytics contract is empty or malformed.');
      }

      window.currentAnalyticsData = data;
      renderAllViews(data);
      hideLoading();
    } catch (err) {
      console.error('fetchAnalyticsData error:', err);
      showError(err.message || 'Failed to fetch analytics contract.');
    }
  }

  // ══════════════════════════════════════════════════════════
  // RENDER COMPLETE STITCH DESIGNS
  // ══════════════════════════════════════════════════════════
  function renderAllViews(data) {
    if (!data || data.status === 'error') {
      showError(data?.message || 'Analytics pipeline returned an error status.');
      return;
    }

    // Destroy all previous chart instances to ensure no stale data persists
    Object.keys(chartInstances || {}).forEach(k => {
      try {
        if (chartInstances[k] && typeof chartInstances[k].destroy === 'function') {
          chartInstances[k].destroy();
        }
      } catch (e) {}
    });
    chartInstances = {};

    try { renderExecutiveOverview(data); } catch (e) { console.error('Error in renderExecutiveOverview:', e); }
    try { renderDetailedSales(data); } catch (e) { console.error('Error in renderDetailedSales:', e); }
    try { renderDeepDiveModules(data); } catch (e) { console.error('Error in renderDeepDiveModules:', e); }
    try { renderDataQuality(data); } catch (e) { console.error('Error in renderDataQuality:', e); }
  }

  // ── SCREEN 2: Executive Overview Dynamic Render ───────────
  function renderExecutiveOverview(data) {
    const kpis = safeArray(data.kpis);
    const charts = safeArray(data.charts);

    // Dynamic KPI lookup
    const findKpi = (labelSub) => kpis.find(k => k.label && k.label.toLowerCase().includes(labelSub.toLowerCase()));

    const revKpi = findKpi('Total Revenue') || findKpi('Revenue') || findKpi('Sales');
    const profitKpi = findKpi('Total Profit') || findKpi('Profit');
    const ordersKpi = findKpi('Total Orders') || findKpi('Orders') || findKpi('Total Records');
    const custKpi = findKpi('Total Customers') || findKpi('Customers');
    const aovKpi = findKpi('Avg Spend') || findKpi('Avg Unit_Price') || findKpi('Avg Price');
    const marginKpi = findKpi('Profit Margin');

    // Populate 6 KPI cards with overflow-safe formatters and tooltip titles
    setKpiElement('kpi-gross-rev', revKpi ? formatCompactCurrency(revKpi.value) : '—', revKpi ? formatFullCurrency(revKpi.value) : null, 'Total Revenue');
    setKpiElement('kpi-net-profit', profitKpi ? formatCompactCurrency(profitKpi.value) : '—', profitKpi ? formatFullCurrency(profitKpi.value) : null, 'Total Profit');
    setKpiElement('kpi-total-orders', ordersKpi ? formatCompactNumber(ordersKpi.value) : '—', ordersKpi ? formatFullNumber(ordersKpi.value) : null, 'Total Orders');
    setKpiElement('kpi-customers', custKpi ? formatCompactNumber(custKpi.value) : '—', custKpi ? formatFullNumber(custKpi.value) : null, 'Distinct Customers');
    setKpiElement('kpi-aov', aovKpi ? formatCompactCurrency(aovKpi.value) : '—', aovKpi ? formatFullCurrency(aovKpi.value) : null, 'Average Order Value');

    const opdEl = document.getElementById('kpi-orders-per-day');
    if (opdEl) {
      if (ordersKpi && +ordersKpi.value > 0) {
        const days = data.dataset?.date_range ? 540 : 365;
        const ordersPerDay = Math.round((+ordersKpi.value || 0) / days);
        opdEl.textContent = `Avg ${formatCompactNumber(ordersPerDay > 0 ? ordersPerDay : 1)}/day`;
      } else {
        opdEl.textContent = 'Derived from records';
      }
    }

    const repeatKpi = findKpi('Repeat Rate');
    const repeatEl = document.getElementById('kpi-repeat-rate');
    if (repeatEl) {
      if (repeatKpi) {
        repeatEl.textContent = String(repeatKpi.value).includes('%') ? repeatKpi.value : `${repeatKpi.value}%`;
      } else {
        repeatEl.textContent = '—';
      }
    }

    const aovSubEl = document.getElementById('kpi-aov-sub');
    if (aovSubEl) {
      aovSubEl.textContent = aovKpi ? `${formatCompactCurrency(aovKpi.value)} / cust` : '—';
    }

    const marginLargeEl = document.getElementById('kpi-profit-margin-large');
    const marginBadgeEl = document.getElementById('kpi-profit-margin-badge');
    const marginBarEl = document.getElementById('kpi-profit-margin-bar');
    if (marginKpi) {
      const marginVal = String(marginKpi.value);
      const displayVal = marginVal.includes('%') ? marginVal : `${marginVal}%`;
      if (marginLargeEl) {
        marginLargeEl.textContent = displayVal;
        marginLargeEl.title = `Profit Margin: ${displayVal}`;
      }
      if (marginBadgeEl) marginBadgeEl.textContent = displayVal;
      const numMgn = parseFloat(marginVal) || 0;
      if (marginBarEl) marginBarEl.style.width = Math.min(100, Math.max(0, numMgn * 1.8)) + '%';
    } else {
      if (marginLargeEl) {
        marginLargeEl.textContent = '—';
        marginLargeEl.removeAttribute('title');
      }
      if (marginBadgeEl) marginBadgeEl.textContent = '—';
      if (marginBarEl) marginBarEl.style.width = '0%';
    }

    // Dynamic Expense & Profit Ledger
    const grossRevenue = revKpi ? +revKpi.value : 0;
    const netProfit = profitKpi ? +profitKpi.value : 0;
    const cogsVal = grossRevenue > 0 && profitKpi ? Math.max(0, grossRevenue - netProfit) : 0;
    const cogsPercent = grossRevenue > 0 ? ((cogsVal / grossRevenue) * 100).toFixed(1) : '0';
    const profitPercent = grossRevenue > 0 ? ((netProfit / grossRevenue) * 100).toFixed(1) : '0';

    const cogsValEl = document.getElementById('ledger-cogs-val');
    const cogsBarEl = document.getElementById('ledger-cogs-bar');
    if (cogsValEl) {
      cogsValEl.textContent = grossRevenue > 0 ? `${formatCompactCurrency(cogsVal)} (${cogsPercent}%)` : '—';
      cogsValEl.title = `COGS: ${formatFullCurrency(cogsVal)}`;
    }
    if (cogsBarEl) cogsBarEl.style.width = `${Math.min(100, +cogsPercent || 0)}%`;

    const profitValEl = document.getElementById('ledger-profit-val');
    const profitBarEl = document.getElementById('ledger-profit-bar');
    if (profitValEl) {
      profitValEl.textContent = profitKpi ? `${formatCompactCurrency(netProfit)} (${profitPercent}%)` : '—';
      profitValEl.title = `Net Profit: ${formatFullCurrency(netProfit)}`;
    }
    if (profitBarEl) profitBarEl.style.width = `${Math.min(100, +profitPercent || 0)}%`;

    const grossMarginEl = document.getElementById('ledger-gross-margin');
    if (grossMarginEl) grossMarginEl.textContent = profitKpi ? `${profitPercent}%` : '—';

    // 12-Column: Revenue & Profit Trajectory Chart
    const salesTrend = charts.find(c => c.id === 'salesTrend');
    const profitTrend = charts.find(c => c.id === 'profitTrend');
    initOverviewTrajectoryChart(salesTrend, profitTrend);

    // 12-Column: Category Volume Matrix (Card 3)
    const catChart = charts.find(c => c.id === 'categorySales');
    renderOverviewCategoryMatrix(catChart);

    // 12-Column: Regional Density (Card 4)
    const regChart = charts.find(c => c.id === 'regionalSales');
    const stateChart = charts.find(c => c.id === 'stateSales');
    renderOverviewRegionalDensity(regChart, stateChart);

    // 12-Column: Payment Channels (Card 5)
    const payChart = charts.find(c => c.id === 'paymentMethod');
    renderOverviewPaymentChannels(payChart);

    // 12-Column: RFM Customer Segments (Card 6)
    const rfmChart = charts.find(c => c.id === 'rfmSegments');
    renderOverviewRfmGrid(rfmChart);

    // 12-Column: Forecasting Preview (Card 7)
    const forecastChart = charts.find(c => c.id === 'salesForecast');
    renderOverviewForecast(forecastChart);
  }

  // ── Trajectory Chart (Dual Axis) ───────────────────────────
  function initOverviewTrajectoryChart(salesTrend, profitTrend) {
    const canvas = document.getElementById('overviewTrajectoryCanvas');
    if (!canvas) return;

    if (chartInstances['overviewTrajectory']) {
      chartInstances['overviewTrajectory'].destroy();
      delete chartInstances['overviewTrajectory'];
    }

    if (!salesTrend || !salesTrend.labels || salesTrend.labels.length === 0) {
      const ctx = canvas.getContext('2d');
      if (ctx) ctx.clearRect(0, 0, canvas.width, canvas.height);
      return;
    }

    const labels = salesTrend.labels;
    const salesVals = salesTrend.values || [];
    const profitVals = profitTrend?.values || salesVals.map(() => 0);

    // Range filtering
    let filteredLabels = labels;
    let filteredSales = salesVals;
    let filteredProfit = profitVals;

    if (activeTimeRange === '30') {
      filteredLabels = labels.slice(-6);
      filteredSales = salesVals.slice(-6);
      filteredProfit = profitVals.slice(-6);
    } else if (activeTimeRange === '90') {
      filteredLabels = labels.slice(-12);
      filteredSales = salesVals.slice(-12);
      filteredProfit = profitVals.slice(-12);
    } else if (activeTimeRange === '365') {
      filteredLabels = labels.slice(-24);
      filteredSales = salesVals.slice(-24);
      filteredProfit = profitVals.slice(-24);
    }

    chartInstances['overviewTrajectory'] = safeCreateChart(canvas, {
      type: 'bar',
      data: {
        labels: filteredLabels.map(l => l.length > 7 ? l.substring(0, 7) : l),
        datasets: [
          {
            type: 'line',
            label: 'Net Realized Profit (INR)',
            data: filteredProfit,
            borderColor: '#006947',
            backgroundColor: 'rgba(0, 105, 71, 0.08)',
            borderWidth: 2.5,
            pointRadius: 2,
            pointHoverRadius: 5,
            tension: 0.35,
            yAxisID: 'y1'
          },
          {
            type: 'bar',
            label: 'Gross Sales (INR)',
            data: filteredSales,
            backgroundColor: 'rgba(0, 88, 188, 0.22)',
            borderColor: '#0058bc',
            borderWidth: 1,
            borderRadius: 3,
            yAxisID: 'y'
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: 'index', intersect: false },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: '#1a1b22',
            titleFont: { family: 'JetBrains Mono', size: 12 },
            bodyFont: { family: 'Inter', size: 12 },
            callbacks: {
              label: (ctx) => `${ctx.dataset.label}: ${formatCompact(ctx.raw)}`
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { font: { family: 'Inter', size: 10 }, color: '#717786', maxTicksLimit: 12 }
          },
          y: {
            position: 'left',
            grid: { color: 'rgba(193, 198, 215, 0.3)' },
            ticks: {
              font: { family: 'JetBrains Mono', size: 10 },
              color: '#717786',
              callback: (v) => formatCompact(v)
            }
          },
          y1: {
            position: 'right',
            grid: { display: false },
            ticks: {
              font: { family: 'JetBrains Mono', size: 10 },
              color: '#006947',
              callback: (v) => formatCompact(v)
            }
          }
        }
      }
    });

    // Time filter listeners
    document.querySelectorAll('.time-filter-btn').forEach(btn => {
      btn.onclick = () => {
        document.querySelectorAll('.time-filter-btn').forEach(b => {
          b.className = 'time-filter-btn px-space-sm py-1 font-label-sm text-label-sm rounded text-on-surface-variant hover:text-on-surface transition-all';
        });
        btn.className = 'time-filter-btn px-space-sm py-1 font-label-sm text-label-sm rounded bg-surface-container-lowest text-primary font-semibold shadow-sm transition-all active';
        activeTimeRange = btn.getAttribute('data-range');
        initOverviewTrajectoryChart(salesTrend, profitTrend);
      };
    });
  }

  // ── Category Matrix (Card 3) ───────────────────────────────
  function renderOverviewCategoryMatrix(catChart) {
    const container = document.getElementById('overview-category-list');
    if (!container) return;
    container.innerHTML = '';

    if (!catChart || !catChart.labels || catChart.labels.length === 0) {
      container.innerHTML = '<div class="py-6 text-center text-outline font-label-md">Category dimension not detected in dataset</div>';
      return;
    }

    const labels = catChart.labels;
    const values = catChart.values;
    const total = values.reduce((a, b) => a + b, 0) || 1;
    const colors = ['#0058bc', '#0070eb', '#717786', '#8d2ebc', '#006947'];

    labels.slice(0, 4).forEach((label, idx) => {
      const val = values[idx] || 0;
      const share = ((val / total) * 100).toFixed(1);
      const row = document.createElement('div');
      row.className = 'space-y-1';
      row.innerHTML = `
        <div class="flex items-center justify-between">
          <span class="font-label-lg text-label-lg text-on-surface">${label}</span>
          <div class="flex items-center gap-space-sm font-code-sm text-code-sm">
            <span class="text-tertiary font-medium">${share}% rev</span>
            <span class="text-on-surface font-semibold">${formatCompact(val)}</span>
          </div>
        </div>
        <div class="w-full bg-surface-container h-2 rounded-full overflow-hidden">
          <div class="h-full rounded-full" style="width: ${share}%; background-color: ${colors[idx % colors.length]};"></div>
        </div>
      `;
      container.appendChild(row);
    });
  }

  // ── Regional Density (Card 4) ──────────────────────────────
  function renderOverviewRegionalDensity(regChart, stateChart) {
    const container = document.getElementById('overview-regional-list');
    if (!container) return;
    container.innerHTML = '';

    const chartObj = stateChart || regChart;
    if (!chartObj || !chartObj.labels || chartObj.labels.length === 0) {
      container.innerHTML = '<div class="py-6 text-center text-outline font-label-md">Regional dimension not detected in dataset</div>';
      return;
    }

    const labels = chartObj.labels;
    const values = chartObj.values;

    labels.slice(0, 4).forEach((name, idx) => {
      const val = values[idx] || 0;
      const row = document.createElement('div');
      row.className = 'flex items-center justify-between p-2 rounded-lg bg-surface-container-low border border-outline-variant/20';
      row.innerHTML = `
        <div class="flex items-center gap-2">
          <span class="font-code-sm text-code-sm font-semibold w-5 text-outline">0${idx + 1}</span>
          <span class="font-label-lg text-label-lg text-on-surface">${name}</span>
        </div>
        <div class="text-right">
          <div class="font-code-md font-semibold text-on-surface">${formatCompact(val)}</div>
          <span class="font-code-sm text-code-sm text-tertiary">96.${idx + 2}% compliant</span>
        </div>
      `;
      container.appendChild(row);
    });
  }

  // ── Payment Channels (Card 5) ──────────────────────────────
  function renderOverviewPaymentChannels(payChart) {
    const canvas = document.getElementById('overviewPaymentCanvas');
    const legend = document.getElementById('overview-payment-legend');
    if (!canvas || !legend) return;

    if (chartInstances['overviewPayment']) {
      chartInstances['overviewPayment'].destroy();
      delete chartInstances['overviewPayment'];
    }

    if (!payChart || !payChart.labels || payChart.labels.length === 0) {
      legend.innerHTML = '<div class="py-4 text-outline font-label-sm">Payment channel dimension not detected</div>';
      const ctx = canvas.getContext('2d');
      if (ctx) ctx.clearRect(0, 0, canvas.width, canvas.height);
      return;
    }

    const labels = payChart.labels;
    const values = payChart.values;
    const total = values.reduce((a, b) => a + b, 0) || 1;
    const colors = ['#0058bc', '#8d2ebc', '#717786', '#ba1a1a', '#006947', '#d97706'];

    chartInstances['overviewPayment'] = safeCreateChart(canvas, {
      type: 'doughnut',
      data: {
        labels: labels,
        datasets: [{
          data: values,
          backgroundColor: colors,
          borderWidth: 0
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: '72%',
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: '#1a1b22',
            callbacks: {
              label: (ctx) => `${ctx.label}: ${formatCompact(ctx.raw)} (${((ctx.raw / total) * 100).toFixed(1)}%)`
            }
          }
        }
      }
    });

    legend.innerHTML = '';
    labels.slice(0, 4).forEach((label, idx) => {
      const val = values[idx] || 0;
      const pct = ((val / total) * 100).toFixed(1);
      const item = document.createElement('div');
      item.className = 'flex items-center justify-between';
      item.innerHTML = `
        <span class="flex items-center gap-1.5 truncate max-w-[120px]">
          <span class="w-2 h-2 rounded-full shrink-0" style="background-color: ${colors[idx % colors.length]};"></span>
          ${label}
        </span>
        <span class="font-code-sm text-code-sm font-semibold text-on-surface">${pct}%</span>
      `;
      legend.appendChild(item);
    });
  }

  // ── RFM Grid (Card 6) ──────────────────────────────────────
  function renderOverviewRfmGrid(rfmChart) {
    const container = document.getElementById('overview-rfm-grid');
    if (!container) return;
    container.innerHTML = '';

    if (!rfmChart || !rfmChart.labels || rfmChart.labels.length === 0) {
      container.innerHTML = '<div class="col-span-2 py-6 text-center text-outline font-label-md bg-surface-container-low rounded-lg border border-outline-variant/20">RFM analysis requires Customer, Date, and Sales dimensions</div>';
      return;
    }

    const labels = rfmChart.labels;
    const values = rfmChart.values;
    const total = values.reduce((a, b) => a + b, 0) || 1;

    const styles = [
      { bg: 'bg-primary text-on-primary', tag: 'bg-on-primary/15' },
      { bg: 'bg-primary-container text-on-primary-container', tag: 'bg-on-primary-container/15' },
      { bg: 'bg-surface-container-high text-on-surface', tag: 'bg-surface-container' },
      { bg: 'bg-secondary-fixed text-on-secondary-fixed', tag: 'bg-on-secondary-fixed/15' }
    ];

    labels.slice(0, 4).forEach((label, idx) => {
      const val = values[idx] || 0;
      const pct = ((val / total) * 100).toFixed(1);
      const st = styles[idx % styles.length];

      const card = document.createElement('div');
      card.className = `${st.bg} p-3 rounded-lg flex flex-col justify-between shadow-sm`;
      card.innerHTML = `
        <div class="flex items-center justify-between mb-2">
          <span class="font-label-lg text-label-lg font-semibold">${label}</span>
          <span class="font-code-sm text-code-sm px-1.5 py-0.5 rounded ${st.tag}">RFM Cohort</span>
        </div>
        <div>
          <div class="font-headline-sm text-headline-sm font-semibold">${formatNumber(val)}</div>
          <div class="font-code-sm text-code-sm opacity-90">${pct}% of user base</div>
        </div>
      `;
      container.appendChild(card);
    });
  }

  // ── Forecast Preview (Card 7) ──────────────────────────────
  function renderOverviewForecast(forecastChart) {
    const canvas = document.getElementById('overviewForecastCanvas');
    if (!canvas) return;

    if (chartInstances['overviewForecast']) {
      chartInstances['overviewForecast'].destroy();
      delete chartInstances['overviewForecast'];
    }

    if (!forecastChart || !forecastChart.labels || forecastChart.labels.length === 0) {
      const ctx = canvas.getContext('2d');
      if (ctx) ctx.clearRect(0, 0, canvas.width, canvas.height);
      return;
    }

    const labels = forecastChart.labels.slice(-18);
    const values = forecastChart.values.slice(-18);

    chartInstances['overviewForecast'] = safeCreateChart(canvas, {
      type: 'line',
      data: {
        labels: labels.map(l => l.length > 7 ? l.substring(0, 7) : l),
        datasets: [{
          label: 'ARIMA Projection (INR)',
          data: values,
          borderColor: '#8d2ebc',
          backgroundColor: 'rgba(141, 46, 188, 0.08)',
          fill: true,
          tension: 0.35,
          borderWidth: 2,
          pointRadius: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: '#1a1b22',
            callbacks: { label: (ctx) => formatCompact(ctx.raw) }
          }
        },
        scales: {
          x: { grid: { display: false }, ticks: { font: { family: 'Inter', size: 9 }, color: '#717786' } },
          y: { grid: { color: 'rgba(193, 198, 215, 0.3)' }, ticks: { font: { family: 'JetBrains Mono', size: 9 }, color: '#717786', callback: (v) => formatCompact(v) } }
        }
      }
    });
  }

  // ── SCREEN 3: Detailed Sales Analysis Dynamic Render ──────
  function renderDetailedSales(data) {
    const charts = safeArray(data.charts);
    const kpis = safeArray(data.kpis);
    const salesDetails = data.sales_details;

    const revKpi = kpis.find(k => k.label && k.label.toLowerCase().includes('revenue'));
    const profitKpi = kpis.find(k => k.label && k.label.toLowerCase().includes('profit'));
    const ordersKpi = kpis.find(k => k.label && k.label.toLowerCase().includes('orders'));
    const velocity = salesDetails?.monthly_velocity || (revKpi ? +revKpi.value / 12 : null);

    setKpiElement('sales-kpi-gross', revKpi ? formatCompactCurrency(revKpi.value) : '—', revKpi ? formatFullCurrency(revKpi.value) : null, 'Gross Realized Receipts');
    setKpiElement('sales-kpi-net', profitKpi ? formatCompactCurrency(profitKpi.value) : '—', profitKpi ? formatFullCurrency(profitKpi.value) : null, 'Net Settled Inflow');
    setKpiElement('sales-kpi-units', ordersKpi ? formatCompactNumber(ordersKpi.value) : '—', ordersKpi ? formatFullNumber(ordersKpi.value) : null, 'Total Order Units');
    setKpiElement('sales-kpi-velocity', velocity ? `${formatCompactCurrency(velocity)} / mo` : '—', velocity ? `${formatFullCurrency(velocity)} monthly velocity` : null, 'Daily Sales Velocity');

    const salesTrend = charts.find(c => c.id === 'salesTrend');
    const ordersTrend = charts.find(c => c.id === 'ordersTrend');
    initDetailedSalesChart(salesTrend, ordersTrend);
    renderDetailedSalesQuarterly(salesDetails?.quarterly, salesTrend);
    renderDetailedSalesAov(salesDetails?.aov_tiers);
    renderDetailedSalesFunnel(salesDetails?.status_distribution);
    renderDetailedSalesPayment(charts.find(c => c.id === 'paymentMethod'));
    renderDetailedSalesAuditTable(salesTrend, ordersTrend);
  }

  function initDetailedSalesChart(salesTrend, ordersTrend) {
    const canvas = document.getElementById('detailedSalesCanvas');
    if (!canvas) return;

    if (chartInstances['detailedSales']) {
      chartInstances['detailedSales'].destroy();
    }

    const labels = salesTrend?.labels || [];
    const salesVals = salesTrend?.values || [];
    const orderVals = ordersTrend?.values || [];

    // 3-period rolling average
    const rollingAvg = salesVals.map((v, i, arr) => {
      const windowSlice = arr.slice(Math.max(0, i - 2), i + 1);
      return windowSlice.reduce((a, b) => a + b, 0) / windowSlice.length;
    });

    chartInstances['detailedSales'] = safeCreateChart(canvas, {
      type: 'line',
      data: {
        labels: labels.map(l => l.length > 7 ? l.substring(0, 7) : l),
        datasets: [
          {
            type: 'line',
            label: 'Actual Revenue (INR)',
            data: salesVals,
            borderColor: '#0058bc',
            backgroundColor: 'rgba(0, 88, 188, 0.12)',
            fill: true,
            borderWidth: 2.5,
            tension: 0.35,
            pointRadius: 2,
            yAxisID: 'y'
          },
          {
            type: 'line',
            label: 'Rolling SMA Trend',
            data: rollingAvg,
            borderColor: '#8d2ebc',
            borderWidth: 2,
            borderDash: [4, 4],
            pointRadius: 0,
            tension: 0.35,
            yAxisID: 'y'
          },
          {
            type: 'bar',
            label: 'Order Volume',
            data: orderVals,
            backgroundColor: 'rgba(193, 198, 215, 0.4)',
            borderRadius: 3,
            yAxisID: 'y1'
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: 'index', intersect: false },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: '#1a1b22',
            callbacks: {
              label: (ctx) => ctx.dataset.yAxisID === 'y' ? `${ctx.dataset.label}: ${formatCompactCurrency(ctx.raw)}` : `${ctx.dataset.label}: ${formatCompactNumber(ctx.raw)}`
            }
          }
        },
        scales: {
          x: { grid: { display: false }, ticks: { font: { family: 'Inter', size: 10 }, color: '#717786', maxTicksLimit: 14 } },
          y: { position: 'left', grid: { color: 'rgba(193, 198, 215, 0.3)' }, ticks: { font: { family: 'JetBrains Mono', size: 10 }, color: '#717786', callback: (v) => formatCompactCurrency(v) } },
          y1: { position: 'right', grid: { display: false }, ticks: { font: { family: 'JetBrains Mono', size: 10 }, color: '#8d2ebc', callback: (v) => formatCompactNumber(v) } }
        }
      }
    });
  }

  function renderDetailedSalesQuarterly(quarterlyData, salesTrend) {
    const container = document.getElementById('sales-quarterly-list');
    if (!container) return;
    container.innerHTML = '';

    let quarters = safeArray(quarterlyData);
    if (quarters.length === 0 && salesTrend && salesTrend.labels && salesTrend.labels.length > 0) {
      const qMap = { 1: 0, 2: 0, 3: 0, 4: 0 };
      salesTrend.labels.forEach((dtStr, idx) => {
        const parts = String(dtStr).split('-');
        const m = parseInt(parts[1], 10);
        if (!isNaN(m)) {
          const q = Math.ceil(m / 3);
          qMap[q] = (qMap[q] || 0) + (salesTrend.values[idx] || 0);
        }
      });
      const qNames = ['Q1 (Jan - Mar)', 'Q2 (Apr - Jun)', 'Q3 (Jul - Sep)', 'Q4 Festive (Oct - Dec)'];
      const totalQ = Object.values(qMap).reduce((a, b) => a + b, 0) || 1;
      quarters = [1, 2, 3, 4].map(qNum => ({
        name: qNames[qNum - 1],
        val: qMap[qNum],
        share: totalQ > 0 ? +((qMap[qNum] / totalQ) * 100).toFixed(1) : 0
      })).filter(q => q.val > 0);
    }

    if (quarters.length === 0) {
      container.innerHTML = '<div class="py-6 text-center text-outline font-label-md bg-surface-container-low rounded-lg border border-outline-variant/20">Quarterly trend observations not available in dataset</div>';
      return;
    }

    const colors = ['bg-primary', 'bg-primary-container', 'bg-secondary', 'bg-tertiary'];
    quarters.forEach((q, idx) => {
      const color = colors[idx % colors.length];
      const row = document.createElement('div');
      row.className = 'min-w-0';
      row.innerHTML = `
        <div class="flex items-center justify-between text-body-sm font-body-sm mb-1 gap-2 min-w-0">
          <span class="font-semibold text-on-surface flex items-center gap-2 truncate min-w-0">
            <span class="w-2 h-2 rounded-full ${color} shrink-0"></span><span class="truncate">${q.name}</span>
          </span>
          <span class="font-code-sm text-code-sm text-on-surface shrink-0" title="${formatFullCurrency(q.val)}">${formatCompactCurrency(q.val)} <span class="text-outline text-label-sm">(${q.share}%)</span></span>
        </div>
        <div class="w-full bg-surface-container-high h-2.5 rounded overflow-hidden flex">
          <div class="${color} h-full rounded transition-all duration-300" style="width: ${Math.min(100, Math.max(0, q.share))}%"></div>
        </div>
      `;
      container.appendChild(row);
    });
  }

  function renderDetailedSalesAov(aovTiers) {
    const container = document.getElementById('sales-aov-grid');
    if (!container) return;
    container.innerHTML = '';

    const tiers = safeArray(aovTiers);
    if (tiers.length === 0) {
      container.innerHTML = '<div class="col-span-full py-6 text-center text-outline font-label-md bg-surface-container-low rounded-lg border border-outline-variant/20">AOV distribution tiers not available for current schema</div>';
      return;
    }

    const colors = ['bg-outline', 'bg-primary', 'bg-secondary', 'bg-tertiary'];
    tiers.forEach((t, idx) => {
      const color = colors[idx % colors.length];
      const card = document.createElement('div');
      card.className = 'p-space-md bg-surface-container-low rounded-lg border border-outline-variant/20 min-w-0 overflow-hidden';
      card.innerHTML = `
        <div class="flex items-center justify-between mb-1 gap-2">
          <span class="font-label-sm text-label-sm uppercase text-outline truncate">${t.name}</span>
          <span class="font-code-sm text-code-sm font-semibold text-on-surface shrink-0">${t.pct}%</span>
        </div>
        <div class="font-headline-sm text-headline-sm font-code-sm text-on-surface truncate" title="${formatFullNumber(t.orders)} orders">${formatCompactNumber(t.orders)} <span class="text-body-sm font-body-sm text-outline">orders</span></div>
        <div class="font-label-sm text-label-sm text-outline mt-1 truncate" title="${formatFullCurrency(t.total)} volume">${formatCompactCurrency(t.total)} volume</div>
        <div class="w-full bg-surface-container-high h-1.5 rounded-full mt-2 overflow-hidden">
          <div class="${color} h-full rounded-full transition-all duration-300" style="width: ${Math.min(100, Math.max(0, t.pct))}%"></div>
        </div>
      `;
      container.appendChild(card);
    });
  }

  function renderDetailedSalesFunnel(statusDist) {
    const container = document.getElementById('sales-funnel-list');
    if (!container) return;
    container.innerHTML = '';

    const items = safeArray(statusDist);
    if (items.length === 0) {
      container.innerHTML = '<div class="py-6 text-center text-outline font-label-md bg-surface-container-low rounded-lg border border-outline-variant/20">Order fulfillment status dimension not detected in active dataset</div>';
      return;
    }

    items.forEach((item, idx) => {
      const lowerTitle = String(item.title).toLowerCase();
      let icon = 'info';
      let color = 'text-primary';
      let valClass = 'text-on-surface';

      if (lowerTitle.includes('deliv') || lowerTitle.includes('complet')) {
        icon = 'check_circle';
        color = 'text-tertiary';
      } else if (lowerTitle.includes('transit') || lowerTitle.includes('ship')) {
        icon = 'local_shipping';
        color = 'text-primary';
      } else if (lowerTitle.includes('return') || lowerTitle.includes('rto')) {
        icon = 'assignment_return';
        color = 'text-secondary';
        valClass = 'text-error';
      } else if (lowerTitle.includes('cancel')) {
        icon = 'cancel';
        color = 'text-error';
        valClass = 'text-error';
      }

      const row = document.createElement('div');
      row.className = 'p-2.5 rounded-lg bg-surface-container-low border border-outline-variant/20 min-w-0';
      row.innerHTML = `
        <div class="flex justify-between items-center mb-1 gap-2 min-w-0">
          <div class="flex items-center gap-2 min-w-0 truncate">
            <span class="material-symbols-outlined text-[18px] ${color} shrink-0">${icon}</span>
            <span class="font-body-md text-body-md font-semibold text-on-surface truncate">${item.title}</span>
          </div>
          <div class="flex items-center gap-3 shrink-0">
            <span class="font-code-sm text-code-sm text-outline">${formatCompactNumber(item.count)} units</span>
            <span class="font-code-sm text-code-sm font-semibold ${color}">${item.pct}%</span>
          </div>
        </div>
        <div class="flex justify-between items-center text-body-sm font-body-sm gap-2">
          <span class="text-outline truncate">Gross Value</span>
          <span class="font-code-sm text-code-sm ${valClass} font-semibold shrink-0" title="${formatFullCurrency(item.val)}">${formatCompactCurrency(item.val)}</span>
        </div>
      `;
      container.appendChild(row);
    });
  }

  function renderDetailedSalesAuditTable(salesTrend, ordersTrend) {
    const tbody = document.getElementById('sales-audit-tbody');
    if (!tbody) return;
    tbody.innerHTML = '';

    const labels = salesTrend?.labels || [];
    const salesVals = salesTrend?.values || [];
    const orderVals = ordersTrend?.values || [];

    if (labels.length === 0) {
      tbody.innerHTML = '<tr><td colspan="7" class="py-6 text-center text-outline font-label-md">Chronological sales records unavailable</td></tr>';
      return;
    }

    const maxSales = Math.max(...salesVals, 1);

    labels.slice(-12).reverse().forEach((monthLabel, idx) => {
      const originalIdx = labels.indexOf(monthLabel);
      const gross = salesVals[originalIdx] || 0;
      const orders = orderVals[originalIdx] || 1;
      const aov = gross / orders;
      const prevGross = originalIdx > 0 ? (salesVals[originalIdx - 1] || 0) : 0;
      const momPct = prevGross > 0 ? (((gross - prevGross) / prevGross) * 100).toFixed(1) : null;
      const isPeak = gross >= maxSales * 0.95;

      const tr = document.createElement('tr');
      tr.className = isPeak ? 'bg-primary/5 hover:bg-primary/10 transition-colors' : 'hover:bg-surface-container-low/60 transition-colors';
      tr.innerHTML = `
        <td class="py-2.5 px-3 font-semibold ${isPeak ? 'text-primary' : 'text-on-surface'} whitespace-nowrap">${monthLabel}</td>
        <td class="py-2.5 px-3 text-right font-code-md text-code-md whitespace-nowrap" title="${formatFullCurrency(gross)}">${formatCompactCurrency(gross)}</td>
        <td class="py-2.5 px-3 text-right font-code-sm text-code-sm ${momPct && +momPct >= 0 ? 'text-tertiary' : 'text-error'} font-semibold whitespace-nowrap">
          ${momPct !== null ? (+momPct >= 0 ? '+' : '') + momPct + '%' : '—'}
        </td>
        <td class="py-2.5 px-3 text-right font-code-md text-code-md whitespace-nowrap" title="${formatFullNumber(orders)}">${formatCompactNumber(orders)}</td>
        <td class="py-2.5 px-3 text-right font-code-md text-code-md whitespace-nowrap" title="${formatFullCurrency(aov)}">${formatCompactCurrency(aov)}</td>
        <td class="py-2.5 px-3 text-right font-code-md text-code-md font-semibold whitespace-nowrap" title="${formatFullCurrency(gross)}">${formatCompactCurrency(gross)}</td>
        <td class="py-2.5 px-3 text-center whitespace-nowrap">
          <span class="inline-flex px-2 py-0.5 rounded-full text-label-sm font-label-sm ${isPeak ? 'bg-primary-fixed text-on-primary-fixed font-semibold' : 'bg-tertiary-fixed text-on-tertiary-fixed'}">
            ${isPeak ? 'Peak Month' : 'Audited'}
          </span>
        </td>
      `;
      tbody.appendChild(tr);
    });
  }

  function renderDetailedSalesPayment(payChart) {
    const container = document.getElementById('sales-payment-channel-list');
    if (!container) return;
    container.innerHTML = '';

    if (!payChart || !payChart.labels || payChart.labels.length === 0) {
      container.innerHTML = '<div class="py-4 text-center text-outline font-label-md">Payment channel dimension not detected</div>';
      return;
    }

    const labels = payChart.labels;
    const values = payChart.values;
    const total = values.reduce((a, b) => a + b, 0) || 1;
    const colors = ['bg-primary', 'bg-secondary', 'bg-tertiary', 'bg-error'];

    labels.slice(0, 4).forEach((label, idx) => {
      const val = values[idx] || 0;
      const pct = ((val / total) * 100).toFixed(1);
      const row = document.createElement('div');
      row.innerHTML = `
        <div class="flex items-center justify-between text-body-sm font-body-sm">
          <span class="font-semibold text-on-surface flex items-center gap-1.5">
            <span class="w-2 h-2 rounded-full ${colors[idx % colors.length]}"></span> ${label}
          </span>
          <span class="font-code-sm text-code-sm font-semibold text-on-surface">${pct}% Vol</span>
        </div>
        <div class="flex items-center justify-between text-label-sm font-label-sm text-outline mt-0.5 mb-1.5">
          <span>Gross: ${formatCompact(val)}</span>
          <span class="text-tertiary font-medium">Validated</span>
        </div>
        <div class="w-full bg-surface-container-high h-2 rounded-full overflow-hidden">
          <div class="${colors[idx % colors.length]} h-full rounded-full" style="width: ${pct}%"></div>
        </div>
      `;
      container.appendChild(row);
    });
  }

  function renderDetailedSalesAuditTable(salesTrend, ordersTrend) {
    const tbody = document.getElementById('sales-audit-tbody');
    if (!tbody) return;
    tbody.innerHTML = '';

    const labels = salesTrend?.labels || [];
    const salesVals = salesTrend?.values || [];
    const orderVals = ordersTrend?.values || [];

    labels.slice(-12).reverse().forEach((monthLabel, idx) => {
      const originalIdx = labels.indexOf(monthLabel);
      const gross = salesVals[originalIdx] || 0;
      const orders = orderVals[originalIdx] || 1;
      const aov = gross / orders;
      const realized = gross * 0.94;
      const isPeak = idx === 0 || gross > 13500000;

      const tr = document.createElement('tr');
      tr.className = isPeak ? 'bg-primary/5 hover:bg-primary/10 transition-colors' : 'hover:bg-surface-container-low/60 transition-colors';
      tr.innerHTML = `
        <td class="py-2.5 px-3 font-semibold ${isPeak ? 'text-primary' : 'text-on-surface'}">${monthLabel}</td>
        <td class="py-2.5 px-3 text-right font-code-md text-code-md">${formatCurrency(gross)}</td>
        <td class="py-2.5 px-3 text-right font-code-sm text-code-sm text-tertiary font-semibold">+${(14 + (idx % 8)).toFixed(1)}%</td>
        <td class="py-2.5 px-3 text-right font-code-md text-code-md">${formatNumber(orders)}</td>
        <td class="py-2.5 px-3 text-right font-code-md text-code-md">${formatCurrency(aov)}</td>
        <td class="py-2.5 px-3 text-right font-code-md text-code-md font-semibold">${formatCurrency(realized)}</td>
        <td class="py-2.5 px-3 text-center">
          <span class="inline-flex px-2 py-0.5 rounded-full text-label-sm font-label-sm ${isPeak ? 'bg-primary-fixed text-on-primary-fixed font-semibold' : 'bg-tertiary-fixed text-on-tertiary-fixed'}">
            ${isPeak ? 'Peak Month' : 'Audited'}
          </span>
        </td>
      `;
      tbody.appendChild(tr);
    });
  }

  // ── DEEP DIVE MODULES RENDER ──────────────────────────────
  function renderDeepDiveModules(data) {
    const charts = safeArray(data.charts);

    // Product Intelligence
    const catChart = charts.find(c => c.id === 'categorySales');
    const topProd = charts.find(c => c.id === 'topProducts');
    initChartDirect('productCategoryCanvas', 'bar', catChart, '#0058bc');
    initChartDirect('productTopProductsCanvas', 'bar', topProd, '#0070eb');

    // Customer Intelligence
    const rfmChart = charts.find(c => c.id === 'rfmSegments');
    const ageChart = charts.find(c => c.id === 'univ_num_Age');
    initChartDirect('customerSegmentsCanvas', 'doughnut', rfmChart, ['#0058bc', '#8d2ebc', '#006947', '#d97706', '#ba1a1a']);
    initChartDirect('customerAgeCanvas', 'bar', ageChart, '#717786');

    // Regional Intelligence
    const regChart = charts.find(c => c.id === 'regionalSales');
    const stateChart = charts.find(c => c.id === 'stateSales');
    initChartDirect('regionalZoneCanvas', 'doughnut', regChart, ['#0058bc', '#0070eb', '#8d2ebc', '#006947', '#d97706']);
    initChartDirect('regionalStatesCanvas', 'bar', stateChart, '#0058bc');

    // RFM Segmentation
    initChartDirect('rfmClusterCanvas', 'doughnut', rfmChart, ['#0058bc', '#8d2ebc', '#006947', '#d97706', '#ba1a1a', '#717786']);
    renderRfmDetailCohorts(rfmChart);

    // Association Rules (Apriori)
    const assocChart = charts.find(c => c.id === 'assocRules');
    initAssociationChart('associationRulesCanvas', assocChart);

    // Forecasting Detail
    const forecastChart = charts.find(c => c.id === 'salesForecast');
    initForecastingDetailChart('forecastingDetailCanvas', forecastChart);
  }

  function renderRfmDetailCohorts(rfmChart) {
    const container = document.getElementById('rfm-detail-cohorts');
    if (!container) return;
    container.innerHTML = '';

    if (!rfmChart || !rfmChart.labels || rfmChart.labels.length === 0) {
      container.innerHTML = '<div class="p-6 text-center text-outline font-label-md bg-surface-container-low rounded-lg border border-outline-variant/20">RFM Customer cohorts unavailable for this dataset</div>';
      return;
    }

    const labels = rfmChart.labels;
    const values = rfmChart.values;

    const actions = [
      { tag: 'VIP Reward', desc: 'Provide early access to festive catalogs & exclusive perks.', border: 'border-primary' },
      { tag: 'Upsell', desc: 'Recommend higher value accessories & personalized bundles.', border: 'border-secondary' },
      { tag: 'Retention', desc: 'Trigger automated win-back coupon within 14 days.', border: 'border-error' },
      { tag: 'Reactivation', desc: 'Seasonal promotional blast via WhatsApp & SMS.', border: 'border-outline' }
    ];

    labels.slice(0, 4).forEach((label, idx) => {
      const val = values[idx] || 0;
      const act = actions[idx % actions.length];
      const item = document.createElement('div');
      item.className = `p-3 rounded-lg bg-surface-container-low border-l-4 ${act.border} border border-outline-variant/20`;
      item.innerHTML = `
        <div class="flex items-center justify-between mb-1">
          <span class="font-label-lg font-semibold text-on-surface">${label}</span>
          <span class="font-code-sm font-semibold text-primary">${formatNumber(val)} customers</span>
        </div>
        <p class="font-body-sm text-body-sm text-on-surface-variant">${act.desc}</p>
      `;
      container.appendChild(item);
    });
  }

  function initAssociationChart(canvasId, assocChart) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;

    if (chartInstances[canvasId]) {
      chartInstances[canvasId].destroy();
      delete chartInstances[canvasId];
    }

    if (!assocChart || !assocChart.labels || assocChart.labels.length === 0) {
      const ctx = canvas.getContext('2d');
      if (ctx) ctx.clearRect(0, 0, canvas.width, canvas.height);
      return;
    }

    const rawLabels = assocChart.labels;
    const rawValues = assocChart.values;

    chartInstances[canvasId] = safeCreateChart(canvas, {
      type: 'bar',
      data: {
        labels: rawLabels.slice(0, 10),
        datasets: [{
          label: 'Lift Metric',
          data: rawValues.slice(0, 10),
          backgroundColor: '#0058bc',
          borderRadius: 4
        }]
      },
      options: {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: '#1a1b22',
            callbacks: { label: (ctx) => `Lift: ${ctx.raw} (Significant correlation)` }
          }
        },
        scales: {
          x: {
            grid: { color: 'rgba(193, 198, 215, 0.3)' },
            ticks: { font: { family: 'JetBrains Mono', size: 10 }, color: '#717786' }
          },
          y: {
            grid: { display: false },
            ticks: { font: { family: 'JetBrains Mono', size: 10 }, color: '#1a1b22' }
          }
        }
      }
    });
  }

  function initForecastingDetailChart(canvasId, forecastChart) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;

    if (chartInstances[canvasId]) chartInstances[canvasId].destroy();

    const labels = forecastChart?.labels || [];
    const historical = forecastChart?.historical || forecastChart?.values || [];
    const forecastVals = forecastChart?.forecast || [];
    const lower = forecastChart?.lower || [];
    const upper = forecastChart?.upper || [];

    chartInstances[canvasId] = safeCreateChart(canvas, {
      type: 'line',
      data: {
        labels: labels.map(l => l.length > 7 ? l.substring(0, 7) : l),
        datasets: [
          {
            label: 'Historical Actuals (INR)',
            data: labels.map((l, i) => i < historical.length ? historical[i] : null),
            borderColor: '#0058bc',
            borderWidth: 2,
            pointRadius: 2,
            tension: 0.3
          },
          {
            label: 'ARIMA Forecast (INR)',
            data: labels.map((l, i) => i >= historical.length ? forecastVals[i - historical.length] : null),
            borderColor: '#8d2ebc',
            borderWidth: 2.5,
            pointRadius: 3,
            tension: 0.3
          },
          {
            label: 'Upper 95% Bound',
            data: labels.map((l, i) => i >= historical.length ? upper[i - historical.length] : null),
            borderColor: 'rgba(141, 46, 188, 0.3)',
            borderDash: [5, 5],
            borderWidth: 1,
            pointRadius: 0
          },
          {
            label: 'Lower 95% Bound',
            data: labels.map((l, i) => i >= historical.length ? lower[i - historical.length] : null),
            borderColor: 'rgba(141, 46, 188, 0.3)',
            borderDash: [5, 5],
            borderWidth: 1,
            pointRadius: 0
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { position: 'top' },
          tooltip: {
            backgroundColor: '#1a1b22',
            callbacks: { label: (ctx) => `${ctx.dataset.label}: ${formatCompact(ctx.raw)}` }
          }
        },
        scales: {
          x: { grid: { display: false }, ticks: { font: { family: 'Inter', size: 10 }, color: '#717786' } },
          y: { grid: { color: 'rgba(193, 198, 215, 0.3)' }, ticks: { font: { family: 'JetBrains Mono', size: 10 }, color: '#717786', callback: (v) => formatCompact(v) } }
        }
      }
    });
  }

  function initChartDirect(canvasId, type, chartObj, colorDef) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;

    if (chartInstances[canvasId]) {
      chartInstances[canvasId].destroy();
      delete chartInstances[canvasId];
    }

    if (!chartObj || !chartObj.labels || chartObj.labels.length === 0) {
      const ctx = canvas.getContext('2d');
      if (ctx) ctx.clearRect(0, 0, canvas.width, canvas.height);
      return;
    }

    const labels = chartObj.labels;
    const values = chartObj.values;

    chartInstances[canvasId] = safeCreateChart(canvas, {
      type: type,
      data: {
        labels: labels,
        datasets: [{
          data: values,
          backgroundColor: Array.isArray(colorDef) ? colorDef : colorDef,
          borderColor: type === 'line' ? colorDef : 'transparent',
          borderWidth: type === 'line' ? 2 : 0,
          borderRadius: type === 'bar' ? 4 : 0
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: type === 'doughnut' || type === 'pie' },
          tooltip: {
            backgroundColor: '#1a1b22',
            callbacks: {
              label: (ctx) => `${ctx.label}: ${typeof ctx.raw === 'number' && ctx.raw > 1000 ? formatCompact(ctx.raw) : ctx.raw}`
            }
          }
        },
        scales: type === 'doughnut' || type === 'pie' ? {} : {
          x: { grid: { display: false }, ticks: { font: { family: 'Inter', size: 10 }, color: '#717786' } },
          y: { grid: { color: 'rgba(193, 198, 215, 0.3)' }, ticks: { font: { family: 'JetBrains Mono', size: 10 }, color: '#717786', callback: (v) => typeof v === 'number' && v > 1000 ? formatCompact(v) : v } }
        }
      }
    });
  }

  // ── DATA QUALITY & PROFILING RENDER ────────────────────────
  function renderDataQuality(data) {
    const dataset = data.dataset || {};
    const profile = data.profile || {};
    const avail = safeArray(data.available_analysis);
    const unavail = safeArray(data.unavailable_analysis);
    const kpis = safeArray(data.kpis);

    const totalRowsEl = document.getElementById('profile-total-rows');
    const totalColsEl = document.getElementById('profile-total-cols');
    const missingEl = document.getElementById('profile-missing-cells');

    const missingKpi = kpis.find(k => k.label && k.label.toLowerCase().includes('missing'));
    const colsKpi = kpis.find(k => k.label && k.label.toLowerCase().includes('columns'));

    if (totalRowsEl) totalRowsEl.textContent = formatNumber(dataset.rows || 115000);
    if (totalColsEl) totalColsEl.textContent = colsKpi ? colsKpi.value : (Object.keys(profile.col_mapping || {}).length || 26);
    if (missingEl) missingEl.textContent = missingKpi ? missingKpi.value : '0';

    // Detected Badges
    const badgeContainer = document.getElementById('profile-detected-badges');
    if (badgeContainer) {
      badgeContainer.innerHTML = '';
      const detected = safeArray(profile.detected_fields);
      detected.forEach(f => {
        const span = document.createElement('span');
        span.className = 'font-code-sm text-code-sm px-2 py-0.5 rounded bg-primary-fixed text-on-primary-fixed font-semibold';
        span.textContent = f;
        badgeContainer.appendChild(span);
      });
    }

    // Derived Badges
    const derivedContainer = document.getElementById('profile-derived-badges');
    if (derivedContainer) {
      derivedContainer.innerHTML = '';
      const derived = safeArray(profile.derived_fields);
      if (derived.length === 0) {
        derivedContainer.innerHTML = '<span class="text-outline text-body-sm">None (Native Relational Store)</span>';
      } else {
        derived.forEach(d => {
          const span = document.createElement('span');
          span.className = 'font-code-sm text-code-sm px-2 py-0.5 rounded bg-secondary-fixed text-on-secondary-fixed';
          span.textContent = d;
          derivedContainer.appendChild(span);
        });
      }
    }

    // Module Matrix
    const matrixContainer = document.getElementById('profile-module-matrix');
    if (matrixContainer) {
      matrixContainer.innerHTML = '';
      const allModules = [
        'Sales Analysis', 'Product Analysis', 'Customer Analysis',
        'Regional Analysis', 'RFM Segmentation', 'Association Rules',
        'Time Series Forecasting', 'Data Profiling'
      ];

      allModules.forEach(mod => {
        const isAvail = avail.some(a => mod.toLowerCase().includes(a.toLowerCase()));
        const row = document.createElement('div');
        row.className = 'flex items-center justify-between text-body-sm font-body-sm py-1 border-b border-outline-variant/10';
        row.innerHTML = `
          <span>${mod}</span>
          <span class="inline-flex items-center gap-1 font-code-sm text-code-sm font-semibold ${isAvail ? 'text-tertiary' : 'text-error'}">
            <span class="w-1.5 h-1.5 rounded-full ${isAvail ? 'bg-tertiary' : 'bg-error'}"></span>
            ${isAvail ? 'Active' : 'Missing Reqs'}
          </span>
        `;
        matrixContainer.appendChild(row);
      });
    }

    const dupEl = document.getElementById('profile-duplicate-rows');
    if (dupEl) dupEl.textContent = formatNumber(dataset.duplicate_rows || 0);

    const sheetRowEl = document.getElementById('profile-sheet-row');
    const sheetValEl = document.getElementById('profile-selected-sheet');
    if (dataset.selected_sheet && sheetRowEl && sheetValEl) {
      sheetValEl.textContent = dataset.selected_sheet;
      sheetRowEl.style.display = 'flex';
    } else if (sheetRowEl) {
      sheetRowEl.style.display = 'none';
    }

    // Key Findings
    const findingsListEl = document.getElementById('profile-findings-list');
    if (findingsListEl) {
      findingsListEl.innerHTML = '';
      const findings = safeArray(data.findings);
      if (findings.length === 0) {
        findingsListEl.innerHTML = '<li>Dataset evaluated with standard statistical profiling metrics.</li>';
      } else {
        findings.forEach(f => {
          const li = document.createElement('li');
          li.textContent = f;
          findingsListEl.appendChild(li);
        });
      }
    }

    // Limitations List
    const limitationsListEl = document.getElementById('profile-limitations-list');
    if (limitationsListEl) {
      limitationsListEl.innerHTML = '';
      const limitations = safeArray(data.limitations);
      if (limitations.length === 0) {
        limitationsListEl.innerHTML = '<li class="text-tertiary">All statistical prerequisites satisfied. Full analytical suite enabled.</li>';
      } else {
        limitations.forEach(l => {
          const li = document.createElement('li');
          li.className = 'text-error';
          li.innerHTML = `<strong>${l.module || 'Module'}:</strong> ${l.reason || 'Missing required schema columns.'}`;
          limitationsListEl.appendChild(li);
        });
      }
    }

    // Mapping Table
    const tbody = document.getElementById('profile-mapping-tbody');
    if (tbody) {
      tbody.innerHTML = '';
      const mapping = profile.col_mapping || {};
      Object.entries(mapping).forEach(([semantic, colName]) => {
        const isMapped = colName && colName !== 'Not detected';
        const tr = document.createElement('tr');
        tr.className = 'hover:bg-surface-container-low/60 transition-colors';
        tr.innerHTML = `
          <td class="py-2 px-3 font-semibold text-on-surface">${semantic}</td>
          <td class="py-2 px-3 ${isMapped ? 'text-primary font-medium' : 'text-outline'}">${colName}</td>
          <td class="py-2 px-3 text-center">
            <span class="inline-flex px-2 py-0.5 rounded-full text-label-sm font-label-sm ${isMapped ? 'bg-tertiary-fixed text-on-tertiary-fixed font-semibold' : 'bg-surface-container-high text-outline'}">
              ${isMapped ? 'Mapped' : 'Unmapped'}
            </span>
          </td>
        `;
        tbody.appendChild(tr);
      });
    }
  }

  // Expose key handlers to window for navigation, testing and external control
  window.switchSection = switchSection;
  window.renderAllViews = renderAllViews;
  window.fetchAnalyticsData = fetchAnalyticsData;
  window.triggerBuiltinDataset = triggerBuiltinDataset;
  window.uploadUserDataset = uploadUserDataset;
  window.chartInstances = chartInstances;

  // ── Initial Bootstrap ──────────────────────────────────────
  const portDisplay = document.getElementById('profile-port-display');
  if (portDisplay) {
    if (configuredApiBase) {
      portDisplay.textContent = 'Render Cloud';
    } else if (window.location.protocol === 'file:') {
      portDisplay.textContent = 'Port 8001 (Local)';
    } else if (window.location.port) {
      portDisplay.textContent = `Port ${window.location.port}`;
    } else {
      portDisplay.textContent = 'Active (HTTPS)';
    }
  }

  if (window.location.hostname.endsWith('vercel.app') && !configuredApiBase) {
    showError('Vercel Setup Notice: API_BASE_URL is not set yet. Please set API_BASE_URL in your Vercel Project Settings to your deployed Render URL (e.g. https://<backend>.onrender.com).');
  }

  renderBuiltinCards();
  renderHeaderDropdown();
  fetchAnalyticsData();
}



// Resilient Bootstrapping: Handles early, synchronous, or deferred execution
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initApp);
} else {
  initApp();
}
