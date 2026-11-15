auth_request /internal/authelia/authz;

auth_request_set $redirection_url $upstream_http_location;
error_page 401 =302 $redirection_url;

error_page 403 =403 @error_403;
error_page 404 410 =404 @error_404;
error_page 500 502 503 504 =502 @error_50x;
