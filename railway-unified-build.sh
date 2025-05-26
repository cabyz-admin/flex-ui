#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

echo "INFO: Starting Railway build process..."
echo "INFO: Node version: $(node -v), npm version: $(npm -v)"

# Set up environment variables to prevent interactive prompts
export CI=true
export TWILIO_SKIP_SUBACCOUNT_PROMPT=true
export TWILIO_DISABLE_INTERACTIVE=true

# AUTH_TOKEN is passed from nixpacks.toml which has a default
export TWILIO_AUTH_TOKEN="$AUTH_TOKEN"
echo "INFO: TWILIO_AUTH_TOKEN is set."

echo "INFO: Installing Twilio CLI..."
npm install -g twilio-cli@latest --omit=dev --omit=optional

echo "INFO: Installing Twilio Flex plugin via npm..."
npm install -g @twilio-labs/plugin-flex@latest --omit=dev --omit=optional || {
    echo "WARN: Global npm install of Flex plugin failed, trying via twilio plugins..."
    printf "y\n" | twilio plugins:install @twilio-labs/plugin-flex@latest || {
        echo "WARN: Plugin install with auto-yes failed, trying echo approach..."
        echo "y" | twilio plugins:install @twilio-labs/plugin-flex@latest
    }
}

echo "INFO: Checking Twilio CLI plugins..."
twilio plugins || echo "INFO: Plugin list command failed, but continuing..."

twilio plugins:link @twilio-labs/plugin-flex 2>/dev/null || true

echo "INFO: Installing root project dependencies..."
rm -f package-lock.json yarn.lock pnpm-lock.yaml
npm install --legacy-peer-deps --omit=dev --omit=optional

echo "INFO: Building the Flex Plugin..."
cd plugin-flex-ts-template-v2

echo "INFO: Installing plugin dependencies..."
npm install --legacy-peer-deps --omit=dev --omit=optional

echo "INFO: Running Twilio Flex plugin build..."
printf "y\n$TWILIO_AUTH_TOKEN\n" | twilio flex:plugins:build || {
    echo "WARN: Build with auto-answers failed, trying with just 'y'..."
    echo "y" | twilio flex:plugins:build || {
        echo "WARN: Build with echo 'y' failed, trying yes command..."
        yes | twilio flex:plugins:build || {
            echo "ERROR: All Twilio CLI Flex plugin build attempts failed. Trying direct npx build..."
            npx @twilio/flex-plugin-scripts@latest build || {
                echo "CRITICAL ERROR: Direct npx build also failed"
                exit 1
            }
        }
    }
}

# Explicitly check for build directory creation
if [ ! -d "build" ]; then
    echo "CRITICAL ERROR: Flex plugin 'build' directory was NOT created in $(pwd)."
    echo "Listing current directory contents (should be plugin-flex-ts-template-v2):"
    ls -la
    exit 1 # Fail the build script
else
    echo "INFO: Flex plugin 'build' directory successfully created in $(pwd)."
    echo "Contents of 'build' directory:"
    ls -la build
fi

cd ..

echo "INFO: Flex Plugin built successfully. Assets are in plugin-flex-ts-template-v2/build/"
echo "INFO: Railway build process finished."