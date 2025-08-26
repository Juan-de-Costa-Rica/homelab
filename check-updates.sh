#!/bin/bash

# 🌊 VAPORWAVE CONTAINER SCANNER - CLEAN EDITION
# Simple, functional, beautiful - no overcomplicated animations

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COLORS - VAPORWAVE PALETTE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PINK='\033[38;2;255;20;147m'
PURPLE='\033[38;2;155;89;182m'
CYAN='\033[38;2;0;255;255m'
ORANGE='\033[38;2;255;99;71m'
BLUE='\033[38;2;64;224;208m'
GREEN='\033[38;2;0;255;127m'
YELLOW='\033[38;2;255;215;0m'
GRAY='\033[38;2;128;128;128m'
WHITE='\033[38;2;255;255;255m'
RED='\033[38;2;255;69;58m'

BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
NC='\033[0m'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DATA STRUCTURES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

declare -A CONTAINERS
declare -A CURRENT_TAGS
declare -A LATEST_TAGS
declare -A CONTAINER_AGES
declare -A UPDATE_STATUS
declare -A IMAGE_SIZES
declare -a NEEDS_UPDATE

TOTAL=0
SCANNED=0
UPDATED=0
ERRORS=0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HELPER FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Simple spinner that actually works
# Wave-style loading animation (safe on its own line)
# Wave-style loading animation (Docker Compose style)
# Docker-Compose style wave spinner
spin() {
    local pid=$1
    local delay=0.12
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i=0

    # Save cursor position so we can overwrite in place
    tput sc
    while ps -p $pid > /dev/null 2>&1; do
        printf "%s" "${frames[i]}"
        tput rc
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep $delay
    done
    # Clear spinner character when done
    printf " "
    tput rc
}



# Get container age in human readable format
get_age() {
    local created="$1"
    local now=$(date +%s)
    local created_epoch=$(date -d "$created" +%s 2>/dev/null || echo $now)
    local diff=$((now - created_epoch))
    
    if [ $diff -lt 86400 ]; then
        echo "$((diff / 3600))h"
    elif [ $diff -lt 2592000 ]; then
        echo "$((diff / 86400))d"
    else
        echo "$((diff / 2592000))mo"
    fi
}

# Get image size
get_size() {
    local image="$1"
    docker image inspect "$image" --format='{{.Size}}' 2>/dev/null | numfmt --to=iec-i --suffix=B 2>/dev/null || echo "?"
}

# Extract version/tag
get_tag() {
    local image="$1"
    echo "$image" | grep -oE ':[^:]+$' | tr -d ':' || echo "latest"
}

# Get image digest (short)
get_digest() {
    local image="$1"
    docker image inspect "$image" --format='{{index .RepoDigests 0}}' 2>/dev/null | \
        grep -oE 'sha256:[a-f0-9]{64}' | cut -c8-19 || echo "unknown"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DISPLAY FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

print_header() {
    clear
    echo
    echo -e "${PINK}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PINK}║${NC}  ${BOLD}${CYAN}░█▀▀░█▀█░█▀█░▀█▀░█▀█░▀█▀░█▀█░█▀▀░█▀▄  ${PURPLE}█▀▀░█▀▀░█▀█░█▀█░█▀█░█▀▀░█▀▄${NC}  ${PINK}║${NC}"
    echo -e "${PINK}║${NC}  ${BOLD}${BLUE}░█░░░█░█░█░█░░█░░█▀█░░█░░█░█░█▀▀░█▀▄  ${PURPLE}▀▀█░█░░░█▀█░█░█░█░█░█▀▀░█▀▄${NC}  ${PINK}║${NC}"
    echo -e "${PINK}║${NC}  ${BOLD}${GREEN}░▀▀▀░▀▀▀░▀░▀░░▀░░▀░▀░▀▀▀░▀░▀░▀▀▀░▀░▀  ${PURPLE}▀▀▀░▀▀▀░▀░▀░▀░▀░▀░▀░▀▀▀░▀░▀${NC}  ${PINK}║${NC}"
    echo -e "${PINK}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "                    ${DIM}${GRAY}Checking for container image updates...${NC}"
    echo
}

print_separator() {
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SCANNING LOGIC
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

scan_container() {
    local name="$1"
    local image="$2"

    SCANNED=$((SCANNED + 1))

    # Print initial status (no newline, leave space for spinner)
    printf "${CYAN}[%02d/%02d]${NC} %-20s ${DIM}checking...${NC} " \
        "$SCANNED" "$TOTAL" "${name:0:20}"

    local current_tag=$(get_tag "$image")
    local current_digest=$(get_digest "$image")

    # Handle pinned
    if [[ "$current_tag" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] || [[ "$current_tag" =~ ^sha256: ]]; then
        UPDATE_STATUS[$name]="PINNED"
        printf "\r${CYAN}[%02d/%02d]${NC} %-20s ${PURPLE}[PINNED:$current_tag]${NC}\n" \
            "$SCANNED" "$TOTAL" "${name:0:20}"
        return
    fi

    # Run pull in background
    local logfile
    logfile=$(mktemp /tmp/docker_pull.XXXXXX)
    docker pull "$image" >"$logfile" 2>&1 &
    local pull_pid=$!

    # Animate spinner until docker pull finishes
    spin $pull_pid

    # Final overwrite with result
    if grep -q "Downloaded newer image\|Pulled" "$logfile"; then
        local new_digest=$(get_digest "$image")
        UPDATE_STATUS[$name]="UPDATE"
        NEEDS_UPDATE+=("$name")
        UPDATED=$((UPDATED + 1))
        printf "\r${CYAN}[%02d/%02d]${NC} %-20s ${GREEN}✓${NC} ${BOLD}${ORANGE}UPDATE AVAILABLE${NC} ${DIM}[${current_digest:0:12} → ${new_digest:0:12}]${NC}\n" \
            "$SCANNED" "$TOTAL" "${name:0:20}"
    elif grep -q "up to date" "$logfile"; then
        UPDATE_STATUS[$name]="CURRENT"
        printf "\r${CYAN}[%02d/%02d]${NC} %-20s ${GREEN}✓${NC} ${GREEN}Up to date${NC} ${DIM}[$current_tag]${NC}\n" \
            "$SCANNED" "$TOTAL" "${name:0:20}"
    else
        UPDATE_STATUS[$name]="ERROR"
        ERRORS=$((ERRORS + 1))
        printf "\r${CYAN}[%02d/%02d]${NC} %-20s ${RED}✗${NC} ${RED}Error checking${NC}\n" \
            "$SCANNED" "$TOTAL" "${name:0:20}"
    fi

    rm -f "$logfile"
}


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RESULTS DISPLAY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_summary() {
    echo
    print_separator
    echo
    
    # Summary stats
    echo
    printf "${PINK}══════════════════════════════════════════${NC}\n"
    printf "${CYAN}           ✨ SCAN COMPLETE ✨            ${NC}\n"
    printf "${PINK}══════════════════════════════════════════${NC}\n"
    echo

    printf "  ${BLUE}●${NC} Total Containers: ${BOLD}%s${NC}\n" "$TOTAL"

    if [ "$UPDATED" -gt 0 ]; then
        printf "  ${PURPLE}●${NC} Updates Available: ${PINK}%s${NC}\n" "$UPDATED"
    fi

    if [ "$ERRORS" -gt 0 ]; then
        printf "  ${RED}●${NC} Errors: ${RED}%s${NC}\n" "$ERRORS"
    fi

    if [ $((TOTAL - UPDATED - ERRORS)) -gt 0 ]; then
        printf "  ${GREEN}●${NC} Up to Date: ${GREEN}%s${NC}\n" "$((TOTAL - UPDATED - ERRORS))"
    fi

    echo
    
    # If updates available, show detailed table
    if [ $UPDATED -gt 0 ]; then
        print_separator
        echo
        echo -e "${BOLD}${ORANGE}CONTAINERS WITH UPDATES:${NC}"
        echo
        printf "${DIM}%-20s %-15s %-10s %-12s %-12s${NC}\n" "CONTAINER" "IMAGE TAG" "AGE" "SIZE" "DIGEST"
        echo -e "${GRAY}────────────────────────────────────────────────────────────────────────────${NC}"
        
        for name in "${NEEDS_UPDATE[@]}"; do
            local image="${CONTAINERS[$name]}"
            local img_name=$(echo "$image" | cut -d':' -f1 | rev | cut -d'/' -f1 | rev)
            local tag="${CURRENT_TAGS[$name]}"
            local age="${CONTAINER_AGES[$name]}"
            local size="${IMAGE_SIZES[$name]}"
            local digest="${LATEST_TAGS[$name]:0:12}"
            
            printf "${BOLD}${CYAN}%-20s${NC} ${YELLOW}%-15s${NC} ${GRAY}%-10s${NC} ${BLUE}%-12s${NC} ${PURPLE}%-12s${NC}\n" \
                "${name:0:20}" "${tag:0:15}" "$age" "$size" "$digest"
        done
        
        echo
        print_separator
        echo
        echo -e "${BOLD}${GREEN}DEPLOYMENT COMMANDS:${NC}"
        echo
        echo -e "  ${DIM}# Update all services${NC}"
        echo -e "  ${BLUE}docker compose up -d${NC}"
        echo
        echo -e "  ${DIM}# Update specific container${NC}"
        echo -e "  ${BLUE}docker compose up -d <container_name>${NC}"
        echo
        echo -e "  ${DIM}# View in Dockge${NC}"
        echo -e "  ${PURPLE}https://dockge.your-tailnet.ts.net${NC}"
    else
        echo -e "${BOLD}${GREEN}✨ All containers are running the latest images! ✨${NC}"
    fi
    
    echo
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN EXECUTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    print_header
    
    # Collect all running containers
    while IFS=$'\t' read -r name image; do
        [ -z "$name" ] && continue
        CONTAINERS[$name]="$image"
        TOTAL=$((TOTAL + 1))
    done < <(docker ps --format "{{.Names}}\t{{.Image}}")
    
    if [ $TOTAL -eq 0 ]; then
        echo -e "${ORANGE}No containers running!${NC}"
        echo -e "${DIM}Start your homelab services first.${NC}"
        echo
        exit 0
    fi
    
    echo -e "${BOLD}${WHITE}SCANNING $TOTAL CONTAINERS${NC}"
    echo
    print_separator
    echo
    
    # Scan each container
    for name in "${!CONTAINERS[@]}"; do
        scan_container "$name" "${CONTAINERS[$name]}"
    done
    
    # Show results
    show_summary
}

# Cleanup on exit
trap "rm -f /tmp/docker_pull_*.log 2>/dev/null" EXIT

# Run it
main "$@"