const express = require('express');
const path = require('path');
const fs = require('fs');
const app = express();
const port = process.env.PORT || 3001; // Railway provides PORT via environment variable

// Correct path to the built plugin assets
const pluginBuildPath = path.join(__dirname, 'plugin-flex-ts-template-v2', 'build');

console.log(`Attempting to serve static files from: ${pluginBuildPath}`);

// Check if build directory exists
if (!fs.existsSync(pluginBuildPath)) {
  console.error(`ERROR: Build directory does not exist: ${pluginBuildPath}`);
  console.log('Current directory contents:', fs.readdirSync(__dirname));
  
  const pluginDir = path.join(__dirname, 'plugin-flex-ts-template-v2');
  if (fs.existsSync(pluginDir)) {
    console.log('Plugin directory contents:', fs.readdirSync(pluginDir));
  }
} else {
  console.log('Build directory found. Contents:', fs.readdirSync(pluginBuildPath));
}

// Serve static files from the plugin's build directory
app.use(express.static(pluginBuildPath));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', buildPath: pluginBuildPath, exists: fs.existsSync(pluginBuildPath) });
});

// A catch-all to serve index.html for any direct navigation to sub-paths (good for SPAs)
app.get('*', (req, res) => {
  const indexPath = path.join(pluginBuildPath, 'index.html');
  
  if (!fs.existsSync(indexPath)) {
    console.error(`ERROR: index.html not found at: ${indexPath}`);
    res.status(404).send(`
      <h1>Build Error</h1>
      <p>The Flex plugin build files were not found.</p>
      <p>Expected location: ${indexPath}</p>
      <p>Build directory exists: ${fs.existsSync(pluginBuildPath)}</p>
    `);
    return;
  }
  
  res.sendFile(indexPath);
});

app.listen(port, () => {
  console.log(`Flex plugin static server listening on port ${port}`);
  console.log(`Build directory: ${pluginBuildPath}`);
  console.log(`Build directory exists: ${fs.existsSync(pluginBuildPath)}`);
});