#!/bin/bash

# nexus_logs.sh - Nexus Logs Management Utility
# Version: 4.0.0 - Standalone log viewer for Nexus Orchestrator

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/logging.sh  
source "$SCRIPT_DIR/lib/logging.sh"

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    show_section_header "Nexus Logs Viewer" "📋"
    
    # Check if logs exist
    if [[ ! -f "$NEXUS_MANAGER_LOG" ]]; then
        echo -e "${YELLOW}⚠️  No logs found at: $NEXUS_MANAGER_LOG${NC}"
        echo -e "${CYAN}💡 Run Nexus Orchestrator first to generate logs${NC}"
        exit 1
    fi

    # Show log options
    echo -e "${CYAN}Log Management Options:${NC}"
    echo ""
    echo "1. View Recent Logs (last 50 lines)"
    echo "2. View Full Logs"
    echo "3. Follow Logs (real-time)"
    echo "4. Search Logs"
    echo "5. Show Log Statistics"
    echo "6. Clean Old Logs"
    echo "0. Exit"
    echo ""

    read -rp "Choose option [0-6]: " choice

    case "$choice" in
        1)
            echo -e "${CYAN}Recent logs (last 50 lines):${NC}"
            echo ""
            tail -n 50 "$NEXUS_MANAGER_LOG"
            ;;
        2)
            if command -v less >/dev/null 2>&1; then
                less "$NEXUS_MANAGER_LOG"
            else
                cat "$NEXUS_MANAGER_LOG"
            fi
            ;;
        3)
            echo -e "${CYAN}Following logs (Press Ctrl+C to stop):${NC}"
            echo ""
            tail -f "$NEXUS_MANAGER_LOG"
            ;;
        4)
            read -rp "Enter search term: " search_term
            if [[ -n "$search_term" ]]; then
                echo -e "${CYAN}Search results for: ${YELLOW}$search_term${NC}"
                echo ""
                grep -n --color=always "$search_term" "$NEXUS_MANAGER_LOG" || {
                    echo -e "${YELLOW}No matches found${NC}"
                }
            fi
            ;;
        5)
            show_log_stats
            ;;
        6)
            clean_old_logs
            echo -e "${GREEN}✅ Old logs cleaned${NC}"
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid option${NC}"
            exit 1
            ;;
    esac
}

# =============================================================================
# RUN MAIN FUNCTION
# =============================================================================

main "$@"
