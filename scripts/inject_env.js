// scripts/inject_env.js
// Executed during Vercel build to inject environment variables into static frontend config

const fs = require('fs');
const path = require('path');

const configPath = path.join(__dirname, '..', 'web', 'js', 'config.js');

// Support standard frontend environment variables
const rawUrl = (
  process.env.VITE_API_BASE_URL ||
  process.env.API_BASE_URL ||
  process.env.RENDER_BACKEND_URL ||
  process.env.NEXT_PUBLIC_API_BASE_URL ||
  ''
).trim();

// Strip any trailing slashes for clean relative path concatenation
const apiUrl = rawUrl.replace(/\/+$/, '');

const fileContent = `// ==============================================================================
// web/js/config.js — Runtime Environment Configuration (Auto-Generated on Build)
// ==============================================================================
// Configured API Base URL: ${apiUrl ? apiUrl : '(Empty - Local Same-Origin Fallback)'}
// ==============================================================================

window.__APP_CONFIG__ = {
  API_BASE_URL: ${JSON.stringify(apiUrl)}
};
`;

try {
  fs.writeFileSync(configPath, fileContent, 'utf-8');
  console.log(`[inject_env] Successfully wrote web/js/config.js`);
  console.log(`[inject_env] API_BASE_URL set to: "${apiUrl || '(empty - defaults to local localhost:8001)'}"`);
} catch (err) {
  console.error(`[inject_env] Error writing web/js/config.js:`, err);
  process.exit(1);
}
