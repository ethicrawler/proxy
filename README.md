# Ethicrawler Enforcement Proxy

An Nginx-based reverse proxy that intercepts AI bot requests and enforces payment requirements for content access.

## Features

- AI bot detection via User-Agent analysis
- Dynamic payment invoice generation
- JWT validation for authenticated access
- Configurable enforcement per site
- High-performance request processing

## Configuration

The proxy uses Nginx with custom Lua scripts for dynamic behavior:

```nginx
# Basic configuration
upstream backend {
    server backend:8000;
}

server {
    listen 80;
    location / {
        access_by_lua_file /etc/nginx/lua/payment_check.lua;
        proxy_pass http://backend;
    }
}
```

## Deployment

```bash
# Build Docker image
docker build -t ethicrawler-proxy .

# Run with docker-compose
docker-compose up -d
```

## Requirements

- Nginx with Lua support
- Docker (for containerized deployment)
- Access to Ethicrawler backend API

## License

MIT License - see LICENSE file for details