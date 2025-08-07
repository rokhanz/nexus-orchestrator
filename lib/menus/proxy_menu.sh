#!/bin/bash

# proxy_menu.sh - Proxy Configuration Menu Module
# Version: 4.0.0 - Modular menu system for Nexus Orchestrator

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

# =============================================================================
# PROXY MENU FUNCTIONS
# =============================================================================

proxy_menu() {
    while true; do
        clear
        show_section_header "Proxy Configuration" "🌐"

        echo -e "${CYAN}Select proxy configuration option:${NC}"
        echo ""
        echo "1. Configure HTTP/HTTPS Proxy"
        echo "2. Configure SOCKS5 Proxy"
        echo "3. View Current Proxy Settings"
        echo "4. Test Proxy Connection"
        echo "5. Remove Proxy Configuration"
        echo "6. Proxy Auto-Detection"
        echo "0. Return to Main Menu"
        echo ""

        read -rp "Choose option [0-6]: " choice

        case "$choice" in
            1)
                configure_http_proxy
                ;;
            2)
                configure_socks_proxy
                ;;
            3)
                view_proxy_settings
                ;;
            4)
                test_proxy_connection
                ;;
            5)
                remove_proxy_config
                ;;
            6)
                auto_detect_proxy
                ;;
            0)
                return 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option. Please try again.${NC}"
                sleep 2
                ;;
        esac
    done
}

# =============================================================================
# HTTP/HTTPS PROXY CONFIGURATION
# =============================================================================

configure_http_proxy() {
    show_section_header "HTTP/HTTPS Proxy Configuration" "🌐"

    echo -e "${CYAN}Configure HTTP/HTTPS proxy settings:${NC}"
    echo ""

    # Get proxy server
    read -rp "Enter proxy server (e.g., proxy.company.com): " proxy_server
    if [[ -z "$proxy_server" ]]; then
        echo -e "${RED}❌ Proxy server cannot be empty${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    # Get proxy port
    read -rp "Enter proxy port (default: 8080): " proxy_port
    proxy_port=${proxy_port:-8080}

    # Validate port
    if ! [[ "$proxy_port" =~ ^[0-9]+$ ]] || [[ "$proxy_port" -lt 1 ]] || [[ "$proxy_port" -gt 65535 ]]; then
        echo -e "${RED}❌ Invalid port number${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    # Get authentication if needed
    read -rp "Does proxy require authentication? [y/N]: " needs_auth

    local proxy_url="http://"

    if [[ "$needs_auth" =~ ^[Yy]$ ]]; then
        read -rp "Enter username: " proxy_user
        read -rsp "Enter password: " proxy_pass
        echo ""

        if [[ -n "$proxy_user" && -n "$proxy_pass" ]]; then
            proxy_url="http://${proxy_user}:${proxy_pass}@${proxy_server}:${proxy_port}"
        else
            proxy_url="http://${proxy_server}:${proxy_port}"
        fi
    else
        proxy_url="http://${proxy_server}:${proxy_port}"
    fi

    # Save proxy configuration
    save_proxy_config "http" "$proxy_url"

    # Apply proxy settings
    apply_proxy_settings

    echo ""
    echo -e "${GREEN}✅ HTTP/HTTPS proxy configured successfully${NC}"
    echo -e "${CYAN}Proxy URL: ${proxy_url%:*}:${proxy_port}${NC}"
    echo ""
    read -rp "Press Enter to continue..."
}

# =============================================================================
# SOCKS5 PROXY CONFIGURATION
# =============================================================================

configure_socks_proxy() {
    show_section_header "SOCKS5 Proxy Configuration" "🔐"

    echo -e "${CYAN}Configure SOCKS5 proxy settings:${NC}"
    echo ""

    # Get proxy server
    read -rp "Enter SOCKS5 server (e.g., socks.company.com): " socks_server
    if [[ -z "$socks_server" ]]; then
        echo -e "${RED}❌ SOCKS5 server cannot be empty${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    # Get proxy port
    read -rp "Enter SOCKS5 port (default: 1080): " socks_port
    socks_port=${socks_port:-1080}

    # Validate port
    if ! [[ "$socks_port" =~ ^[0-9]+$ ]] || [[ "$socks_port" -lt 1 ]] || [[ "$socks_port" -gt 65535 ]]; then
        echo -e "${RED}❌ Invalid port number${NC}"
        read -rp "Press Enter to continue..."
        return 1
    fi

    # Get authentication if needed
    read -rp "Does SOCKS5 require authentication? [y/N]: " needs_auth

    local socks_url="socks5://"

    if [[ "$needs_auth" =~ ^[Yy]$ ]]; then
        read -rp "Enter username: " socks_user
        read -rsp "Enter password: " socks_pass
        echo ""

        if [[ -n "$socks_user" && -n "$socks_pass" ]]; then
            socks_url="socks5://${socks_user}:${socks_pass}@${socks_server}:${socks_port}"
        else
            socks_url="socks5://${socks_server}:${socks_port}"
        fi
    else
        socks_url="socks5://${socks_server}:${socks_port}"
    fi

    # Save proxy configuration
    save_proxy_config "socks5" "$socks_url"

    # Apply proxy settings
    apply_proxy_settings

    echo ""
    echo -e "${GREEN}✅ SOCKS5 proxy configured successfully${NC}"
    echo -e "${CYAN}Proxy URL: ${socks_url%:*}:${socks_port}${NC}"
    echo ""
    read -rp "Press Enter to continue..."
}

# =============================================================================
# PROXY MANAGEMENT FUNCTIONS
# =============================================================================

save_proxy_config() {
    local proxy_type="$1"
    local proxy_url="$2"

    ensure_directories

    # Create or update proxy configuration
    local temp_file
    temp_file=$(mktemp)

    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo '{}' > "$CREDENTIALS_FILE"
    fi

    # Save proxy configuration to JSON
    jq --arg type "$proxy_type" --arg url "$proxy_url" \
        '.proxy = {type: $type, url: $url, enabled: true}' \
        "$CREDENTIALS_FILE" > "$temp_file" && \
    mv "$temp_file" "$CREDENTIALS_FILE"

    log_info "Proxy configuration saved: $proxy_type"
}

apply_proxy_settings() {
    local proxy_config
    proxy_config=$(read_config_value "proxy")

    if [[ -z "$proxy_config" ]]; then
        return 1
    fi

    local proxy_url
    proxy_url=$(echo "$proxy_config" | jq -r '.url // empty')

    if [[ -z "$proxy_url" ]]; then
        return 1
    fi

    # Set environment variables for current session
    export http_proxy="$proxy_url"
    export https_proxy="$proxy_url"
    export HTTP_PROXY="$proxy_url"
    export HTTPS_PROXY="$proxy_url"

    # Create proxy environment file for Docker
    cat > "$DEFAULT_WORKDIR/proxy.env" << EOF
http_proxy=$proxy_url
https_proxy=$proxy_url
HTTP_PROXY=$proxy_url
HTTPS_PROXY=$proxy_url
no_proxy=localhost,127.0.0.1,::1
NO_PROXY=localhost,127.0.0.1,::1
EOF

    log_info "Proxy settings applied"
}

view_proxy_settings() {
    show_section_header "Current Proxy Settings" "📋"

    local proxy_config
    proxy_config=$(read_config_value "proxy")

    if [[ -z "$proxy_config" ]]; then
        echo -e "${YELLOW}⚠️  No proxy configuration found${NC}"
        echo ""
        read -rp "Press Enter to continue..."
        return 0
    fi

    local proxy_type
    proxy_type=$(echo "$proxy_config" | jq -r '.type // "unknown"')

    local proxy_url
    proxy_url=$(echo "$proxy_config" | jq -r '.url // "unknown"')

    local proxy_enabled
    proxy_enabled=$(echo "$proxy_config" | jq -r '.enabled // false')

    echo -e "${CYAN}Current proxy configuration:${NC}"
    echo ""
    printf "  %-15s %s\n" "Type:" "$proxy_type"
    printf "  %-15s %s\n" "Status:" "$(if [[ "$proxy_enabled" == "true" ]]; then echo -e "${GREEN}Enabled${NC}"; else echo -e "${RED}Disabled${NC}"; fi)"

    # Show URL without credentials
    local safe_url
    safe_url=${proxy_url//\/\/[^@]*@/\/\/***:***@}
    printf "  %-15s %s\n" "URL:" "$safe_url"

    # Show environment variables
    echo ""
    echo -e "${CYAN}Environment variables:${NC}"
    printf "  %-15s %s\n" "http_proxy:" "${http_proxy:-not set}"
    printf "  %-15s %s\n" "https_proxy:" "${https_proxy:-not set}"

    echo ""
    read -rp "Press Enter to continue..."
}

test_proxy_connection() {
    show_section_header "Test Proxy Connection" "🔍"

    echo -e "${CYAN}Testing proxy connection...${NC}"
    echo ""

    # Test with curl
    local test_url="https://httpbin.org/ip"
    local timeout=10

    echo -e "${BLUE}Testing connection to $test_url...${NC}"

    if curl -s --max-time "$timeout" --proxy-header "User-Agent: Nexus-Orchestrator/4.0" "$test_url" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Proxy connection successful${NC}"

        # Get external IP
        local external_ip
        external_ip=$(curl -s --max-time "$timeout" "$test_url" | jq -r '.origin // "unknown"' 2>/dev/null || echo "unknown")
        echo -e "${CYAN}External IP: $external_ip${NC}"
    else
        echo -e "${RED}❌ Proxy connection failed${NC}"
        echo -e "${YELLOW}💡 Please check your proxy settings${NC}"
    fi

    echo ""

    # Test Docker connectivity if proxy is configured
    if [[ -f "$DEFAULT_WORKDIR/proxy.env" ]]; then
        echo -e "${BLUE}Testing Docker with proxy...${NC}"

        if docker run --rm --env-file "$DEFAULT_WORKDIR/proxy.env" alpine:latest wget -q --spider https://www.google.com 2>/dev/null; then
            echo -e "${GREEN}✅ Docker proxy configuration working${NC}"
        else
            echo -e "${RED}❌ Docker proxy configuration failed${NC}"
        fi
    fi

    echo ""
    read -rp "Press Enter to continue..."
}

remove_proxy_config() {
    show_section_header "Remove Proxy Configuration" "🗑️"

    echo -e "${YELLOW}⚠️  This will remove all proxy settings${NC}"
    read -rp "Are you sure? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        return 0
    fi

    # Remove from configuration
    local temp_file
    temp_file=$(mktemp)

    if [[ -f "$CREDENTIALS_FILE" ]]; then
        jq 'del(.proxy)' "$CREDENTIALS_FILE" > "$temp_file" && \
        mv "$temp_file" "$CREDENTIALS_FILE"
    fi

    # Unset environment variables
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY

    # Remove proxy environment file
    if [[ -f "$DEFAULT_WORKDIR/proxy.env" ]]; then
        rm -f "$DEFAULT_WORKDIR/proxy.env"
    fi

    echo ""
    echo -e "${GREEN}✅ Proxy configuration removed${NC}"
    log_info "Proxy configuration removed"
    echo ""
    read -rp "Press Enter to continue..."
}

auto_detect_proxy() {
    show_section_header "Auto-Detect Proxy" "🔍"

    echo -e "${CYAN}Attempting to auto-detect proxy settings...${NC}"
    echo ""

    local detected_proxies=()
    local proxy_list_file="$DEFAULT_WORKDIR/proxy_list.txt"

    # Check for proxy_list.txt file
    if [[ -f "$proxy_list_file" ]]; then
        echo -e "${GREEN}✅ Found proxy_list.txt file${NC}"
        echo -e "${BLUE}Reading proxies from $proxy_list_file...${NC}"

        local line_count=0
        local valid_count=0

        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

            line_count=$((line_count + 1))

            # Parse proxy format: protocol://[username:password@]host:port
            if [[ "$line" =~ ^(https?|socks[45]?)://.*:[0-9]+$ ]]; then
                detected_proxies+=("$line")
                valid_count=$((valid_count + 1))
                echo -e "${GREEN}  ✅ Valid proxy: $line${NC}"
            else
                echo -e "${YELLOW}  ⚠️  Invalid format: $line${NC}"
            fi
        done < "$proxy_list_file"

        echo -e "${CYAN}Found $valid_count valid proxies out of $line_count lines${NC}"
        echo ""
    else
        echo -e "${YELLOW}⚠️  No proxy_list.txt file found at: $proxy_list_file${NC}"
        echo -e "${BLUE}You can create one with proxy entries like:${NC}"
        echo -e "${GRAY}  http://proxy.company.com:8080${NC}"
        echo -e "${GRAY}  https://user:pass@proxy.example.com:3128${NC}"
        echo -e "${GRAY}  socks5://127.0.0.1:1080${NC}"
        echo ""
    fi

    # Check environment variables
    echo -e "${BLUE}Checking environment variables...${NC}"
    local env_found=false

    if [[ -n "${http_proxy:-}" ]]; then
        echo -e "${GREEN}✅ Found http_proxy: $http_proxy${NC}"
        detected_proxies+=("$http_proxy")
        env_found=true
    fi

    if [[ -n "${https_proxy:-}" ]]; then
        echo -e "${GREEN}✅ Found https_proxy: $https_proxy${NC}"
        detected_proxies+=("$https_proxy")
        env_found=true
    fi

    if [[ -n "${SOCKS_PROXY:-}" ]]; then
        echo -e "${GREEN}✅ Found SOCKS_PROXY: $SOCKS_PROXY${NC}"
        detected_proxies+=("$SOCKS_PROXY")
        env_found=true
    fi

    if [[ "$env_found" == false ]]; then
        echo -e "${YELLOW}⚠️  No proxy environment variables found${NC}"
    fi
    echo ""

    # Check system proxy settings on different platforms
    echo -e "${BLUE}Checking system proxy settings...${NC}"
    if command -v gsettings >/dev/null 2>&1; then
        local gnome_proxy_mode
        gnome_proxy_mode=$(gsettings get org.gnome.system.proxy mode 2>/dev/null || echo "'none'")

        if [[ "$gnome_proxy_mode" != "'none'" ]]; then
            echo -e "${GREEN}✅ GNOME proxy detected: $gnome_proxy_mode${NC}"

            # Try to get actual proxy settings
            local gnome_proxy_host
            local gnome_proxy_port
            gnome_proxy_host=$(gsettings get org.gnome.system.proxy.http host 2>/dev/null || echo "")
            gnome_proxy_port=$(gsettings get org.gnome.system.proxy.http port 2>/dev/null || echo "")

            if [[ -n "$gnome_proxy_host" && -n "$gnome_proxy_port" && "$gnome_proxy_host" != "''" ]]; then
                local gnome_proxy="http://${gnome_proxy_host//\'/}:${gnome_proxy_port}"
                detected_proxies+=("$gnome_proxy")
                echo -e "${GREEN}  → Proxy URL: $gnome_proxy${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  No GNOME proxy configuration found${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  gsettings not available (not running GNOME)${NC}"
    fi
    echo ""

    # Check common proxy ports
    echo -e "${BLUE}Scanning for common proxy services...${NC}"

    local common_ports=(3128 8080 1080 8888 3129)
    local found_proxy=false

    for port in "${common_ports[@]}"; do
        if command -v nc >/dev/null 2>&1 && nc -z localhost "$port" 2>/dev/null; then
            echo -e "${GREEN}✅ Found service on localhost:$port${NC}"
            detected_proxies+=("http://localhost:$port")
            found_proxy=true
        fi
    done

    if [[ "$found_proxy" == false ]]; then
        echo -e "${YELLOW}⚠️  No local proxy services detected${NC}"
    fi
    echo ""

    # Summary of detected proxies
    if [[ ${#detected_proxies[@]} -gt 0 ]]; then
        echo -e "${GREEN}${BOLD}📋 Summary: Found ${#detected_proxies[@]} potential proxy(ies)${NC}"
        for i in "${!detected_proxies[@]}"; do
            echo -e "${CYAN}  $((i+1)). ${detected_proxies[i]}${NC}"
        done
        echo ""

        read -rp "$(echo -e "${PURPLE}Would you like to configure one of these proxies? [y/N]: ${NC}")" configure_choice
        if [[ "$configure_choice" =~ ^[Yy]$ ]]; then
            echo ""
            read -rp "Enter proxy number to configure [1-${#detected_proxies[@]}]: " proxy_choice

            if [[ "$proxy_choice" =~ ^[0-9]+$ ]] && [[ "$proxy_choice" -ge 1 ]] && [[ "$proxy_choice" -le ${#detected_proxies[@]} ]]; then
                local selected_proxy="${detected_proxies[$((proxy_choice-1))]}"
                echo -e "${GREEN}Selected proxy: $selected_proxy${NC}"

                # Determine proxy type and save configuration
                if [[ "$selected_proxy" =~ ^socks ]]; then
                    save_proxy_config "socks5" "$selected_proxy"
                else
                    save_proxy_config "http" "$selected_proxy"
                fi

                apply_proxy_settings
                echo -e "${GREEN}✅ Proxy configured successfully${NC}"
            else
                echo -e "${RED}❌ Invalid selection${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  No proxies detected${NC}"
        echo -e "${BLUE}💡 You can:${NC}"
        echo -e "${GRAY}  1. Create proxy_list.txt with your proxy servers${NC}"
        echo -e "${GRAY}  2. Set environment variables (http_proxy, https_proxy)${NC}"
        echo -e "${GRAY}  3. Configure manually using options 1 or 2${NC}"
    fi

    echo ""
    read -rp "Press Enter to continue..."
}

# =============================================================================
# EXPORT FUNCTIONS
# =============================================================================

export -f proxy_menu configure_http_proxy configure_socks_proxy
export -f save_proxy_config apply_proxy_settings view_proxy_settings
export -f test_proxy_connection remove_proxy_config auto_detect_proxy

log_success "Proxy configuration menu loaded successfully"
