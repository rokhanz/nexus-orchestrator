#!/bin/bash

# nexus_cache_cleanup.sh - Nexus Cache Cleanup Utility
# Usage: ./nexus_cache_cleanup.sh [option]

# Load dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/port_manager.sh"

show_cache_menu() {
    clear
    echo -e "${CYAN}${BOLD}🧹 NEXUS CACHE CLEANUP UTILITY${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Show current memory usage
    echo -e "${BLUE}📊 Current System Status:${NC}"
    free -h | head -2
    echo ""

    echo -e "${GREEN}Quick Cleanup Options:${NC}"
    echo -e "  ${GREEN}1.${NC} ${CYAN}Nexus Cache Cleanup${NC} ${GRAY}(Restart containers)${NC}"
    echo -e "  ${GREEN}2.${NC} ${CYAN}System Cache Cleanup${NC} ${GRAY}(Memory optimization)${NC}"
    echo -e "  ${GREEN}3.${NC} ${CYAN}Full Cleanup${NC} ${GRAY}(Both Nexus + System)${NC}"
    echo -e "  ${GREEN}4.${NC} ${YELLOW}Show Memory Usage${NC}"
    echo -e "  ${GREEN}0.${NC} ${WHITE}Exit${NC}"
    echo ""

    read -rp "Select cleanup option [1-4/0]: " choice
    echo ""

    case "$choice" in
        1)
            cleanup_nexus_cache
            ;;
        2)
            cleanup_system_cache
            ;;
        3)
            echo -e "${CYAN}${BOLD}🧹 Full System Cleanup${NC}"
            echo -e "${BLUE}This will clean both Nexus and system cache${NC}"
            echo ""
            cleanup_nexus_cache
            echo ""
            cleanup_system_cache
            ;;
        4)
            echo -e "${BLUE}📊 Detailed Memory Usage:${NC}"
            free -h
            echo ""
            echo -e "${BLUE}📊 Disk Usage:${NC}"
            df -h | head -5
            echo ""
            echo -e "${BLUE}📊 Docker Usage:${NC}"
            docker system df 2>/dev/null || echo "Docker not available"
            ;;
        0)
            echo -e "${GREEN}👋 Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option${NC}"
            sleep 2
            show_cache_menu
            ;;
    esac

    echo ""
    read -rp "Press Enter to continue..."
    show_cache_menu
}

# Quick cleanup functions for direct usage
quick_nexus_cleanup() {
    echo -e "${CYAN}🧹 Quick Nexus Cache Cleanup${NC}"
    cleanup_nexus_cache
}

quick_system_cleanup() {
    echo -e "${CYAN}🧹 Quick System Cache Cleanup${NC}"
    cleanup_system_cache
}

quick_full_cleanup() {
    echo -e "${CYAN}🧹 Quick Full Cleanup${NC}"
    cleanup_nexus_cache
    echo ""
    cleanup_system_cache
}

# Main execution
case "${1:-menu}" in
    "nexus"|"n")
        quick_nexus_cleanup
        ;;
    "system"|"s")
        quick_system_cleanup
        ;;
    "full"|"f")
        quick_full_cleanup
        ;;
    "memory"|"m")
        echo -e "${BLUE}📊 Current Memory Usage:${NC}"
        free -h
        echo ""
        df -h | head -5
        ;;
    "help"|"h"|"-h"|"--help")
        echo -e "${CYAN}Nexus Cache Cleanup Utility${NC}"
        echo ""
        echo -e "${WHITE}Usage:${NC}"
        echo -e "  ./nexus_cache_cleanup.sh [option]"
        echo ""
        echo -e "${WHITE}Options:${NC}"
        echo -e "  ${GREEN}nexus${NC}   - Clean Nexus container cache"
        echo -e "  ${GREEN}system${NC}  - Clean system memory cache"
        echo -e "  ${GREEN}full${NC}    - Clean both Nexus and system cache"
        echo -e "  ${GREEN}memory${NC}  - Show memory usage"
        echo -e "  ${GREEN}help${NC}    - Show this help"
        echo ""
        echo -e "${WHITE}Examples:${NC}"
        echo -e "  ./nexus_cache_cleanup.sh nexus"
        echo -e "  ./nexus_cache_cleanup.sh system"
        echo -e "  ./nexus_cache_cleanup.sh full"
        ;;
    *)
        show_cache_menu
        ;;
esac
