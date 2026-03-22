# Zabbix Agent Interactive Audit Tool 🕵️‍♂️

This script (`zabbix_audit.sh`) provides a professional, interactive interface to verify connectivity and authentication between a Zabbix Server/Proxy and a Zabbix Agent.

## 🌟 Key Features
* **Interactive Data Entry**: Prompts for Agent IP, PSK Identity, and PSK file paths with sensible defaults.
* **Dual-Mode Testing**: Supports both **Encrypted (TLS-PSK)** and **Unencrypted** connection audits.
* **Network Validation**: Performs an initial check on port `10050` using `netcat`.
* **Authentication Verification**: Uses `zabbix_get` to perform real-time pings or uptime checks to confirm the agent configuration is correct.
* **Visual Feedback**: Uses color-coded output (Green for success, Red for failure) for fast diagnostics.

## 📋 Prerequisites
* **Packages**: Ensure `zabbix-get` and `nc` (netcat) are installed on the system running the script.
* **Permissions**: Access to the PSK key file usually requires `sudo` privileges, which the script handles internally.

## 🚀 How to Use
1. **Navigate to the directory**:
   ```bash
   cd audit-tool
