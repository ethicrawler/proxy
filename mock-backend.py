#!/usr/bin/env python3
"""
Mock backend for testing Ethicrawler proxy functionality
"""

import json
import time
import uuid
from datetime import datetime, timedelta
from flask import Flask, request, jsonify

app = Flask(__name__)

# Mock data storage
mock_sites = {
    "test-site.com": {"enforcement_enabled": True},
    "localhost": {"enforcement_enabled": True},
    "disabled-site.com": {"enforcement_enabled": False}
}

mock_payments = {}
mock_jwts = {}

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "service": "mock-backend"})

@app.route('/internal/health', methods=['GET'])
def internal_health():
    return jsonify({"status": "healthy", "service": "internal-api"})

@app.route('/internal/enforcement/<site_id>', methods=['GET'])
def check_enforcement(site_id):
    """Check if enforcement is enabled for a site"""
    site = mock_sites.get(site_id, {"enforcement_enabled": False})
    return jsonify({
        "enforcement_enabled": site["enforcement_enabled"],
        "site_details": {
            "site_id": site_id,
            "per_page_rate": 0.001
        }
    })

@app.route('/internal/generate_invoice', methods=['POST'])
def generate_invoice():
    """Generate a payment invoice"""
    data = request.json
    
    payment_id = str(uuid.uuid4())
    expires_at = datetime.now() + timedelta(minutes=15)
    
    invoice = {
        "payment_id": payment_id,
        "site_id": data["site_id"],
        "url": data["url"],
        "url_hash": str(hash(data["url"])),
        "amount_xlm": 0.001,
        "amount_stroops": 1000,
        "expires_at": expires_at.isoformat(),
        "status": "pending",
        "user_agent": data["user_agent"],
        "ip_address": data["ip_address"]
    }
    
    mock_payments[payment_id] = invoice
    
    return jsonify(invoice)

@app.route('/internal/validate_jwt', methods=['POST'])
def validate_jwt():
    """Validate JWT token"""
    data = request.json
    token = data.get("token")
    site_id = data.get("site_id")
    
    # Simple mock validation - in real implementation, this would verify JWT signature
    if token in mock_jwts:
        jwt_data = mock_jwts[token]
        if jwt_data["site_id"] == site_id and jwt_data["expires_at"] > datetime.now():
            return jsonify({
                "valid": True,
                "payment_id": jwt_data["payment_id"],
                "site_id": jwt_data["site_id"],
                "expires_at": jwt_data["expires_at"].isoformat()
            })
    
    return jsonify({
        "valid": False,
        "error": "Invalid or expired token"
    })

@app.route('/api/public/payments/submit', methods=['POST'])
def submit_payment():
    """Submit payment and get JWT"""
    data = request.json
    payment_id = data.get("payment_id")
    tx_hash = data.get("stellar_tx_hash", "mock_tx_" + str(uuid.uuid4()))
    
    if payment_id in mock_payments:
        # Generate mock JWT
        jwt_token = f"mock_jwt_{uuid.uuid4()}"
        expires_at = datetime.now() + timedelta(hours=1)
        
        mock_jwts[jwt_token] = {
            "payment_id": payment_id,
            "site_id": mock_payments[payment_id]["site_id"],
            "expires_at": expires_at
        }
        
        return jsonify({
            "verified": True,
            "access_token": jwt_token,
            "expires_at": expires_at.isoformat(),
            "payment_id": payment_id,
            "tx_hash": tx_hash
        })
    
    return jsonify({
        "verified": False,
        "error": "Payment not found"
    }), 404

@app.route('/api/public/payments/status/<payment_id>', methods=['GET'])
def payment_status(payment_id):
    """Get payment status"""
    if payment_id in mock_payments:
        return jsonify({
            "found": True,
            "payment": mock_payments[payment_id]
        })
    
    return jsonify({
        "found": False,
        "error": "Payment not found"
    }), 404

@app.route('/debug/payments', methods=['GET'])
def debug_payments():
    """Debug endpoint to view all payments"""
    return jsonify({
        "payments": list(mock_payments.values()),
        "jwts": {k: {**v, "expires_at": v["expires_at"].isoformat()} for k, v in mock_jwts.items()}
    })

@app.route('/debug/reset', methods=['POST'])
def debug_reset():
    """Reset mock data"""
    global mock_payments, mock_jwts
    mock_payments.clear()
    mock_jwts.clear()
    return jsonify({"message": "Mock data reset"})

if __name__ == '__main__':
    print("Starting Ethicrawler Mock Backend...")
    print("Available endpoints:")
    print("  GET  /health")
    print("  GET  /internal/enforcement/<site_id>")
    print("  POST /internal/generate_invoice")
    print("  POST /internal/validate_jwt")
    print("  POST /api/public/payments/submit")
    print("  GET  /debug/payments")
    print("  POST /debug/reset")
    
    app.run(host='0.0.0.0', port=8000, debug=True)