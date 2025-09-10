#!/bin/bash

# Production-ready entrypoint script for service-discovery
ENV_JSON_FILE="/mnt/secrets/service-discovery-env.json"

# List of environment variables to ignore (already hardcoded in deployment)
IGNORE_VARS="SPRING_PROFILES_ACTIVE SERVER_PORT EUREKA_CLIENT_SERVICEURL_DEFAULTZONE ENV_CONFIG_FILE"

echo "=== Service Discovery Entrypoint ==="
echo "Loading environment variables from: $ENV_JSON_FILE"

if [ -f "$ENV_JSON_FILE" ]; then
  # Check if JSON file is valid
  if ! jq empty "$ENV_JSON_FILE" 2>/dev/null; then
    echo "ERROR: Invalid JSON format in $ENV_JSON_FILE"
    echo "Continuing with existing environment variables..."
  else
    # Create a temporary file to store the export commands
    temp_exports=$(mktemp)
    
    # Parse JSON using jq and process each key-value pair
    # Handle string values
    jq -r 'to_entries[] | select(.value | type == "string") | "\(.key)=\(.value)"' "$ENV_JSON_FILE" > /tmp/json_env.tmp
    
    # Handle complex JSON types (objects and arrays) by converting to JSON strings
    jq -r 'to_entries[] | select(.value | type != "string") | "\(.key)=\(.value | tostring)"' "$ENV_JSON_FILE" >> /tmp/json_env.tmp
    
    echo "Found $(wc -l < /tmp/json_env.tmp) environment variables in JSON file"
    
    while IFS= read -r line; do
      # Skip empty lines
      [ -z "$line" ] && continue
      
      # Extract key and value
      key="${line%%=*}"
      value="${line#*=}"
      
      # Skip empty key or value
      [ -z "$key" ] || [ -z "$value" ] && continue
      
      # Check if should ignore
      should_ignore=false
      for ignore_var in $IGNORE_VARS; do
        if [ "$key" = "$ignore_var" ]; then
          should_ignore=true
          echo "  [IGNORED] $key (hardcoded in deployment)"
          break
        fi
      done
      
      # Export if not ignored and not already set
      if [ "$should_ignore" = false ] && [ -z "$(printenv "$key")" ]; then
        echo "export $key=\"$value\"" >> "$temp_exports"
        echo "  [LOADED] $key"
      elif [ "$should_ignore" = false ]; then
        echo "  [SKIPPED] $key (already set)"
      fi
    done < /tmp/json_env.tmp
  
    # Source the exports if any were created
    if [ -s "$temp_exports" ]; then
      echo "Sourcing $(wc -l < "$temp_exports") environment variables..."
      . "$temp_exports"
      echo "Environment variables loaded successfully!"
    else
      echo "No new environment variables to load."
    fi
  
    # Clean up temporary files
    rm -f "$temp_exports" /tmp/json_env.tmp
  fi
else
  echo "WARNING: Environment JSON file not found: $ENV_JSON_FILE"
  echo "Continuing with existing environment variables..."
fi

echo "=== Starting Application ==="

# Check for critical environment variables
if [ -z "$SPRING_APPLICATION_NAME" ]; then
  echo "WARNING: SPRING_APPLICATION_NAME is not set. Using default value from application.yml"
fi

echo "Available environment variables:"
env | grep -E "(SPRING|CONFIG|GIT|MANAGEMENT)" | sort

# Check if running in Kubernetes
if [ ! -z "$KUBERNETES_SERVICE_HOST" ]; then
  echo "=== Kubernetes Environment Detected ==="
  echo "Pod name: $HOSTNAME"
  echo "Mounted secrets path exists: $([ -d "/mnt/secrets" ] && echo "Yes" || echo "No")"
fi

# Execute the main command
echo "Starting application with command: $@"
exec "$@"
