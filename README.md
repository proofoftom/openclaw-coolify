# OpenClaw Coolify Deployment

This repository contains the docker-compose configuration for deploying OpenClaw instances via Coolify.

## Quick Start

1. **Create a new application in Coolify**
   - Select "Docker Compose" as the build pack
   - Use this repository: `https://github.com/proofoftom/openclaw-coolify.git`

2. **Configure environment variables** in Coolify:

   | Variable | Description | Example | Required |
   |----------|-------------|---------|----------|
   | `INSTANCE_NAME` | Name of this OpenClaw instance | `proofofclaw-coder` | Yes |
   | `GATEWAY_TOKEN` | Unique gateway token (generate a new one per instance) | `openssl rand -hex 32` | Yes |
   | `DISCORD_BOT_TOKEN` | Discord bot token from Discord Developer Portal | `MTQ2ODU...` | Yes |
   | `DISCORD_GUILDS` | Comma-separated list of Discord server IDs to allow | `1468535982637711413` | Yes |
   | `MODEL` | Primary model to use | `zai/glm-4.7` | No (defaults to zai/glm-4.7) |
   | `API_KEY` | Z.ai API key | `your-key-here` | Yes |

3. **Deploy!**

## What Gets Configured Automatically

On first deployment, the init container creates:
- `auth-profiles.json` - Z.ai API key configuration
- `openclaw.json` - Instance configuration with:
  - Model: `zai/glm-4.7` (configurable via MODEL env var)
  - Discord group policy: `open` (responds in all servers)

## Important Notes

### Gateway Tokens
**Each instance MUST have a unique GATEWAY_TOKEN**. Generate a new one for each instance:
```bash
openssl rand -hex 32
```

### Discord Bots
Each instance needs its own Discord bot application:
1. Go to https://discord.com/developers/applications
2. Create a new application
3. Create a bot and copy the token
4. Invite the bot to your server with these permissions:
   - Read Messages/View Channels
   - Send Messages
   - Embed Links
   - Add Reactions

### Server IDs
To find your Discord server ID:
1. Enable Developer Mode in Discord (Settings → Advanced)
2. Right-click the server name → Copy ID

## Troubleshooting

### Bot not responding
- Check logs in Coolify
- Verify `DISCORD_GUILDS` includes your server ID
- Ensure the bot is invited to the server
- Check that `API_KEY` is valid

### "401 token expired or incorrect"
- The Z.ai API key is invalid or expired
- Update the `API_KEY` environment variable and redeploy

### "Model is not allowed"
- The model configured in `MODEL` is not available
- Check the API key has access to the requested model

## Architecture

```
┌─────────────────────────────────────────┐
│         Coolify Deployment             │
├─────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐   │
│  │ openclaw-init │  │ openclaw-    │   │
│  │ (runs once)  │  │ gateway      │   │
│  └──────────────┘  └──────────────┘   │
│         │                   │          │
│         └───────────────────┘          │
│              │                         │
│        ┌─────────▼─────────┐          │
│        │  openclaw-data    │          │
│        │  (persistent)     │          │
│        └───────────────────┘          │
└─────────────────────────────────────────┘
```

The init container runs once on first deployment to create configuration files, then exits. The gateway container starts once init completes successfully.
