FROM openresty/openresty:alpine

# Install additional dependencies
RUN apk add --no-cache \
    curl \
    jq \
    bash

# Create necessary directories
RUN mkdir -p /etc/nginx/lua \
    && mkdir -p /var/log/nginx \
    && mkdir -p /var/cache/nginx

# Copy Nginx configuration
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

# Copy Lua scripts
COPY lua/ /etc/nginx/lua/

# Install Lua dependencies
RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-http
RUN /usr/local/openresty/luajit/bin/luarocks install lua-cjson

# Create non-root user for security
RUN addgroup -g 1000 -S nginx && \
    adduser -S -D -H -u 1000 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx

# Set proper permissions
RUN chown -R nginx:nginx /var/log/nginx \
    && chown -R nginx:nginx /var/cache/nginx \
    && chown -R nginx:nginx /etc/nginx/lua

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Expose port
EXPOSE 80

# Switch to non-root user
USER nginx

# Start OpenResty
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]