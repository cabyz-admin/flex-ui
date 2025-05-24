#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

echo "=== Railway Start/Deploy Phase Start ==="

# Environment Variables from Railway:
# TWILIO_ACCOUNT_SID, TWILIO_API_KEY, TWILIO_API_SECRET, TF_ENCRYPTION_KEY
# ENVIRONMENT (e.g., staging, production)
# INITIAL_RELEASE (true/false)
# OVERWRITE_CONFIG (true/false)
# DEPLOY_TERRAFORM (true/false)

# --- 1. Validate Environment (Optional in Railway, as env vars are set directly) ---
# If your 'npm run -s validate-environment' script is crucial and doesn't rely on GitHub-specific APIs, you can run it.
# echo "Running environment validation..."
# npm run -s validate-environment

# --- 2. Initial Serverless Release (Conditional) ---
# Mimics 'perform-initial-serverless-release' job
if [ "$INITIAL_RELEASE" = "true" ] && [ "$DEPLOY_TERRAFORM" = "true" ]; then
  echo "Performing Initial Serverless Release steps..."
  # The 'npm run postinstall -- --skip-plugin' was already run in build.
  # If a different postinstall is needed here, adjust.
  echo "Deploying Addons (Initial Release)..."
  npm run deploy-addons
  echo "Deploying Main Serverless Functions (Initial Release)..."
  cd serverless-functions
  npm run deploy
  cd ..
else
  echo "Skipping Initial Serverless Release steps."
fi

# --- 3. Deploy Terraform (Conditional and Complex) ---
# Mimics 'deploy-terraform' job which uses './.github/workflows/terraform_deploy.yaml'
if [ "$DEPLOY_TERRAFORM" = "true" ]; then
  echo "Attempting Terraform Deployment..."
  # This is the most complex part to translate directly.
  # Your terraform_deploy.yaml likely does:
  # - checkout code
  # - setup terraform CLI
  # - terraform init, plan, apply
  # To replicate, you'd need to:
  # 1. Ensure Terraform CLI is available in your Railway environment (add to Nixpacks/Dockerfile).
  # 2. Navigate to your Terraform configuration directory.
  # 3. Run terraform init, plan, apply, passing necessary variables.
  # Example (highly simplified, assumes Terraform files are in a 'terraform/' dir):
  # cd terraform
  # terraform init
  # terraform apply -auto-approve \
  #   -var="twilio_account_sid=$TWILIO_ACCOUNT_SID" \
  #   -var="twilio_api_key=$TWILIO_API_KEY" \
  #   # ... other vars ...
  # cd ..
  echo "TERRAFORM DEPLOYMENT: Manual implementation required based on terraform_deploy.yaml content."
  echo "For now, this step is a placeholder. You'll need to script the Terraform CLI commands here."
else
  echo "Skipping Terraform Deployment."
fi

# --- 4. Deploy Packages (Addons & Serverless) ---
# Mimics 'deploy-packages' job. This often runs regardless of initial release.
echo "Deploying Addons (Main Deployment)..."
npm run deploy-addons # This script iterates through addons and runs 'npm run deploy' in each

echo "Deploying Main Serverless Functions (Main Deployment)..."
cd serverless-functions
npm run deploy # This runs 'npm run deploy' from serverless-functions/package.json
cd ..

# --- 5. Deploy Flex Config ---
# Mimics 'deploy-flex-config' job
echo "Deploying Flex Configuration..."
# The 'deploy-flex-config' job runs 'npm run postinstall -- --packages=flex-config'
# If this specific postinstall is vital before its deploy, run it:
# npm run postinstall -- --packages=flex-config
cd flex-config
# The OVERWRITE_CONFIG logic from GitHub Actions needs to be passed to this script if it uses it.
# Assuming 'npm run deploy' in flex-config reads OVERWRITE_CONFIG from env:
echo "OVERWRITE_CONFIG is set to: $OVERWRITE_CONFIG"
npm run deploy
cd ..

# --- 6. Deploy and Release Flex Plugin ---
# Mimics 'deploy-release-plugin' job
echo "Deploying and Releasing Flex Plugin..."
cd plugin-flex-ts-template-v2
# The plugin's own 'npm run deploy' and 'npm run release' scripts handle its build.
GIT_COMMIT_SHA=$(git rev-parse --short HEAD || echo "unknown")
npm run deploy -- --changelog="Deploy from Railway - Commit $GIT_COMMIT_SHA"
npm run release -- --name="Release from Railway - Commit $GIT_COMMIT_SHA" --description="Release from Railway - Commit $GIT_COMMIT_SHA"
cd ..

echo "=== Railway Start/Deploy Phase End: All deployments initiated. ==="

# --- 7. Start the Flex UI Server ---
echo "Starting Flex UI server..."
cd plugin-flex-ts-template-v2

# Ensure serve is installed locally (in case it wasn't installed globally)
echo "DEBUG: Ensuring serve is installed..."
npm install serve --save-dev

# For production, we'll use the --name and --no-browser flags
# and specify a port that Railway expects (from the PORT environment variable)
PORT=${PORT:-3000}
echo "Starting Flex UI on port $PORT..."

# Check if build directory exists
if [ ! -d "build" ]; then
  echo "ERROR: Build directory not found. The build process may have failed."
  echo "Current directory: $(pwd)"
  ls -la
  exit 1
fi

# Start the server with a 5-minute timeout to catch any startup errors
# If the server crashes, the container will restart
echo "Starting server on port $PORT..."
npx serve -s build -l $PORT &
SERVER_PID=$!

echo "Waiting for server to start..."
sleep 5

# Check if the server is still running
if ! ps -p $SERVER_PID > /dev/null; then
  echo "ERROR: Server failed to start. Check the logs above for errors."
  exit 1
fi

echo "Flex UI server is running on port $PORT"

# Keep the container running and monitor the server process
while true; do
  if ! ps -p $SERVER_PID > /dev/null; then
    echo "ERROR: Server process has stopped. Exiting..."
    exit 1
  fi
  sleep 5
done