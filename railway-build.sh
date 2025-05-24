#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

echo "=== Railway Build Phase Start (./railway-build.sh) ==="
# Root production dependencies are assumed to be already installed by 
# Nixpacks' [phases.install] (i.e., npm_config_optional=false npm ci --omit=dev)

echo "Installing specific devDependencies needed for build/deploy scripts..."
# Based on your package.json devDependencies and common script needs:
# - shelljs: For scripts/deploy-addons.mjs and potentially others
# - twilio-cli: For twilio commands (plugin install, serverless operations)
# - semver, prompt, lodash, json5, npm-run-all2: Potentially used by other .mjs scripts
# Using exact versions from your package.json for reproducibility:
npm install \
  shelljs@0.8.5 \
  twilio-cli@5.22.7 \
  semver@7.6.2 \
  prompt@1.3.0 \
  lodash@4.17.21 \
  json5@2.2.3 \
  npm-run-all2@6.0.6
# This command adds these to the /app/node_modules, making them available.

echo "Installing Twilio Serverless Plugin..."
# This command needs 'twilio-cli' from the step above.
npm run install-serverless-plugin 

echo "Running initial postinstall script (for serverless, addons, flex-config)..."
# This runs 'node scripts/setup-environment.mjs', which may use some of the devDeps installed above.
npm run postinstall -- --skip-plugin

echo "Installing dependencies for Flex Plugin (plugin-flex-ts-template-v2)..."
cd plugin-flex-ts-template-v2
npm install # Installs dependencies specific to the plugin
echo "Ensuring Flex Plugin CLI tools are installed (e.g., @twilio-labs/plugin-flex)..."
# This script might also rely on the root 'twilio-cli' or install its own.
npm run install-flex-plugin 
cd ..

echo "Installing dependencies for flex-config..."
cd flex-config
npm install # Installs dependencies specific to flex-config
cd ..

echo "=== Railway Build Phase End (./railway-build.sh) ==="