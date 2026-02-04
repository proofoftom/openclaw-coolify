# Detailed Fix Instructions

## File to Edit

`/tmp/openclaw-coolify/docker-compose.yml`

## Changes Needed

### Change #1: Line 15

**Current:**
```yaml
        cat > /home/node/.openclaw/agents/main/agent/auth-profiles.json << 'EOF'
```

**Change to:**
```yaml
        cat > /home/node/.openclaw/agents/main/agent/auth-profiles.json << EOF
```

**What to remove:** The two single quotes around `'EOF'` → `EOF`

---

### Change #2: Line 39

**Current:**
```yaml
        cat > /home/node/.openclaw/openclaw.json << 'EOF'
```

**Change to:**
```yaml
        cat > /home/node/.openclaw/openclaw.json << EOF
```

**What to remove:** The two single quotes around `'EOF'` → `EOF`

---

## Visual Diff

```diff
--- a/docker-compose.yml
+++ b/docker-compose.yml
@@ -12,7 +12,7 @@
         mkdir -p /home/node/.openclaw/agents/main/agent
         if [ ! -f /home/node/.openclaw/agents/main/agent/auth-profiles.json ] && [ -n "$$AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY" ]; then
-          cat > /home/node/.openclaw/agents/main/agent/auth-profiles.json << 'EOF'
+          cat > /home/node/.openclaw/agents/main/agent/auth-profiles.json << EOF
         {
           "version": 1,
           "profiles": {
@@ -36,7 +36,7 @@
         }
         EOF
         fi
-        if [ ! -f /home/node/.openclaw/openclaw.json ]; then
+        if [ ! -f /home/node/.openclaw/openclaw.json ]; then  
           cat > /home/node/.openclaw/openclaw.json << 'EOF'
+          cat > /home/node/.openclaw/openclaw.json << EOF
         {
           "messages": {
             "ackReactionScope": "group-mentions"
```

---

## Applying the Fix

### Option 1: Using sed (automatic)

```bash
cd /tmp/openclaw-coolify
sed -i "s/<< 'EOF'/<< EOF/g" docker-compose.yml
```

### Option 2: Manual Edit

1. Open the file in your editor: `nano /tmp/openclaw-coolify/docker-compose.yml`
2. Go to line 15
3. Remove the single quotes: Change `<< 'EOF'` to `<< EOF`
4. Go to line 39
5. Remove the single quotes: Change `<< 'EOF'` to `<< EOF`
6. Save and exit

### Option 3: Using the Edit tool (if available)

```
Read the file first, then use Edit to change:
- Line 15: Remove quotes around 'EOF'
- Line 39: Remove quotes around 'EOF'
```

---

## Verification After Fix

### 1. Verify the changes

```bash
cd /tmp/openclaw-coolify
grep -n "<< EOF" docker-compose.yml
```

Expected output:
```
15:        cat > /home/node/.openclaw/agents/main/agent/auth-profiles.json << EOF
39:        cat > /home/node/.openclaw/openclaw.json << EOF
```

### 2. Test the syntax

```bash
docker-compose config
```

If no errors, the YAML syntax is valid.

### 3. Deploy and verify

```bash
# Stop existing services
docker-compose down

# Remove old volume to force re-initialization
docker volume rm openclaw-coolify_openclaw-data

# Start services
docker-compose up -d

# Watch init container
docker-compose logs -f openclaw-init

# Wait for it to complete, then check the file
docker exec openclaw-gateway cat /home/node/.openclaw/agents/main/agent/auth-profiles.json
```

### 4. Verify API key is correct

The output should show:
```json
{
  "version": 1,
  "profiles": {
    "zai:default": {
      "type": "api_key",
      "provider": "zai",
      "key": "sk-your-actual-api-key-here"
    }
  }
}
```

NOT:
```json
{
  "key": "$AGENTS_DEFAULTS_MODEL_PROVIDERS__ZAI__API_KEY"
}
```

---

## Rollback (If Needed)

If something goes wrong, revert the changes:

```bash
cd /tmp/openclaw-coolify
sed -i "s/<< EOF/<< 'EOF'/g" docker-compose.yml
git checkout docker-compose.yml  # If using git
```

---

## Summary

- **Lines to change:** 15 and 39
- **Characters to remove:** Two single quotes (')
- **Time required:** 30 seconds
- **Risk level:** Very low
- **Reversible:** Yes (just add the quotes back)

The fix is minimal, safe, and easily reversible.
