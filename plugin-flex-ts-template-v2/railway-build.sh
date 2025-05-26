#!/bin/bash
# Enable verbose output and exit on any error
set -exo pipefail

echo "=== FLEX PLUGIN BUILD STARTED ==="
echo "INFO: Node version: $(node -v), npm version: $(npm -v)"
echo "INFO: Current working directory: $(pwd)"
echo "INFO: Directory contents:"
ls -la

# Set up environment variables
export CI=true
export NODE_ENV=production

# Create a temporary directory for npm cache
export NPM_CONFIG_CACHE="$(pwd)/.npm"
mkdir -p "$NPM_CONFIG_CACHE"

# Clean up any previous builds
rm -rf build node_modules package-lock.json

# Install all dependencies locally
echo "INFO: Installing project dependencies..."
npm install --legacy-peer-deps --omit=optional

# Install build dependencies
echo "INFO: Installing build dependencies..."
npm install --legacy-peer-deps --omit=optional \
  @twilio/flex-plugin-scripts@7.1.0 \
  @twilio/flex-plugin@7.1.0 \
  @twilio/flex-dev-utils@7.1.0 \
  webpack@^5.88.2 \
  webpack-cli@^5.1.4 \
  webpack-dev-server@^4.15.1

# Build the plugin
echo "INFO: Building plugin..."
TWILIO_ACCOUNT_SID=AC00000000000000000000000000000000 \
TWILIO_AUTH_TOKEN=${AUTH_TOKEN:-4320eb2a6d58faef9c9c21a8f13aa3e3} \
TWILIO_FLEX_PLUGIN_ENV=production \
npx flex-plugin-scripts build

# Verify build directory was created
if [ ! -d "build" ]; then
    echo "CRITICAL ERROR: Build directory was not created!"
    echo "Current directory contents:"
    ls -la
    exit 1
fi

# Create a simple server to serve the built files
cat > server.js << 'EOL'
const express = require('express');
const path = require('path');
const app = express();
const PORT = process.env.PORT || 3000;

// Log all requests
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Serve static files from the build directory
const staticPath = path.join(__dirname, 'build');
console.log(`Serving static files from: ${staticPath}`);
app.use(express.static(staticPath));

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

// All other GET requests not handled will return the React app
app.get('*', (req, res) => {
  const indexPath = path.resolve(__dirname, 'build', 'index.html');
  console.log(`Serving index.html from: ${indexPath}`);
  
  // Check if file exists
  const fs = require('fs');
  if (!fs.existsSync(indexPath)) {
    console.error('ERROR: index.html not found in build directory');
    return res.status(500).send('Build files not found. The build may have failed.');
  }
  
  res.sendFile(indexPath);
});

// Error handling
app.use((err, req, res, next) => {
  console.error('Server error:', err.stack);
  res.status(500).send('Something broke!');});

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on port ${PORT}`);
  console.log('Build directory contents:', require('fs').readdirSync('build'));
});

// Handle shutdown gracefully
process.on('SIGTERM', () => {
  console.log('SIGTERM received. Shutting down gracefully...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});
EOL

# Install express for the server
echo "INFO: Installing express server..."
npm install express --save-prod

echo "=== BUILD SUCCESS ==="
echo "Build directory contents:"
ls -la build/

echo "=== FLEX PLUGIN BUILD COMPLETED SUCCESSFULLY ==="
exit 0
