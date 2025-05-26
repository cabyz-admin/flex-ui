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

# Set up npm to use a writable directory
export NPM_CONFIG_PREFIX=/app/.npm-global
export PATH="/app/.npm-global/bin:$PATH"
mkdir -p /app/.npm-global
npm config set prefix '/app/.npm-global'

# Install dependencies locally instead of globally
echo "INFO: Installing project dependencies..."
rm -f package-lock.json yarn.lock pnpm-lock.yaml

# Install flex-plugin-scripts locally
npm install --legacy-peer-deps --omit=optional @twilio/flex-plugin-scripts@7.1.0

# Install other required dependencies
npm install --legacy-peer-deps --omit=optional \
  @twilio/flex-plugin@7.1.0 \
  @twilio/flex-dev-utils@7.1.0 \
  webpack webpack-cli webpack-dev-server

# Build using the locally installed flex-plugin-scripts
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

// Serve static files from the build directory
app.use(express.static(path.join(__dirname, 'build')));

// All other GET requests not handled will return the React app
app.get('*', (req, res) => {
  res.sendFile(path.resolve(__dirname, 'build', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
EOL

# Install express for the server
npm install express --save-prod

echo "=== BUILD SUCCESS ==="
echo "Build directory contents:"
ls -la build/

echo "=== FLEX PLUGIN BUILD COMPLETED SUCCESSFULLY ==="
exit 0
