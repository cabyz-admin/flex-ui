#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

echo "=== Railway Build Phase Start ==="
# Node.js v18 should be set in Railway service settings (Nixpacks usually auto-detects or can be configured)
# Root dependencies are installed by Nixpacks' [phases.install] as defined in nixpacks.toml

echo "Installing Twilio Serverless Plugin..."
npm run install-serverless-plugin # From your workflow

echo "Running initial postinstall script (for serverless, addons, flex-config)..."
# This command prepares various packages by linking dependencies, etc.
# The specific arguments (--skip-plugin or --packages=flex-config) are used later in the start script
# For a general build, a broad postinstall might be okay, or you can be more specific if needed.
# Let's use the one that sets up most things initially.
npm run postinstall -- --skip-plugin

echo "Installing dependencies for Flex Plugin (plugin-flex-ts-template-v2)..."
cd plugin-flex-ts-template-v2
npm install
echo "Ensuring Flex Plugin CLI tools are installed (e.g., @twilio-labs/plugin-flex)..."
npm run install-flex-plugin # From your 'deploy-release-plugin' job
cd ..

echo "Installing dependencies for flex-config..."
cd flex-config
npm install
cd ..

# Dependencies for individual addons (e.g., serverless-schedule-manager) and serverless-functions
# are typically installed as part of their respective 'npm run deploy' scripts,
# which often include an 'npm install' step internally or are handled by the twilio-cli.
# If any addon requires a specific pre-build/install step *before* its deploy script is called, add it here.

echo "=== Railway Build Phase End: Dependencies installed and tools ready ==="