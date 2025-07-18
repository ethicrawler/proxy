# Proxy Migration Note

## Status: MIGRATED TO MAIN INFRASTRUCTURE

The enforcement proxy has been successfully integrated into the main infrastructure at:
`ethicrawler-saas/infrastructure/nginx/`

## What Was Migrated

- **Lua enforcement script**: Moved to `ethicrawler-saas/infrastructure/nginx/lua/payment_enforcement.lua`
- **OpenResty configuration**: Integrated into `ethicrawler-saas/infrastructure/nginx/nginx.conf`
- **Dockerfile**: Created `ethicrawler-saas/infrastructure/nginx/Dockerfile`
- **Docker Compose**: Updated `ethicrawler-saas/infrastructure/docker-compose.yml`

## Files in This Directory

This directory contains the original standalone proxy implementation used for development and testing:

- `nginx.conf` - Original OpenResty configuration
- `lua/payment_enforcement.lua` - Original Lua enforcement script
- `Dockerfile` - Standalone container build
- `docker-compose.yml` - Standalone environment
- `test-*.sh` - Test scripts for standalone setup
- `mock-backend.py` - Mock backend for testing

## Current Usage

The **main infrastructure** should now be used for all development and production:

```bash
# Use the integrated proxy
cd ethicrawler-saas/infrastructure
docker-compose up -d
./test-integrated-proxy.sh
```

## Cleanup Recommendation

These standalone files can be:
1. **Kept** as reference implementation and testing utilities
2. **Removed** if no longer needed (recommend keeping test scripts)
3. **Archived** to a separate testing directory

The integrated proxy in the main infrastructure is now the canonical implementation.