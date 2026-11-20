FROM docker.angie.software/angie:1.12.5@sha256:79d5f44d7a77b0c9a8f09f636572c54f91fd68f35882eaf2bb80d422299b7f74 AS donor

FROM donor AS runtime-extractor

SHELL ["/bin/ash", "-o", "pipefail", "-c"]

COPY data/modules.conf /tmp/modules.conf
COPY data/angie.conf /tmp/angie.conf
COPY data/mime.types /tmp/mime.types
COPY data/conf.d/0rtt-anti-replay.conf \
     data/conf.d/error-pages.inc \
     data/conf.d/healthcheck.inc \
     data/conf.d/http-protocols.conf \
     data/conf.d/security-headers.inc \
     data/conf.d/ssl-reject-handshake.conf \
     data/conf.d/stream.inc \
     /tmp/conf.d/

RUN mkdir -p /out/usr/sbin \
             /out/usr/local/bin \
             /out/usr/lib/angie/modules \
             /out/usr/share/angie/html \
             /out/etc/angie/conf.d/main \
             /out/etc/angie/conf.d/domains \
             /out/etc/angie/conf.d/stream \
             /out/etc/ssl \
             /out/run/angie \
             /out/run/sockets/php \
             /out/var/run/sockets/php \
             /out/var/www/html \
             /out/var/lib/angie/acme \
             /out/var/log/angie/domains \
             /out/var/cache/angie \
             /out/var/www/tmp \
             /out/tmp && \
    chmod 0755 /out/usr \
               /out/usr/sbin \
               /out/usr/local \
               /out/usr/local/bin \
               /out/usr/lib \
               /out/usr/lib/angie \
               /out/usr/lib/angie/modules \
               /out/usr/share \
               /out/usr/share/angie \
               /out/etc \
               /out/etc/ssl \
               /out/etc/angie \
               /out/etc/angie/conf.d \
               /out/etc/angie/conf.d/main \
               /out/etc/angie/conf.d/domains \
               /out/run \
               /out/run/sockets \
               /out/var \
               /out/var/lib \
               /out/var/lib/angie \
               /out/var/log \
               /out/var/log/angie \
               /out/var/log/angie/domains \
               /out/var/cache \
               /out/var/run \
               /out/var/run/sockets \
               /out/var/www && \
    chmod 0750 /out/etc/angie/conf.d/stream \
               /out/usr/share/angie/html \
               /out/var/www/html && \
    chmod 0700 /out/var/lib/angie/acme \
               /out/var/cache/angie && \
    chmod 1777 /out/tmp \
               /out/run/angie \
               /out/run/sockets/php \
               /out/var/run/sockets/php \
               /out/var/www/tmp && \
    cp -L /usr/sbin/angie /out/usr/sbin/angie && \
    chmod 0555 /out/usr/sbin/angie && \
    for f in fastcgi.conf fastcgi_params scgi_params uwsgi_params prometheus_all.conf; do \
      if [ -f "/etc/angie/$f" ]; then \
        cp -L "/etc/angie/$f" "/out/etc/angie/$f" && \
        chmod 0444 "/out/etc/angie/$f"; \
      fi; \
    done && \
    cp /tmp/modules.conf /out/etc/angie/modules.conf && \
    chmod 0444 /out/etc/angie/modules.conf && \
    cp /tmp/angie.conf /out/etc/angie/angie.conf && \
    sed -i -E 's/^[[:space:]]*(proxy_cache_|proxy_temp_path|client_body_temp_path|proxy_ignore_headers)/    # &/' /out/etc/angie/angie.conf && \
    chmod 0444 /out/etc/angie/angie.conf && \
    cp /tmp/mime.types /out/etc/angie/mime.types && \
    chmod 0444 /out/etc/angie/mime.types && \
    cp /tmp/conf.d/* /out/etc/angie/conf.d/ && \
    chmod 0444 /out/etc/angie/conf.d/* && \
    curl -fSs https://www.cloudflare.com/ips-v4 | awk '{print "set_real_ip_from " $1 ";"}' > /out/etc/angie/conf.d/cloudflare-ips.inc && \
    curl -fSs https://www.cloudflare.com/ips-v6 | awk '{print "set_real_ip_from " $1 ";"}' >> /out/etc/angie/conf.d/cloudflare-ips.inc && \
    chmod 0444 /out/etc/angie/conf.d/cloudflare-ips.inc && \
    ln -s /dev/stderr /out/var/log/angie/error.log && \
    ln -s /usr/lib/angie/modules /out/etc/angie/modules && \
    if [ -f /etc/ssl/openssl.cnf ]; then \
      cp -L /etc/ssl/openssl.cnf /out/etc/ssl/openssl.cnf && \
      chmod 0444 /out/etc/ssl/openssl.cnf; \
    fi && \
    while IFS= read -r line || [ -n "$line" ]; do \
      trimmed=$(printf '%s\n' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'); \
      case "$trimmed" in \
        "" | \#*) \
          continue \
          ;; \
        load_module\ modules/*.so\;) \
          mod=$(printf '%s\n' "$trimmed" | sed -E 's/^load_module[[:space:]]+modules\/([a-zA-Z0-9_]+\.so);$/\1/'); \
          src="/usr/lib/angie/modules/$mod"; \
          if [ ! -f "$src" ]; then \
            printf 'ERROR: requested module not found in donor: %s\n' "$src" >&2; \
            exit 1; \
          fi; \
          cp -L "$src" "/out/usr/lib/angie/modules/$mod" && \
          chmod 0555 "/out/usr/lib/angie/modules/$mod"; \
          case "$mod" in \
            ngx_http_lua_module.so | ngx_stream_lua_module.so) \
              if [ -d /usr/lib/angie/luajit ]; then \
                mkdir -p /out/usr/lib/angie/luajit && \
                cp -RL /usr/lib/angie/luajit/. /out/usr/lib/angie/luajit/; \
              fi; \
              if [ -d /usr/share/angie/luajit ]; then \
                mkdir -p /out/usr/share/angie/luajit && \
                cp -RL /usr/share/angie/luajit/. /out/usr/share/angie/luajit/; \
              fi \
              ;; \
            ngx_http_modsecurity_module.so) \
              if [ -d /etc/angie/modsecurity ]; then \
                mkdir -p /out/etc/angie/modsecurity && \
                cp -RL /etc/angie/modsecurity/. /out/etc/angie/modsecurity/; \
              fi \
              ;; \
            ngx_http_vhost_traffic_status_module.so | ngx_http_stream_server_traffic_status_module.so | ngx_stream_server_traffic_status_module.so) \
              if [ -d /usr/share/angie-module-vts ]; then \
                mkdir -p /out/usr/share/angie-module-vts && \
                cp -RL /usr/share/angie-module-vts/. /out/usr/share/angie-module-vts/; \
              fi \
              ;; \
          esac \
          ;; \
        *) \
          printf 'ERROR: invalid directive in modules.conf: %s\n' "$line" >&2; \
          exit 1 \
          ;; \
      esac; \
    done < /tmp/modules.conf && \
    for l in /lib/ld-musl-*.so.1 /lib/libc.musl-*.so.1; do \
      if [ -e "$l" ]; then \
        mkdir -p /out/lib && \
        cp -L "$l" /out/lib/ && \
        chmod 0755 /out/lib && \
        chmod 0555 "/out/lib/$(basename "$l")"; \
      fi; \
    done && \
    find /out -type f \( -name "angie" -o -name "*.so" -o -name "*.so.*" \) | while read -r elf; do \
      ldd "$elf" 2>/dev/null || true; \
    done | awk '/^\t\/|=> \// { for (i=1; i<=NF; i++) { if ($i ~ /^\//) { sub(/\(.*/, "", $i); print $i } } }' | sort -u | while read -r lib; do \
      if [ -f "$lib" ]; then \
        destdir="/out$(dirname "$lib")"; \
        mkdir -p "$destdir" && \
        cp -L "$lib" "$destdir/" && \
        chmod 0755 "$destdir" && \
        chmod 0555 "$destdir/$(basename "$lib")"; \
      fi; \
    done

FROM --platform=$BUILDPLATFORM golang:1.27.4-alpine3.24@sha256:70bd7ddea8b6cbe5d6943cde279d6b67feb10cc924fb9100d1d8757c1575b280 AS go-builder

ARG TARGETOS
ARG TARGETARCH

WORKDIR /build

COPY go.mod ./
COPY probe/ ./probe/

RUN mkdir -p /out/etc/ssl/certs && \
    chmod 0755 /out/etc /out/etc/ssl /out/etc/ssl/certs && \
    cp /etc/ssl/certs/ca-certificates.crt /out/etc/ssl/certs/ca-certificates.crt && \
    chmod 0444 /out/etc/ssl/certs/ca-certificates.crt && \
    ln -s certs/ca-certificates.crt /out/etc/ssl/cert.pem && \
    CGO_ENABLED=0 GOOS="${TARGETOS}" GOARCH="${TARGETARCH}" go build -ldflags="-s -w" -trimpath -o /out/probe ./probe

FROM scratch AS final

ENV PATH="/usr/sbin:/usr/local/bin"

COPY --from=runtime-extractor /out/ /
COPY --from=go-builder /out/etc/ssl /etc/ssl
COPY --from=go-builder --chmod=0555 /out/probe /usr/local/bin/probe

STOPSIGNAL SIGQUIT

ENTRYPOINT ["/usr/sbin/angie"]
CMD ["-g", "daemon off;"]
