#!/bin/bash
# Enable verbose output and exit on any error
set -exo pipefail

echo "=== RAILWAY BUILD STARTED ==="
echo "INFO: Node version: $(node -v), npm version: $(npm -v)"
echo "INFO: Current working directory: $(pwd)"
echo "INFO: Directory contents:"
ls -la

# Set up environment variables to prevent interactive prompts
export CI=true
export TWILIO_SKIP_SUBACCOUNT_PROMPT=true
export TWILIO_DISABLE_INTERACTIVE=true

# AUTH_TOKEN is passed from nixpacks.toml which has a default
export TWILIO_AUTH_TOKEN="${AUTH_TOKEN:-4320eb2a6d58faef9c9c21a8f13aa3e3}"
echo "INFO: TWILIO_AUTH_TOKEN is set (length: ${#TWILIO_AUTH_TOKEN} chars)"

# Function to log and run commands with error handling
run_command() {
    echo "\n=== RUNNING: $* ==="
    if ! "$@"; then
        echo "ERROR: Command failed: $*"
        return 1
    fi
    echo "=== COMPLETED: $* ===\n"
}

# Main build process
{
    # Install Twilio CLI
    run_command npm install -g twilio-cli@latest --omit=dev --omit=optional
    
    # Install Flex plugin with multiple fallback methods
    echo "=== INSTALLING TWILIO FLEX PLUGIN ==="
    if ! npm install -g @twilio-labs/plugin-flex@latest --omit=dev --omit=optional; then
        echo "WARN: Global npm install of Flex plugin failed, trying via twilio plugins..."
        if ! printf "y\n" | twilio plugins:install @twilio-labs/plugin-flex@latest; then
            echo "WARN: Plugin install with auto-yes failed, trying echo approach..."
            if ! echo "y" | twilio plugins:install @twilio-labs/plugin-flex@latest; then
                echo "ERROR: All plugin installation methods failed"
            fi
        fi
    fi
    
    # Verify and link plugin
    echo "=== VERIFYING PLUGIN INSTALLATION ==="
    twilio plugins || echo "WARN: Could not list Twilio plugins"
    twilio plugins:link @twilio-labs/plugin-flex 2>/dev/null || echo "WARN: Could not link Flex plugin"
    
    # Install root dependencies
    echo "=== INSTALLING ROOT DEPENDENCIES ==="
    run_command rm -f package-lock.json yarn.lock pnpm-lock.yaml
    run_command npm install --legacy-peer-deps --omit=dev --omit=optional
    
    # Build the plugin
    if [ ! -d "plugin-flex-ts-template-v2" ]; then
        echo "ERROR: plugin-flex-ts-template-v2 directory not found!"
        echo "Current directory contents:"
        ls -la
        exit 1
    fi
    
    echo "=== BUILDING FLEX PLUGIN ==="
    cd plugin-flex-ts-template-v2
    echo "Current directory: $(pwd)"
    
    # Install plugin dependencies
    run_command npm install --legacy-peer-deps --omit=dev --omit=optional
    
    # Try multiple build methods
    echo "=== ATTEMPTING TO BUILD PLUGIN ==="
    if ! printf "y\n$TWILIO_AUTH_TOKEN\n" | twilio flex:plugins:build; then
        echo "WARN: First build attempt failed, trying with just 'y'..."
        if ! echo "y" | twilio flex:plugins:build; then
            echo "WARN: Second build attempt failed, trying with 'yes'..."
            if ! yes | twilio flex:plugins:build; then
                echo "ERROR: All Twilio CLI build attempts failed. Trying direct npx build..."
                if ! npx @twilio/flex-plugin-scripts@latest build; then
                    echo "CRITICAL ERROR: All build methods failed"
                    exit 1
                fi
            fi
        fi
    fi
    
    # Verify build directory was created
    if [ ! -d "build" ]; then
        echo "CRITICAL ERROR: Build directory was not created!"
        echo "Current directory contents:"
        ls -la
        exit 1
    fi
    
    echo "=== BUILD SUCCESS ==="
    echo "Build directory contents:"
    ls -la build/
    
} || {
    echo "=== BUILD FAILED ==="
    echo "Error on line $LINENO"
    exit 1
}

echo "=== RAILWAY BUILD COMPLETED SUCCESSFULLY ==="
exit 0