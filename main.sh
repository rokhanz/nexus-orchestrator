#!/bin/bash

# main.sh - Nexus Orchestrator Entry Point
# Version: 4.0.0 - Intelligent zkML Infrastructure Management
# Enterprise-grade orchestration tool for Nexus zero-knowledge machine learning infrastructure

set -euo pipefail

# =============================================================================
# SCRIPT INITIALIZATION
# =============================================================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Source core libraries
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/progress.sh
source "$SCRIPT_DIR/lib/progress.sh"
# shellcheck source=lib/dependency_manager.sh
source "$SCRIPT_DIR/lib/dependency_manager.sh"

# =============================================================================
# COMMAND LINE ARGUMENTS
# =============================================================================

show_help() {
    echo "Nexus Orchestrator v4.0.0"
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -v, --version           Show version information"
    echo "  --skip-deps             Skip dependency auto-installation"
    echo "  --health-check          Run health check only"
    echo "  --dev-mode              Enable development mode (detailed errors)"
    echo "Examples:"
    echo "  $0                      Start normal interactive mode"
    echo "  $0 --skip-deps          Start without dependency check"
    echo "  $0 --health-check       Run system health check only"
    echo "  $0 --dev-mode           Enable development mode with detailed errors"
}

show_version() {
    echo "Nexus Orchestrator"
    echo "Version: 4.0.0"
    echo "Architecture: Intelligent zkML Infrastructure Management"
    echo "Build: $(date '+%Y-%m-%d')"
}

# =============================================================================
# PERMISSION MANAGEMENT
# =============================================================================

set_shell_script_permissions() {
    log_activity "Setting executable permissions for all shell scripts"

    local script_count=0
    local error_count=0

    # Find all .sh files in the project
    while IFS= read -r -d '' script_file; do
        if [[ -f "$script_file" ]]; then
            if chmod +x "$script_file" 2>/dev/null; then
                script_count=$((script_count + 1))
                log_debug "Set executable permission: $script_file"
            else
                error_count=$((error_count + 1))
                log_warning "Failed to set permission: $script_file"
            fi
        fi
    done < <(find "$SCRIPT_DIR" -name "*.sh" -type f -print0)

    if [[ $error_count -eq 0 ]]; then
        log_success "Set executable permissions for $script_count shell scripts"
        return 0
    else
        log_warning "Set permissions for $script_count scripts, $error_count failed"
        return 1
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local skip_deps=false
    local health_only=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            --skip-deps)
                skip_deps=true
                shift
                ;;
            --health-check)
                health_only=true
                shift
                ;;
            --dev-mode)
                export DEV_MODE=true
                echo -e "${YELLOW}Development mode enabled - detailed errors will be shown${NC}"
                shift
                ;;
            *)
                echo -e "${RED}❌ Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Show banner
    show_banner

    # Handle special modes
    if [[ "$health_only" == true ]]; then
        echo -e "${CYAN}Running health check only...${NC}"
        echo ""
        if ensure_dependencies "true"; then
            log_success "Health check passed"
            exit 0
        else
            log_error "Health check failed"
            exit 1
        fi
    fi

    # Normal startup sequence with dependency management
    log_activity "Starting Nexus Orchestrator v4.0.0"

    if [[ "$skip_deps" != true ]]; then
        echo -e "${CYAN}🔍 Checking and installing dependencies...${NC}"
        echo ""

        if ! ensure_dependencies; then
            echo ""
            echo -e "${RED}❌ Dependency check failed${NC}"
            echo -e "${YELLOW}💡 Please resolve dependency issues and restart${NC}"
            echo ""
            exit 1
        fi

        # Set executable permissions for all shell scripts
        echo ""
        set_shell_script_permissions
    fi

    echo ""
    log_success "System ready! Starting main menu..."
    sleep 1

    # Load menu modules
    source "$SCRIPT_DIR/lib/menus/setup_menu.sh"
    source "$SCRIPT_DIR/lib/menus/manage_menu.sh"

    # Start main interactive menu
    show_main_menu
}

# =============================================================================
# MAIN MENU SYSTEM
# =============================================================================

show_main_menu() {
    while true; do
        clear
        show_banner

        echo -e "${CYAN}${BOLD}🎛️  NEXUS ORCHESTRATOR MAIN MENU${NC}"
        echo -e "${CYAN}════════════════════════════════════════════${NC}"
        echo ""

        # Check if credentials are configured
        local wallet_configured=false
        local node_configured=false
        local docker_configured=false

        if [[ -f "$CREDENTIALS_FILE" ]]; then
            local wallet_address
            wallet_address=$(read_config_value "wallet_address" 2>/dev/null)
            if [[ -n "$wallet_address" && "$wallet_address" != "null" ]]; then
                wallet_configured=true
            fi

            # Check for node_id array
            local node_count
            node_count=$(read_config_value "node_id" 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
            if [[ "$node_count" -gt 0 ]]; then
                node_configured=true
            fi
        fi

        # Check if Docker configuration exists
        if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
            docker_configured=true
        fi
        # Note: docker_configured is used below in menu option 2 validation

        # Display status
        echo -e "${PURPLE}${BOLD}📊 System Status:${NC}"
        if [[ "$wallet_configured" == true ]]; then
            echo -e "  ${GREEN}✅ Wallet Address:${NC} ${CYAN}Configured${NC}"
        else
            echo -e "  ${RED}❌ Wallet Address:${NC} ${YELLOW}Not configured${NC}"
        fi

        if [[ "$node_configured" == true ]]; then
            local node_count
            node_count=$(read_config_value "node_id" 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
            echo -e "  ${GREEN}✅ Node ID:${NC} ${CYAN}$node_count node(s) configured${NC}"
        else
            echo -e "  ${RED}❌ Node ID:${NC} ${YELLOW}Not configured${NC}"
        fi

        if [[ "$docker_configured" == true ]]; then
            echo -e "  ${GREEN}✅ Docker Config:${NC} ${CYAN}Generated${NC}"
        else
            echo -e "  ${RED}❌ Docker Config:${NC} ${YELLOW}Not generated${NC}"
        fi
        echo ""

        # Menu options
        echo -e "${YELLOW}${BOLD}📋 Available Options:${NC}"
        echo -e "  ${GREEN}1.${NC} ${CYAN}🔧 Initial Setup & Configuration${NC}"
        echo -e "  ${GREEN}2.${NC} ${CYAN}🎮 Nexus Management (Start/Stop/Monitor)${NC}"
        echo -e "  ${GREEN}3.${NC} ${CYAN}📊 View System Logs${NC}"
        echo -e "  ${GREEN}4.${NC} ${CYAN}🗑️  System Uninstall & Cleanup${NC}"
        echo -e "  ${GREEN}5.${NC} ${CYAN}❓ Help & Documentation${NC}"
        echo -e "  ${GREEN}0.${NC} ${RED}🚪 Exit${NC}"
        echo ""

        read -rp "$(echo -e "${PURPLE}${BOLD}Select option [0-5]:${NC} ")" choice

        case "$choice" in
            1)
                clear
                setup_menu
                ;;
            2)
                if [[ "$wallet_configured" == false || "$node_configured" == false || "$docker_configured" == false ]]; then
                    echo ""
                    echo -e "${RED}${BOLD}❌ Please complete setup first (option 1)${NC}"
                    if [[ "$wallet_configured" == false ]]; then
                        echo -e "${YELLOW}   • Configure wallet address${NC}"
                    fi
                    if [[ "$node_configured" == false ]]; then
                        echo -e "${YELLOW}   • Setup Node ID(s)${NC}"
                    fi
                    if [[ "$docker_configured" == false ]]; then
                        echo -e "${YELLOW}   • Generate Docker configuration${NC}"
                    fi
                    echo ""
                    read -rp "$(echo -e "${YELLOW}Press Enter to continue...${NC}")"
                else
                    clear
                    source "$SCRIPT_DIR/lib/menus/manage_menu.sh"
                    manage_menu
                fi
                ;;
            3)
                clear
                source "$SCRIPT_DIR/lib/logging.sh"
                view_logs_interactive
                ;;
            4)
                clear
                source "$SCRIPT_DIR/lib/menus/uninstall_menu.sh"
                uninstall_menu
                ;;
            5)
                clear
                show_help_menu
                ;;
            0)
                echo ""
                echo -e "${GREEN}Thank you for using Nexus Orchestrator v4.0!${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option. Please select 0-5.${NC}"
                sleep 2
                ;;
        esac
    done
}

# =============================================================================
# HELP MENU
# =============================================================================

show_help_menu() {
    clear
    show_section_header "Help & Documentation" "❓"

    echo -e "${CYAN}Nexus Orchestrator v4.0.0 Help${NC}"
    echo ""
    echo -e "${YELLOW}Getting Started:${NC}"
    echo "  1. Run Initial Setup (Option 1) to configure system dependencies and credentials"
    echo "  2. Use Nexus Management (Option 2) to start/stop/monitor services"
    echo ""
    echo -e "${YELLOW}Configuration:${NC}"
    echo "  • All wallet and Node ID configuration is done through Initial Setup"
    echo "  • Multiple Node IDs supported for managing multiple nodes"
    echo "  • Management menu provides additional configuration options"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "  • Check logs (Option 4) for detailed error information"
    echo "  • Use --health-check flag for system diagnostics"
    echo "  • Use --skip-deps flag to bypass dependency checks"
    echo ""

    read -rp "Press Enter to return to main menu..."
}

# =============================================================================
# FUNCTION EXPORTS
# =============================================================================

# Export functions
export -f show_main_menu show_help_menu

# Execute main function with all arguments
main "$@"
