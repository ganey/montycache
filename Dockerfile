# Build Stage
FROM alpine:3.18 as builder

ENV NGINX_VERSION 1.25.2
ENV PROXY_CONNECT_VERSION 0.0.5
ENV COREDNS_VERSION 1.11.1
ENV VTS_VERSION 0.2.2

RUN apk add --no-cache --virtual .build-deps \
    gcc libc-dev make openssl-dev pcre2-dev zlib-dev linux-headers curl patch

# Get Nginx source
RUN curl -fSL http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz && \
    mkdir -p /usr/src && tar -zxC /usr/src -f nginx.tar.gz

# Get Proxy Connect module
RUN curl -fSL https://github.com/chobits/ngx_http_proxy_connect_module/archive/refs/tags/v$PROXY_CONNECT_VERSION.tar.gz -o proxy_connect.tar.gz && \
    tar -zxC /usr/src -f proxy_connect.tar.gz

# Get VTS module
RUN curl -fSL https://github.com/vozlt/nginx-module-vts/archive/refs/tags/v$VTS_VERSION.tar.gz -o vts.tar.gz && \
    tar -zxC /usr/src -f vts.tar.gz

# Get CoreDNS binary
RUN mkdir -p /usr/src/coredns && \
    curl -fSL https://github.com/coredns/coredns/releases/download/v$COREDNS_VERSION/coredns_${COREDNS_VERSION}_linux_amd64.tgz -o coredns.tgz && \
    tar -zxC /usr/src/coredns -f coredns.tgz

# Patch and Compile Nginx
WORKDIR /usr/src/nginx-$NGINX_VERSION
RUN patch -p1 < /usr/src/ngx_http_proxy_connect_module-$PROXY_CONNECT_VERSION/patch/proxy_connect_rewrite_102101.patch && \
    ./configure \
        --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf --with-http_ssl_module \
        --with-stream --with-stream_ssl_module --with-stream_ssl_preread_module \
        --add-module=/usr/src/ngx_http_proxy_connect_module-$PROXY_CONNECT_VERSION \
        --add-module=/usr/src/nginx-module-vts-$VTS_VERSION && \
    make -j$(getconf _NPROCESSORS_ONLN) && make install

# Final Image
FROM alpine:3.18
RUN apk add --no-cache ca-certificates pcre2 zlib openssl && \
    addgroup -S nginx && adduser -S -D -H -G nginx nginx

COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /usr/src/coredns/coredns /usr/bin/coredns
COPY nginx.conf /etc/nginx/nginx.conf

RUN mkdir -p /var/cache/nginx /var/log/nginx /etc/coredns && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    rm -rf /etc/nginx/conf.d /etc/nginx/http.d /etc/nginx/nginx.conf.default && \
    chown -R nginx:nginx /var/cache/nginx /var/log/nginx

COPY entrypoint.sh /usr/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/bin/entrypoint.sh && \
    chmod +x /usr/bin/entrypoint.sh

STOPSIGNAL SIGQUIT
ENTRYPOINT ["/usr/bin/entrypoint.sh"]
