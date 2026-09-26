server {
    listen 80 default_server;
    server_name _;

    location /healthz {
        access_log off;
        keepalive_timeout 0;
        default_type text/plain;
        return 200 "OK\n";
    }

    location / {
        return 444;
    }
}
