# Deployment checklist:
# - Replace 'matrix-rtc.example.com' with your MatrixRTC / LiveKit TURN FQDN (matching turn.domain in livekit.yaml, domains/matrix-rtc.conf, and LIVEKIT_URL).
# - Ensure this FQDN is DNS-only (not proxied through Cloudflare) so port 5349/tcp reaches Angie directly.
# - Replace 'matrix_rtc' with the exact acme_client identifier from domains/matrix-rtc.conf.
# - Replace 'matrix_livekit_turn_backend' with a unique upstream pool name if running multiple instances.
# - Ensure domains/matrix-rtc.conf is enabled in http {}, 'include /etc/angie/conf.d/stream.inc;' is enabled in angie.conf, and port 5349/tcp is published in docker-compose.yaml.
# - Ensure livekit/livekit.yaml has turn.external_tls: true, turn.proxy_protocol: true, and Angie's IP in turn.proxy_protocol_trusted_cidrs.

upstream matrix_livekit_turn_backend {
    zone matrix_livekit_turn_backend 64k;
    server matrix-livekit:5349 resolve;
}

server {
    listen 5349 ssl;
    server_name matrix-rtc.example.com;

    acme matrix_rtc;

    ssl_certificate $acme_cert_matrix_rtc;
    ssl_certificate_key $acme_cert_key_matrix_rtc;

    access_log /var/log/angie/domains/matrix-rtc.example.com.stream.log stream_basic;
    error_log /var/log/angie/domains/matrix-rtc.example.com.stream.error.log error;

    tcp_nodelay on;
    proxy_protocol on;
    proxy_connect_timeout 5s;
    proxy_timeout 15m;
    proxy_pass matrix_livekit_turn_backend;
}
