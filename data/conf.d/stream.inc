# Single global stream {} context for L4 TCP/UDP proxies (included strictly after http {} in angie.conf).
# Enable targeted service includes below only for services you actually deploy.

stream {
    resolver                        127.0.0.11 valid=300s ipv6=off;
    resolver_timeout                5s;
    variables_hash_max_size         1024;
    variables_hash_bucket_size      128;

    log_format                      stream_basic '$remote_addr [$time_local] '
                                    '$protocol $status $bytes_sent $bytes_received '
                                    '$session_time "$upstream_addr" '
                                    '"$upstream_bytes_sent" "$upstream_bytes_received" "$upstream_connect_time"';
    access_log                      off;

    ssl_ciphers                     "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:DHE-RSA-AES256-SHA384";
    ssl_dhparam                     /etc/angie/dhparam.pem;
    ssl_ecdh_curve                  auto;
    ssl_prefer_server_ciphers       on;
    ssl_protocols                   TLSv1.2 TLSv1.3;
    ssl_session_cache               shared:STREAM_SSL:10m;
    ssl_session_tickets             on;
    ssl_session_timeout             7d;

    include /etc/angie/conf.d/stream/livekit-turn.inc;
}
