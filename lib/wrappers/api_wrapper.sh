#!/bin/bash

# api_wrapper.sh - API Operations Wrapper
# Version: 4.0.0 - Complex API operations for Nexus Orchestrator

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"bash

# api_wrapper.sh - API Interactions Wrapper
# Version: 4.0.0 - Complex API operations for Nexus Orchestrator with retry logic

# shellcheck source=../common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

# =============================================================================
# API WRAPPER CONFIGURATION
# =============================================================================

readonly API_WRAPPER_MAX_RETRIES=3
readonly API_WRAPPER_RETRY_DELAY=5
readonly API_WRAPPER_TIMEOUT=30
readonly API_WRAPPER_USER_AGENT="Nexus-Orchestrator/4.0"

# Nexus API endpoints
readonly NEXUS_API_BASE="https://api.nexus.xyz"
readonly NEXUS_CLI_INSTALL_URL="https://cli.nexus.xyz/install.sh"

# =============================================================================
# MAIN API WRAPPER FUNCTION
# =============================================================================

api_wrapper() {
    local operation="$1"
    shift

    log_activity "API wrapper: $operation operation requested"

    # Pre-execution validation
    if ! validate_api_requirements; then
        return 1
    fi

    # Execute operation with retry logic
    case "$operation" in
        "check_nexus_status")
            check_nexus_network_status "$@"
            ;;
        "download_prover")
            download_nexus_prover "$@"
            ;;
        "verify_wallet")
            verify_wallet_address "$@"
            ;;
        "get_node_info")
            get_nexus_node_info "$@"
            ;;
        "submit_proof")
            submit_proof_to_network "$@"
            ;;
        "check_rewards")
            check_nex_rewards "$@"
            ;;
        "get_network_stats")
            get_network_statistics "$@"
            ;;
        *)
            log_error "Unknown API operation: $operation"
            return 1
            ;;
    esac

    local exit_code=$?

    # Post-execution validation
    if [[ $exit_code -eq 0 ]]; then
        log_success "API wrapper: $operation completed successfully"
    else
        handle_error "API wrapper: $operation failed with exit code $exit_code"
    fi

    return $exit_code
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_api_requirements() {
    local validation_ok=true

    # Check curl availability
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl is required for API operations"
        validation_ok=false
    fi

    # Check jq availability
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required for JSON processing"
        validation_ok=false
    fi

    # Check internet connectivity
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        log_warning "Internet connectivity check failed"
        # Don't fail validation for connectivity - might work with proxy
    fi

    [[ "$validation_ok" == true ]]
}

# =============================================================================
# HTTP HELPER FUNCTIONS
# =============================================================================

make_http_request() {
    local method="$1"
    local url="$2"
    local data="${3:-}"
    local headers="${4:-}"
    local retries=0

    while [[ $retries -lt $API_WRAPPER_MAX_RETRIES ]]; do
        local curl_cmd=(
            curl
            -s
            --max-time "$API_WRAPPER_TIMEOUT"
            --user-agent "$API_WRAPPER_USER_AGENT"
            --connect-timeout 10
        )

        # Add method
        case "$method" in
            "GET")
                curl_cmd+=(-X GET)
                ;;
            "POST")
                curl_cmd+=(-X POST)
                ;;
            "PUT")
                curl_cmd+=(-X PUT)
                ;;
            *)
                log_error "Unsupported HTTP method: $method"
                return 1
                ;;
        esac

        # Add headers if provided
        if [[ -n "$headers" ]]; then
            while IFS= read -r header; do
                curl_cmd+=(-H "$header")
            done <<< "$headers"
        fi

        # Add data if provided
        if [[ -n "$data" ]]; then
            curl_cmd+=(-d "$data")
        fi

        # Add URL
        curl_cmd+=("$url")

        # Execute request
        local response
        local http_code

        # Capture both response and HTTP status code
        response=$(mktemp)
        http_code=$(
            "${curl_cmd[@]}" \
            -w "%{http_code}" \
            -o "$response" 2>/dev/null
        )

        # Check if request was successful
        if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
            cat "$response"
            rm -f "$response"
            return 0
        else
            log_warning "HTTP request failed with code $http_code (attempt $((retries + 1)))"
            rm -f "$response"

            retries=$((retries + 1))
            if [[ $retries -lt $API_WRAPPER_MAX_RETRIES ]]; then
                sleep $API_WRAPPER_RETRY_DELAY
            fi
        fi
    done

    log_error "HTTP request failed after $API_WRAPPER_MAX_RETRIES attempts"
    return 1
}

# =============================================================================
# NEXUS NETWORK STATUS
# =============================================================================

check_nexus_network_status() {
    log_activity "Checking Nexus network status"

    local status_url="$NEXUS_API_BASE/status"
    local response

    if response=$(make_http_request "GET" "$status_url"); then
        local network_status
        network_status=$(echo "$response" | jq -r '.status // "unknown"' 2>/dev/null)

        case "$network_status" in
            "online"|"active")
                log_success "Nexus network is online"
                return 0
                ;;
            "maintenance")
                log_warning "Nexus network is under maintenance"
                return 1
                ;;
            *)
                log_warning "Nexus network status: $network_status"
                return 1
                ;;
        esac
    else
        log_error "Failed to check Nexus network status"
        return 1
    fi
}

# =============================================================================
# NEXUS PROVER DOWNLOAD
# =============================================================================

download_nexus_prover() {
    local install_dir="$1"
    local force_download="${2:-false}"

    log_activity "Downloading Nexus prover"

    local prover_path="$install_dir/nexus-prover"

    # Check if already exists and not forcing download
    if [[ -f "$prover_path" && "$force_download" != "true" ]]; then
        log_info "Nexus prover already exists at $prover_path"
        return 0
    fi

    # Create installation directory
    ensure_directory "$install_dir"

    # Download installation script
    local install_script
    install_script=$(mktemp)

    if ! make_http_request "GET" "$NEXUS_CLI_INSTALL_URL" > "$install_script"; then
        log_error "Failed to download Nexus installation script"
        rm -f "$install_script"
        return 1
    fi

    # Make script executable and run it
    chmod +x "$install_script"

    # Set installation directory environment variable
    export NEXUS_INSTALL_DIR="$install_dir"

    if "$install_script"; then
        log_success "Nexus prover downloaded successfully"
        rm -f "$install_script"
        return 0
    else
        log_error "Nexus prover installation failed"
        rm -f "$install_script"
        return 1
    fi
}

# =============================================================================
# WALLET VERIFICATION
# =============================================================================

verify_wallet_address() {
    local wallet_address="$1"

    log_activity "Verifying wallet address: $wallet_address"

    # Basic format validation
    if ! validate_wallet_address "$wallet_address"; then
        log_error "Invalid wallet address format"
        return 1
    fi

    # API verification (if endpoint exists)
    local verify_url="$NEXUS_API_BASE/wallet/verify"
    local request_data
    request_data=$(jq -n --arg address "$wallet_address" '{wallet: $address}')

    local response
    if response=$(make_http_request "POST" "$verify_url" "$request_data" "Content-Type: application/json"); then
        local is_valid
        is_valid=$(echo "$response" | jq -r '.valid // false' 2>/dev/null)

        if [[ "$is_valid" == "true" ]]; then
            log_success "Wallet address verified successfully"
            return 0
        else
            local error_message
            error_message=$(echo "$response" | jq -r '.error // "Unknown error"' 2>/dev/null)
            log_error "Wallet verification failed: $error_message"
            return 1
        fi
    else
        log_warning "Unable to verify wallet with API, using local validation only"
        return 0  # Accept local validation if API is unavailable
    fi
}

# =============================================================================
# NODE INFORMATION
# =============================================================================

get_nexus_node_info() {
    local node_id="$1"

    log_activity "Getting node information for: $node_id"

    local node_url="$NEXUS_API_BASE/nodes/$node_id"
    local response

    if response=$(make_http_request "GET" "$node_url"); then
        # Extract node information
        local node_status
        node_status=$(echo "$response" | jq -r '.status // "unknown"' 2>/dev/null)

        local last_proof
        last_proof=$(echo "$response" | jq -r '.last_proof // "never"' 2>/dev/null)

        local total_proofs
        total_proofs=$(echo "$response" | jq -r '.total_proofs // 0' 2>/dev/null)

        # Display information
        echo "Node ID: $node_id"
        echo "Status: $node_status"
        echo "Last Proof: $last_proof"
        echo "Total Proofs: $total_proofs"

        return 0
    else
        log_error "Failed to get node information"
        return 1
    fi
}

# =============================================================================
# PROOF SUBMISSION
# =============================================================================

submit_proof_to_network() {
    local proof_data="$1"
    local node_id="$2"

    log_activity "Submitting proof to Nexus network"

    local submit_url="$NEXUS_API_BASE/proofs/submit"
    local request_data
    request_data=$(jq -n \
        --arg proof "$proof_data" \
        --arg node "$node_id" \
        '{proof: $proof, node_id: $node}'
    )

    local response
    if response=$(make_http_request "POST" "$submit_url" "$request_data" "Content-Type: application/json"); then
        local proof_id
        proof_id=$(echo "$response" | jq -r '.proof_id // "unknown"' 2>/dev/null)

        local status
        status=$(echo "$response" | jq -r '.status // "unknown"' 2>/dev/null)

        if [[ "$status" == "accepted" ]]; then
            log_success "Proof submitted successfully (ID: $proof_id)"
            return 0
        else
            local error_message
            error_message=$(echo "$response" | jq -r '.error // "Unknown error"' 2>/dev/null)
            log_error "Proof submission failed: $error_message"
            return 1
        fi
    else
        log_error "Failed to submit proof to network"
        return 1
    fi
}

# =============================================================================
# REWARDS CHECKING
# =============================================================================

check_nex_rewards() {
    local wallet_address="$1"

    log_activity "Checking NEX rewards for wallet: $wallet_address"

    local rewards_url="$NEXUS_API_BASE/rewards/$wallet_address"
    local response

    if response=$(make_http_request "GET" "$rewards_url"); then
        local total_rewards
        total_rewards=$(echo "$response" | jq -r '.total_rewards // "0"' 2>/dev/null)

        local pending_rewards
        pending_rewards=$(echo "$response" | jq -r '.pending_rewards // "0"' 2>/dev/null)

        local claimed_rewards
        claimed_rewards=$(echo "$response" | jq -r '.claimed_rewards // "0"' 2>/dev/null)

        # Display rewards information
        echo "Wallet: $wallet_address"
        echo "Total Rewards: $total_rewards NEX"
        echo "Pending: $pending_rewards NEX"
        echo "Claimed: $claimed_rewards NEX"

        return 0
    else
        log_error "Failed to check NEX rewards"
        return 1
    fi
}

# =============================================================================
# NETWORK STATISTICS
# =============================================================================

get_network_statistics() {
    log_activity "Getting Nexus network statistics"

    local stats_url="$NEXUS_API_BASE/statistics"
    local response

    if response=$(make_http_request "GET" "$stats_url"); then
        local total_nodes
        total_nodes=$(echo "$response" | jq -r '.total_nodes // "unknown"' 2>/dev/null)

        local active_nodes
        active_nodes=$(echo "$response" | jq -r '.active_nodes // "unknown"' 2>/dev/null)

        local total_proofs
        total_proofs=$(echo "$response" | jq -r '.total_proofs // "unknown"' 2>/dev/null)

        local network_hashrate
        network_hashrate=$(echo "$response" | jq -r '.network_hashrate // "unknown"' 2>/dev/null)

        # Display network statistics
        echo "=== Nexus Network Statistics ==="
        echo "Total Nodes: $total_nodes"
        echo "Active Nodes: $active_nodes"
        echo "Total Proofs: $total_proofs"
        echo "Network Hashrate: $network_hashrate"

        return 0
    else
        log_error "Failed to get network statistics"
        return 1
    fi
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

test_api_connectivity() {
    local test_url="$NEXUS_API_BASE/ping"

    log_activity "Testing API connectivity"

    if make_http_request "GET" "$test_url" >/dev/null; then
        log_success "API connectivity test passed"
        return 0
    else
        log_error "API connectivity test failed"
        return 1
    fi
}

get_api_version() {
    local version_url="$NEXUS_API_BASE/version"
    local response

    if response=$(make_http_request "GET" "$version_url"); then
        local api_version
        api_version=$(echo "$response" | jq -r '.version // "unknown"' 2>/dev/null)
        echo "$api_version"
        return 0
    else
        echo "unknown"
        return 1
    fi
}

check_api_rate_limit() {
    local rate_limit_url="$NEXUS_API_BASE/rate-limit"
    local response

    if response=$(make_http_request "GET" "$rate_limit_url"); then
        local remaining_requests
        remaining_requests=$(echo "$response" | jq -r '.remaining // "unknown"' 2>/dev/null)

        local reset_time
        reset_time=$(echo "$response" | jq -r '.reset_time // "unknown"' 2>/dev/null)

        echo "Remaining API requests: $remaining_requests"
        echo "Rate limit resets: $reset_time"
        return 0
    else
        log_warning "Unable to check API rate limit"
        return 1
    fi
}

# =============================================================================
# BATCH OPERATIONS
# =============================================================================

batch_check_nodes() {
    local node_ids=("$@")

    log_activity "Checking multiple nodes (${#node_ids[@]} nodes)"

    local success_count=0
    local failed_count=0

    for node_id in "${node_ids[@]}"; do
        if get_nexus_node_info "$node_id" >/dev/null; then
            success_count=$((success_count + 1))
        else
            failed_count=$((failed_count + 1))
        fi
    done

    log_info "Batch node check completed: $success_count success, $failed_count failed"

    if [[ $failed_count -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f api_wrapper validate_api_requirements make_http_request
export -f check_nexus_network_status download_nexus_prover verify_wallet_address
export -f get_nexus_node_info submit_proof_to_network check_nex_rewards
export -f get_network_statistics test_api_connectivity get_api_version
export -f check_api_rate_limit batch_check_nodes

log_success "API wrapper loaded successfully"
