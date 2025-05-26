#!/bin/bash
# Enable verbose output and exit on any error
set -exo pipefail

echo "=== RAILWAY BUILD STARTED ==="
echo "INFO: Node version: $(node -v), npm version: $(npm -v)"
echo "INFO: Current working directory: $(pwd)"
echo "INFO: Directory contents:"
ls -la

# Set up environment variables
export CI=true
export NODE_ENV=production

echo "INFO: Installing root project dependencies..."
rm -f package-lock.json yarn.lock pnpm-lock.yaml
npm install --legacy-peer-deps --omit=dev --omit=optional

echo "=== BUILDING FLEX PLUGIN ==="
if [ ! -d "plugin-flex-ts-template-v2" ]; then
    echo "ERROR: plugin-flex-ts-template-v2 directory not found!"
    echo "Current directory contents:"
    ls -la
    exit 1
fi

cd plugin-flex-ts-template-v2
echo "Current directory: $(pwd)"

# Install plugin dependencies
echo "INFO: Installing plugin dependencies..."
npm install --legacy-peer-deps --omit=dev --omit=optional

# Build using flex-plugin-scripts directly (bypasses Twilio CLI authentication)
echo "INFO: Building plugin using flex-plugin-scripts..."
npx @twilio/flex-plugin-scripts build || {
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

cd ..

echo "=== RAILWAY BUILD COMPLETED SUCCESSFULLY ==="
exit 0