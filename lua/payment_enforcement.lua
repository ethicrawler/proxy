-- Ethicrawler Payment Enforcement Module
-- This module handles AI bot detection and payment enforcement

local http = require "resty.http"
local cjson = require "cjson"

-- Cache references
local enforcement_cache = ngx.shared.enforcement_cache
local payment_cache = ngx.shared.payment_cache

-- Configuration
local BACKEND_URL = _G.backend_url or "http://backend:8000"
local ENFORCEMENT_CACHE_TTL = _G.enforcement_cache_ttl or 300
local PAYMENT_CACHE_TTL = _G.payment_cache_ttl or 60

-- AI bot patterns (case-insensitive)
local AI_BOT_PATTERNS = {
    "gpt",
    "chatgpt",
    "claude",
    "bard",
    "openai",
    "anthropic",
    "grok",
    "perplexity",
    "ai%-bot",
    "ai%-crawler",
    "ai%-spider",
    "ai%-scraper",
    "llm%-bot",
    "crawler",
    "spider",
    "scraper",
    "bot/",
    "python%-requests",
    "curl/",
    "wget/",
    "scrapy"
}

-- Whitelisted legitimate crawlers
local WHITELISTED_BOTS = {
    "googlebot",
    "bingbot",
    "slurp",
    "duckduckbot",
    "baiduspider",
    "yandexbot",
    "facebookexternalhit",
    "twitterbot",
    "linkedinbot",
    "applebot",
    "ia_archiver",
    "msnbot",
    "yahoo! slurp",
    "archive.org_bot",
    "wayback",
    "semrushbot",
    "ahrefsbot"
}

-- Helper function to check if string contains pattern
local function contains_pattern(str, patterns)
    if not str then return false end
    local lower_str = string.lower(str)
    
    for _, pattern in ipairs(patterns) do
        if string.find(lower_str, pattern, 1, true) then
            return true
        end
    end
    return false
end

-- Check if User-Agent is a whitelisted bot
local function is_whitelisted_bot(user_agent)
    return contains_pattern(user_agent, WHITELISTED_BOTS)
end

-- Check if User-Agent is an AI bot
local function is_ai_bot(user_agent)
    return contains_pattern(user_agent, AI_BOT_PATTERNS)
end

-- Get site enforcement status from cache or backend
local function get_enforcement_status(site_id)
    local cache_key = "enforcement:" .. site_id
    local cached_status = enforcement_cache:get(cache_key)
    
    if cached_status then
        ngx.log(ngx.INFO, "Enforcement status cache hit for site: ", site_id, " status: ", cached_status)
        return cached_status == "enabled"
    end
    
    -- Query backend for enforcement status
    local httpc = http.new()
    httpc:set_timeout(5000)
    
    local res, err = httpc:request_uri(BACKEND_URL .. "/internal/enforcement/" .. site_id, {
        method = "GET",
        headers = {
            ["Content-Type"] = "application/json",
            ["User-Agent"] = "ethicrawler-proxy/1.0",
            ["X-Request-ID"] = ngx.var.request_id or "unknown"
        }
    })
    
    if not res or err then
        ngx.log(ngx.ERR, "Failed to check enforcement status for site ", site_id, ": ", err or "unknown error")
        -- Cache disabled status briefly to avoid repeated failures
        enforcement_cache:set(cache_key, "disabled", 60)
        return false
    end
    
    if res.status == 200 then
        local ok, data = pcall(cjson.decode, res.body)
        if not ok then
            ngx.log(ngx.ERR, "Failed to decode enforcement response for site ", site_id, ": ", data)
            enforcement_cache:set(cache_key, "disabled", 60)
            return false
        end
        
        local enabled = data.enforcement_enabled or false
        ngx.log(ngx.INFO, "Enforcement status for site ", site_id, ": ", enabled)
        
        -- Cache the result
        local cache_value = enabled and "enabled" or "disabled"
        enforcement_cache:set(cache_key, cache_value, ENFORCEMENT_CACHE_TTL)
        
        return enabled
    end
    
    ngx.log(ngx.WARN, "Backend returned status ", res.status, " for enforcement check on site ", site_id)
    enforcement_cache:set(cache_key, "disabled", 60)
    return false
end

-- Generate payment invoice via backend
local function generate_invoice(site_id, url, user_agent, ip_address)
    local httpc = http.new()
    httpc:set_timeout(5000)
    
    local request_data = {
        site_id = site_id,
        url = url,
        user_agent = user_agent,
        ip_address = ip_address
    }
    
    local res, err = httpc:request_uri(BACKEND_URL .. "/internal/generate_invoice", {
        method = "POST",
        body = cjson.encode(request_data),
        headers = {
            ["Content-Type"] = "application/json",
            ["User-Agent"] = "ethicrawler-proxy/1.0",
            ["X-Request-ID"] = ngx.var.request_id or "unknown"
        }
    })
    
    if not res or err then
        ngx.log(ngx.ERR, "Failed to generate invoice for site ", site_id, ": ", err or "unknown error")
        return nil
    end
    
    if res.status == 200 then
        local ok, data = pcall(cjson.decode, res.body)
        if not ok then
            ngx.log(ngx.ERR, "Failed to decode invoice response: ", data)
            return nil
        end
        
        ngx.log(ngx.INFO, "Generated invoice for site ", site_id, " payment_id: ", data.payment_id or "unknown")
        return data
    end
    
    ngx.log(ngx.ERR, "Invoice generation failed with status ", res.status, " for site ", site_id, " body: ", res.body or "empty")
    return nil
end

-- Validate JWT token
local function validate_jwt(token, site_id)
    -- Create cache key with hash to handle long tokens
    local cache_key = "jwt:" .. site_id .. ":" .. ngx.md5(token)
    local cached_result = payment_cache:get(cache_key)
    
    if cached_result then
        ngx.log(ngx.INFO, "JWT validation cache hit for site: ", site_id, " result: ", cached_result)
        return cached_result == "valid"
    end
    
    local httpc = http.new()
    httpc:set_timeout(5000)
    
    local res, err = httpc:request_uri(BACKEND_URL .. "/internal/validate_jwt", {
        method = "POST",
        body = cjson.encode({
            token = token,
            site_id = site_id
        }),
        headers = {
            ["Content-Type"] = "application/json",
            ["User-Agent"] = "ethicrawler-proxy/1.0",
            ["X-Request-ID"] = ngx.var.request_id or "unknown"
        }
    })
    
    if not res or err then
        ngx.log(ngx.ERR, "Failed to validate JWT for site ", site_id, ": ", err or "unknown error")
        -- Cache invalid briefly to avoid repeated failures
        payment_cache:set(cache_key, "invalid", 30)
        return false
    end
    
    local valid = false
    if res.status == 200 then
        local ok, data = pcall(cjson.decode, res.body)
        if ok and data.valid then
            valid = true
            ngx.log(ngx.INFO, "JWT validation successful for site ", site_id, " payment_id: ", data.payment_id or "unknown")
        else
            ngx.log(ngx.INFO, "JWT validation failed for site ", site_id, " reason: ", data and data.error or "unknown")
        end
    else
        ngx.log(ngx.WARN, "JWT validation returned status ", res.status, " for site ", site_id)
    end
    
    -- Cache the result
    local cache_value = valid and "valid" or "invalid"
    local cache_ttl = valid and PAYMENT_CACHE_TTL or 30
    payment_cache:set(cache_key, cache_value, cache_ttl)
    
    return valid
end

-- Main enforcement logic
local function enforce_payment()
    local user_agent = ngx.var.http_user_agent or ""
    local site_id = ngx.var.host or "default"
    local url = ngx.var.scheme .. "://" .. ngx.var.host .. ngx.var.request_uri
    local ip_address = ngx.var.remote_addr
    local request_method = ngx.var.request_method
    
    -- Log request for debugging
    ngx.log(ngx.INFO, "Processing request - Method: ", request_method, " Site: ", site_id, " User-Agent: ", user_agent)
    
    -- Skip enforcement for whitelisted bots
    if is_whitelisted_bot(user_agent) then
        ngx.log(ngx.INFO, "Whitelisted bot detected, allowing access: ", user_agent)
        return
    end
    
    -- Only enforce for AI bots
    if not is_ai_bot(user_agent) then
        ngx.log(ngx.INFO, "Regular user detected, allowing access: ", user_agent)
        return
    end
    
    ngx.log(ngx.INFO, "AI bot detected: ", user_agent)
    
    -- Check if enforcement is enabled for this site
    if not get_enforcement_status(site_id) then
        ngx.log(ngx.INFO, "Enforcement disabled for site, allowing access: ", site_id)
        return
    end
    
    -- Check for existing JWT token
    local auth_header = ngx.var.http_authorization
    if auth_header then
        local token = string.match(auth_header, "Bearer%s+(.+)")
        if token and validate_jwt(token, site_id) then
            ngx.log(ngx.INFO, "Valid JWT token provided, allowing access for site: ", site_id)
            return
        else
            ngx.log(ngx.INFO, "Invalid or expired JWT token for site: ", site_id)
        end
    end
    
    -- Generate payment invoice
    local invoice = generate_invoice(site_id, url, user_agent, ip_address)
    if not invoice then
        ngx.log(ngx.ERR, "Failed to generate invoice, allowing access (fail-open policy)")
        return
    end
    
    -- Return 402 Payment Required with invoice details
    ngx.status = 402
    ngx.header["Content-Type"] = "application/json; charset=utf-8"
    ngx.header["WWW-Authenticate"] = 'Bearer realm="Ethicrawler Payment Required"'
    ngx.header["Cache-Control"] = "no-cache, no-store, must-revalidate"
    ngx.header["Pragma"] = "no-cache"
    ngx.header["Expires"] = "0"
    
    local response = {
        error = "Payment Required",
        message = "AI bot access requires payment for this content",
        payment_url = BACKEND_URL .. "/api/public/payments/submit",
        invoice_details = {
            payment_id = invoice.payment_id,
            amount_xlm = invoice.amount_xlm or invoice.amount,
            amount_stroops = invoice.amount_stroops,
            expires_at = invoice.expires_at,
            site_id = site_id,
            url_hash = invoice.url_hash
        },
        instructions = {
            step1 = "Submit payment to the Stellar network",
            step2 = "Call the payment_url with your transaction hash",
            step3 = "Include the returned JWT token in subsequent requests"
        },
        documentation = "https://docs.ethicrawler.com/crawler-integration",
        request_id = ngx.var.request_id or "unknown"
    }
    
    ngx.log(ngx.INFO, "Returning 402 Payment Required for site: ", site_id, " payment_id: ", invoice.payment_id)
    ngx.say(cjson.encode(response))
    ngx.exit(402)
end

-- Execute enforcement
enforce_payment()