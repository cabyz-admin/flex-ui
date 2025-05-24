#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

echo "=== Railway Start/Deploy Phase Start ==="

# Set default values for environment variables
ENVIRONMENT=${ENVIRONMENT:-production}
INITIAL_RELEASE=${INITIAL_RELEASE:-false}
DEPLOY_TERRAFORM=${DEPLOY_TERRAFORM:-false}
OVERWRITE_CONFIG=${OVERWRITE_CONFIG:-false}

# Debug environment
echo "=== Environment Variables ==="
echo "ENVIRONMENT: $ENVIRONMENT"
echo "INITIAL_RELEASE: $INITIAL_RELEASE"
echo "DEPLOY_TERRAFORM: $DEPLOY_TERRAFORM"
echo "OVERWRITE_CONFIG: $OVERWRITE_CONFIG"

# --- 1. Deploy Addons ---
echo "=== Deploying Addons ==="
if [ -f "package.json" ] && grep -q "deploy-addons" package.json; then
  echo "Running deploy-addons script..."
  npm run deploy-addons
else
  echo "No deploy-addons script found in package.json, skipping..."
fi

# --- 2. Deploy Serverless Functions ---
echo "=== Deploying Serverless Functions ==="
if [ -d "serverless-functions" ]; then
  echo "Found serverless-functions directory, deploying..."
  cd serverless-functions
  npm install --omit=dev --no-package-lock --prefer-offline --no-audit
  npm run deploy
  cd ..
else
  echo "No serverless-functions directory found, skipping..."
fi

# --- 3. Deploy Flex Config ---
echo "=== Deploying Flex Configuration ==="
if [ -d "flex-config" ]; then
  echo "Found flex-config directory, deploying..."
  cd flex-config
  npm install --omit=dev --no-package-lock --prefer-offline --no-audit
  echo "OVERWRITE_CONFIG is set to: $OVERWRITE_CONFIG"
  npm run deploy
  cd ..
else
  echo "No flex-config directory found, skipping..."
fi

# --- 4. Deploy and Release Flex Plugin ---
echo "=== Deploying and Releasing Flex Plugin ==="
if [ -d "plugin-flex-ts-template-v2" ]; then
  cd plugin-flex-ts-template-v2
  
  # Install dependencies if needed
  if [ ! -d "node_modules" ]; then
    echo "Installing plugin dependencies..."
    npm install --omit=dev --no-package-lock --prefer-offline --no-audit
  fi
  
  # Build the plugin if not already built
  if [ ! -d "build" ]; then
    echo "Building plugin..."
    npm run build
  fi
  
  # Deploy the plugin
  echo "Deploying plugin..."
  GIT_COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
  npm run deploy -- --changelog="Deploy from Railway - $GIT_COMMIT_SHA"
  
  # Only run release if not in development
  if [ "$ENVIRONMENT" = "production" ]; then
    echo "Releasing plugin..."
    npm run release -- --name="Release $GIT_COMMIT_SHA" --description="Auto-deployed from Railway"
  else
    echo "Skipping plugin release in non-production environment"
  fi
  
  cd ..
else
  echo "No plugin-flex-ts-template-v2 directory found, skipping..."
fi

echo "=== Railway Start/Deploy Phase Complete ==="

# --- 5. Start the Flex UI Server ---
echo "=== Starting Flex UI Server ==="
if [ -d "plugin-flex-ts-template-v2" ]; then
  cd plugin-flex-ts-template-v2
  
  # Set default port if not provided
  PORT=${PORT:-3000}
  
  # Verify build directory exists
  if [ ! -d "build" ]; then
    echo "=== ERROR: Build directory not found. Attempting to build... ==="
    npm run build || { echo "=== Build failed. Exiting. ==="; exit 1; }
  fi
  
  # Install serve if not already installed
  if [ ! -d "node_modules/serve" ]; then
    echo "Installing serve..."
    npm install serve@14.2.1 --save-dev --no-package-lock --prefer-offline --no-audit
  fi
  
  # Start the server
  echo "=== Starting server on port $PORT ==="
  ./node_modules/.bin/serve -s build -l $PORT &
  SERVER_PID=$!
  
  # Wait for server to start
  echo "Waiting for server to start..."
  sleep 5
  
  # Verify server is running
  if ! ps -p $SERVER_PID > /dev/null; then
    echo "=== ERROR: Server failed to start ==="
    exit 1
  fi
  
  echo "=== Server is running on port $PORT ==="
  
  # Keep the container alive
  while true; do
    if ! ps -p $SERVER_PID > /dev/null; then
      echo "=== Server process has stopped ==="
      exit 1
    fi
    sleep 10
  done
else
  echo "=== ERROR: Plugin directory not found. Cannot start server. ==="
  exit 1
fi