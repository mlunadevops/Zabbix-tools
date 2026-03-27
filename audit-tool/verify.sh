#!/bin/bash

# --- COLORS ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}    ZABBIX AGENT INTERACTIVE AUDIT TOOL        ${NC}"
echo -e "${BLUE}===============================================${NC}\n"

read -p "Enter Agent IP address [172.16.20.233]: " IP_INPUT
AGENT_IP=${IP_INPUT:-172.16.20.233}

read -p "Is this agent using PSK encryption? (y/n): " USE_PSK

if [[ "$USE_PSK" =~ ^[Yy]$ ]]; then
    read -p "Enter PSK Identity [SQLAPI00]: " ID_INPUT
    PSK_IDENTITY=${ID_INPUT:-SQLAPI00}
    echo -e "${YELLOW}Hint: Press Enter to use default [/etc/zabbix/psk.key]${NC}"
    read -p "Enter path to PSK File: " PSK_INPUT
    PSK_FILE=${PSK_INPUT:-/etc/zabbix/psk.key}

    echo -e "\n${BLUE}--- PSK Configuration Preview ---${NC}"
    echo -e "Path: ${YELLOW}$PSK_FILE${NC}"
    echo -n "Content: "
    if [ -f "$PSK_FILE" ]; then
        sudo cat -e "$PSK_FILE"
    else
        echo -e "${RED}FILE NOT FOUND!${NC}"
    fi
else
    echo -e "\n${YELLOW}Mode: Unencrypted Connection Only.${NC}"
fi

echo -e "\n${BLUE}--- Starting Diagnostics for $AGENT_IP ---${NC}\n"

echo -n "[1] Port 10050 Check: "
if nc -vz -w 2 "$AGENT_IP" 10050 &>/dev/null; then
    echo -e "${GREEN}OPEN${NC}"
else
    echo -e "${RED}CLOSED${NC}"
fi

if [[ "$USE_PSK" =~ ^[Yy]$ ]]; then
    echo -n "[2] TLS PSK Test:      "
    RESULT=$(sudo zabbix_get -s "$AGENT_IP" -k "agent.ping" \
        --tls-connect=psk \
        --tls-psk-identity="$PSK_IDENTITY" \
        --tls-psk-file="$PSK_FILE" 2>/dev/null)

    if [ "$RESULT" == "1" ]; then
        echo -e "${GREEN}SUCCESS${NC} (Authenticated)"
    else
        echo -e "${RED}FAILED${NC} (Check Key/Identity)"
    fi
else
    echo -n "[2] Unencrypted Test: "
    UPTIME=$(zabbix_get -s "$AGENT_IP" -k "system.uptime" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SUCCESS${NC} (Uptime: $UPTIME)"
    else
        echo -e "${RED}FAILED${NC} (Check 'Server=' whitelist on Agent)"
    fi
fi

echo -e "\n${BLUE}===============================================${NC}"
echo -e "${BLUE}            AUDIT PROCESS COMPLETE             ${NC}"
echo -e "${BLUE}===============================================${NC}"

echo -e "\n${YELLOW}This window will close automatically in 20 seconds.${NC}"
echo -e "${YELLOW}Press any key to exit now...${NC}"
read -t 20 -n 1
clear
