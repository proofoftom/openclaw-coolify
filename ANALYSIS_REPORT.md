# Init Container Configuration Analysis Report

**File Analyzed:** `/tmp/openclaw-coolify/docker-compose.yml`
**Date:** 2026-02-04
**Status:** CRITICAL BUG FOUND

---

## Executive Summary

The init container configuration in the docker-compose.yml file has a **critical bug** that prevents the API key from being properly written to the configuration files. While the container executes successfully (exit code 0), it creates configuration files containing literal variable names instead of the actual API key values, causing runtime authentication failures.

---

## Configuration Analysis

### 1. Service Configuration ✓ CORRECT

```yaml
openclaw-init:
  image: localhost:5000/openclaw-discord:latest
  restart: "no"
```

**Status:** CORRECT
- Restart policy of "no" is appropriate for init containers
- Init containers should not restart; failure should prevent dependent services from starting

### 2. Depends On Configuration ✓ CORRECT

```yaml
openclaw-gateway:
  depends_on:
    openclaw-init:
      condition: service_completed_successfully
```

**Status:** CORRECT
- Gateway properly waits for init container to complete successfully
- Uses `service_completed_successfully` condition (Docker Compose v2+)
- If init fails (non-zero exit code), gateway will not start

### 3. Environment Variables ✓ CORRECT

```yaml
environment:
  - AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY=${API_KEY}
```

**Status:** CORRECT
- Docker Compose substitutes `${API_KEY}` from host environment or .env file
- The value is properly passed to the container as `AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY`
- Variable is accessible in the shell script

### 4. Volumes ✓ CORRECT

```yaml
volumes:
  - openclaw-data:/home/node/.openclaw
```

**Status:** CORRECT
- Both services share the same named volume
- Files created by init are visible to gateway
- Volume mount path is consistent

### 5. Command Script ❌ CRITICAL BUG

**Current Configuration (Lines 12-82):**

```yaml
command:
  - sh
  - -c
  - |
    mkdir -p /home/node/.openclaw/agents/main/agent
    if [ ! -f /home/node/.openclaw/agents/main/agent/auth-profiles.json ] && [ -n "$$AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY" ]; then
      cat > /home/node/.openclaw/agents/main/agent/auth-profiles.json << 'EOF'
    {
      "version": 1,
      "profiles": {
        "zai:default": {
          "type": "api_key",
          "provider": "zai",
          "key": "$$AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY"
        }
      }
    }
    EOF
    fi
    if [ ! -f /home/node/.openclaw/openclaw.json ]; then
      cat > /home/node/.openclaw/openclaw.json << 'EOF'
    {
      "agents": {
        "defaults": {
          "models": {
            "zai/glm-4.7": {
              "alias": "GLM"
            }
          }
        }
      }
    }
    EOF
    fi
```

---

## The Critical Bug

### Problem Description

The script uses **quoted heredocs** (`<< 'EOF'`) which prevents variable expansion inside the JSON content.

### Technical Explanation

1. **Docker Compose Variable Substitution:**
   - `$$VAR` in docker-compose.yml is converted to `$VAR` (escape mechanism)
   - Single `$` would be interpreted by Compose itself

2. **Shell Variable Expansion:**
   - `$VAR` is expanded by the shell to its value
   - This works correctly in the `if` condition: `[ -n "$$AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY" ]`

3. **Heredoc Behavior:**
   - `<< 'EOF'` (quoted) = literal mode, NO variable expansion
   - `<< EOF` (unquoted) = variables ARE expanded

### What Actually Happens

**In the if statement (works correctly):**
```sh
[ -n "$$AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY" ]
# Compose: $$ -> $
# Shell: $VAR -> actual_value
# Result: [ -n "sk-test-1234567890abcdef" ] ✓
```

**In the heredoc (BROKEN):**
```sh
cat > file.json << 'EOF'
{
  "key": "$$AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY"
}
EOF
# Result: file.json contains literal string "$AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY"
# NOT the actual API key value!
```

### Evidence

**File created by current configuration:**
```json
{
  "version": 1,
  "profiles": {
    "zai:default": {
      "type": "api_key",
      "provider": "zai",
      "key": "$AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY"
    }
  }
}
```

**What the file SHOULD contain:**
```json
{
  "version": 1,
  "profiles": {
    "zai:default": {
      "type": "api_key",
      "provider": "zai",
      "key": "sk-actual-api-key-here"
    }
  }
}
```

---

## Impact Analysis

### Immediate Effects

1. **Init Container Status:**
   - Exits with code 0 (success)
   - No error messages
   - Appears to work correctly

2. **Gateway Service:**
   - Starts successfully (depends_on condition satisfied)
   - Runs without immediate crashes

3. **Runtime Behavior:**
   - Application attempts to use auth-profiles.json
   - API key is the literal string "$AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY"
   - Authentication to API provider fails
   - Application cannot make API calls
   - Silent failure or cryptic error messages

### Detection Difficulty

- Container logs show successful execution
- No validation of file contents
- Error appears in application runtime, not init phase
- Difficult to debug without inspecting the generated JSON files

---

## The Fix

### Required Changes

**Change 1 - auth-profiles.json (Lines 15-36):**

```diff
- cat > /home/node/.openclaw/agents/main/agent/auth-profiles.json << 'EOF'
+ cat > /home/node/.openclaw/agents/main/agent/auth-profiles.json << EOF
    {
      "version": 1,
      "profiles": {
        "zai:default": {
          "type": "api_key",
          "provider": "zai",
          "key": "$$AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY"
        }
      },
      "lastGood": {
        "zai": "zai:default"
      },
      "usageStats": {
        "zai:default": {
          "lastUsed": 0,
          "errorCount": 0,
          "lastFailureAt": 0
        }
      }
    }
- EOF
+ EOF
```

**Change 2 - openclaw.json (Lines 39-80):**

```diff
- cat > /home/node/.openclaw/openclaw.json << 'EOF'
+ cat > /home/node/.openclaw/openclaw.json << EOF
    {
      "messages": {
        "ackReactionScope": "group-mentions"
      },
      "agents": {
        "defaults": {
          "maxConcurrent": 4,
          "subagents": {
            "maxConcurrent": 8
          },
          "compaction": {
            "mode": "safeguard"
          },
          "workspace": "/home/node/.openclaw/workspace",
          "models": {
            "zai/glm-4.7": {
              "alias": "GLM"
            }
          },
          "model": {
            "primary": "zai/glm-4.7"
          }
        }
      },
      "channels": {
        "discord": {
          "groupPolicy": "open"
        }
      },
      "plugins": {
        "entries": {
          "discord": {
            "enabled": true
          }
        }
      },
      "meta": {
        "lastTouchedVersion": "2026.2.2-3"
      }
    }
- EOF
+ EOF
```

**Note:** The second heredoc (openclaw.json) doesn't actually use variables, but removing the quotes is consistent and prevents future issues if variables are added.

### Why This Fix Works

1. Docker Compose sees `$$VAR` and converts it to `$VAR`
2. Shell receives: `$VAR` inside the heredoc
3. Unquoted heredoc (`<< EOF`) allows variable expansion
4. Shell expands `$VAR` to actual value
5. JSON file contains the real API key

---

## Additional Recommendations

### 1. Add Validation

```sh
# After writing files, validate them
if [ -f /home/node/.openclaw/agents/main/agent/auth-profiles.json ]; then
  if grep -q '"key": "\$' /home/node/.openclaw/agents/main/agent/auth-profiles.json; then
    echo "ERROR: API key not properly expanded!" >&2
    exit 1
  fi
fi
```

### 2. Add Error Handling

```sh
# Check if file operations succeed
if ! cat > /home/node/.openclaw/agents/main/agent/auth-profiles.json << EOF
...
EOF
then
  echo "ERROR: Failed to write auth-profiles.json" >&2
  exit 1
fi
```

### 3. Add Logging

```sh
# Log what's happening
echo "Initializing OpenClaw configuration..."
echo "Creating directory: /home/node/.openclaw/agents/main/agent"
echo "Writing auth-profiles.json..."
echo "Writing openclaw.json..."
echo "Initialization complete."
```

### 4. Verify File Contents

```sh
# After creating files, verify them
echo "Created files:"
ls -la /home/node/.openclaw/agents/main/agent/
echo "auth-profiles.json contents:"
cat /home/node/.openclaw/agents/main/agent/auth-profiles.json
```

---

## Summary Table

| Component | Status | Details |
|-----------|--------|---------|
| Service Name | ✓ | `openclaw-init` - appropriate naming |
| Image | ✓ | `localhost:5000/openclaw-discord:latest` |
| Restart Policy | ✓ | `"no"` - correct for init container |
| Depends On | ✓ | `service_completed_successfully` - proper condition |
| Environment Variables | ✓ | Correctly passed to container |
| Volume Mount | ✓ | Correctly shared with gateway |
| Directory Creation | ✓ | `mkdir -p` with proper paths |
| File Existence Checks | ✓ | `[ ! -f ]` checks are correct |
| Variable Expansion (if) | ✓ | `$$VAR` works correctly in conditionals |
| Variable Expansion (heredoc) | ❌ | `<< 'EOF'` prevents expansion - CRITICAL BUG |
| Error Handling | ⚠️ | No validation of file writes |
| Logging | ⚠️ | No output for debugging |
| Script Syntax | ✓ | Valid shell syntax |

---

## Testing Recommendations

### Before Applying Fix

1. Start the current configuration
2. Check init container logs: `docker-compose logs openclaw-init`
3. Inspect generated file: `docker exec openclaw-gateway cat /home/node/.openclaw/agents/main/agent/auth-profiles.json`
4. Verify the bug: file will contain literal `$AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY`

### After Applying Fix

1. Restart services: `docker-compose down && docker-compose up -d`
2. Check init container completed: `docker-compose ps openclaw-init`
3. Inspect generated file: `docker exec openclaw-gateway cat /home/node/.openclaw/agents/main/agent/auth-profiles.json`
4. Verify the fix: file will contain actual API key value
5. Test application: verify API calls work correctly

---

## Conclusion

The init container configuration has a critical bug where quoted heredocs prevent environment variable expansion in the generated JSON configuration files. This causes the API authentication to fail silently at runtime.

**Fix:** Remove the single quotes around `EOF` in both heredoc statements (lines 15 and 39).

**Severity:** HIGH - Application cannot function without valid API credentials

**Complexity:** LOW - Simple text change, no logic changes required

**Risk:** LOW - Change is well-understood and easily reversible
