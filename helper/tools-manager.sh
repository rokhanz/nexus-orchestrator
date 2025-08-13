#!/bin/bash
# Author: Rokhanz
# Date: August 13, 2025
# License: MIT
# Description: Advanced tools manager - UFW, proxy, diagnostics, backup, debug

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

## advanced_tools_menu - Advanced tools submenu
advanced_tools_menu() {
    while true; do
        clear
        echo -e "${CYAN}⚙️ ADVANCED TOOLS${NC}"
        echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
        echo ""
        echo -e "${GREEN}1) 🔧 UFW Port Management${NC}"
        echo -e "${GREEN}2) 🌐 Proxy Configuration${NC}"
        echo -e "${GREEN}3) 📊 Network Diagnostics${NC}"
        echo -e "${GREEN}4) 💾 Backup/Restore Config${NC}"
        echo -e "${GREEN}5) 🧪 Debug Mode Toggle${NC}"
        echo -e "${GREEN}6) ⚡ Install Nexus CLI Direct${NC}"
        echo -e "${RED}7) 🚪 Kembali ke Main Menu${NC}"
        echo ""

        read -r -p "$(echo -e "${YELLOW}🔢 Masukkan nomor pilihan Anda [1-7]: ${NC}")" tools_choice

        case $tools_choice in
            1)
                echo -e "${CYAN}🔧 Opening UFW Port Management...${NC}"
                ufw_port_management
                ;;
            2)
                echo -e "${CYAN}🌐 Opening Proxy Configuration...${NC}"
                proxy_configuration
                ;;
            3)
                echo -e "${CYAN}📊 Opening Network Diagnostics...${NC}"
                network_diagnostics
                ;;
            4)
                echo -e "${CYAN}💾 Opening Backup/Restore Config...${NC}"
                backup_restore_config
                ;;
            5)
                echo -e "${CYAN}🧪 Opening Debug Mode Toggle...${NC}"
                debug_mode_toggle
                ;;
            6)
                echo -e "${CYAN}⚡ Opening Install Nexus CLI Direct...${NC}"
                install_nexus_cli_direct
                ;;
            7)
                echo -e "${GREEN}↩️ Kembali ke Main Menu...${NC}"
                break
                ;;
            *)
                echo -e "${RED}❌ Pilihan tidak valid. Silakan pilih nomor 1-7.${NC}"
                wait_for_keypress
                ;;
        esac
    done
}

## ufw_port_management - UFW Port Management
ufw_port_management() {
    echo -e "${CYAN}🔧 UFW PORT MANAGEMENT${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    # Check if UFW is installed
    if ! command -v ufw &> /dev/null; then
        echo -e "${RED}❌ UFW is not installed${NC}"
        echo -e "${YELLOW}Install with: sudo apt install ufw${NC}"
        echo ""
        wait_for_keypress
        return
    fi

    echo -e "${GREEN}📋 Current UFW Status:${NC}"
    sudo ufw status numbered
    echo ""

    echo -e "${WHITE}🔐 Pilih aksi UFW port management:${NC}"
    echo ""
    PS3="$(echo -e "${YELLOW}🔢 Masukkan nomor pilihan Anda: ${NC}")"
    select opt in "🔓 Open Nexus Port" "🔒 Close Nexus Port" "📋 List Nexus Ports" "🔄 Auto-configure All Nexus Ports" "🚪 Back"; do
        case $opt in
            "🔓 Open Nexus Port")
                read -r -p "$(echo -e "${YELLOW}Enter port number: ${NC}")" port
                if [[ "$port" =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
                    echo ""
                    read -r -p "$(echo -e "${YELLOW}Enter comment/description (optional): ${NC}")" comment

                    if [[ -n "$comment" ]]; then
                        sudo ufw allow "$port/tcp" comment "$comment"
                        echo -e "${GREEN}✅ Port $port opened with comment: $comment${NC}"
                    else
                        sudo ufw allow "$port/tcp" comment "Manual Nexus Port"
                        echo -e "${GREEN}✅ Port $port opened (Manual Nexus Port)${NC}"
                    fi
                else
                    echo -e "${RED}❌ Invalid port number${NC}"
                fi
                break
                ;;
            "🔒 Close Nexus Port")
                echo ""
                echo -e "${GREEN}📋 Current UFW Rules:${NC}"
                sudo ufw status numbered
                echo ""
                echo -e "${WHITE}Choose how to close port:${NC}"
                echo "1) By rule number (recommended)"
                echo "2) By port number"
                echo ""
                read -r -p "$(echo -e "${YELLOW}Enter choice (1-2): ${NC}")" close_method

                case $close_method in
                    1)
                        read -r -p "$(echo -e "${YELLOW}Enter rule number to delete: ${NC}")" rule_num
                        if [[ "$rule_num" =~ ^[0-9]+$ ]]; then
                            echo -e "${YELLOW}Deleting rule #$rule_num...${NC}"
                            if sudo ufw --force delete "$rule_num"; then
                                echo -e "${GREEN}✅ Rule #$rule_num deleted${NC}"
                            else
                                echo -e "${RED}❌ Failed to delete rule #$rule_num${NC}"
                            fi
                        else
                            echo -e "${RED}❌ Invalid rule number${NC}"
                        fi
                        ;;
                    2)
                        read -r -p "$(echo -e "${YELLOW}Enter port number: ${NC}")" port
                        if [[ "$port" =~ ^[0-9]+$ ]]; then
                            echo -e "${YELLOW}Closing port $port (IPv4 and IPv6)...${NC}"
                            local success=false

                            # Try to delete IPv4 rule
                            if sudo ufw delete allow "$port/tcp" 2>/dev/null; then
                                echo -e "${GREEN}✅ IPv4 rule for port $port deleted${NC}"
                                success=true
                            else
                                echo -e "${YELLOW}⚠️ IPv4 rule for port $port not found or already deleted${NC}"
                            fi

                            # Try to delete IPv6 rule
                            if sudo ufw delete allow "$port/tcp" 2>/dev/null; then
                                echo -e "${GREEN}✅ IPv6 rule for port $port deleted${NC}"
                                success=true
                            else
                                echo -e "${YELLOW}⚠️ IPv6 rule for port $port not found or already deleted${NC}"
                            fi

                            if [[ "$success" == "true" ]]; then
                                echo -e "${GREEN}✅ Port $port closed successfully${NC}"
                            else
                                echo -e "${RED}❌ Could not find any rules for port $port${NC}"
                            fi
                        else
                            echo -e "${RED}❌ Invalid port number${NC}"
                        fi
                        ;;
                    *)
                        echo -e "${RED}❌ Invalid choice${NC}"
                        ;;
                esac
                break
                ;;
            "📋 List Nexus Ports")
                echo -e "${GREEN}🐳 Active Nexus Container Ports:${NC}"
                docker ps --filter "name=nexus-node-" --format "table {{.Names}}\t{{.Ports}}"
                break
                ;;
            "🔄 Auto-configure All Nexus Ports")
                echo -e "${YELLOW}Configuring UFW for all running Nexus containers...${NC}"

                # Get containers with their ports
                local container_info
                container_info=$(docker ps --filter "name=nexus-node-" --format "{{.Names}}\t{{.Ports}}")

                if [[ -n "$container_info" ]]; then
                    while IFS=$'\t' read -r container_name container_ports; do
                        if [[ -n "$container_name" && -n "$container_ports" ]]; then
                            # Extract ports for this container
                            local ports
                            ports=$(echo "$container_ports" | grep -oE '0\.0\.0\.0:[0-9]+' | cut -d: -f2 | sort -u)

                            while IFS= read -r port; do
                                if [[ -n "$port" ]]; then
                                    # Add UFW rule with container name as comment
                                    sudo ufw allow "$port/tcp" comment "$container_name"
                                    echo -e "${GREEN}✅ Opened port $port for $container_name${NC}"
                                fi
                            done <<< "$ports"
                        fi
                    done <<< "$container_info"
                else
                    echo -e "${YELLOW}⚠️ No Nexus containers with ports found${NC}"
                fi
                break
                ;;
            "🚪 Back")
                return
                ;;
        esac
    done

    echo ""
    wait_for_keypress
}

## proxy_configuration - Proxy Configuration
proxy_configuration() {
    echo -e "${CYAN}🌐 PROXY CONFIGURATION${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    local proxy_file
    proxy_file="$(dirname "$(dirname "${BASH_SOURCE[0]}")")/proxy_list.txt"

    echo -e "${WHITE}🌐 Pilih aksi proxy configuration:${NC}"
    echo ""
    PS3="$(echo -e "${YELLOW}🔢 Masukkan nomor pilihan Anda: ${NC}")"
    select opt in "📝 Add Proxy" "📋 List Proxies" "❌ Remove Proxy" "🔄 Test Proxy" "🚪 Back"; do
        case $opt in
            "📝 Add Proxy")
                echo ""
                read -r -p "$(echo -e "${YELLOW}Enter proxy (format: http://user:pass@ip:port): ${NC}")" proxy

                if [[ -n "$proxy" ]]; then
                    echo "$proxy" >> "$proxy_file"
                    echo -e "${GREEN}✅ Proxy added: $proxy${NC}"
                else
                    echo -e "${RED}❌ Proxy cannot be empty${NC}"
                fi
                break
                ;;
            "📋 List Proxies")
                echo ""
                if [[ -f "$proxy_file" && -s "$proxy_file" ]]; then
                    echo -e "${GREEN}📋 Configured Proxies:${NC}"
                    nl -w2 -s') ' "$proxy_file"
                else
                    echo -e "${YELLOW}⚠️ No proxies configured${NC}"
                fi
                break
                ;;
            "❌ Remove Proxy")
                echo ""
                if [[ -f "$proxy_file" && -s "$proxy_file" ]]; then
                    echo -e "${GREEN}📋 Current Proxies:${NC}"
                    nl -w2 -s') ' "$proxy_file"
                    echo ""
                    read -r -p "$(echo -e "${YELLOW}Enter line number to remove: ${NC}")" line_num

                    if [[ "$line_num" =~ ^[0-9]+$ ]]; then
                        sed -i "${line_num}d" "$proxy_file"
                        echo -e "${GREEN}✅ Proxy removed${NC}"
                    else
                        echo -e "${RED}❌ Invalid line number${NC}"
                    fi
                else
                    echo -e "${YELLOW}⚠️ No proxies to remove${NC}"
                fi
                break
                ;;
            "🔄 Test Proxy")
                echo ""
                if [[ -f "$proxy_file" && -s "$proxy_file" ]]; then
                    echo -e "${GREEN}📋 Available Proxies:${NC}"
                    nl -w2 -s') ' "$proxy_file"
                    echo ""
                    read -r -p "$(echo -e "${YELLOW}Enter line number to test: ${NC}")" line_num

                    if [[ "$line_num" =~ ^[0-9]+$ ]]; then
                        local proxy
                        proxy=$(sed -n "${line_num}p" "$proxy_file")
                        if [[ -n "$proxy" ]]; then
                            echo -e "${YELLOW}Testing proxy: $proxy${NC}"
                            if curl --proxy "$proxy" --connect-timeout 10 -s -o /dev/null https://httpbin.org/ip; then
                                echo -e "${GREEN}✅ Proxy is working${NC}"
                            else
                                echo -e "${RED}❌ Proxy failed${NC}"
                            fi
                        else
                            echo -e "${RED}❌ Proxy not found${NC}"
                        fi
                    else
                        echo -e "${RED}❌ Invalid line number${NC}"
                    fi
                else
                    echo -e "${YELLOW}⚠️ No proxies to test${NC}"
                fi
                break
                ;;
            "🚪 Back")
                return
                ;;
        esac
    done

    echo ""
    wait_for_keypress
}

## network_diagnostics - Network Diagnostics
network_diagnostics() {
    echo -e "${CYAN}📊 NETWORK DIAGNOSTICS${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    echo -e "${GREEN}🌐 Network Information:${NC}"
    echo ""

    # Public IP
    echo -e "${YELLOW}🌍 Public IP:${NC}"
    local public_ip
    public_ip=$(curl -s --connect-timeout 5 https://ipinfo.io/ip || echo "Unable to fetch")
    echo "  $public_ip"
    echo ""

    # Network interfaces
    echo -e "${YELLOW}🔌 Network Interfaces:${NC}"
    ip addr show | grep -E '^[0-9]+:|inet ' | sed 's/^/  /'
    echo ""

    # DNS test
    echo -e "${YELLOW}🔍 DNS Test:${NC}"
    if nslookup nexus.xyz &>/dev/null; then
        echo -e "  nexus.xyz: ${GREEN}✅ OK${NC}"
    else
        echo -e "  nexus.xyz: ${RED}❌ Failed${NC}"
    fi

    if nslookup docker.io &>/dev/null; then
        echo -e "  docker.io: ${GREEN}✅ OK${NC}"
    else
        echo -e "  docker.io: ${RED}❌ Failed${NC}"
    fi
    echo ""

    # Port connectivity test
    echo -e "${YELLOW}🔗 Port Connectivity Test:${NC}"
    local test_ports=("80" "443" "22")
    for port in "${test_ports[@]}"; do
        if timeout 3 bash -c "</dev/tcp/google.com/$port" &>/dev/null; then
            echo -e "  Port $port: ${GREEN}✅ Open${NC}"
        else
            echo -e "  Port $port: ${RED}❌ Blocked${NC}"
        fi
    done
    echo ""

    # Docker network test
    echo -e "${YELLOW}🐳 Docker Network Test:${NC}"
    if docker network ls &>/dev/null; then
        echo -e "  Docker daemon: ${GREEN}✅ OK${NC}"
        local docker_networks
        docker_networks=$(docker network ls --format "{{.Name}}" | wc -l)
        echo "  Networks available: $docker_networks"
    else
        echo -e "  Docker daemon: ${RED}❌ Failed${NC}"
    fi

    echo ""
    wait_for_keypress
}

## backup_restore_config - Backup/Restore Configuration
backup_restore_config() {
    echo -e "${CYAN}🔄 BACKUP/RESTORE CONFIG${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    local backup_dir
    backup_dir="$(dirname "$(dirname "${BASH_SOURCE[0]}")")/workdir/backup"
    mkdir -p "$backup_dir"

    echo -e "${WHITE}💾 Pilih aksi backup/restore:${NC}"
    echo ""
    PS3="$(echo -e "${YELLOW}🔢 Masukkan nomor pilihan Anda: ${NC}")"
    select opt in "💾 Create Backup" "📂 List Backups" "🔄 Restore Backup" "❌ Delete Backup" "🚪 Back"; do
        case $opt in
            "💾 Create Backup")
                echo ""
                local backup_name
                local source_dir
                backup_name="nexus-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
                source_dir="$(dirname "$(dirname "${BASH_SOURCE[0]}")")/workdir"

                echo -e "${YELLOW}Creating backup: $backup_name${NC}"

                if tar -czf "$backup_dir/$backup_name" -C "$source_dir" config logs 2>/dev/null; then
                    echo -e "${GREEN}✅ Backup created: $backup_name${NC}"
                    local backup_size
                    backup_size=$(du -h "$backup_dir/$backup_name" | cut -f1)
                    echo "  Size: $backup_size"
                else
                    echo -e "${RED}❌ Backup failed${NC}"
                fi
                break
                ;;
            "📂 List Backups")
                echo ""
                if find "$backup_dir" -name "*.tar.gz" -print0 2>/dev/null | grep -qz .; then
                    echo -e "${GREEN}📂 Available Backups:${NC}"
                    find "$backup_dir" -name "*.tar.gz" -exec ls -lh {} + | awk '{print "  " $9 " (" $5 ", " $6 " " $7 " " $8 ")"}'
                else
                    echo -e "${YELLOW}⚠️ No backups found${NC}"
                fi
                break
                ;;
            "🔄 Restore Backup")
                echo ""
                if find "$backup_dir" -name "*.tar.gz" -print0 2>/dev/null | grep -qz .; then
                    echo -e "${GREEN}📂 Available Backups:${NC}"
                    local backups
                    mapfile -d '' -t backups < <(find "$backup_dir" -name "*.tar.gz" -printf '%f\0' 2>/dev/null)

                    for i in "${!backups[@]}"; do
                        echo "  $((i+1))) ${backups[i]}"
                    done
                    echo ""

                    read -r -p "$(echo -e "${YELLOW}Enter backup number to restore: ${NC}")" backup_num

                    if [[ "$backup_num" =~ ^[0-9]+$ ]] && [[ $backup_num -ge 1 ]] && [[ $backup_num -le ${#backups[@]} ]]; then
                        local selected_backup="${backups[$((backup_num-1))]}"
                        echo -e "${YELLOW}Restoring: $selected_backup${NC}"

                        # Create backup of current config before restore
                        local current_backup
                        current_backup="pre-restore-$(date +%Y%m%d-%H%M%S).tar.gz"
                        tar -czf "$backup_dir/$current_backup" -C "$(dirname "$(dirname "${BASH_SOURCE[0]}")")/workdir" config logs 2>/dev/null

                        # Restore
                        if tar -xzf "$backup_dir/$selected_backup" -C "$(dirname "$(dirname "${BASH_SOURCE[0]}")")/workdir"; then
                            echo -e "${GREEN}✅ Backup restored successfully${NC}"
                            echo -e "${YELLOW}💡 Current config backed up as: $current_backup${NC}"
                        else
                            echo -e "${RED}❌ Restore failed${NC}"
                        fi
                    else
                        echo -e "${RED}❌ Invalid backup number${NC}"
                    fi
                else
                    echo -e "${YELLOW}⚠️ No backups available${NC}"
                fi
                break
                ;;
            "❌ Delete Backup")
                echo ""
                if find "$backup_dir" -name "*.tar.gz" -print0 2>/dev/null | grep -qz .; then
                    echo -e "${GREEN}📂 Available Backups:${NC}"
                    local backups
                    mapfile -d '' -t backups < <(find "$backup_dir" -name "*.tar.gz" -printf '%f\0' 2>/dev/null)

                    for i in "${!backups[@]}"; do
                        echo "  $((i+1))) ${backups[i]}"
                    done
                    echo ""

                    read -r -p "$(echo -e "${YELLOW}Enter backup number to delete: ${NC}")" backup_num

                    if [[ "$backup_num" =~ ^[0-9]+$ ]] && [[ $backup_num -ge 1 ]] && [[ $backup_num -le ${#backups[@]} ]]; then
                        local selected_backup="${backups[$((backup_num-1))]}"
                        read -r -p "$(echo -e "${RED}Delete $selected_backup? (y/N): ${NC}")" confirm

                        if [[ "$confirm" =~ ^[Yy]$ ]]; then
                            rm "$backup_dir/$selected_backup"
                            echo -e "${GREEN}✅ Backup deleted${NC}"
                        else
                            echo -e "${YELLOW}Operation cancelled${NC}"
                        fi
                    else
                        echo -e "${RED}❌ Invalid backup number${NC}"
                    fi
                else
                    echo -e "${YELLOW}⚠️ No backups to delete${NC}"
                fi
                break
                ;;
            "🚪 Back")
                return
                ;;
        esac
    done

    echo ""
    wait_for_keypress
}

## debug_mode_toggle - Debug Mode Toggle
debug_mode_toggle() {
    echo -e "${CYAN}🧪 DEBUG MODE TOGGLE${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    local debug_file
    debug_file="$(dirname "$(dirname "${BASH_SOURCE[0]}")")/.debug_mode"

    if [[ -f "$debug_file" ]]; then
        echo -e "${GREEN}🐛 Debug mode is currently: ENABLED${NC}"
        echo ""
        read -r -p "$(echo -e "${YELLOW}Disable debug mode? (y/N): ${NC}")" choice

        if [[ "$choice" =~ ^[Yy]$ ]]; then
            rm "$debug_file"
            echo -e "${GREEN}✅ Debug mode disabled${NC}"
        fi
    else
        echo -e "${YELLOW}🐛 Debug mode is currently: DISABLED${NC}"
        echo ""
        read -r -p "$(echo -e "${YELLOW}Enable debug mode? (y/N): ${NC}")" choice

        if [[ "$choice" =~ ^[Yy]$ ]]; then
            touch "$debug_file"
            echo -e "${GREEN}✅ Debug mode enabled${NC}"
            echo ""
            echo -e "${YELLOW}Debug features:${NC}"
            echo "  - Verbose logging"
            echo "  - Extended error messages"
            echo "  - Command tracing"
            echo "  - Performance metrics"
        fi
    fi

    echo ""
    wait_for_keypress
}

## install_nexus_cli_direct - Install Nexus CLI directly to system
install_nexus_cli_direct() {
    echo -e "${CYAN}⚡ INSTALL NEXUS CLI DIRECT${NC}"
    echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
    echo ""

    echo -e "${YELLOW}🎯 OPSI B: Direct CLI Installation${NC}"
    echo -e "${GREEN}✅ Benefits:${NC}"
    echo "  • No Docker overhead during registration"
    echo "  • Faster node registration process"
    echo "  • Lightweight (only CLI binary)"
    echo "  • Better resource efficiency"
    echo ""

    # Check if already installed
    if command -v nexus-network &> /dev/null; then
        echo -e "${GREEN}✅ Nexus CLI already installed!${NC}"
        local version
        version=$(nexus-network --version 2>/dev/null || echo "unknown")
        echo -e "${YELLOW}Version: $version${NC}"
        echo ""
        read -r -p "$(echo -e "${YELLOW}Reinstall anyway? (y/N): ${NC}")" -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            wait_for_keypress
            return
        fi
    fi

    read -r -p "$(echo -e "${YELLOW}Continue with installation? (Y/n): ${NC}")" -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Installation cancelled${NC}"
        echo ""
        wait_for_keypress
        return
    fi

    echo -e "${CYAN}📥 Downloading and installing Nexus CLI...${NC}"

    # Download and install using official script
    if curl -fsSL https://cli.nexus.xyz | sh; then
        echo ""
        echo -e "${GREEN}✅ Nexus CLI installed successfully!${NC}"

        # Add to PATH if needed
        if ! command -v nexus-network &> /dev/null; then
            echo -e "${YELLOW}⚠️ Adding Nexus CLI to PATH...${NC}"
            echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.bashrc
            export PATH="$HOME/.local/bin:$PATH"
        fi

        echo -e "${GREEN}✅ Installation complete!${NC}"
        echo ""
        echo -e "${YELLOW}💡 Now you can register nodes quickly without Docker overhead!${NC}"
        echo -e "${YELLOW}💡 Go to Node Management → Register New Node for fast registration${NC}"
    else
        echo -e "${RED}❌ Failed to install Nexus CLI${NC}"
        echo -e "${YELLOW}💡 The Docker method will still work as fallback${NC}"
    fi

    echo ""
    wait_for_keypress
}
