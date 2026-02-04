# Quick Reference: Init Container Bug & Fix

## The Problem in One Sentence

**Quoted heredocs (`<< 'EOF'`) prevent variable expansion, so the API key is written as a literal string instead of its actual value.**

## What's Broken

```yaml
# Line 15 and 39 in docker-compose.yml
cat > file.json << 'EOF'   # ← Single quotes = no variable expansion
{
  "key": "$$AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY"  # ← Won't expand!
}
EOF
```

## The Fix

```yaml
# Remove the single quotes around 'EOF'
cat > file.json << EOF    # ← No quotes = variables expand
{
  "key": "$$AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY"  # ← Will expand!
}
EOF
```

## Changes Required

**File:** `/tmp/openclaw-coolify/docker-compose.yml`

**Line 15:** Change `<< 'EOF'` to `<< EOF`
**Line 39:** Change `<< 'EOF'` to `<< EOF`

**That's it!** Just two characters to remove (two single quotes).

## What Works Currently

- ✓ Restart policy: `"no"` (correct for init containers)
- ✓ Depends on: `service_completed_successfully` (proper condition)
- ✓ Environment variables: correctly passed to container
- ✓ Volumes: properly shared between services
- ✓ Directory creation: `mkdir -p` works correctly
- ✓ If conditions: `$$VAR` expansion works in conditionals
- ✓ File checks: `[ ! -f ]` properly detects file existence

## What Doesn't Work

- ✗ Heredoc variable expansion: `<< 'EOF'` prevents expansion
- Result: auth-profiles.json contains literal `$AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY`
- Impact: API authentication fails at runtime

## Verification Commands

```bash
# Check if bug exists
docker exec openclaw-gateway cat /home/node/.openclaw/agents/main/agent/auth-profiles.json | grep '"key"'

# If you see: "key": "$AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY"
# Then you have the bug

# If you see: "key": "sk-actual-api-key-value"
# Then it's working correctly
```

## Technical Explanation

1. **Docker Compose:** `$$VAR` → `$VAR` (escape mechanism)
2. **Shell:** `$VAR` → actual_value (variable expansion)
3. **Heredoc with quotes:** `<< 'EOF'` = literal mode, NO expansion
4. **Heredoc without quotes:** `<< EOF` = expansion enabled

## Severity

**HIGH** - Application cannot authenticate to API, complete failure of core functionality.

## Fix Time

**< 1 minute** - Remove two single quotes and restart containers.

## Testing

```bash
# After applying fix
docker-compose down
docker-compose up -d
docker-compose logs openclaw-init
docker exec openclaw-gateway cat /home/node/.openclaw/agents/main/agent/auth-profiles.json
```

Verify the `"key"` field contains your actual API key, not a variable name.
