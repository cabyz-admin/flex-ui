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

# Ensure npm global bin is in PATH
export PATH="/app/.npm-global/bin:$PATH"
mkdir -p /app/.npm-global
npm config set prefix '/app/.npm-global'

echo "INFO: Checking Twilio CLI installation..."
if ! command -v twilio &> /dev/null; then
    echo "Twilio CLI not found, installing..."
    npm install -g twilio-cli --omit=dev
fi

# Verify Twilio CLI installation
twilio --version || {
    echo "ERROR: Failed to install or find Twilio CLI"
    echo "PATH: $PATH"
    echo "Global npm modules:"
    npm list -g --depth=0
    exit 1
}

# Install project dependencies
echo "INFO: Installing project dependencies..."
rm -f package-lock.json yarn.lock pnpm-lock.yaml
npm install --legacy-peer-deps --omit=dev --omit=optional

# Install flex-plugin-scripts locally for npx to find
echo "INFO: Installing @twilio/flex-plugin-scripts..."
npm install @twilio/flex-plugin-scripts --save-dev

# Build using flex-plugin-scripts with proper environment variables
echo "INFO: Building plugin using flex-plugin-scripts..."
TWILIO_ACCOUNT_SID=AC00000000000000000000000000000000 \
TWILIO_AUTH_TOKEN=${AUTH_TOKEN:-4320eb2a6d58faef9c9c21a8f13aa3e3} \
./node_modules/.bin/twilio-flex-plugin-scripts build || {
    echo "WARN: flex-plugin-scripts build failed, trying webpack directly..."
    npx webpack --mode=production || {
        echo "ERROR: All build methods failed"
        exit 1
    }
}

# Verify build directory was created
if [ ! -d "build" ]; then
    echo "CRITICAL ERROR: Build directory was not created!"
    echo "Current directory contents:"
    ls -la
    exit 1
fi

echo "=== BUILD SUCCESS ==="
echo "Build directory contents:"
ls -la build/

echo "=== FLEX PLUGIN BUILD COMPLETED SUCCESSFULLY ==="

# Create a simple HTTP server to serve the built files
cat > server.js << 'EOL'
const express = require('express');
const path = require('path');
const app = express();
const port = process.env.PORT || 3000;

app.use(express.static(path.join(__dirname, 'build')));

app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'build', 'index.html'));
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
EOL

echo "=== STARTING HTTP SERVER ==="
npx express@4.17.1
node server.js
