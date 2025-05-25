const express = require('express');
const path = require('path');
const app = express();
const port = process.env.PORT || 3001; // Railway provides PORT via environment variable

// Correct path to the built plugin assets
const pluginBuildPath = path.join(__dirname, 'plugin-flex-ts-template-v2', 'build');

console.log(`Attempting to serve static files from: ${pluginBuildPath}`);

// Serve static files from the plugin's build directory
app.use(express.static(pluginBuildPath));

// A catch-all to serve index.html for any direct navigation to sub-paths (good for SPAs)
app.get('*', (req, res) => {
  const indexPath = path.join(pluginBuildPath, 'index.html');
  res.sendFile(indexPath, (err) => {
    if (err) {
      console.error('Error sending index.html:', err);
      res.status(500).send(err);
    }
  });
});

app.listen(port, () => {
  console.log(`Flex plugin static server listening on port ${port}`);
});