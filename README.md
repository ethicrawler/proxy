# Ethicrawler Enforcement Proxy

An OpenResty-based reverse proxy that intercepts AI bot requests and enforces payment requirements for content access.

## Features

- AI bot detection via User-Agent analysis
- Dynamic payment invoice generation via smart contract
- JWT validation for authenticated access
- Configurable enforcement per site
- High-performance request processing with caching
- Graceful error handling and fail-open design

## Architecture

The proxy consists of:
- **OpenResty/Nginx**: High-performance web server with Lua support
- **Lua Scripts**: Dynamic enforcement logic with caching
- **Backend Integration**: REST API calls to Ethicrawler backend
- **Smart Contract**: Payment processing via Soroban

## Quick Start

```bash
# Build and run
./build.sh --run

# Or manually:
docker build -t ethicrawler/proxy:latest .
docker-compose up -d
```

## Configuration

### Environment Variables

- `BACKEND_URL`: Ethicrawler backend API URL (default: http://backend:8000)
- `ENFORCEMENT_CACHE_TTL`: Cache TTL for enforcement settings (default: 300s)
- `PAYMENT_CACHE_TTL`: Cache TTL for JWT validation (default: 60s)

### Bot Detection

The proxy identifies AI bots by User-Agent patterns:
- AI bots: `gpt`, `claude`, `bard`, `openai`, `anthropic`, `ai`, `crawler`, `spider`, `bot`
- Whitelisted: `googlebot`, `bingbot`, `slurp`, `duckduckbot`, `baiduspider`

### Payment Flow

1. AI bot requests content
2. Proxy checks enforcement status (cached)
3. If enabled, generates payment invoice via backend
4. Returns 402 Payment Required with invoice details
5. Bot submits payment and receives JWT
6. Subsequent requests with valid JWT are allowed

## API Endpoints

### Health Check
```
GET /health
```

### Payment Enforcement
All requests go through the payment enforcement logic in `lua/payment_enforcement.lua`

## Backend Integration

The proxy calls these internal backend endpoints:
- `GET /internal/enforcement/{site_id}` - Check enforcement status
- `POST /internal/generate_invoice` - Generate payment invoice
- `POST /internal/validate_jwt` - Validate JWT token

## Docker Support

### Build
```bash
docker build -t ethicrawler/proxy:latest .
```

### Run with Docker Compose
```bash
docker-compose up -d
```

### Health Check
```bash
curl http://localhost/health
```

## Development

### Directory Structure
```
├── nginx.conf              # OpenResty configuration
├── lua/
│   └── payment_enforcement.lua  # Main enforcement logic
├── Dockerfile              # Container build
├── docker-compose.yml      # Development environment
└── build.sh               # Build script
```

### Testing

#### Basic Tests
```bash
# Run basic proxy tests
./test-proxy.sh

# Run complete workflow tests
./test-complete-workflow.sh
```

#### Integration Tests
```bash
# Run full integration test with mock backend
./test-integration.sh

# Start test environment manually
docker-compose -f docker-compose.test.yml up -d
```

#### Manual Testing
```bash
# Test AI bot detection
curl -H "User-Agent: MyAI-Bot/1.0" http://localhost/

# Test whitelisted bot
curl -H "User-Agent: Googlebot/2.1" http://localhost/

# Test with JWT
curl -H "Authorization: Bearer <jwt-token>" http://localhost/

# Test different AI bot patterns
curl -H "User-Agent: GPT-4-Bot/1.0" http://localhost/
curl -H "User-Agent: Claude-AI/2.0" http://localhost/
curl -H "User-Agent: python-requests/2.28.0" http://localhost/
```

#### Mock Backend Testing
```bash
# Start mock backend for testing
python3 mock-backend.py

# Test complete payment flow:
# 1. Get 402 response with payment details
# 2. Submit payment to get JWT
# 3. Access content with JWT
```

## Performance

- **Response Time**: < 200ms for 402 responses
- **Caching**: Enforcement settings cached for 5 minutes
- **Concurrency**: Handles high-traffic loads with OpenResty
- **Error Handling**: Fails open to prevent site disruption

## Security

- Non-root container execution
- Input validation and sanitization
- Rate limiting protection
- Secure JWT validation

## Monitoring

Logs are available in:
- `/var/log/nginx/access.log` - Request logs
- `/var/log/nginx/error.log` - Error logs
- `./logs/` - Mounted log directory

## Requirements

- OpenResty with Lua support
- Docker (for containerized deployment)
- Access to Ethicrawler backend API
- Soroban smart contract for payment processing

## License

MIT License - see LICENSE file for details