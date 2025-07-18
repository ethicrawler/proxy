#!/bin/bash

# Ethicrawler Proxy Complete Workflow Test Script

set -e

echo "Testing Complete Ethicrawler Proxy Workflow..."
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
PROXY_URL="http://localhost"
BACKEND_URL="http://localhost:8000"
TEST_SITE="test-site.com"

# Helper functions
log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
}

log_info() {
    echo -e "ℹ $1"
}

# Check if services are running
check_services() {
    echo "Checking required services..."
    
    if ! curl -s "$PROXY_URL/health" > /dev/null 2>&1; then
        log_error "Proxy service is not running at $PROXY_URL"
        echo "Please start the proxy with: docker-compose up -d"
        exit 1
    fi
    log_success "Proxy service is running"
    
    if ! curl -s "$BACKEND_URL/health" > /dev/null 2>&1; then
        log_warning "Backend service is not running at $BACKEND_URL"
        log_info "Some tests will be skipped without backend integration"
    else
        log_success "Backend service is running"
    fi
}

# Test 1: Health check
test_health_check() {
    echo -e "\n1. Testing health check..."
    
    response=$(curl -s "$PROXY_URL/health")
    if echo "$response" | grep -q "healthy"; then
        log_success "Health check passed"
    else
        log_error "Health check failed: $response"
        exit 1
    fi
}

# Test 2: Regular user access
test_regular_user() {
    echo -e "\n2. Testing regular user access..."
    
    status=$(curl -s -w "%{http_code}" -o /dev/null -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "$PROXY_URL/")
    if [ "$status" = "200" ] || [ "$status" = "502" ]; then
        log_success "Regular user allowed (status: $status)"
    else
        log_error "Regular user blocked unexpectedly (status: $status)"
    fi
}

# Test 3: Whitelisted bot access
test_whitelisted_bot() {
    echo -e "\n3. Testing whitelisted bot access..."
    
    status=$(curl -s -w "%{http_code}" -o /dev/null -H "User-Agent: Googlebot/2.1 (+http://www.google.com/bot.html)" "$PROXY_URL/")
    if [ "$status" = "200" ] || [ "$status" = "502" ]; then
        log_success "Whitelisted bot allowed (status: $status)"
    else
        log_error "Whitelisted bot blocked unexpectedly (status: $status)"
    fi
}

# Test 4: AI bot detection (should get 402 if enforcement enabled)
test_ai_bot_detection() {
    echo -e "\n4. Testing AI bot detection..."
    
    response=$(curl -s -w "HTTP_STATUS:%{http_code}" -H "User-Agent: MyAI-Bot/1.0" "$PROXY_URL/")
    status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    if [ "$status" = "402" ]; then
        log_success "AI bot correctly blocked with 402 Payment Required"
        
        # Parse JSON response
        if echo "$body" | jq -e '.payment_id' > /dev/null 2>&1; then
            payment_id=$(echo "$body" | jq -r '.payment_id')
            amount=$(echo "$body" | jq -r '.invoice_details.amount_xlm // .invoice_details.amount')
            log_info "Payment ID: $payment_id"
            log_info "Amount: $amount XLM"
            
            # Store payment_id for later tests
            echo "$payment_id" > /tmp/test_payment_id
            echo "$body" > /tmp/test_invoice_response
        else
            log_warning "402 response missing payment details"
        fi
    elif [ "$status" = "200" ] || [ "$status" = "502" ]; then
        log_warning "AI bot allowed - enforcement may be disabled (status: $status)"
    else
        log_error "Unexpected response status: $status"
    fi
}

# Test 5: Invalid JWT token
test_invalid_jwt() {
    echo -e "\n5. Testing invalid JWT token..."
    
    status=$(curl -s -w "%{http_code}" -o /dev/null \
        -H "User-Agent: MyAI-Bot/1.0" \
        -H "Authorization: Bearer invalid-jwt-token" \
        "$PROXY_URL/")
    
    if [ "$status" = "402" ]; then
        log_success "Invalid JWT correctly rejected with 402"
    elif [ "$status" = "401" ]; then
        log_success "Invalid JWT correctly rejected with 401"
    else
        log_warning "Invalid JWT response: $status"
    fi
}

# Test 6: Multiple AI bot patterns
test_ai_bot_patterns() {
    echo -e "\n6. Testing various AI bot patterns..."
    
    local patterns=(
        "GPT-4-Bot/1.0"
        "Claude-AI/2.0"
        "OpenAI-Crawler/1.0"
        "AI-Spider/1.0"
        "python-requests/2.28.0"
        "curl/7.68.0"
    )
    
    for pattern in "${patterns[@]}"; do
        status=$(curl -s -w "%{http_code}" -o /dev/null -H "User-Agent: $pattern" "$PROXY_URL/")
        if [ "$status" = "402" ]; then
            log_success "Pattern '$pattern' correctly identified as AI bot"
        else
            log_info "Pattern '$pattern' status: $status"
        fi
    done
}

# Test 7: Rate limiting and caching
test_caching() {
    echo -e "\n7. Testing caching behavior..."
    
    # Make multiple requests to test caching
    for i in {1..3}; do
        start_time=$(date +%s%3N)
        status=$(curl -s -w "%{http_code}" -o /dev/null -H "User-Agent: Test-AI-Bot/1.0" "$PROXY_URL/")
        end_time=$(date +%s%3N)
        response_time=$((end_time - start_time))
        
        log_info "Request $i: Status $status, Response time: ${response_time}ms"
        
        if [ $i -gt 1 ] && [ $response_time -lt 50 ]; then
            log_success "Fast response suggests caching is working"
        fi
    done
}

# Test 8: Proxy headers and security
test_proxy_headers() {
    echo -e "\n8. Testing proxy headers and security..."
    
    headers=$(curl -s -I -H "User-Agent: MyAI-Bot/1.0" "$PROXY_URL/")
    
    if echo "$headers" | grep -q "X-Frame-Options"; then
        log_success "Security headers present"
    else
        log_warning "Security headers missing"
    fi
    
    if echo "$headers" | grep -q "application/json"; then
        log_success "Correct content type for 402 response"
    fi
}

# Test 9: Concurrent requests
test_concurrent_requests() {
    echo -e "\n9. Testing concurrent request handling..."
    
    # Run 5 concurrent requests
    for i in {1..5}; do
        curl -s -w "%{http_code}\n" -o /dev/null -H "User-Agent: Concurrent-AI-Bot-$i/1.0" "$PROXY_URL/" &
    done
    
    wait
    log_success "Concurrent requests completed"
}

# Test 10: Backend integration (if available)
test_backend_integration() {
    echo -e "\n10. Testing backend integration..."
    
    if curl -s "$BACKEND_URL/health" > /dev/null 2>&1; then
        # Test internal endpoints
        if curl -s "$BACKEND_URL/internal/health" | grep -q "healthy"; then
            log_success "Backend internal API accessible"
        else
            log_warning "Backend internal API not accessible"
        fi
    else
        log_info "Backend not available, skipping integration tests"
    fi
}

# Main test execution
main() {
    check_services
    test_health_check
    test_regular_user
    test_whitelisted_bot
    test_ai_bot_detection
    test_invalid_jwt
    test_ai_bot_patterns
    test_caching
    test_proxy_headers
    test_concurrent_requests
    test_backend_integration
    
    echo -e "\n=============================================="
    echo -e "${GREEN}✓ Complete proxy workflow testing finished!${NC}"
    echo "Check the logs for detailed information:"
    echo "  docker-compose logs ethicrawler-proxy"
    echo ""
    echo "To test with a real payment flow:"
    echo "  1. Start the full backend stack"
    echo "  2. Enable enforcement for a test site"
    echo "  3. Use the AI crawler CLI to test payment submission"
}

# Cleanup function
cleanup() {
    rm -f /tmp/test_payment_id /tmp/test_invoice_response
}

# Set up cleanup trap
trap cleanup EXIT

# Run tests
main "$@"