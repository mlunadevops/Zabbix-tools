#!/bin/bash

# ==============================================================================
# Script Name    : zabbix_audit.sh
# Description    : Interactive tool to verify Zabbix Agent connectivity & auth.
# Author         : mlunadevops
# Date Created   : 2026-03-22
# Version        : 1.0.0
# License        : MIT
# ==============================================================================
# Usage          : chmod +x zabbix_audit.sh && ./zabbix_audit.sh
# ==============================================================================

# --- COLORS ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Clear the screen for a professional look
clear
echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}    ZABBIX AGENT INTERACTIVE AUDIT TOOL        ${NC}"
echo -e "${BLUE}===============================================${NC}\n"

# 1. Get Agent IP with Default
read -p "Enter Agent IP address [172.16.20.233]: " IP_INPUT
AGENT_IP=${IP_INPUT:-172.16.20.233}

# --- DECISION POINT: PSK OR UNENCRYPTED ---
read -p "Is this agent using PSK encryption? (y/n): " USE_PSK

if [[ "$USE_PSK" =~ ^[Yy]$ ]]; then
    # 2. Get PSK Identity
    read -p "Enter PSK Identity [SQLAPI00]: " ID_INPUT
    PSK_IDENTITY=${ID_INPUT:-SQLAPI00}
    
    # 3. Get PSK File Path with Default
    echo -e "${YELLOW}Hint: Press Enter to use default [/etc/zabbix/psk.key]${NC}"
    read -p "Enter path to PSK File: " PSK_INPUT
    PSK_FILE=${PSK_INPUT:-/etc/zabbix/psk.key}

    # --- PSK CONTENT PREVIEW ---
    echo -e "\n${BLUE}--- PSK Configuration Preview ---${NC}"
    echo -e "Path: ${YELLOW}$PSK_FILE${NC}"
    echo -n "Content: "
    if [ -f "$PSK_FILE" ]; then
        # -e reveals hidden characters/newlines
        sudo cat -e "$PSK_FILE"
    else
        echo -e "${RED}FILE NOT FOUND!${NC}"
    fi
else
    echo -e "\n${YELLOW}Mode: Unencrypted Connection Only.${NC}"
fi

echo -e "\n${BLUE}--- Starting Diagnostics for $AGENT_IP ---${NC}\n"

# --- TEST 1: NETWORK PORT (Always runs) ---
echo -n "[1] Port 10050 Check: "
if nc -vz -w 2 "$AGENT_IP" 10050 &>/dev/null; then
    echo -e "${GREEN}OPEN${NC}"
else
    echo -e "${RED}CLOSED${NC}"
fi

# --- TEST 2: CONDITIONAL MODE (Exclusive) ---
if [[ "$USE_PSK" =~ ^[Yy]$ ]]; then
    # ENCRYPTED TEST
    echo -n "[2] TLS PSK Test:      "
    RESULT=$(sudo zabbix_get -s "$AGENT_IP" -k "agent.ping" \
        --tls-connect=psk \
        --tls-psk-identity="$PSK_IDENTITY" \
        --tls-psk-file="$PSK_FILE" 2>/dev/null)

    if [ "$RESULT" == "1" ]; then
        echo -e "${GREEN}SUCCESS${NC} (Authenticated)"
    else
        echo -e "${RED}FAILED${NC} (Check PSK Key or Identity)"
    fi
else
    # UNENCRYPTED TEST
    echo -n "[2] Unencrypted Test: "
    UPTIME=$(zabbix_get -s "$AGENT_IP" -k "system.uptime" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SUCCESS${NC} (Uptime: $UPTIME)"
    else
        echo -e "${RED}FAILED${NC} (Check 'Server=' line in agent config)"
    fi
fi

echo -e "\n${BLUE}===============================================${NC}"
echo -e "${BLUE}            AUDIT PROCESS COMPLETE             ${NC}"
echo -e "${BLUE}===============================================${NC}"

# --- AUTO-CLOSE TIMEOUT ---
echo -e "\n${YELLOW}This window will close automatically in 20 seconds.${NC}"
echo -e "${YELLOW}Press any key to exit now...${NC}"

# -t 20: Wait 20 seconds. -n 1: Or close immediately on any key press.
read -t 20 -n 1
clear
