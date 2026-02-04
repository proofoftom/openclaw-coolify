#!/bin/sh
# Initialize auth-profiles.json from environment variables

AUTH_DIR="/home/node/.openclaw/agents/main/agent"
AUTH_FILE="$AUTH_DIR/auth-profiles.json"

mkdir -p "$AUTH_DIR"

# Check if auth-profiles.json exists
if [ ! -f "$AUTH_FILE" ]; then
  echo "Initializing auth-profiles.json from environment variables..."
  
  # Build the auth-profiles.json from environment variables
  PROFILES=""
  LAST_GOOD=""
  USAGE_STATS=""
  
  # Check for ZAI_API_KEY
  if [ -n "$AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY" ] || [ -n "$ZAI_API_KEY" ]; then
    KEY="${AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY:-$ZAI_API_KEY}"
    if [ -n "$PROFILES" ]; then PROFILES="$PROFILES,"; fi
    PROFILES="$PROFILES
    \"zai:default\": {
      \"type\": \"api_key\",
      \"provider\": \"zai\",
      \"key\": \"$KEY\"
    }"
    LAST_GOOD='"zai": "zai:default"'
    USAGE_STATS="$USAGE_STATS
    \"zai:default\": {
      \"lastUsed\": 0,
      \"errorCount\": 0,
      \"lastFailureAt\": 0
    }"
  fi
  
  # Check for ANTHROPIC_API_KEY
  if [ -n "$ANTHROPIC_API_KEY" ]; then
    if [ -n "$PROFILES" ]; then PROFILES="$PROFILES,"; fi
    PROFILES="$PROFILES
    \"anthropic:default\": {
      \"type\": \"api_key\",
      \"provider\": \"anthropic\",
      \"key\": \"$ANTHROPIC_API_KEY\"
    }"
    if [ -n "$LAST_GOOD" ]; then LAST_GOOD="$LAST_GOOD,"; fi
    LAST_GOOD="$LAST_GOOD
    \"anthropic\": \"anthropic:default\""
    USAGE_STATS="$USAGE_STATS
    \"anthropic:default\": {
      \"lastUsed\": 0,
      \"errorCount\": 0,
      \"lastFailureAt\": 0
    }"
  fi
  
  # Write the auth-profiles.json file
  if [ -n "$PROFILES" ]; then
    cat > "$AUTH_FILE" << AUTH_EOF
{
  "version": 1,
  "profiles": {$PROFILES
  },
  "lastGood": {$LAST_GOOD
  },
  "usageStats": {$USAGE_STATS
  }
}
AUTH_EOF
    echo "auth-profiles.json created successfully"
  else
    echo "Warning: No API keys found in environment variables"
  fi
fi

# Execute the main command
exec "$@"
