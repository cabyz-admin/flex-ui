#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

echo "INFO: Starting Railway build process..."
echo "INFO: Node version: $(node -v), npm version: $(npm -v)"

# Set up environment variables to prevent interactive prompts
export CI=true
export TWILIO_SKIP_SUBACCOUNT_PROMPT=true
export TWILIO_DISABLE_INTERACTIVE=true

# If AUTH_TOKEN is provided via environment, use it
if [ -n "$AUTH_TOKEN" ]; then
    export TWILIO_AUTH_TOKEN="$AUTH_TOKEN"
else
    # Fallback to the provided token if needed
    export TWILIO_AUTH_TOKEN="4320eb2a6d58faef9c9c21a8f13aa3e3"
fi

echo "INFO: Installing root project dependencies..."
# Remove lockfile to avoid fsevents issues on Linux if it was committed
rm -f package-lock.json yarn.lock pnpm-lock.yaml
npm install --legacy-peer-deps

echo "INFO: Building the Flex Plugin..."
cd plugin-flex-ts-template-v2

# Install plugin dependencies
echo "INFO: Installing plugin dependencies..."
npm install --legacy-peer-deps

# Build the plugin using npm run build
echo "INFO: Building plugin with npm run build..."
npm run build || {
    echo "ERROR: npm run build failed"
    
    # Fallback: try using the webpack directly
    echo "INFO: Trying direct webpack build..."
    npx webpack --mode production --config webpack.config.js || {
        echo "ERROR: Direct webpack build also failed"
        exit 1
    }
}

# Verify build output exists
if [ -d "build" ]; then
    echo "INFO: Build directory created successfully!"
    echo "INFO: Build contents:"
    ls -la build/
else
    echo "ERROR: Build directory was not created!"
    echo "INFO: Current directory contents:"
    ls -la
    exit 1
fi

cd ..

echo "INFO: Flex Plugin built successfully. Assets are in plugin-flex-ts-template-v2/build/"
echo "INFO: Railway build process finished."