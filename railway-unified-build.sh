#!/bin/bash
echo "DEBUG: railway-unified-build.sh SCRIPT IS EXECUTING NOW"
set -e # Exit immediately if a command exits with a non-zero status.

echo "DEBUG: Current directory: $(pwd)"
echo "DEBUG: Listing files in current directory:"
ls -la

echo "DEBUG: STEP 1: Running initial production npm ci..."
# Ensure fsevents and other optional dependencies are handled correctly, and only install production deps
# Your .npmrc file with 'optional=false' will be respected here.
npm_config_optional=false npm ci --omit=dev
echo "DEBUG: FINISHED initial production npm ci."

echo "DEBUG: STEP 2: Installing specific devDependencies needed for build/deploy scripts..."
# Based on your package.json devDependencies and common script needs:
npm install \
  shelljs@0.8.5 \
  twilio-cli@5.22.7 \
  semver@7.6.2 \
  prompt@1.3.0 \
  lodash@4.17.21 \
  json5@2.2.3 \
  npm-run-all2@6.0.6
echo "DEBUG: FINISHED installing specific devDependencies."

echo "DEBUG: STEP 3: Installing Twilio Serverless Plugin..."
# This command needs 'twilio-cli' from the step above.
npm run install-serverless-plugin
echo "DEBUG: FINISHED installing Twilio Serverless Plugin."

echo "DEBUG: STEP 4: Running initial postinstall script (for serverless, addons, flex-config)..."
# This runs 'node scripts/setup-environment.mjs', which may use some of the devDeps installed above.
npm run postinstall -- --skip-plugin
echo "DEBUG: FINISHED running initial postinstall script."

echo "DEBUG: STEP 5: Installing dependencies for Flex Plugin (plugin-flex-ts-template-v2)..."
cd plugin-flex-ts-template-v2
echo "DEBUG: Current directory: $(pwd) (inside plugin-flex-ts-template-v2)"
npm install # Installs dependencies specific to the plugin
echo "DEBUG: Ensuring Flex Plugin CLI tools are installed (e.g., @twilio-labs/plugin-flex)..."
npm run install-flex-plugin
cd ..
echo "DEBUG: Returned to directory: $(pwd)"
echo "DEBUG: FINISHED installing dependencies for Flex Plugin."

echo "DEBUG: STEP 6: Installing dependencies for flex-config..."
cd flex-config
echo "DEBUG: Current directory: $(pwd) (inside flex-config)"
npm install # Installs dependencies specific to flex-config
cd ..
echo "DEBUG: Returned to directory: $(pwd)"
echo "DEBUG: FINISHED installing dependencies for flex-config."

echo "DEBUG: STEP 7: Verifying shelljs installation..."
if node -e "require.resolve('shelljs')" &> /dev/null; then
  echo "DEBUG: shelljs IS RESOLVABLE by Node.js"
else
  echo "DEBUG: shelljs IS NOT RESOLVABLE by Node.js - THIS IS A PROBLEM"
  echo "DEBUG: Contents of /app/node_modules:"
  ls -la /app/node_modules
  echo "DEBUG: Contents of /app/node_modules/shelljs (if it exists):"
  ls -la /app/node_modules/shelljs || echo "DEBUG: /app/node_modules/shelljs directory does not exist"
fi

echo "DEBUG: railway-unified-build.sh SCRIPT FINISHED"
