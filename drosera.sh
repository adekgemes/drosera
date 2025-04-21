#!/bin/bash

# Function to derive public address from private key (simplified placeholder)
derive_address_from_private_key() {
    # In a real scenario, use a tool like `cast` from Foundry or an Ethereum library
    # Here, we simulate it for simplicity (replace with actual derivation if needed)
    echo "0x$(echo $1 | sha256sum | head -c 40)"
}

# Color Codes
GREEN="\e[1;32m"
YELLOW="\e[1;33m"
BLUE="\e[1;36m"
RESET="\e[0m"

# Function to log error and exit
error_exit() {
    echo -e "${YELLOW}Error: $1${RESET}"
    exit 1
}

# Beautiful ASCII Art Intro
echo -e "${GREEN}"
cat << "EOF"
Drosera Trap & Operator Deployment
Built by:
  ___       __  __            _ 
 / _ \__  _|  \/  | ___   ___(_)
| | | \ \/ / |\/| |/ _ \ / _ \ |
| |_| |>  <| |  | | (_) |  __/ |
 \___//_/\_\_|  |_|\___/ \___|_|        
 
Follow me on X: https://x.com/0xMoei
Follow me on Github: https://github.com/0xmoei
EOF
echo -e "${RESET}"
echo ""

# Prompt for EVM private key
read -p "Enter your EVM private key (Make sure it's funded with Testnet Holesky ETH): " EVM_PRIVATE_KEY
if [ -z "$EVM_PRIVATE_KEY" ]; then
    error_exit "EVM private key is required."
fi

# Derive public address
echo "Deriving your public address..."
EVM_PUBLIC_ADDRESS=$(derive_address_from_private_key "$EVM_PRIVATE_KEY")
echo -e "Public address derived: ${YELLOW}$EVM_PUBLIC_ADDRESS${RESET}"

# Prompt for Testnet Holesky Ethereum RPC
read -p "Enter your Testnet Holesky Ethereum RPC (or press Enter to use default): " ETH_RPC_URL
ETH_RPC_URL=${ETH_RPC_URL:-"https://ethereum-holesky-rpc.publicnode.com"}
echo -e "Using RPC URL: ${YELLOW}$ETH_RPC_URL${RESET}"

# Prompt for backup RPC
read -p "Enter backup Holesky Ethereum RPC (or press Enter to use default): " ETH_BACKUP_RPC_URL
ETH_BACKUP_RPC_URL=${ETH_BACKUP_RPC_URL:-"https://1rpc.io/holesky"}
echo -e "Using backup RPC URL: ${YELLOW}$ETH_BACKUP_RPC_URL${RESET}"

# Prompt for VPS public IP
read -p "Enter your VPS public IP (or type 'local' to use 0.0.0.0): " VPS_IP_INPUT
if [ -z "$VPS_IP_INPUT" ]; then
    error_exit "VPS public IP is required."
fi
VPS_IP=$([ "$VPS_IP_INPUT" = "local" ] && echo "0.0.0.0" || echo "$VPS_IP_INPUT")
echo -e "Using IP: ${YELLOW}$VPS_IP${RESET}"

# Step 1: Install Dependencies
echo -e "\n${YELLOW}[Step 1/13] Installing system dependencies...${RESET}"
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install -y curl ufw iptables build-essential git wget lz4 jq make gcc \
    nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev \
    libleveldb-dev tar clang bsdmainutils ncdu unzip ca-certificates gnupg

# Step 2: Install Development Tools
echo -e "\n${YELLOW}[Step 2/13] Installing Development Tools...${RESET}"
# Drosera CLI
curl -L https://app.drosera.io/install | bash

# Foundry CLI
curl -L https://foundry.paradigm.xyz | bash

# Bun
curl -fsSL https://bun.sh/install | bash

# Source configuration files
source "$HOME/.bashrc"
source "$HOME/.bash_profile"
source "$HOME/.profile"

# Ensure paths are set
export PATH="$HOME/.foundry/bin:$HOME/.drosera/bin:$HOME/.bun/bin:$PATH"

# Install Foundry tools
$HOME/.foundry/bin/foundryup || echo "It's normal if foundryup shows a usage message."

# Verify installed tools
echo -e "\n${YELLOW}Checking installed tools...${RESET}"
which forge || error_exit "Forge not installed"
which bun || error_exit "Bun not installed"
which drosera || error_exit "Drosera CLI not installed"

# Step 3: Trap Project Setup
echo -e "\n${YELLOW}[Step 3/13] Setting Up Drosera Trap Project...${RESET}"
mkdir -p "$HOME/my-drosera-trap"
cd "$HOME/my-drosera-trap" || error_exit "Cannot create trap directory"

# Git Configuration
git config --global user.email "user@example.com"
git config --global user.name "DroseraUser"

# Initialize Trap Project
$HOME/.foundry/bin/forge init -t drosera-network/trap-foundry-template
$HOME/.bun/bin/bun install
$HOME/.foundry/bin/forge build

# Create Drosera Configuration
cat > drosera.toml << EOL
# Drosera Trap Configuration
private_trap = true
whitelist = ["$EVM_PUBLIC_ADDRESS"]
EOL

# Step 4: Deploy Trap
echo -e "\n${YELLOW}[Step 4/13] Deploying Trap...${RESET}"
DROSERA_PRIVATE_KEY="$EVM_PRIVATE_KEY" $HOME/.drosera/bin/drosera apply
TRAP_ADDRESS=$(grep 'address =' drosera.toml | awk '{print $3}')
echo -e "Trap deployed! Address: ${GREEN}$TRAP_ADDRESS${RESET}"

# Step 5: Bloom Boost Trap
echo -e "\n${YELLOW}[Step 5/13] Bloom Boosting Trap...${RESET}"
read -p "Enter the amount of Holesky ETH to deposit for Bloom Boost (default 0.1): " ETH_AMOUNT
ETH_AMOUNT=${ETH_AMOUNT:-0.1}
$HOME/.drosera/bin/drosera bloomboost --trap-address "$TRAP_ADDRESS" --eth-amount "$ETH_AMOUNT"

# Step 6: Fetch Blocks
echo -e "\n${YELLOW}[Step 6/13] Fetching Blocks...${RESET}"
$HOME/.drosera/bin/drosera dryrun

# Step 7: Install Operator CLI
echo -e "\n${YELLOW}[Step 7/13] Installing Operator CLI...${RESET}"
cd "$HOME" || error_exit "Cannot change to home directory"
OPERATOR_VERSION="v1.16.2"
curl -LO "https://github.com/drosera-network/releases/releases/download/${OPERATOR_VERSION}/drosera-operator-${OPERATOR_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
tar -xvf "drosera-operator-${OPERATOR_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
sudo cp drosera-operator /usr/bin
drosera-operator --version

# Step 8: Register Operator
echo -e "\n${YELLOW}[Step 8/13] Registering Operator...${RESET}"
drosera-operator register --eth-rpc-url "$ETH_RPC_URL" --eth-private-key "$EVM_PRIVATE_KEY"

# Step 9: Configure Firewall
echo -e "\n${YELLOW}[Step 9/13] Configuring Firewall...${RESET}"
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp
sudo ufw --force enable

# Step 10: Opt-in Trap
echo -e "\n${YELLOW}[Step 10/13] Opting into Trap...${RESET}"
drosera-operator optin --eth-rpc-url "$ETH_RPC_URL" --eth-private-key "$EVM_PRIVATE_KEY" --trap-config-address "$TRAP_ADDRESS"

# Step 11: Configure SystemD Service
echo -e "\n${YELLOW}[Step 11/13] Configuring SystemD Service...${RESET}"
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

# Step 12: Start SystemD Service
echo -e "\n${YELLOW}[Step 12/13] Starting Drosera Node Service...${RESET}"
sudo systemctl daemon-reload
sudo systemctl enable drosera
sudo systemctl start drosera

# Final Step: Display Information
echo -e "\n${GREEN}=== Drosera Network Setup Complete! ===${RESET}"
echo -e "${BLUE}Node Information:${RESET}"
echo -e "  - Operator Address: ${YELLOW}$EVM_PUBLIC_ADDRESS${RESET}"
echo -e "  - Trap Address: ${YELLOW}$TRAP_ADDRESS${RESET}"
echo -e "  - External IP: ${YELLOW}$VPS_IP${RESET}"
echo -e "  - Primary RPC: ${YELLOW}$ETH_RPC_URL${RESET}"

echo -e "\n${BLUE}Useful Commands:${RESET}"
echo -e "  - Check node logs: ${YELLOW}journalctl -u drosera.service -f${RESET}"
echo -e "  - Stop node: ${YELLOW}sudo systemctl stop drosera${RESET}"
echo -e "  - Restart node: ${YELLOW}sudo systemctl restart drosera${RESET}"

echo -e "\n${GREEN}Node Status:${RESET} https://app.drosera.io/trap?trapId=$TRAP_ADDRESS"

echo -e "\n${YELLOW}Note: If you see 'WARN drosera_services::network::service: Failed to gossip message: InsufficientPeers', this is normal.${RESET}"
