location /internal/authelia/authz {
    internal;
    proxy_pass http://authelia_backend/api/authz/auth-request;

    proxy_set_header X-Original-Method $request_method;
    proxy_set_header X-Original-URL $scheme://$host$is_request_port$request_port$request_uri;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header Content-Length "";
    proxy_set_header Connection "";

    proxy_set_header Authorization "";
    proxy_set_header Proxy-Authorization "";

    proxy_pass_request_body off;
    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
    proxy_http_version 1.1;
    proxy_cache_bypass $cookie_authelia_session;
    proxy_no_cache $cookie_authelia_session;
    proxy_buffers 4 32k;
    client_body_buffer_size 128k;

    send_timeout 5m;
    proxy_read_timeout 240;
    proxy_send_timeout 240;
    proxy_connect_timeout 240;
}
