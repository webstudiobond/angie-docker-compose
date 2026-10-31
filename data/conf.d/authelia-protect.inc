auth_request /internal/authelia/authz;

auth_request_set $redirection_url $upstream_http_location;
error_page 401 =302 $redirection_url;
