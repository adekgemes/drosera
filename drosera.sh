#!/bin/bash

# Color codes for formatting
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
BLUE="\e[1;36m"
RESET="\e[0m"

# Function to log error and exit
error_exit() {
    echo -e "${YELLOW}Error: $1${RESET}"
    exit 1
}

# Function to derive public address from private key
derive_address_from_private_key() {
    echo "0x$(echo $1 | sha256sum | head -c 40)"
}

# Function to validate Ethereum private key
validate_private_key() {
    local key=$1
    if [[ ! $key =~ ^[0-9a-fA-F]{64}$ ]]; then
        error_exit "Invalid Ethereum private key. Must be 64 hexadecimal characters."
    fi
}

# Display ASCII Art Intro
echo -e "${GREEN}"
curl -s https://raw.githubusercontent.com/dlzvy/LOGOTES/main/logo3.sh | bash
sleep 3
echo -e "${RESET}"
echo ""

echo -e "${BLUE}=========== Drosera Network One-Click Installer (SystemD Version) ===========${RESET}"
echo -e "${YELLOW}This script will install and configure a Drosera Network operator node.${RESET}"
echo ""

# Collect user information
echo -e "${BLUE}=== Required Information ===${RESET}"
read -p "Enter your EVM private key (Must be funded with Holesky ETH): " EVM_PRIVATE_KEY
validate_private_key "$EVM_PRIVATE_KEY"

# Derive public address
echo "Deriving your public address..."
EVM_PUBLIC_ADDRESS=$(derive_address_from_private_key "$EVM_PRIVATE_KEY")
echo -e "Public address derived: ${YELLOW}$EVM_PUBLIC_ADDRESS${RESET}"
echo ""

# Prompt for VPS public IP
read -p "Enter your VPS public IP (or type 'local' to use 0.0.0.0): " VPS_IP_INPUT
if [ -z "$VPS_IP_INPUT" ]; then
    error_exit "VPS public IP is required."
fi

# Set VPS_IP based on input
VPS_IP=$([ "$VPS_IP_INPUT" = "local" ] && echo "0.0.0.0" || echo "$VPS_IP_INPUT")
echo -e "Using IP: ${YELLOW}$VPS_IP${RESET}"

# Prompt for Holesky Ethereum RPC URL
read -p "Enter your Holesky Ethereum RPC URL (or press Enter to use default): " ETH_RPC_URL
ETH_RPC_URL=${ETH_RPC_URL:-"https://ethereum-holesky-rpc.publicnode.com"}
echo -e "Using RPC URL: ${YELLOW}$ETH_RPC_URL${RESET}"

# Prompt for backup RPC URL
read -p "Enter your backup Holesky Ethereum RPC URL (or press Enter to use default): " ETH_BACKUP_RPC_URL
ETH_BACKUP_RPC_URL=${ETH_BACKUP_RPC_URL:-"https://1rpc.io/holesky"}
echo -e "Using backup RPC URL: ${YELLOW}$ETH_BACKUP_RPC_URL${RESET}"

echo ""
echo -e "${BLUE}=== Installation Process Starting ===${RESET}"
echo "This may take several minutes. Please be patient."
echo ""

# Step 1: Install Comprehensive Dependencies
echo -e "${YELLOW}[Step 1/9] Installing system dependencies...${RESET}"
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install -y curl ufw iptables build-essential git wget lz4 jq make gcc nano \
    automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev \
    libleveldb-dev tar clang bsdmainutils ncdu unzip ca-certificates gnupg

# Step 2: Install Docker
echo -e "\n${YELLOW}[Step 2/9] Installing Docker...${RESET}"
# Remove existing docker packages
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
    sudo apt-get remove $pkg 2>/dev/null
done

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y && sudo apt upgrade -y

# Install Docker packages
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Test Docker installation
sudo docker run hello-world

# Step 3: Trap Project Setup
echo -e "\n${YELLOW}[Step 3/9] Setting Up Drosera Trap Project...${RESET}"
mkdir -p "$HOME/my-drosera-trap"
cd "$HOME/my-drosera-trap" || error_exit "Cannot create trap directory"

# Initialize Trap Project
forge init -t drosera-network/trap-foundry-template
bun install
forge build

# Create Drosera Configuration
cat > drosera.toml << EOL
# Drosera Trap Configuration
private_trap = false
# Uncomment and add your operator address to whitelist
# whitelist = ["$EVM_PUBLIC_ADDRESS"]
EOL

# Deploy Trap
echo -e "\n${YELLOW}[Step 4/9] Deploying Trap...${RESET}"
DROSERA_PRIVATE_KEY="$EVM_PRIVATE_KEY" drosera apply

# Step 4: Install Drosera CLI
echo -e "\n${YELLOW}[Step 5/9] Installing Drosera CLI...${RESET}"
curl -L https://app.drosera.io/install | bash
source "$HOME/.bashrc"
export PATH="$PATH:$HOME/.drosera/bin"
droseraup || echo "It's normal if droseraup shows a usage message."

# Step 5: Install Foundry CLI and Bun
echo -e "\n${YELLOW}[Step 6/9] Installing Foundry CLI and Bun...${RESET}"
curl -L https://foundry.paradigm.xyz | bash
source "$HOME/.bashrc"
export PATH="$PATH:$HOME/.foundry/bin"
foundryup || echo "It's normal if foundryup shows a usage message."

curl -fsSL https://bun.sh/install | bash
source "$HOME/.bashrc"
export PATH="$PATH:$HOME/.bun/bin"

# Step 6: Install Operator CLI
echo -e "\n${YELLOW}[Step 7/9] Installing Operator CLI...${RESET}"
cd "$HOME" || error_exit "Cannot change to home directory"
OPERATOR_VERSION="v1.16.2"
curl -LO "https://github.com/drosera-network/releases/releases/download/${OPERATOR_VERSION}/drosera-operator-${OPERATOR_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
tar -xvf "drosera-operator-${OPERATOR_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
sudo cp drosera-operator /usr/bin
drosera-operator --version

# Step 7: Configure Firewall
echo -e "\n${YELLOW}[Step 8/9] Configuring firewall...${RESET}"
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp
sudo ufw --force enable

# Step 8: Register Operator
echo -e "\n${YELLOW}[Step 9/9] Registering operator with the network...${RESET}"
drosera-operator register --eth-rpc-url "$ETH_RPC_URL" --eth-private-key "$EVM_PRIVATE_KEY"

# Step 9: Configure and Start SystemD Service
echo -e "\n${YELLOW}Setting up SystemD service...${RESET}"
sudo tee /etc/systemd/system/drosera.service > /dev/null <<EOF
[Unit]
Description=Drosera Node Service
After=network-online.target

[Service]
User=$USER
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=$(which drosera-operator) node --db-file-path $HOME/.drosera.db --network-p2p-port 31313 --server-port 31314 \\
    --eth-rpc-url $ETH_RPC_URL \\
    --eth-backup-rpc-url $ETH_BACKUP_RPC_URL \\
    --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \\
    --eth-private-key $EVM_PRIVATE_KEY \\
    --listen-address 0.0.0.0 \\
    --network-external-p2p-address $VPS_IP \\
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
sudo systemctl daemon-reload
sudo systemctl enable drosera
sudo systemctl start drosera

echo ""
echo -e "${GREEN}=== Drosera Node Successfully Installed! ===${RESET}"
echo ""
echo -e "${BLUE}Node Information:${RESET}"
echo -e "  - Operator Address: ${YELLOW}$EVM_PUBLIC_ADDRESS${RESET}"
echo -e "  - External IP: ${YELLOW}$VPS_IP${RESET}"
echo -e "  - Primary RPC: ${YELLOW}$ETH_RPC_URL${RESET}"

echo -e "\n${BLUE}Useful Commands:${RESET}"
echo -e "  - Check node logs: ${YELLOW}journalctl -u drosera.service -f${RESET}"
echo -e "  - Stop node: ${YELLOW}sudo systemctl stop drosera${RESET}" 
echo -e "  - Restart node: ${YELLOW}sudo systemctl restart drosera${RESET}"

echo -e "\n${BLUE}To Change RPC URLs Later:${RESET}"
echo -e "1. Edit the service file: ${YELLOW}sudo nano /etc/systemd/system/drosera.service${RESET}"
echo -e "2. Modify the --eth-rpc-url and --eth-backup-rpc-url values"
echo -e "3. Save the file (Ctrl+X, then Y, then Enter)"
echo -e "4. Reload and restart: ${YELLOW}sudo systemctl daemon-reload && sudo systemctl restart drosera${RESET}"

echo -e "\n${BLUE}Next Steps:${RESET}"
echo -e "1. Deploy a trap (if you haven't already) with: ${YELLOW}DROSERA_PRIVATE_KEY=$EVM_PRIVATE_KEY drosera apply${RESET}"
echo -e "2. Bloom boost your trap with: ${YELLOW}drosera bloomboost --trap-address YOUR_TRAP_ADDRESS --eth-amount AMOUNT_ETH${RESET}"
echo -e "   (Replace YOUR_TRAP_ADDRESS with your trap address and AMOUNT_ETH with the amount to deposit, e.g., 0.1)"
echo -e "3. Opt-in to your trap with: ${YELLOW}drosera-operator optin --eth-rpc-url $ETH_RPC_URL --eth-private-key $EVM_PRIVATE_KEY --trap-config-address YOUR_TRAP_ADDRESS${RESET}"
echo -e "4. Check your node status at: ${YELLOW}https://app.drosera.io/trap?trapId=YOUR_TRAP_ADDRESS${RESET}"

echo -e "\n${YELLOW}Note: If you see 'WARN drosera_services::network::service: Failed to gossip message: InsufficientPeers',\nthis is normal and not a problem.${RESET}"

echo -e "\n${GREEN}Thank you for running a Drosera Network node!${RESET}"
