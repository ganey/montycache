# MontyCache - High-Performance Caching Proxy

MontyCache is a unified caching solution that combines Nginx (with `proxy_connect` and `stream` modules) and CoreDNS into a single, high-performance container. It supports transparent DNS-based caching, selective HTTPS MITM, and standard forward proxying.

## Features
- **Unified Engine:** Nginx + CoreDNS in one container.
- **10GB Persistent Cache:** Optimized for static assets (`.js`, `.css`, `.png`, etc.).
- **Smart Caching:** `proxy_cache_min_uses 3` ensures only frequently accessed items are cached.
- **Selective HTTPS MITM:** SNI-based routing decrypts specific domains for caching while passing others through transparently.
- **Transparent Fallback:** Port 80 automatically attempts HTTPS and falls back to HTTP if needed.
- **Auto-Cert Management:** Automatic Root CA and Site Certificate generation.

## Ports & Architecture
- **Port 53 (UDP/TCP):** CoreDNS server for domain redirection.
- **Port 80:** Transparent HTTP/HTTPS-First Proxy.
- **Port 443:** SNI-based Router (Selective MITM vs. Passthrough).
- **Port 3128:** Standard Forward Proxy (Squid-compatible).
- **Port 8080:** App-style Dynamic Gateway (via `X-Target` header).
- **Port 8443:** Internal SSL Termination point for MITM domains.

## Quick Start

1. **Build & Start:**
   ```bash
   docker-compose up -d --build
   ```

2. **Install Root CA:**
   Visit `http://<server-ip>/ca.pem` on your device to download and install the MontyCache Root CA. You MUST trust this CA in your system settings to enable HTTPS caching.

3. **Configure DNS:**
   Point your devices' DNS to the MontyCache server's IP. 

4. **Update Cached Domains:**
   Edit the `stream` block in `nginx.conf` and the `alt_names` in `entrypoint.sh` to add new domains for HTTPS caching.

## Configuration Files
- `nginx.conf`: Core proxy, caching, and SNI-routing logic.
- `Corefile`: DNS redirection rules for CoreDNS.
- `entrypoint.sh`: Orchestration and automated certificate generation.
- `Dockerfile`: Multi-stage build with custom Nginx modules.

## Maintenance
- **Check Status:** `docker-compose logs -f`
- **Clear Cache:** `rm -rf cache/* && docker-compose restart`
- **Renew Certificates:** `rm -rf ssl/* && docker-compose restart`
