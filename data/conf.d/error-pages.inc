error_page 403 =403 @error_403;
error_page 404 410 =404 @error_404;
error_page 500 502 503 504 =502 @error_50x;

location @error_403 {
    default_type text/html;
    return 403 '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>403 Forbidden</title><style>body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:#0f172a;color:#f8fafc;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}.c{text-align:center;padding:2rem;max-width:420px}h1{font-size:2.5rem;margin:0 0 .5rem;color:#f59e0b;font-weight:700}p{font-size:1rem;color:#94a3b8;line-height:1.5;margin:0}</style></head><body><div class="c"><h1>403</h1><p>Access denied. You do not have permission to view this resource.</p></div></body></html>';
}

location @error_404 {
    default_type text/html;
    return 404 '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>404 Not Found</title><style>body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:#0f172a;color:#f8fafc;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}.c{text-align:center;padding:2rem;max-width:420px}h1{font-size:2.5rem;margin:0 0 .5rem;color:#94a3b8;font-weight:700}p{font-size:1rem;color:#94a3b8;line-height:1.5;margin:0}</style></head><body><div class="c"><h1>404</h1><p>The requested resource could not be found on this server.</p></div></body></html>';
}

location @error_50x {
    default_type text/html;
    return 502 '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>502 Service Unavailable</title><style>body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:#0f172a;color:#f8fafc;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}.c{text-align:center;padding:2rem;max-width:420px}h1{font-size:2.5rem;margin:0 0 .5rem;color:#ef4444;font-weight:700}p{font-size:1rem;color:#94a3b8;line-height:1.5;margin:0}</style></head><body><div class="c"><h1>502</h1><p>The server encountered a temporary error and could not complete your request. Please try again in a few moments.</p></div></body></html>';
}
