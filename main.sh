#!/bin/bash
# Author: Rokhanz
# Date: August 13, 2025
# License: MIT
# Description: Main entry point for Nexus Orchestrator - Clean modular routing only

set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/helper/common.sh"

## show_banner - Display main banner
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"

  ██████╗  ██████╗ ██╗  ██╗██╗  ██╗ █████╗ ███╗   ██╗███████╗
  ██╔══██╗██╔═══██╗██║ ██╔╝██║  ██║██╔══██╗████╗  ██║╚══███╔╝
  ██████╔╝██║   ██║█████╔╝ ███████║███████║██╔██╗ ██║  ███╔╝
  ██╔══██╗██║   ██║██╔═██╗ ██╔══██║██╔══██║██║╚██╗██║ ███╔╝
  ██║  ██║╚██████╔╝██║  ██╗██║  ██║██║  ██║██║ ╚████║███████╗
  ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝

EOF
    echo -e "${NC}${LIGHT_GREEN}        🚀 NEXUS ORCHESTRATOR - Modular Architecture${NC}"
    echo -e "${YELLOW}        Working Directory: $(pwd)${NC}"
    echo ""
}

## show_how_to_use - Display comprehensive usage guide
show_how_to_use() {
    while true; do
        clear
        echo -e "${CYAN}📚 HOW TO USE NEXUS ORCHESTRATOR${NC}"
        echo -e "${LIGHT_BLUE}══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${YELLOW}🚀 Welcome to the comprehensive usage guide!${NC}"
        echo ""
        echo -e "${WHITE}📋 Available Sections:${NC}"
        echo ""
        echo -e "${GREEN}1) 🎯 Quick Start Guide${NC}"
        echo -e "${GREEN}2) 🔧 Docker & System Management${NC}"
        echo -e "${GREEN}3) 📊 Monitoring & Logs${NC}"
        echo -e "${GREEN}4) 🌐 Node Management${NC}"
        echo -e "${GREEN}5) 🔑 Wallet Management${NC}"
        echo -e "${GREEN}6) ⚙️  Advanced Tools${NC}"
        echo -e "${GREEN}7) 🔍 Troubleshooting${NC}"
        echo -e "${GREEN}8) 💡 Tips & Best Practices${NC}"
        echo -e "${RED}9) 🚪 Back to Main Menu${NC}"
        echo ""

        read -r -p "$(echo -e "${YELLOW}🔢 Select section [1-9]: ${NC}")" section

        case $section in
            1) show_quick_start_guide ;;
            2) show_docker_system_guide ;;
            3) show_monitoring_guide ;;
            4) show_node_management_guide ;;
            5) show_wallet_guide ;;
            6) show_advanced_tools_guide ;;
            7) show_troubleshooting_guide ;;
            8) show_tips_guide ;;
            9) return ;;
            *)
                echo -e "${RED}❌ Invalid selection. Please choose 1-9.${NC}"
                wait_for_keypress
                ;;
        esac
    done
}

## show_quick_start_guide - Quick start instructions
show_quick_start_guide() {
    clear
    echo -e "${CYAN}🎯 QUICK START GUIDE${NC}"
    echo -e "${LIGHT_BLUE}══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Welcome to Nexus Orchestrator! Let's get you started quickly:${NC}"
    echo ""
    echo -e "${WHITE}📋 Step-by-Step Setup:${NC}"
    echo ""
    echo -e "${GREEN}1. 🔧 First-Time Setup:${NC}"
    echo "   • Dependencies are auto-checked on startup"
    echo "   • Docker and Docker Compose will be installed if missing"
    echo "   • All required packages are configured automatically"
    echo ""
    echo -e "${GREEN}2. 🔑 Wallet Setup:${NC}"
    echo "   • Go to 'Wallet & Account Management' (Option 3)"
    echo "   • Choose 'Create New Wallet' if you don't have one"
    echo "   • Or 'Import Existing Wallet' if you have credentials"
    echo "   • Save your wallet securely!"
    echo ""
    echo -e "${GREEN}3. 🌐 Node Registration:${NC}"
    echo "   • Go to 'Node Management' (Option 4)"
    echo "   • Choose 'Register New Node' for first-time setup"
    echo "   • Follow the prompts to register your node"
    echo "   • Note down your Node ID for future reference"
    echo ""
    echo -e "${GREEN}4. 🚀 Start Mining:${NC}"
    echo "   • Use 'Start with Existing Node ID' in Node Management"
    echo "   • Your node will start automatically"
    echo "   • Monitor progress in 'Monitor Logs' (Option 2)"
    echo ""
    echo -e "${YELLOW}⚡ Quick Commands:${NC}"
    echo -e "${CYAN}   • main.sh${NC} - Run from /root/nexus-orchestrator/"
    echo -e "${CYAN}   • sudo bash main.sh${NC} - If permissions needed"
    echo ""
    echo -e "${RED}⚠️  Important Notes:${NC}"
    echo "   • Always run from /root/nexus-orchestrator/ directory"
    echo "   • Keep your wallet credentials secure"
    echo "   • Monitor logs regularly for issues"
    echo "   • Use 'Advanced Tools' for system optimization"
    echo ""

    wait_for_keypress
}

## show_docker_system_guide - Docker & System management guide
show_docker_system_guide() {
    clear
    echo -e "${CYAN}🔧 DOCKER & SYSTEM MANAGEMENT${NC}"
    echo -e "${LIGHT_BLUE}══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${WHITE}🐳 Docker Management Features:${NC}"
    echo ""
    echo -e "${GREEN}1. 🐳 Docker Status & Health Check:${NC}"
    echo "   • Comprehensive system health analysis"
    echo "   • Docker daemon status verification"
    echo "   • Container health monitoring"
    echo "   • Resource usage statistics"
    echo ""
    echo -e "${GREEN}2. 🔄 Restart All Containers:${NC}"
    echo "   • Safe restart of all Nexus containers"
    echo "   • Preserves container data and configuration"
    echo "   • Useful for applying updates or fixing issues"
    echo ""
    echo -e "${GREEN}3. 🧹 Clean Unused Images/Volumes:${NC}"
    echo "   • Removes unused Docker images"
    echo "   • Cleans up unused volumes"
    echo "   • Frees up disk space"
    echo "   • Safe cleanup - preserves active containers"
    echo ""
    echo -e "${GREEN}4. 📦 Update Docker Compose:${NC}"
    echo "   • Regenerate docker-compose.yml from saved nodes"
    echo "   • Update container configurations"
    echo "   • View current compose content"
    echo "   • Preserve working settings"
    echo ""
    echo -e "${GREEN}5. 🔧 System Resources Monitor:${NC}"
    echo "   • Real-time system resource monitoring"
    echo "   • CPU, memory, and disk usage"
    echo "   • Docker container statistics"
    echo "   • Network and volume information"
    echo ""
    echo -e "${YELLOW}💡 Best Practices:${NC}"
    echo "   • Run health checks regularly"
    echo "   • Clean unused resources weekly"
    echo "   • Monitor resource usage"
    echo "   • Restart containers if issues persist"
    echo ""

    wait_for_keypress
}

## show_monitoring_guide - Monitoring & logs guide
show_monitoring_guide() {
    clear
    echo -e "${CYAN}📊 MONITORING & LOGS${NC}"
    echo -e "${LIGHT_BLUE}══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${WHITE}📈 Monitoring Features:${NC}"
    echo ""
    echo -e "${GREEN}1. 🎯 Monitor Specific Node:${NC}"
    echo "   • Real-time log monitoring for individual nodes"
    echo "   • 10-second auto-refresh"
    echo "   • Shows proving tasks, submissions, and status"
    echo "   • Press 'q' to exit, 'r' to force refresh"
    echo ""
    echo -e "${GREEN}2. 📡 Monitor All Nodes (Real-time):${NC}"
    echo "   • Dashboard view of all running nodes"
    echo "   • 15-second refresh cycle"
    echo "   • Shows latest activity from each container"
    echo "   • Perfect for multi-node setups"
    echo ""
    echo -e "${GREEN}3. 📈 Show Success Statistics:${NC}"
    echo "   • Success rate calculation per node"
    echo "   • Total success vs error counts"
    echo "   • Overall system performance metrics"
    echo "   • Helps identify problem nodes"
    echo ""
    echo -e "${GREEN}4. ⚠️ Analyze Error Logs:${NC}"
    echo "   • Detailed error analysis"
    echo "   • Common error patterns identification"
    echo "   • Suggested solutions for each error type"
    echo "   • Troubleshooting recommendations"
    echo ""
    echo -e "${GREEN}5. 📊 Show Performance Metrics:${NC}"
    echo "   • System resource utilization"
    echo "   • Container performance statistics"
    echo "   • Network and disk usage"
    echo "   • Docker volume information"
    echo ""
    echo -e "${YELLOW}🔍 Understanding Logs:${NC}"
    echo "   • Success: ✅ Task completed, points earned"
    echo "   • Waiting: ⏳ Rate limited or processing"
    echo "   • Refresh: 🔄 Requesting new tasks"
    echo "   • Error: ❌ Failed submission or connection"
    echo ""

    wait_for_keypress
}

## show_node_management_guide - Node management guide
show_node_management_guide() {
    clear
    echo -e "${CYAN}🌐 NODE MANAGEMENT${NC}"
    echo -e "${LIGHT_BLUE}══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${WHITE}🚀 Node Management Features:${NC}"
    echo ""
    echo -e "${GREEN}1. 🚀 Start with Existing Node ID:${NC}"
    echo "   • Start a previously registered node"
    echo "   • Uses saved node credentials"
    echo "   • Automatically configures Docker container"
    echo "   • Supports proxy configuration"
    echo ""
    echo -e "${GREEN}2. 📝 Register New Node:${NC}"
    echo "   • Register a brand new node with Nexus"
    echo "   • Requires valid wallet credentials"
    echo "   • Generates unique node ID"
    echo "   • Saves configuration for future use"
    echo ""
    echo -e "${GREEN}3. 🔄 Re-register Existing Wallet:${NC}"
    echo "   • Re-register using existing wallet"
    echo "   • Useful if node ID is lost or corrupted"
    echo "   • Creates new node association"
    echo "   • Preserves wallet balance and history"
    echo ""
    echo -e "${GREEN}4. 🔄 Multi-Node Manager:${NC}"
    echo "   • Manage multiple nodes simultaneously"
    echo "   • Start/stop individual or all nodes"
    echo "   • Bulk operations for efficiency"
    echo "   • Resource monitoring across nodes"
    echo ""
    echo -e "${GREEN}5. 📊 Node Statistics:${NC}"
    echo "   • Comprehensive node performance overview"
    echo "   • Container resource usage"
    echo "   • Health check results"
    echo "   • Network connectivity status"
    echo ""
    echo -e "${GREEN}6. 🔍 Nexus Version Info:${NC}"
    echo "   • Current Nexus CLI version"
    echo "   • Docker image information"
    echo "   • System compatibility check"
    echo "   • Update availability status"
    echo ""
    echo -e "${YELLOW}💡 Node Management Tips:${NC}"
    echo "   • Use Multi-Node Manager for bulk operations"
    echo "   • Monitor statistics regularly"
    echo "   • Keep node configurations backed up"
    echo "   • Use proxy if needed for rate limiting"
    echo ""

    wait_for_keypress
}

## show_wallet_guide - Wallet management guide
show_wallet_guide() {
    clear
    echo -e "${CYAN}🔑 WALLET MANAGEMENT${NC}"
    echo -e "${LIGHT_BLUE}══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${WHITE}💳 Wallet Management Features:${NC}"
    echo ""
    echo -e "${GREEN}1. 💼 Create New Wallet:${NC}"
    echo "   • Generate brand new Nexus wallet"
    echo "   • Creates public/private key pair"
    echo "   • Generates recovery phrase"
    echo "   • Saves credentials securely"
    echo ""
    echo -e "${GREEN}2. 📂 Import Existing Wallet:${NC}"
    echo "   • Import wallet from recovery phrase"
    echo "   • Import from private key"
    echo "   • Restore from backup file"
    echo "   • Validates credentials during import"
    echo ""
    echo -e "${GREEN}3. 📋 Show Wallet Info:${NC}"
    echo "   • Display wallet address"
    echo "   • Show account balance"
    echo "   • View transaction history"
    echo "   • Network connection status"
    echo ""
    echo -e "${GREEN}4. 💾 Backup Wallet:${NC}"
    echo "   • Create encrypted backup files"
    echo "   • Export recovery phrases"
    echo "   • Save to secure locations"
    echo "   • Timestamp all backups"
    echo ""
    echo -e "${GREEN}5. 🔐 Change Wallet Password:${NC}"
    echo "   • Update wallet encryption password"
    echo "   • Secure existing credentials"
    echo "   • Verify old password before change"
    echo "   • Re-encrypt all wallet data"
    echo ""
    echo -e "${RED}🔒 Security Best Practices:${NC}"
    echo "   • NEVER share your private key or recovery phrase"
    echo "   • Always backup your wallet after creation"
    echo "   • Use strong, unique passwords"
    echo "   • Store backups in multiple secure locations"
    echo "   • Regularly verify backup integrity"
    echo ""
    echo -e "${YELLOW}📁 Wallet File Locations:${NC}"
    echo "   • Credentials: /root/nexus-orchestrator/workdir/credentials.json"
    echo "   • Backups: /root/nexus-orchestrator/workdir/backup/"
    echo "   • Logs: /root/nexus-orchestrator/workdir/nexus-manager.log"
    echo ""

    wait_for_keypress
}

## show_advanced_tools_guide - Advanced tools guide
show_advanced_tools_guide() {
    clear
    echo -e "${CYAN}⚙️ ADVANCED TOOLS${NC}"
    echo -e "${LIGHT_BLUE}══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${WHITE}🛠️ Advanced Tools Features:${NC}"
    echo ""
    echo -e "${GREEN}1. 🔧 UFW Port Management:${NC}"
    echo "   • Open/close firewall ports"
    echo "   • Manage IPv4 and IPv6 rules simultaneously"
    echo "   • Auto-configure ports for Nexus nodes"
    echo "   • List active port configurations"
    echo "   • Safe rule deletion by number or port"
    echo ""
    echo -e "${GREEN}2. 🌐 Proxy Configuration:${NC}"
    echo "   • Add/remove proxy servers"
    echo "   • Test proxy connectivity"
    echo "   • Multiple proxy support"
    echo "   • Automatic proxy rotation"
    echo "   • Format: http://user:pass@ip:port"
    echo ""
    echo -e "${GREEN}3. 📊 Network Diagnostics:${NC}"
    echo "   • Public IP detection"
    echo "   • Network interface analysis"
    echo "   • DNS resolution testing"
    echo "   • Port connectivity checks"
    echo "   • Docker network validation"
    echo ""
    echo -e "${GREEN}4. 💾 Backup/Restore Config:${NC}"
    echo "   • Full system configuration backup"
    echo "   • Wallet and node data preservation"
    echo "   • Docker compose backup"
    echo "   • Restore from previous backups"
    echo "   • Scheduled backup support"
    echo ""
    echo -e "${GREEN}5. 🧪 Debug Mode Toggle:${NC}"
    echo "   • Enable/disable verbose logging"
    echo "   • Extended error messages"
    echo "   • Command tracing for troubleshooting"
    echo "   • Performance metric collection"
    echo "   • Development debugging features"
    echo ""
    echo -e "${GREEN}6. ⚡ Install Nexus CLI Direct:${NC}"
    echo "   • Direct Nexus CLI installation"
    echo "   • Bypass Docker if preferred"
    echo "   • Native binary installation"
    echo "   • System integration setup"
    echo "   • Performance optimization"
    echo ""
    echo -e "${YELLOW}🔧 UFW Port Management Details:${NC}"
    echo "   • When closing ports by number: IPv4 and IPv6 rules deleted together"
    echo "   • Rule numbers change after deletion (always check current status)"
    echo "   • Auto-configure detects running containers and opens required ports"
    echo "   • Port ranges supported for bulk operations"
    echo ""

    wait_for_keypress
}

## show_troubleshooting_guide - Troubleshooting guide
show_troubleshooting_guide() {
    clear
    echo -e "${CYAN}🔍 TROUBLESHOOTING${NC}"
    echo -e "${LIGHT_BLUE}══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${WHITE}🚨 Common Issues & Solutions:${NC}"
    echo ""
    echo -e "${RED}❌ Issue: Docker daemon not running${NC}"
    echo -e "${GREEN}✅ Solution:${NC}"
    echo "   • sudo systemctl start docker"
    echo "   • sudo systemctl enable docker"
    echo "   • Check: sudo systemctl status docker"
    echo ""
    echo -e "${RED}❌ Issue: Permission denied errors${NC}"
    echo -e "${GREEN}✅ Solution:${NC}"
    echo "   • Run with sudo: sudo bash main.sh"
    echo "   • Add user to docker group: sudo usermod -aG docker \$USER"
    echo "   • Logout and login again"
    echo ""
    echo -e "${RED}❌ Issue: Node fails to register${NC}"
    echo -e "${GREEN}✅ Solution:${NC}"
    echo "   • Check internet connectivity"
    echo "   • Verify wallet credentials"
    echo "   • Try different proxy if using one"
    echo "   • Check Nexus network status"
    echo ""
    echo -e "${RED}❌ Issue: Container keeps restarting${NC}"
    echo -e "${GREEN}✅ Solution:${NC}"
    echo "   • Check logs: Monitor Logs → Monitor Specific Node"
    echo "   • Verify system resources (CPU, RAM)"
    echo "   • Check Docker container limits"
    echo "   • Restart Docker service"
    echo ""
    echo -e "${RED}❌ Issue: Rate limiting errors${NC}"
    echo -e "${GREEN}✅ Solution:${NC}"
    echo "   • Configure proxy in Advanced Tools"
    echo "   • Wait for rate limit to reset"
    echo "   • Use different IP/proxy server"
    echo "   • Monitor timing between requests"
    echo ""
    echo -e "${RED}❌ Issue: Wallet import fails${NC}"
    echo -e "${GREEN}✅ Solution:${NC}"
    echo "   • Verify recovery phrase format (12/24 words)"
    echo "   • Check private key format (hex)"
    echo "   • Ensure proper wallet type compatibility"
    echo "   • Try re-typing credentials manually"
    echo ""
    echo -e "${YELLOW}🔧 Diagnostic Commands:${NC}"
    echo "   • docker ps -a (show all containers)"
    echo "   • docker logs nexus-node-[ID] (view container logs)"
    echo "   • sudo ufw status (check firewall)"
    echo "   • df -h (check disk space)"
    echo "   • free -h (check memory usage)"
    echo ""

    wait_for_keypress
}

## show_tips_guide - Tips & best practices guide
show_tips_guide() {
    clear
    echo -e "${CYAN}💡 TIPS & BEST PRACTICES${NC}"
    echo -e "${LIGHT_BLUE}══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${WHITE}🏆 Performance Optimization:${NC}"
    echo ""
    echo -e "${GREEN}🚀 System Performance:${NC}"
    echo "   • Keep at least 20% disk space free"
    echo "   • Monitor memory usage (keep below 80%)"
    echo "   • Use SSD storage for better I/O performance"
    echo "   • Regular system updates and reboots"
    echo ""
    echo -e "${GREEN}🐳 Docker Optimization:${NC}"
    echo "   • Clean unused images weekly"
    echo "   • Limit container memory if needed"
    echo "   • Use docker system prune monthly"
    echo "   • Monitor container logs size"
    echo ""
    echo -e "${GREEN}🌐 Network Optimization:${NC}"
    echo "   • Use proxy for rate limiting avoidance"
    echo "   • Rotate proxies if available"
    echo "   • Monitor network latency"
    echo "   • Open required ports in firewall"
    echo ""
    echo -e "${WHITE}🔒 Security Best Practices:${NC}"
    echo ""
    echo -e "${GREEN}🛡️ System Security:${NC}"
    echo "   • Regular security updates"
    echo "   • Use UFW firewall properly"
    echo "   • Limit SSH access if remote"
    echo "   • Monitor system logs for intrusions"
    echo ""
    echo -e "${GREEN}💳 Wallet Security:${NC}"
    echo "   • NEVER share private keys or recovery phrases"
    echo "   • Use strong, unique passwords"
    echo "   • Regular backup to multiple locations"
    echo "   • Encrypt backup files"
    echo "   • Test backup restoration periodically"
    echo ""
    echo -e "${WHITE}📊 Monitoring & Maintenance:${NC}"
    echo ""
    echo -e "${GREEN}📈 Regular Monitoring:${NC}"
    echo "   • Check success rates daily"
    echo "   • Monitor error logs for patterns"
    echo "   • Review system resource usage"
    echo "   • Verify node synchronization"
    echo ""
    echo -e "${GREEN}🔧 Maintenance Schedule:${NC}"
    echo "   • Daily: Check node status and logs"
    echo "   • Weekly: Clean Docker resources, backup wallet"
    echo "   • Monthly: System updates, log rotation"
    echo "   • Quarterly: Full system backup and testing"
    echo ""
    echo -e "${YELLOW}⚡ Pro Tips:${NC}"
    echo "   • Use screen/tmux for persistent sessions"
    echo "   • Set up log rotation to prevent disk issues"
    echo "   • Use multiple small nodes vs one large node"
    echo "   • Keep spare proxy servers configured"
    echo "   • Document your node IDs and configurations"
    echo ""

    wait_for_keypress
}

## main_menu - Display main menu options
main_menu() {
    while true; do
        show_banner
        echo -e "${CYAN}🔧 MAIN MENU${NC}"
        echo -e "${LIGHT_BLUE}═══════════════════════════════${NC}"
        echo ""
        echo -e "${WHITE}🏠 Selamat datang di Nexus Orchestrator!${NC}"
        echo ""
        echo -e "${GREEN}1) 🔧 Manage Docker & System${NC}"
        echo -e "${GREEN}2) 📊 Monitor Logs${NC}"
        echo -e "${GREEN}3) 🔑 Wallet & Account Management${NC}"
        echo -e "${GREEN}4) 🌐 Node Management${NC}"
        echo -e "${GREEN}5) ⚙️  Advanced Tools${NC}"
        echo -e "${CYAN}6) 📚 How to Use (Complete Guide)${NC}"
        echo -e "${RED}7) 🚪 Exit${NC}"
        echo ""

        read -r -p "$(echo -e "${YELLOW}🔢 Masukkan nomor pilihan Anda [1-7]: ${NC}")" choice

        case $choice in
            1)
                echo -e "${CYAN}🔧 Membuka Docker & System Management...${NC}"
                # shellcheck disable=SC1091
                if [[ -f "$(dirname "${BASH_SOURCE[0]}")/helper/docker-manager.sh" ]]; then
                    source "$(dirname "${BASH_SOURCE[0]}")/helper/docker-manager.sh"
                    docker_management_menu
                else
                    echo -e "${RED}❌ docker-manager.sh tidak ditemukan${NC}"
                    echo ""
                    wait_for_keypress
                fi
                ;;
            2)
                echo -e "${CYAN}📊 Membuka Monitor Logs...${NC}"
                # shellcheck disable=SC1091
                if [[ -f "$(dirname "${BASH_SOURCE[0]}")/helper/nexus-monitor.sh" ]]; then
                    source "$(dirname "${BASH_SOURCE[0]}")/helper/nexus-monitor.sh"
                    monitor_logs_menu
                else
                    echo -e "${RED}❌ nexus-monitor.sh tidak ditemukan${NC}"
                    wait_for_keypress
                fi
                ;;
            3)
                echo -e "${CYAN}🔑 Membuka Wallet & Account Management...${NC}"
                # shellcheck disable=SC1091
                if [[ -f "$(dirname "${BASH_SOURCE[0]}")/helper/wallet-manager.sh" ]]; then
                    source "$(dirname "${BASH_SOURCE[0]}")/helper/wallet-manager.sh"
                    wallet_management_menu
                else
                    echo -e "${RED}❌ wallet-manager.sh tidak ditemukan${NC}"
                    wait_for_keypress
                fi
                ;;
            4)
                echo -e "${CYAN}🌐 Membuka Node Management...${NC}"
                # shellcheck disable=SC1091
                if [[ -f "$(dirname "${BASH_SOURCE[0]}")/helper/node-manager.sh" ]]; then
                    source "$(dirname "${BASH_SOURCE[0]}")/helper/node-manager.sh"
                    node_management_menu
                else
                    echo -e "${RED}❌ node-manager.sh tidak ditemukan${NC}"
                    echo ""
                    wait_for_keypress
                fi
                ;;
            5)
                echo -e "${CYAN}⚙️ Membuka Advanced Tools...${NC}"
                # shellcheck disable=SC1091
                if [[ -f "$(dirname "${BASH_SOURCE[0]}")/helper/tools-manager.sh" ]]; then
                    source "$(dirname "${BASH_SOURCE[0]}")/helper/tools-manager.sh"
                    advanced_tools_menu
                else
                    echo -e "${RED}❌ tools-manager.sh tidak ditemukan${NC}"
                    wait_for_keypress
                fi
                ;;
            6)
                echo -e "${CYAN}📚 Membuka How to Use Guide...${NC}"
                show_how_to_use
                ;;
            7)
                echo -e "${GREEN}👋 Terima kasih telah menggunakan Nexus Orchestrator!${NC}"
                echo -e "${YELLOW}💡 Sampai jumpa lagi!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Pilihan tidak valid. Silakan pilih nomor 1-7.${NC}"
                wait_for_keypress
                ;;
        esac
    done
}

# Check working directory and validate environment
EXPECTED_PATH="/root/nexus-orchestrator"
if [[ "$(pwd)" != "$EXPECTED_PATH" && "$(pwd)" != "/tmp/nexus-orchestrator" ]]; then
    echo -e "${RED}⚠️ Terminal berada di $(pwd), harap jalankan dari $EXPECTED_PATH${NC}" >&2
    exit 1
fi

# Check if all helper modules exist
HELPER_MODULES=(
    "common.sh"
    "docker-manager.sh"
    "node-manager.sh"
    "wallet-manager.sh"
    "tools-manager.sh"
    "nexus-monitor.sh"
)

HELPER_DIR="$(dirname "${BASH_SOURCE[0]}")/helper"
MISSING_MODULES=()

for module in "${HELPER_MODULES[@]}"; do
    if [[ ! -f "$HELPER_DIR/$module" ]]; then
        MISSING_MODULES+=("$module")
    fi
done

if [[ ${#MISSING_MODULES[@]} -gt 0 ]]; then
    echo -e "${RED}❌ Missing helper modules:${NC}"
    for module in "${MISSING_MODULES[@]}"; do
        echo "  - $module"
    done
    echo ""
    echo -e "${YELLOW}💡 Falling back to index.sh if available...${NC}"
    if [[ -f "$(dirname "${BASH_SOURCE[0]}")/index.sh" ]]; then
        exec bash "$(dirname "${BASH_SOURCE[0]}")/index.sh"
    else
        echo -e "${RED}❌ No fallback available. Please check your installation.${NC}"
        exit 1
    fi
fi

# Perform dependency check and auto-install
echo -e "${CYAN}🚀 Initializing Nexus Orchestrator...${NC}"
echo ""

if ! check_and_install_dependencies; then
    echo -e "${RED}❌ Dependency check failed. Please resolve the issues and try again.${NC}"
    echo -e "${YELLOW}💡 You may need to:"
    echo "  1. Run as sudo for package installation"
    echo "  2. Logout and login after Docker group changes"
    echo "  3. Check your internet connection"
    echo ""
    read -r -p "$(echo -e "${YELLOW}Press Enter to continue anyway or Ctrl+C to exit...${NC}")"3

fi

# Start main menu
main_menu
