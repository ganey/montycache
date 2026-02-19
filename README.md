# 🍎 MontyCache - High-Performance Caching Proxy

MontyCache is a unified, high-performance caching engine that combines **Nginx** (with `proxy_connect` and `stream` modules) and **CoreDNS** into a single container. It is designed to transparently cache static assets (JS, CSS, images, fonts) across your network to save bandwidth and speed up repeated requests.

## ✨ Features

- **🚀 Unified Architecture:** Nginx + CoreDNS in one lightweight Alpine-based container.
- **📦 10GB Persistent Cache:** Optimized for high-traffic assets with a smart `min_uses 3` rule to prevent "one-off" clutter.
- **🛡️ Selective HTTPS MITM:** Automatically decrypts and caches specific domains (e.g., `httpbin.org`) while passing all other HTTPS traffic through untouched (no certificate errors for standard browsing).
- **🔄 Transparent Fallback:** Port 80 automatically attempts HTTPS and falls back to HTTP if a site is legacy-only.
- **🛠️ Zero-Config SSL:** Automatic Root CA and Site Certificate generation on first boot.
- **🖥️ Unraid Ready:** Includes a template for easy deployment on Unraid.

---

## 🚀 Quick Start

### Docker Compose
1. Clone the repo and start the container:
   ```bash
   docker-compose up -d --build
   ```
2. Set your device's DNS to the IP of the MontyCache server.
3. (Optional) Customize `CACHE_DOMAINS`, `UPSTREAM_DNS`, and `CACHE_SIZE` (e.g., `20g`) in your environment variables.

### Unraid Installation
1. Use the provided `unraid-template.xml` in your Unraid template folder.
2. Configure the **Cache Domains** (comma-separated list) and **Upstream DNS** in the UI.

---

## 🔐 Root CA Installation (Required for HTTPS Caching)

To cache content from HTTPS sites, you must install and trust the MontyCache Root CA on your devices.

### 📥 1. Download the Certificate
On any device connected to your network, open a browser and visit:
`http://<YOUR-MONTYCACHE-IP>/ca.pem`

### 💻 2. Install & Trust

#### **Windows**
1. Double-click the downloaded `ca.pem` (rename to `.crt` if needed).
2. Click **Install Certificate...** -> **Local Machine**.
3. Select **Place all certificates in the following store**.
4. Click **Browse** and select **Trusted Root Certification Authorities**.
5. Finish the wizard and click **Yes** on the security warning.

#### **iOS (iPhone/iPad)**
1. Download the file and go to **Settings > Profile Downloaded**.
2. Tap **Install** and enter your passcode.
3. Go to **Settings > General > About > Certificate Trust Settings**.
4. Toggle **Full Trust** for "MontyCache-Root-CA".

#### **Android**
1. Open **Settings > Security > Advanced > Encryption & credentials**.
2. Tap **Install a certificate > CA certificate**.
3. Tap **Install anyway** and select the downloaded file.

---

## ⚙️ How it Works

### Selective MITM vs. Passthrough
MontyCache uses SNI-based routing. When you visit an HTTPS site:
- If the domain is in your **Cache Domains** list: Nginx intercepts the connection using your Root CA to cache assets.
- If the domain is **NOT** in the list: Nginx simply "pipes" the encrypted traffic directly to the real server. **No certificate errors occur.**

### Caching Logic
- **Asset Filtering:** Only `.js`, `.css`, `.png`, `.jpg`, `.jpeg`, `.gif`, `.ico`, `.svg`, `.woff`, `.woff2`, `.ttf`, and `.otf` files are cached.
- **3-Use Rule:** Files are only stored after they have been requested **3 times**.
- **Port 80 Fallback:** Requests to port 80 are fetched over HTTPS by default to maximize security and caching potential.

---

## 🛠️ Maintenance
- **Logs:** `docker-compose logs -f`
- **Purge Cache:** `rm -rf cache/* && docker-compose restart`
- **Regenerate CA:** `rm -rf ssl/* && docker-compose restart` (Note: You will need to re-install the CA on all devices).
