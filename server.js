const express = require('express');
const path = require('path');
const fs = require('fs');
const app = express();
const port = process.env.PORT || 3001; // Railway provides PORT via environment variable

const pluginBuildPath = path.join(__dirname, 'plugin-flex-ts-template-v2', 'build');
const pluginBuildPathExists = fs.existsSync(pluginBuildPath);

console.log(`INFO: Attempting to serve static files from: ${pluginBuildPath}`);
console.log(`INFO: Build directory exists: ${pluginBuildPathExists}`);

if (!pluginBuildPathExists) {
  console.error(`ERROR: Build directory does not exist: ${pluginBuildPath}`);
  console.log('INFO: Current directory contents:', fs.readdirSync(__dirname));
  const pluginDir = path.join(__dirname, 'plugin-flex-ts-template-v2');
  if (fs.existsSync(pluginDir)) {
    console.log('INFO: Plugin directory (plugin-flex-ts-template-v2) contents:', fs.readdirSync(pluginDir));
  }
}

// Health check endpoint - always available
app.get('/health', (req, res) => {
  res.json({
    status: pluginBuildPathExists ? 'ok' : 'error_build_dir_missing',
    buildPath: pluginBuildPath,
    buildPathExists: pluginBuildPathExists,
    message: pluginBuildPathExists ? 'Serving Flex plugin' : 'Build directory missing, Flex plugin not served'
  });
});

// Only configure static serving and SPA catch-all if the build directory exists
if (pluginBuildPathExists) {
  console.log('INFO: Build directory found. Configuring static asset serving.');
  console.log('INFO: Contents of build directory:', fs.readdirSync(pluginBuildPath));

  app.use(express.static(pluginBuildPath));

  app.get('*', (req, res) => {
    const indexPath = path.join(pluginBuildPath, 'index.html');
    if (!fs.existsSync(indexPath)) {
      console.error(`ERROR: index.html not found at: ${indexPath} (even though build dir exists)`);
      res.status(404).send(`<h1>Error</h1><p>index.html not found in build directory.</p>`);
    } else {
      res.sendFile(indexPath);
    }
  });
} else {
  console.warn('WARN: Build directory not found. Static assets and SPA routing will not be configured.');
  // Fallback for when build directory is missing, to prevent other errors and give a clear message
  app.get('*', (req, res) => {
    // Exclude /health from this catch-all if it's already handled
    if (req.path === '/health') return res.status(404).send('Not Found'); 

    res.status(503).send(`
      <h1>Service Unavailable</h1>
      <p>The Flex plugin build files are missing and the application cannot start correctly.</p>
      <p>Expected build directory: ${pluginBuildPath}</p>
      <p>Please check the build logs for errors.</p>
      <p><a href="/health">Check Health Status</a></p>
    `);
  });
}

app.listen(port, () => {
  console.log(`INFO: Flex plugin static server process started, listening on port ${port}`);
  if (pluginBuildPathExists) {
    console.log(`INFO: Serving static assets from: ${pluginBuildPath}`);
  } else {
    console.error(`CRITICAL ERROR: Not serving static assets because build directory is missing: ${pluginBuildPath}`);
  }
});