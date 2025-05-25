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

echo "INFO: Installing Twilio CLI..."
npm install -g twilio-cli@latest

echo "INFO: Installing Twilio Flex plugin via npm..."
# Install the Flex plugin directly as a global npm package
npm install -g @twilio-labs/plugin-flex@latest || {
    echo "WARN: Global npm install of Flex plugin failed, trying via twilio plugins..."
    
    # Create a expect-like response for the plugin installation
    # Using printf to send 'y' followed by newline for any prompts
    printf "y\n" | twilio plugins:install @twilio-labs/plugin-flex@latest || {
        echo "WARN: Plugin install with auto-yes failed, trying echo approach..."
        echo "y" | twilio plugins:install @twilio-labs/plugin-flex@latest
    }
}

# Verify plugin installation
echo "INFO: Checking Twilio CLI plugins..."
twilio plugins || echo "INFO: Plugin list command failed, but continuing..."

# Also try to link the plugin if it's installed but not linked
twilio plugins:link @twilio-labs/plugin-flex 2>/dev/null || true

echo "INFO: Installing root project dependencies..."
# Remove lockfile to avoid fsevents issues on Linux if it was committed
rm -f package-lock.json yarn.lock pnpm-lock.yaml
npm install --legacy-peer-deps

echo "INFO: Building the Flex Plugin..."
cd plugin-flex-ts-template-v2

# Install plugin dependencies
npm install --legacy-peer-deps

# Multiple approaches to build the plugin without prompts
echo "INFO: Running Twilio Flex plugin build..."

# First attempt: Use printf to auto-answer any prompts
printf "y\n$TWILIO_AUTH_TOKEN\n" | twilio flex:plugins:build || {
    echo "WARN: Build with auto-answers failed, trying with just 'y'..."
    
    # Second attempt: Just answer 'y' to the plugin install prompt
    echo "y" | twilio flex:plugins:build || {
        echo "WARN: Build with echo 'y' failed, trying yes command..."
        
        # Third attempt: Use yes command
        yes | twilio flex:plugins:build || {
            echo "ERROR: All Flex plugin build attempts failed"
            
            # Last resort: try using npx to run the build command directly
            echo "INFO: Attempting direct build with npx..."
            npx @twilio/flex-plugin-scripts@latest build || {
                echo "ERROR: Direct npx build also failed"
                exit 1
            }
        }
    }
}

cd ..

echo "INFO: Flex Plugin built successfully. Assets are in plugin-flex-ts-template-v2/build/"
echo "INFO: Railway build process finished."