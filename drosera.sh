#!/bin/bash

# Strict mode
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ASCII Art
echo -e "${GREEN}"
cat << "EOF"
 ____   ____  ____  _____ _____ ___    _    ____ 
|  _ \ / _ \/ ___|| ____|  ___|_ _|  / \  |  _ \
| | | | | | \___ \|  _| | |_   | |  / _ \ | |_) |
| |_| | |_| |___) | |___|  _|  | | / ___ \|  _ <
|____/ \___/|____/|_____|_|   |___/_/   \_\_| \_\
              Network Automated Installer
EOF
echo -e "${NC}"

# Check for root/sudo
if [[ $EUID -ne 0 ]]; then
   echo -e "${YELLOW}This script must be run with sudo or as root${NC}" 
   exit 1
fi

# Prerequisites Check
prereqs() {
    echo -e "${YELLOW}Checking system prerequisites...${NC}"
    # Check for required tools
    for cmd in curl git docker ufw; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${YELLOW}Installing $cmd...${NC}"
            apt-get update
            apt-get install -y $cmd
        fi
    done
}

# Install Dependencies
install_deps() {
    echo -e "${YELLOW}Installing system dependencies...${NC}"
    apt-get update && apt-get upgrade -y
    apt-get install -y curl ufw iptables build-essential git wget lz4 jq make gcc \
        nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev \
        libleveldb-dev tar clang bsdmainutils ncdu unzip
}

# Install Docker
install_docker() {
    echo -e "${YELLOW}Installing Docker...${NC}"
    # Remove conflicting packages
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
        apt-get remove -y $pkg
    done

    # Docker official GPG key and repo
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# Install Drosera Components
install_drosera_components() {
    echo -e "${YELLOW}Installing Drosera CLI, Foundry, and Bun...${NC}"
    
    # Drosera CLI
    curl -L https://app.drosera.io/install | bash
    source /root/.bashrc
    droseraup

    # Foundry CLI
    curl -L https://foundry.paradigm.xyz | bash
    source /root/.bashrc
    foundryup

    # Bun
    curl -fsSL https://bun.sh/install | bash
    source /root/.bashrc
}

# Deployment Configuration
configure_deployment() {
    echo -e "${YELLOW}Configuring Drosera Network Deployment...${NC}"
    
    # Prompt for critical information
    read -p "Enter your EVM Private Key (Holesky ETH funded): " EVM_PRIVATE_KEY
    read -p "Enter your VPS Public IP: " VPS_IP
    read -p "Enter Holesky Ethereum RPC URL (default: https://ethereum-holesky-rpc.publicnode.com): " ETH_RPC_URL
    ETH_RPC_URL=${ETH_RPC_URL:-https://ethereum-holesky-rpc.publicnode.com}

    # Trap Deployment
    mkdir -p ~/my-drosera-trap
    cd ~/my-drosera-trap
    
    # Git config (using placeholders)
    git config --global user.email "drosera-user@example.com"
    git config --global user.name "DroseraTrapUser"
    
    # Initialize and build trap
    forge init -t drosera-network/trap-foundry-template
    bun install
    forge build
    
    # Deploy trap
    DROSERA_PRIVATE_KEY=$EVM_PRIVATE_KEY drosera apply
}

# Operator Setup
setup_operator() {
    echo -e "${YELLOW}Setting up Drosera Operator...${NC}"
    
    # Download and install operator CLI
    curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
    tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
    cp drosera-operator /usr/bin
    
    # Pull Docker image
    docker pull ghcr.io/drosera-network/drosera-operator:latest
    
    # Configure systemd service
    tee /etc/systemd/system/drosera.service > /dev/null <<EOF
[Unit]
Description=Drosera Operator Node
After=network-online.target

[Service]
User=root
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=$(which drosera-operator) node --db-file-path \$HOME/.drosera.db --network-p2p-port 31313 --server-port 31314 \
    --eth-rpc-url $ETH_RPC_URL \
    --eth-backup-rpc-url https://1rpc.io/holesky \
    --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \
    --eth-private-key $EVM_PRIVATE_KEY \
    --listen-address 0.0.0.0 \
    --network-external-p2p-address $VPS_IP \
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd, enable and start service
    systemctl daemon-reload
    systemctl enable drosera
    systemctl start drosera
}

# Firewall Configuration
configure_firewall() {
    echo -e "${YELLOW}Configuring Firewall...${NC}"
    ufw allow ssh
    ufw allow 22
    ufw allow 31313/tcp
    ufw allow 31314/tcp
    ufw enable
}

# Main Execution
main() {
    prereqs
    install_deps
    install_docker
    install_drosera_components
    configure_deployment
    setup_operator
    configure_firewall

    echo -e "${GREEN}Drosera Network Deployment Complete!${NC}"
    echo "Check node logs: journalctl -u drosera.service -f"
}

# Run main function with error handling
main || { echo -e "${YELLOW}Installation encountered an error. Please check the output.${NC}"; exit 1; }
