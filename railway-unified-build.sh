#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

echo "=== Starting Railway Build Process ==="
echo "Current directory: $(pwd)"

echo "=== STEP 1: Installing production dependencies ==="
# Clean up any existing lock files to prevent conflicts
rm -f package-lock.json
rm -f yarn.lock

# Install only production dependencies
npm install --omit=dev --omit=optional --no-package-lock --prefer-offline --no-audit

echo "=== STEP 2: Installing build tools ==="
# Install serve globally for serving the application
npm install -g serve@14.2.1

# Install Twilio CLI and Flex plugin
npm install -g twilio-cli@5.22.7
# Use --force to avoid interactive prompts
twilio plugins:install @twilio-labs/plugin-flex@7.1.0 --force

echo "=== STEP 3: Building Flex plugin ==="
cd plugin-flex-ts-template-v2

# Install plugin dependencies
npm install --omit=dev --omit=optional --no-package-lock --prefer-offline --no-audit

# Build the plugin
echo "Building Flex plugin..."
npm run build

# Verify build was successful
if [ ! -d "build" ]; then
  echo "ERROR: Build directory not found. Build likely failed."
  exit 1
fi

cd ..
echo "=== Build completed successfully ==="

echo "DEBUG: Listing files in current directory (after build):"
ls -la

echo "DEBUG: STEP 2: Installing specific devDependencies needed for build/deploy scripts..."
# Based on your package.json devDependencies and common script needs:
# This will use the newly generated package-lock.json.
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
