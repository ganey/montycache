#!/bin/sh

# Default variables if not provided
UPSTREAM_DNS=${UPSTREAM_DNS:-8.8.8.8}
CACHE_DOMAINS=${CACHE_DOMAINS:-httpbin.org,example.com}
CACHE_SIZE=${CACHE_SIZE:-10g}

echo "Configuring MontyCache..."
echo "Upstream DNS: $UPSTREAM_DNS"
echo "Cache Size: $CACHE_SIZE"

# Ensure directories exist
mkdir -p /etc/nginx/ssl /var/cache/nginx /var/log/nginx

# 1. Generate Root CA if it doesn't exist
if [ ! -f /etc/nginx/ssl/rootCA.pem ]; then
    echo "Generating Root CA..."
    openssl genrsa -out /etc/nginx/ssl/rootCA.key 4096
    openssl req -x509 -new -nodes -key /etc/nginx/ssl/rootCA.key -sha256 -days 3650 -out /etc/nginx/ssl/rootCA.pem \
        -subj "/C=US/ST=State/L=City/O=MontyCache/CN=MontyCache-Root-CA"
fi

# 2. Generate Site Certificate dynamically
echo "Generating MITM Site Certificate for: $CACHE_DOMAINS"
cat > /etc/nginx/ssl/sites.ext <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
EOF

i=1
NGINX_MAP=""
IFS=','
for domain in $CACHE_DOMAINS; do
    echo "DNS.$i = $domain" >> /etc/nginx/ssl/sites.ext
    echo "DNS.$((i+1)) = *.$domain" >> /etc/nginx/ssl/sites.ext
    NGINX_MAP="$NGINX_MAP    \"$domain\" 127.0.0.1:8443;\n    \".$domain\" 127.0.0.1:8443;\n"
    i=$((i+2))
done

openssl genrsa -out /etc/nginx/ssl/sites.key 2048
openssl req -new -key /etc/nginx/ssl/sites.key -out /etc/nginx/ssl/sites.csr \
    -subj "/C=US/ST=State/L=City/O=MontyCache/CN=MontyCache-Intercept"

openssl x509 -req -in /etc/nginx/ssl/sites.csr -CA /etc/nginx/ssl/rootCA.pem -CAkey /etc/nginx/ssl/rootCA.key \
    -CAcreateserial -out /etc/nginx/ssl/sites.pem -days 825 -sha256 -extfile /etc/nginx/ssl/sites.ext

# 3. Update Corefile with Auto-Redirection
CONTAINER_IP=$(hostname -i | awk '{print $1}')
echo "Container IP: $CONTAINER_IP"

COREFILE_CONTENT=". {
    forward . $UPSTREAM_DNS
    log
    errors
"
IFS=','
for domain in $CACHE_DOMAINS; do
    COREFILE_CONTENT="$COREFILE_CONTENT
    template IN A $domain {
        match $domain
        answer \"{{ .Name }} 60 IN A $CONTAINER_IP\"
        fallthrough
    }
    template IN A *.$domain {
        match .*\\.$domain
        answer \"{{ .Name }} 60 IN A $CONTAINER_IP\"
        fallthrough
    }"
done
echo "$COREFILE_CONTENT
}" > /etc/coredns/Corefile

# 4. Inject Dynamic Config into nginx.conf
# Update all resolvers to use UPSTREAM_DNS
sed -i "s|resolver .*;|resolver $UPSTREAM_DNS;|g" /etc/nginx/nginx.conf
sed -i "s|resolver .* valid=30s;|resolver $UPSTREAM_DNS valid=30s;|g" /etc/nginx/nginx.conf
sed -i "s|max_size=[0-9]*[g|m]|max_size=$CACHE_SIZE|g" /etc/nginx/nginx.conf
sed -i '/map $ssl_preread_server_name $backend_name {/,/}/c\    map $ssl_preread_server_name $backend_name {\n'"$NGINX_MAP"'        default $ssl_preread_server_name:443;\n    }' /etc/nginx/nginx.conf

# 5. REMOVE DEFAULT CONFIGS (Crucial for Unraid/Alpine)
rm -rf /etc/nginx/conf.d/*.conf
rm -f /etc/nginx/http.d/*.conf

# --- DEBUGGING ---
echo "--- GENERATED NGINX CONFIG ---"
cat /etc/nginx/nginx.conf
echo "--- LISTENING PORTS ---"
netstat -tulnp
echo "----------------------------"

# 6. Fix permissions for Alpine Nginx
chown -R root:root /etc/nginx /var/cache/nginx /var/log/nginx
chmod -R 755 /etc/nginx /var/cache/nginx /var/log/nginx

# TEST: Check Nginx configuration before starting
echo "Testing Nginx configuration..."
/usr/sbin/nginx -t || { echo "Nginx config check failed!"; exit 1; }

# Start Services
echo "Starting CoreDNS..."
coredns -conf /etc/coredns/Corefile &

echo "Starting Nginx..."
exec /usr/sbin/nginx -g "daemon off;"
