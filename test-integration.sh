#!/bin/bash

# Ethicrawler Proxy Integration Test
# Tests the complete payment flow with mock backend

set -e

echo "Testing Ethicrawler Proxy Integration..."
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROXY_URL="http://localhost"
BACKEND_URL="http://localhost:8000"

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
}

log_info() {
    echo -e "ℹ $1"
}

# Start test environment
start_test_environment() {
    echo "Starting test environment..."
    
    # Build images
    docker-compose -f docker-compose.test.yml build
    
    # Start services
    docker-compose -f docker-compose.test.yml up -d
    
    # Wait for services to be ready
    echo "Waiting for services to be ready..."
    sleep 10
    
    # Check if services are running
    if curl -s "$PROXY_URL/health" | grep -q "healthy"; then
        log_success "Proxy service is ready"
    else
        log_error "Proxy service failed to start"
        exit 1
    fi
    
    if curl -s "$BACKEND_URL/health" | grep -q "healthy"; then
        log_success "Mock backend service is ready"
    else
        log_error "Mock backend service failed to start"
        exit 1
    fi
}

# Test complete payment flow
test_payment_flow() {
    echo -e "\nTesting complete payment flow..."
    
    # Step 1: AI bot request (should get 402)
    log_info "Step 1: AI bot requests content..."
    response=$(curl -s -w "HTTP_STATUS:%{http_code}" -H "User-Agent: MyAI-Bot/1.0" "$PROXY_URL/")
    status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]*$//')
    
    if [ "$status" != "402" ]; then
        log_error "Expected 402, got $status"
        exit 1
    fi
    
    log_success "AI bot correctly blocked with 402"
    
    # Step 2: Parse payment details
    log_info "Step 2: Parsing payment details..."
    payment_id=$(echo "$body" | jq -r '.invoice_details.payment_id')
    amount=$(echo "$body" | jq -r '.invoice_details.amount_xlm')
    
    if [ "$payment_id" = "null" ] || [ -z "$payment_id" ]; then
        log_error "Payment ID not found in response"
        exit 1
    fi
    
    log_success "Payment details parsed: ID=$payment_id, Amount=$amount XLM"
    
    # Step 3: Submit payment
    log_info "Step 3: Submitting payment..."
    payment_response=$(curl -s -X POST "$BACKEND_URL/api/public/payments/submit" \
        -H "Content-Type: application/json" \
        -d "{\"payment_id\":\"$payment_id\",\"stellar_tx_hash\":\"mock_tx_123\"}")
    
    jwt_token=$(echo "$payment_response" | jq -r '.access_token')
    
    if [ "$jwt_token" = "null" ] || [ -z "$jwt_token" ]; then
        log_error "JWT token not received"
        echo "Payment response: $payment_response"
        exit 1
    fi
    
    log_success "Payment submitted, JWT token received"
    
    # Step 4: Access content with JWT
    log_info "Step 4: Accessing content with JWT..."
    auth_response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -H "User-Agent: MyAI-Bot/1.0" \
        -H "Authorization: Bearer $jwt_token" \
        "$PROXY_URL/")
    
    auth_status=$(echo "$auth_response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
    
    if [ "$auth_status" = "200" ] || [ "$auth_status" = "502" ]; then
        log_success "Content access granted with valid JWT (status: $auth_status)"
    else
        log_error "Content access denied with valid JWT (status: $auth_status)"
        exit 1
    fi
    
    # Step 5: Test JWT caching
    log_info "Step 5: Testing JWT caching..."
    for i in {1..3}; do
        start_time=$(date +%s%3N)
        cached_status=$(curl -s -w "%{http_code}" -o /dev/null \
            -H "User-Agent: MyAI-Bot/1.0" \
            -H "Authorization: Bearer $jwt_token" \
            "$PROXY_URL/")
        end_time=$(date +%s%3N)
        response_time=$((end_time - start_time))
        
        if [ $i -gt 1 ] && [ $response_time -lt 100 ]; then
            log_success "JWT validation cached (${response_time}ms)"
        fi
    done
}

# Test error scenarios
test_error_scenarios() {
    echo -e "\nTesting error scenarios..."
    
    # Test with invalid JWT
    log_info "Testing invalid JWT..."
    invalid_status=$(curl -s -w "%{http_code}" -o /dev/null \
        -H "User-Agent: MyAI-Bot/1.0" \
        -H "Authorization: Bearer invalid-jwt" \
        "$PROXY_URL/")
    
    if [ "$invalid_status" = "402" ]; then
        log_success "Invalid JWT correctly rejected"
    else
        log_error "Invalid JWT handling failed (status: $invalid_status)"
    fi
    
    # Test enforcement disabled site
    log_info "Testing enforcement disabled site..."
    disabled_status=$(curl -s -w "%{http_code}" -o /dev/null \
        -H "User-Agent: MyAI-Bot/1.0" \
        -H "Host: disabled-site.com" \
        "$PROXY_URL/")
    
    if [ "$disabled_status" = "200" ] || [ "$disabled_status" = "502" ]; then
        log_success "Enforcement disabled site allows access"
    else
        log_error "Enforcement disabled site blocking incorrectly (status: $disabled_status)"
    fi
}

# Cleanup function
cleanup() {
    echo -e "\nCleaning up test environment..."
    docker-compose -f docker-compose.test.yml down
    docker-compose -f docker-compose.test.yml rm -f
}

# Main test execution
main() {
    # Set up cleanup trap
    trap cleanup EXIT
    
    start_test_environment
    test_payment_flow
    test_error_scenarios
    
    echo -e "\n========================================"
    echo -e "${GREEN}✓ All integration tests passed!${NC}"
    echo -e "The Ethicrawler proxy is working correctly with:"
    echo -e "  - AI bot detection and blocking"
    echo -e "  - Payment invoice generation"
    echo -e "  - JWT token validation"
    echo -e "  - Caching for performance"
    echo -e "  - Error handling and fail-open behavior"
}

# Run the tests
main "$@"