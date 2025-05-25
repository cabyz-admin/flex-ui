#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

echo "INFO: Starting Railway build process..."

echo "INFO: Installing Twilio CLI and essential plugins..."
# Check if already installed to potentially speed up builds, or just install
if ! command -v twilio &> /dev/null || ! twilio plugins | grep -q flex; then
    npm install -g twilio-cli
    twilio plugins:install @twilio-labs/plugin-flex --no-interactive || echo "WARN: Flex plugin install failed or already exists, continuing..."
    # Serverless plugin might not be strictly needed if only building the Flex plugin
    # twilio plugins:install @twilio-labs/plugin-serverless --no-interactive || echo "WARN: Serverless plugin install failed or already exists, continuing..."
else
    echo "INFO: Twilio CLI and Flex plugin appear to be installed."
fi

echo "INFO: Installing root project dependencies..."
npm install --legacy-peer-deps # Added --legacy-peer-deps as it's common for complex projects

echo "INFO: Building the Flex Plugin..."
cd plugin-flex-ts-template-v2
# npm install --legacy-peer-deps # Run if sub-project has its own lockfile or specific needs
twilio flex:plugins:build
cd ..

echo "INFO: Flex Plugin built successfully. Assets are in plugin-flex-ts-template-v2/build/"
echo "INFO: Railway build process finished."#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

echo "INFO: Starting Railway build process..."
echo "INFO: Node version: $(node -v), npm version: $(npm -v)"

echo "INFO: Installing Twilio CLI and essential plugins..."
# This global install is fine.
if ! command -v twilio &> /dev/null || ! twilio plugins | grep -q flex; then
    npm install -g twilio-cli@latest # Use latest twilio-cli
    twilio plugins:install @twilio-labs/plugin-flex --no-interactive || echo "WARN: Flex plugin install failed or already exists, continuing..."
else
    echo "INFO: Twilio CLI and Flex plugin appear to be installed."
fi

echo "INFO: Installing root project dependencies..."
# Remove lockfile to avoid fsevents issues on Linux if it was committed
rm -f package-lock.json yarn.lock pnpm-lock.yaml
npm install --legacy-peer-deps # Installs all dependencies from package.json

echo "INFO: Building the Flex Plugin..."
cd plugin-flex-ts-template-v2
# The root npm install should have handled dependencies for workspaces if configured,
# but an explicit install here is safer if it's not a strict workspace.
npm install --legacy-peer-deps # Ensure plugin's specific deps are met
# Ensure twilio CLI is available for the next command.
# If installed globally, it should be. If installed as a root devDep, use npx.
# Assuming global install from above or PATH is set up by Nixpacks.
twilio flex:plugins:build
cd ..

echo "INFO: Flex Plugin built successfully. Assets are in plugin-flex-ts-template-v2/build/"
echo "INFO: Railway build process finished."