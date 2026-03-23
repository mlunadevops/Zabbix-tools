#!/bin/bash

# ==============================================================================
# Script Name    : register_zabbix_host.sh
# Description    : Advanced automation to register hosts via Zabbix JSON-RPC API.
# Author         : mlunadevops (Senior Systems Engineer)
# Date Created   : 2026-03-22
# Version        : 1.0.0
# License        : MIT
# Requirements   : jq, curl, nc (netcat)
# ==============================================================================
# Usage          : 1. Set ZABBIX_URL and AUTH_TOKEN
#                  2. chmod +x register_zabbix_host.sh
#                  3. ./register_zabbix_host.sh
# ==============================================================================

# --- CONFIGURATION ---
# IMPORTANT: Use environment variables or keep these private. 
# Do not commit your real token to a public GitHub repo!
ZABBIX_URL="YOUR_ZABBIX_URL_HERE"
AUTH_TOKEN="YOUR_AUTH_TOKEN_HERE"

echo -e "\e[34m--- Zabbix Host Registration Setup ---\e[0m"

# --- STEP 1: SMART FILTER & LOOKUP TEMPLATES ---
read -p "Filter templates by name (e.g., windows, linux) [Blank for ALL]: " QUERY

if [ ! -z "$QUERY" ]; then
    # Capitalize the first letter (e.g., windows -> Windows)
    QUERY="$(echo ${QUERY,,} | sed 's/./\u&/')"
fi

echo -e "\e[33mSearching for templates containing '$QUERY'...\e[0m"

TEMPLATES_LIST=$(curl -s -X POST \
  -H "Content-Type: application/json-rpc" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"template.get\",
    \"params\": {
        \"output\": [\"name\", \"templateid\"],
        \"search\": { \"name\": \"*$QUERY*\" },
        \"searchWildcardsEnabled\": true,
        \"sortfield\": \"name\"
    },
    \"id\": 1
}" "$ZABBIX_URL")

COUNT=$(echo "$TEMPLATES_LIST" | jq '.result | length' 2>/dev/null || echo 0)

if [[ ! "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -eq 0 ]; then
    echo -e "\e[31m[!] No templates found for '$QUERY'.\e[0m"
else
    echo -e "ID\t| Template Name"
    echo -e "------------------------------------"
    echo "$TEMPLATES_LIST" | jq -r '.result[] | "\(.templateid)\t| \(.name)"'
fi
echo -e "------------------------------------"

# --- STEP 2: INTERACTIVE DATA ENTRY ---
read -p "Enter Template ID from the list above [10351]: " TEMPLATE_ID
TEMPLATE_ID=${TEMPLATE_ID:-10351}

read -p "Enter Host Name [SQLAPITEST]: " HOST_NAME
HOST_NAME=${HOST_NAME:-SQLAPI00}

read -p "Enter Agent IP [172.16.0.2]: " AGENT_IP
AGENT_IP=${AGENT_IP:-172.16.20.233}

read -p "Enter PSK Identity [$HOST_NAME]: " PSK_IDENTITY
PSK_IDENTITY=${PSK_IDENTITY:-$HOST_NAME}

PSK_FILE="/etc/zabbix/psk.key"

# --- STEP 3: PSK HANDLING ---
if [ -f "$PSK_FILE" ]; then
    PSK_VALUE=$(sudo cat "$PSK_FILE" | tr -d '\n\r')
else
    echo -e "\e[31m[!] Error: PSK file not found at $PSK_FILE\e[0m"
    exit 1
fi

echo -e "\e[32mRegistering $HOST_NAME ($AGENT_IP) with Template $TEMPLATE_ID...\e[0m"

# --- STEP 4: CREATE THE HOST ---
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json-rpc" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -d "{
    \"jsonrpc\": \"2.0\",
    \"method\": \"host.create\",
    \"params\": {
        \"host\": \"$HOST_NAME\",
        \"interfaces\": [{
            \"type\": 1, \"main\": 1, \"useip\": 1, \"ip\": \"$AGENT_IP\", \"dns\": \"\", \"port\": \"10050\"
        }],
        \"groups\": [{\"groupid\": \"2\"}],
        \"templates\": [{\"templateid\": \"$TEMPLATE_ID\"}],
        \"tls_connect\": 2, \"tls_accept\": 2, \"tls_psk_identity\": \"$PSK_IDENTITY\", \"tls_psk\": \"$PSK_VALUE\"
    },
    \"id\": 1
}" "$ZABBIX_URL")

echo "$RESPONSE" | jq

# --- STEP 5: NEW CONNECTION TEST ---
echo -e "\e[33m\n--- Testing Connection to $AGENT_IP on Port 10050 ---\e[0m"
if nc -z -v -w 5 "$AGENT_IP" 10050 2>&1 | grep -q 'succeeded\|open'; then
    echo -e "\e[32m[OK] Port 10050 is OPEN. The Zabbix Server can reach the Agent!\e[0m"
else
    echo -e "\e[31m[!] Port 10050 is CLOSED. Please check the Firewall on $AGENT_IP.\e[0m"
fi
