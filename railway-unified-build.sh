#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

echo "INFO: Starting Railway build process..."
echo "INFO: Node version: $(node -v), npm version: $(npm -v)"

echo "INFO: Installing Twilio CLI and essential plugins..."
# Install Twilio CLI globally
npm install -g twilio-cli@latest

# Force install the Flex plugin without prompts
echo "INFO: Installing Twilio Flex plugin..."
# Use yes to auto-answer prompts, or use the force flag
twilio plugins:install @twilio-labs/plugin-flex@latest --force || {
    echo "WARN: Direct plugin install failed, trying alternative method..."
    # Alternative: answer 'y' to any prompts
    yes | twilio plugins:install @twilio-labs/plugin-flex@latest || echo "WARN: Plugin install still failed"
}

# Verify plugin is installed
echo "INFO: Verifying Twilio plugins..."
twilio plugins || echo "No plugins listed"

echo "INFO: Installing root project dependencies..."
# Remove lockfile to avoid fsevents issues on Linux if it was committed
rm -f package-lock.json yarn.lock pnpm-lock.yaml
npm install --legacy-peer-deps # Installs all dependencies from package.json

echo "INFO: Building the Flex Plugin..."
cd plugin-flex-ts-template-v2
# The root npm install should have handled dependencies for workspaces if configured,
# but an explicit install here is safer if it's not a strict workspace.
npm install --legacy-peer-deps # Ensure plugin's specific deps are met

# Build the plugin with explicit non-interactive mode
echo "INFO: Running Twilio Flex plugin build..."
# Set CI environment variable to prevent any prompts
CI=true twilio flex:plugins:build || {
    echo "ERROR: Flex plugin build failed"
    exit 1
}
cd ..

echo "INFO: Flex Plugin built successfully. Assets are in plugin-flex-ts-template-v2/build/"
echo "INFO: Railway build process finished."