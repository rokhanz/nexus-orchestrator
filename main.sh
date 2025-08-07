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
    echo "  --skip-permissions      Skip permission check"
    echo "  --health-check          Run health check only"
    echo "  --dev-mode              Enable development mode (detailed errors)"
    echo "Examples:"
    echo "  $0                      Start normal interactive mode"
    echo "  $0 --skip-deps          Start without dependency check"
    echo "  $0 --skip-permissions   Start without permission check"
    echo "  $0 --health-check       Run system health check only"
    echo "  $0 --dev-mode           Enable development mode with detailed errors"
}

show_version() {
    echo "Nexus Orchestrator"
    echo "Version: 4.0.0"
    echo "Architecture: Intelligent zkML Infrastructure Management"
    echo "Build: $(date '+%Y-%m-%d')"
}

main() {
    local skip_deps=false
    local skip_permissions=false
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
            --skip-permissions)
                skip_permissions=true
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

    # Simple startup - check dependencies if not skipping
    if [[ "$skip_deps" == false ]]; then
        if ensure_dependencies "false"; then
            echo ""
            echo -e "${GREEN}${BOLD}✅ All dependencies are satisfied!${NC}"
        else
            echo ""
            echo -e "${RED}${BOLD}❌ Some dependencies need attention${NC}"
        fi
        echo ""
    fi

    # Load menu modules
    source "$SCRIPT_DIR/lib/menus/setup_menu.sh"
    source "$SCRIPT_DIR/lib/menus/manage_menu.sh"

    # Check permissions before starting (unless skipped)
    if [[ "$skip_permissions" == false ]]; then
        check_permissions
    else
        echo -e "${YELLOW}⚠️  Permission check skipped${NC}"
        echo ""
    fi

    # Start main interactive menu
    show_main_menu
}

# =============================================================================
# PERMISSION CHECK FUNCTIONS
# =============================================================================

check_permissions() {
    echo -e "${CYAN}${BOLD}🔐 Permission Check${NC}"
    echo -e "${CYAN}$(printf '%.0s─' {1..50})${NC}"
    echo ""

    local permission_ok=true

    # Check if running as root or with sudo
    if [[ $EUID -eq 0 ]]; then
        echo -e "${GREEN}✅ Running with root privileges${NC}"
    else
        echo -e "${YELLOW}⚠️  Running as regular user: $(whoami)${NC}"

        # Check if user has sudo access
        if sudo -n true 2>/dev/null; then
            echo -e "${GREEN}✅ User has sudo privileges${NC}"
        else
            echo -e "${RED}❌ User does not have sudo privileges${NC}"
            echo -e "${YELLOW}💡 Some operations may require elevated permissions${NC}"
            permission_ok=false
        fi
    fi

    # Check Docker permissions
    if command -v docker >/dev/null 2>&1; then
        if docker ps >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Docker access available${NC}"
        else
            echo -e "${YELLOW}⚠️  Docker daemon access limited${NC}"
            if [[ $EUID -ne 0 ]]; then
                echo -e "${BLUE}💡 Consider adding user to docker group: sudo usermod -aG docker $(whoami)${NC}"
            fi
        fi
    fi

    # Check file system permissions for working directory
    local workdir="${DEFAULT_WORKDIR:-/root/nexus-orchestrator/workdir}"
    if [[ -w "$(dirname "$workdir")" ]] || [[ -w "$workdir" ]] 2>/dev/null; then
        echo -e "${GREEN}✅ Working directory permissions OK${NC}"
    else
        echo -e "${YELLOW}⚠️  Limited write access to working directory${NC}"
        echo -e "${BLUE}💡 Working directory: $workdir${NC}"
    fi

    # Check systemctl permissions (for Docker service management)
    if systemctl status docker >/dev/null 2>&1; then
        echo -e "${GREEN}✅ System service management available${NC}"
    else
        if [[ $EUID -ne 0 ]]; then
            echo -e "${YELLOW}⚠️  Limited system service management${NC}"
        fi
    fi

    # Check UFW firewall permissions
    if command -v ufw >/dev/null 2>&1; then
        if ufw status >/dev/null 2>&1; then
            echo -e "${GREEN}✅ UFW firewall management available${NC}"
        else
            echo -e "${YELLOW}⚠️  Limited UFW firewall access${NC}"
            echo -e "${BLUE}💡 Port management features may require elevated permissions${NC}"
        fi
    fi

    # Check network interface access (for proxy detection)
    if ip addr show >/dev/null 2>&1 || ifconfig >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Network interface access available${NC}"
    else
        echo -e "${YELLOW}⚠️  Limited network interface access${NC}"
        echo -e "${BLUE}💡 Proxy auto-detection may be limited${NC}"
    fi

    echo ""

    if [[ "$permission_ok" == true ]] || [[ $EUID -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✅ Permission check completed - Ready to proceed${NC}"
    else
        echo -e "${YELLOW}${BOLD}⚠️  Permission check completed with warnings${NC}"
        echo -e "${CYAN}   Some features may require additional permissions${NC}"
        echo ""

        read -rp "$(echo -e "${YELLOW}Continue anyway? [y/N]: ${NC}")" continue_choice
        if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${CYAN}💡 To resolve permission issues:${NC}"
            echo -e "   1. Run as root: ${WHITE}sudo $0${NC}"
            echo -e "   2. Add user to docker group: ${WHITE}sudo usermod -aG docker $(whoami)${NC}"
            echo -e "   3. Logout and login again to apply group changes${NC}"
            echo ""
            exit 0
        fi
    fi

    echo ""
}

# =============================================================================
# MAIN MENU FUNCTIONS
# =============================================================================

show_main_menu() {
    while true; do
        clear
        show_banner

        echo -e "${CYAN}${BOLD}🎛️  NEXUS ORCHESTRATOR MAIN MENU${NC}"
        echo -e "${CYAN}════════════════════════════════════════════${NC}"
        echo ""

        # Menu options
        echo -e "${YELLOW}${BOLD}🎯 Available Options:${NC}"
        echo -e "  ${GREEN}1.${NC} ${CYAN}🔧 Initial Setup & Configuration${NC}"
        echo -e "  ${GREEN}2.${NC} ${CYAN}🎮 Nexus Management (Start/Stop/Monitor)${NC}"
        echo -e "  ${GREEN}3.${NC} ${CYAN}🌐 Proxy Configuration${NC}"
        echo -e "  ${GREEN}4.${NC} ${CYAN} View System Logs${NC}"
        echo -e "  ${GREEN}5.${NC} ${CYAN}🗑️  System Uninstall & Cleanup${NC}"
        echo -e "  ${GREEN}6.${NC} ${CYAN}❓ Help & Documentation${NC}"
        echo -e "  ${GREEN}0.${NC} ${RED}🚪 Exit${NC}"
        echo ""

        read -rp "$(echo -e "${PURPLE}${BOLD}Select option [0-6]:${NC} ")" choice

        case "$choice" in
            1)
                clear
                source "$SCRIPT_DIR/lib/menus/setup_menu.sh"
                setup_menu
                ;;
            2)
                clear
                source "$SCRIPT_DIR/lib/menus/manage_menu.sh"
                manage_menu
                ;;
            3)
                clear
                source "$SCRIPT_DIR/lib/menus/proxy_menu.sh"
                proxy_menu
                ;;
            4)
                clear
                source "$SCRIPT_DIR/lib/menus/manage_menu.sh"
                view_node_logs
                ;;
            5)
                clear
                source "$SCRIPT_DIR/lib/menus/uninstall_menu.sh"
                uninstall_menu
                ;;
            6)
                show_help_menu
                ;;
            0)
                echo ""
                echo -e "${GREEN}Thank you for using Nexus Orchestrator v4.0!${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option. Please select 0-7.${NC}"
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
    echo "  • Check logs (Option 5) for detailed error information"
    echo "  • Use --health-check flag for system diagnostics"
    echo "  • Use --skip-deps flag to bypass dependency checks"
    echo ""

    read -rp "Press Enter to return to main menu..."
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Execute main function with all arguments
main "$@"
