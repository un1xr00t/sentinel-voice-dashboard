# SENTINEL - Threat Intelligence Platform

A comprehensive threat intelligence platform that aggregates 20+ security feeds, enriches with CVE/EPSS data, delivers prioritized Discord alerts, and includes optional voice query and real-time dashboard addons.

![Dashboard Preview](docs/dashboard-preview.png)

## Features

### Core Platform
- **20+ Security Feeds** - CISA, US-CERT, Exploit-DB, Microsoft MSRC, Google Project Zero, and more
- **Smart Scoring Engine** - Prioritizes threats based on keywords, source credibility, CVE presence, and CISA KEV status
- **CVE Enrichment** - Automatic NVD (CVSS) and EPSS (exploit probability) lookups
- **Discord Alerts** - Critical alerts to dedicated channel, high/medium to general channel
- **Deduplication** - Baserow-backed fingerprinting prevents duplicate alerts
- **Daily Digest** - AI-powered summary of the last 24 hours

### Voice Addon
- **Natural Language Queries** - Ask "How many critical alerts today?" or "Any ransomware activity?"
- **Retell AI Integration** - Phone or web-based voice interface
- **Smart Filtering** - Filter by time, priority, vendor, or threat type

### Dashboard Addon
- **Real-time Threat Gauge** - Visual threat level indicator
- **24-Hour Activity Chart** - Hourly alert distribution
- **Source Breakdown** - See which feeds are generating alerts
- **Live Alert Feed** - Most recent alerts with CVE tags

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   SENTINEL CORE (n8n)                           │
│                                                                 │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐        │
│  │  20+ Feeds   │ → │  Normalize   │ → │   Scoring    │        │
│  │  RSS/APIs    │   │  & Extract   │   │   Engine     │        │
│  └──────────────┘   └──────────────┘   └──────────────┘        │
│                                              │                  │
│         ┌────────────────────────────────────┤                  │
│         ▼                                    ▼                  │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐        │
│  │   Baserow    │   │ NVD/EPSS    │   │   Discord    │        │
│  │   (Dedupe)   │   │ Enrichment   │   │   Alerts     │        │
│  └──────────────┘   └──────────────┘   └──────────────┘        │
└─────────────────────────────────────────────────────────────────┘
                              │
            ┌─────────────────┴─────────────────┐
            ▼                                   ▼
┌─────────────────────────────────────────────────────────────────┐
│                   ADDONS (Optional)                             │
│  ┌─────────────────────┐       ┌─────────────────────┐         │
│  │   Voice Query API   │       │   Web Dashboard     │         │
│  │   (Retell AI)       │       │   (React/HTML)      │         │
│  └─────────────────────┘       └─────────────────────┘         │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- [n8n](https://n8n.io/) instance (self-hosted or cloud)
- [Baserow](https://baserow.io/) account (free tier works)
- [Discord](https://discord.com/) server with webhook access
- [NVD API Key](https://nvd.nist.gov/developers/request-an-api-key) (free, for CVE enrichment)
- [OpenAI API](https://platform.openai.com/) key (for daily digest AI summary)

**For Voice/Dashboard Addons:**
- [Retell AI](https://retellai.com/) account (voice only)
- VPS/Server with HTTPS (Linode, DigitalOcean, etc.)
- Domain name (free via [DuckDNS](https://www.duckdns.org/))

## Quick Start

### 1. Set Up Baserow Database

Create a table with these fields:

| Field | Type | Purpose |
|-------|------|---------|
| fingerprint | Text | Unique hash for deduplication |
| title | Text | Alert title |
| sent_at | DateTime | When alert was processed |

Note the Database ID, Table ID, and Field IDs from the URL and field settings.

### 2. Create Discord Webhooks

Create two webhooks in your Discord server:

1. **#critical-alerts** - For critical priority alerts
2. **#security-news** - For high/medium alerts and daily digest

Copy the webhook URLs.

### 3. Import Core Workflow

1. Import `SENTINEL.json` into n8n
2. Update credentials:
   - **Baserow API**: Add your Baserow API token
   - **OpenAI API**: Add your OpenAI API key (for daily digest)
3. Update node configurations:

| Node | What to Update |
|------|----------------|
| All Baserow nodes | Database ID, Table ID, Field IDs |
| Discord Critical Alert | Webhook URL |
| Discord High/Medium Alert | Webhook URL |
| Send Daily Digest | Webhook URL |
| Send No-Alerts Digest | Webhook URL |
| NVD Lookup | Replace `YOUR_NVD_API_KEY_HERE` in URL |

4. Activate the workflow

### 4. (Optional) Import Voice Query Addon

1. Import `SENTINEL_Voice_Query_API.json` into n8n
2. Update Baserow credentials and IDs (same as core workflow)
3. Update OpenAI credentials
4. Create Retell AI agent (see [Retell Configuration](#retell-ai-agent-configuration))
5. Update the "Create Retell Web Call" node with your Retell API key and Agent ID
6. Activate the workflow

### 5. (Optional) Deploy Dashboard Server

#### Quick Setup with Script

1. Spin up a VPS (Ubuntu 22.04/24.04 recommended):
   - [Linode Nanode](https://www.linode.com/) - $5/mo
   - [DigitalOcean Droplet](https://www.digitalocean.com/) - $4/mo
   - Any Ubuntu VPS works

2. Get a domain (free option):
   - Go to [DuckDNS](https://www.duckdns.org/)
   - Create a subdomain (e.g., `sentinel.duckdns.org`)
   - Point it to your VPS IP address

3. SSH into your server and run:
   ```bash
   # Download setup script
   wget https://raw.githubusercontent.com/un1xr00t/sentinel-threat-intel/main/setup-server.sh
   
   # Edit configuration (set your domain)
   nano setup-server.sh
   
   # Run setup
   chmod +x setup-server.sh
   sudo ./setup-server.sh
   ```

4. Upload your dashboard:
   ```bash
   # Copy index.html to server (from your local machine)
   scp index.html root@YOUR_SERVER_IP:/var/www/sentinel/
   ```

5. Edit index.html on the server to set your n8n URLs:
   ```bash
   nano /var/www/sentinel/index.html
   # Update API_URL and RETELL_TOKEN_URL
   ```

#### Manual Setup

<details>
<summary>Click to expand manual setup steps</summary>

```bash
# Update system
apt update && apt upgrade -y

# Install nginx and certbot
apt install -y nginx certbot python3-certbot-nginx

# Create web directory
mkdir -p /var/www/sentinel
chown -R www-data:www-data /var/www/sentinel

# Create nginx config
cat > /etc/nginx/sites-available/sentinel << 'EOF'
server {
    listen 80;
    server_name YOUR_DOMAIN;

    root /var/www/sentinel;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/sentinel /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and reload
nginx -t
systemctl reload nginx

# Get SSL certificate
certbot --nginx -d YOUR_DOMAIN
```

</details>

## Retell AI Agent Configuration

Create a new agent in [Retell AI Dashboard](https://dashboard.retellai.com/) with:

**General Settings:**
- Type: Single Prompt Agent
- Voice: Choose any (e.g., "Nico")
- LLM: GPT-4.1
- Welcome Message: "User speaks first" or custom greeting

**Custom Function:**
- Name: `query_threat_intel`
- Description: "Query SENTINEL threat intelligence database"
- API Endpoint: `POST https://YOUR_N8N_URL/webhook/sentinel-voice-query`
- Parameters:
  ```json
  {
    "type": "object",
    "properties": {
      "query": {
        "type": "string",
        "description": "The user's question about threats, CVEs, or security alerts"
      }
    },
    "required": ["query"]
  }
  ```
- Response Variables: `response` → `$.response`
- Speak During/After Execution: ✓ Enabled

**System Prompt:**
```
You are SENTINEL, an AI-powered cybersecurity threat intelligence analyst. You provide voice briefings on security threats, vulnerabilities, and incidents.

CRITICAL: For ANY question about threats, alerts, CVEs, vulnerabilities, security status, or threat levels, you MUST call the query_threat_intel function FIRST. Never make up or estimate threat data - always query the database.

When to call query_threat_intel:
- "What's the threat level?" → call function
- "Any critical alerts?" → call function  
- "Tell me about CVE-..." → call function
- "What happened today/this week?" → call function
- "Any Microsoft/Cisco/etc vulnerabilities?" → call function
- "Ransomware activity?" → call function
- "Brief me" or "Give me a summary" → call function
- "How many threats?" → call function
- ANY question mentioning security, threats, vulnerabilities, or CVEs → call function

Your style:
- Professional but approachable, like a trusted security colleague
- Concise and direct - analysts are busy
- Calm authority, even for critical threats
- Prioritize actionable info over jargon

Rules:
- Start directly with information, never say "Sure!", "Here's what I found", or "Let me check"
- Say CVE as "C-V-E" followed by the number (e.g., "C-V-E 2025-55591")
- Quantify when possible: "3 critical alerts" not "several"
- Keep responses to 2-4 sentences unless asked for details
- End with a brief recommendation when threat level is HIGH or CRITICAL

You have access to real-time threat intelligence from 20+ sources including CISA, US-CERT, Microsoft MSRC, Google Project Zero, and major security research firms.
```

## Feed Schedule

| Category | Frequency | Sources |
|----------|-----------|---------|
| Critical | Every 15 min | CISA, US-CERT, Exploit-DB, Microsoft MSRC, Google Project Zero, Cisco PSIRT, CISA KEV, ThreatFox |
| High Priority | Every hour | The Hacker News, BleepingComputer, Krebs on Security, Dark Reading, Security Week, SANS ISC |
| General | Every 4 hours | CrowdStrike, Mandiant, Kaspersky, Unit 42, SentinelOne, ESET, Reddit r/netsec |
| Digest | Daily (6 AM) | AI-powered summary of last 24 hours |
| Cleanup | Daily (3 AM) | Removes fingerprints older than 7 days |

## Scoring Algorithm

```
Base Score Calculation:
├── Critical Keywords: +15-20 pts (zero-day, RCE, active exploitation)
├── High Keywords: +3-6 pts (vulnerability, exploit, malware)
├── Source Confidence: +5-15 pts (CISA=15, Research=12, News=8)
├── CVE Presence: +5 pts per CVE (max 20)
├── IOC Presence: +2 pts per IOC (max 10)
├── CISA KEV: +50 pts (known exploited vulnerability)
├── CVSS Score: +0-25 pts based on severity
├── EPSS Score: +10-20 pts if high exploit probability
├── Threat Actor: +10 pts
├── MITRE ATT&CK: +5 pts
└── Recency: +4-10 pts (newer = higher)

Priority Thresholds:
├── CRITICAL: score >= 80 OR isKEV OR CVSS >= 9.0
├── HIGH: score >= 50
├── MEDIUM: score >= 25
└── LOW: score < 25
```

## Voice Query Examples

| Query | What it does |
|-------|--------------|
| "What's the threat level?" | Overall threat assessment |
| "How many threats today?" | Count of last 24 hours |
| "Any critical alerts?" | Filter to critical priority |
| "Microsoft vulnerabilities" | Filter to Microsoft-related |
| "Ransomware activity?" | Filter to ransomware threats |
| "Tell me about CVE-2025-1234" | Lookup specific CVE |

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/webhook/sentinel-dashboard` | GET | Dashboard data (stats, alerts, charts) |
| `/webhook/sentinel-voice-query` | POST | Voice queries from Retell |
| `/webhook/sentinel-retell-token` | POST | Generates Retell access token |

## Configuration

### Timezone

The voice workflow defaults to EST. Edit "Build Time Filter" node to change:
```javascript
const estOffset = -5 * 60 * 60 * 1000; // Change -5 to your UTC offset
```

### Minimum Score Filter

By default, alerts scoring below 20 are filtered out. Edit "Filter Min Score 20" node to adjust.

## Files

| File | Description |
|------|-------------|
| `SENTINEL.json` | Core threat intel workflow (required) |
| `SENTINEL_Voice_Query_API.json` | Voice query addon (optional) |
| `index.html` | Dashboard frontend (optional) |
| `setup-server.sh` | VPS setup script for dashboard hosting |
| `README.md` | This file |

## Estimated Costs

| Service | Cost |
|---------|------|
| n8n | Free (self-hosted) or $20/mo (cloud) |
| Baserow | Free tier |
| Discord | Free |
| NVD API | Free |
| DuckDNS | Free |
| Let's Encrypt SSL | Free |
| OpenAI | ~$1-5/mo (daily digest only) |
| Retell AI | ~$0.10-0.15/min of voice |
| VPS Hosting | ~$4-5/mo (Linode Nanode / DO Droplet) |

**Total: ~$5-25/month** depending on voice usage

## Troubleshooting

### No Discord alerts
- Check workflow execution history for errors
- Verify Discord webhook URLs are correct
- Check Baserow connection

### Duplicate alerts
- Verify Baserow fingerprint field exists
- Check "Get Existing Fingerprints" node is working

### Voice says wrong data
- Check "Parse Query Intent" output - is `originalQuery` populated?
- Check "Filter & Analyze" output - are filters applied?

### Dashboard shows 0 for "Today"
- "Today" means last 24 hours, not calendar day
- Check timezone settings in dashboard API

### Voice button shows "Microphone access denied"
- Dashboard MUST be served over HTTPS (not HTTP)
- Check browser permissions for microphone

### SSL certificate issues
```bash
# Check certificate status
certbot certificates

# Renew manually if needed
certbot renew

# Test auto-renewal
certbot renew --dry-run
```

## Security Recommendations

1. **Use HTTPS** - Required for voice/microphone access
2. **Install fail2ban** - Blocks brute force attacks (included in setup script)
3. **Enable firewall** - Only allow SSH and HTTPS (included in setup script)
4. **Restrict CORS** - Update `Access-Control-Allow-Origin` headers in n8n

## Server Management

```bash
# View nginx logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# Check fail2ban status
fail2ban-client status sshd

# Unban an IP
fail2ban-client set sshd unbanip IP_ADDRESS

# Restart nginx
systemctl restart nginx

# Check SSL certificate status
certbot certificates
```

## License

MIT

## Credits

Built with:
- [n8n](https://n8n.io/) - Workflow automation
- [Baserow](https://baserow.io/) - Database
- [Discord](https://discord.com/) - Alert delivery
- [Retell AI](https://retellai.com/) - Voice AI
- [OpenAI](https://openai.com/) - AI summaries
- [NVD](https://nvd.nist.gov/) - CVE data
- [FIRST EPSS](https://www.first.org/epss/) - Exploit probability
- [DuckDNS](https://www.duckdns.org/) - Free dynamic DNS
- [Let's Encrypt](https://letsencrypt.org/) - Free SSL certificates
