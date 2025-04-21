#!/bin/bash

# Display ASCII Art Intro
echo -e "\e[1;32m"
curl -s https://raw.githubusercontent.com/dlzvy/LOGOTES/main/logo3.sh | bash
sleep 3
echo -e "\e[0m"
echo ""

echo -e "\e[1;36m=========== Drosera Network One-Click Installer (SystemD Version) ===========\e[0m"
echo -e "\e[1;33mThis script will install and configure a Drosera Network operator node.\e[0m"
echo ""

# Function to derive public address from private key
derive_address_from_private_key() {
    echo "0x$(echo $1 | sha256sum | head -c 40)"
}

# Collect user information
echo -e "\e[1;36m=== Required Information ===\e[0m"
read -p "Enter your EVM private key (Must be funded with Holesky ETH): " EVM_PRIVATE_KEY
if [ -z "$EVM_PRIVATE_KEY" ]; then
    echo "Error: EVM private key is required. Exiting."
    exit 1
fi

# Derive public address
echo "Deriving your public address..."
EVM_PUBLIC_ADDRESS=$(derive_address_from_private_key "$EVM_PRIVATE_KEY")
echo -e "Public address derived: \e[1;33m$EVM_PUBLIC_ADDRESS\e[0m"
echo ""

# Prompt for VPS public IP
read -p "Enter your VPS public IP (or type 'local' to use 0.0.0.0): " VPS_IP_INPUT
if [ -z "$VPS_IP_INPUT" ]; then
    echo "Error: VPS public IP is required. Exiting."
    exit 1
fi

# Set VPS_IP based on input
if [ "$VPS_IP_INPUT" = "local" ]; then
    VPS_IP="0.0.0.0"
else
    VPS_IP="$VPS_IP_INPUT"
fi
echo -e "Using IP: \e[1;33m$VPS_IP\e[0m"

# Prompt for Holesky Ethereum RPC URL
read -p "Enter your Holesky Ethereum RPC URL (or press Enter to use default): " ETH_RPC_URL
if [ -z "$ETH_RPC_URL" ]; then
    ETH_RPC_URL="https://ethereum-holesky-rpc.publicnode.com"
    echo -e "Using default RPC URL: \e[1;33m$ETH_RPC_URL\e[0m"
else
    echo -e "Using provided RPC URL: \e[1;33m$ETH_RPC_URL\e[0m"
fi

# Prompt for backup RPC URL
read -p "Enter your backup Holesky Ethereum RPC URL (or press Enter to use default): " ETH_BACKUP_RPC_URL
if [ -z "$ETH_BACKUP_RPC_URL" ]; then
    ETH_BACKUP_RPC_URL="https://1rpc.io/holesky"
    echo -e "Using default backup RPC URL: \e[1;33m$ETH_BACKUP_RPC_URL\e[0m"
fi

echo ""
echo -e "\e[1;36m=== Installation Process Starting ===\e[0m"
echo "This may take several minutes. Please be patient."
echo ""

# Step 1: Install Dependencies
echo -e "\e[1;33m[Step 1/7] Installing system dependencies...\e[0m"
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install curl ufw iptables build-essential git wget jq make gcc nano tmux htop pkg-config libssl-dev tar unzip -y

# Step 2: Install Drosera CLI
echo -e "\n\e[1;33m[Step 2/7] Installing Drosera CLI...\e[0m"
curl -L https://app.drosera.io/install | bash
source $HOME/.bashrc
export PATH=$PATH:$HOME/.drosera/bin
droseraup || echo "It's normal if droseraup shows a usage message."

# Step 3: Install Foundry CLI and Bun
echo -e "\n\e[1;33m[Step 3/7] Installing Foundry CLI and Bun...\e[0m"
curl -L https://foundry.paradigm.xyz | bash
source $HOME/.bashrc
export PATH=$PATH:$HOME/.foundry/bin
foundryup || echo "It's normal if foundryup shows a usage message."

curl -fsSL https://bun.sh/install | bash
source $HOME/.bashrc
export PATH=$PATH:$HOME/.bun/bin

# Step 4: Install Operator CLI
echo -e "\n\e[1;33m[Step 4/7] Installing Operator CLI...\e[0m"
cd $HOME
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
sudo cp drosera-operator /usr/bin
drosera-operator --version

# Step 5: Configure Firewall
echo -e "\n\e[1;33m[Step 5/7] Configuring firewall...\e[0m"
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp
sudo ufw --force enable

# Step 6: Register Operator
echo -e "\n\e[1;33m[Step 6/7] Registering operator with the network...\e[0m"
drosera-operator register --eth-rpc-url "$ETH_RPC_URL" --eth-private-key "$EVM_PRIVATE_KEY"

# Step 7: Configure and Start SystemD Service
echo -e "\n\e[1;33m[Step 7/7] Setting up SystemD service...\e[0m"
sudo tee /etc/systemd/system/drosera.service > /dev/null <<EOF
[Unit]
Description=drosera node service
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
echo -e "\e[1;32m=== Drosera Node Successfully Installed! ===\e[0m"
echo ""
echo -e "\e[1;36mNode Information:\e[0m"
echo -e "  - Operator Address: \e[1;33m$EVM_PUBLIC_ADDRESS\e[0m"
echo -e "  - External IP: \e[1;33m$VPS_IP\e[0m"
echo -e "  - Primary RPC: \e[1;33m$ETH_RPC_URL\e[0m"
echo ""
echo -e "\e[1;36mUseful Commands:\e[0m"
echo -e "  - Check node logs: \e[1;33mjournalctl -u drosera.service -f\e[0m"
echo -e "  - Stop node: \e[1;33msudo systemctl stop drosera\e[0m" 
echo -e "  - Restart node: \e[1;33msudo systemctl restart drosera\e[0m"
echo ""
echo -e "\e[1;36mTo Change RPC URLs Later:\e[0m"
echo -e "1. Edit the service file: \e[1;33msudo nano /etc/systemd/system/drosera.service\e[0m"
echo -e "2. Modify the --eth-rpc-url and --eth-backup-rpc-url values"
echo -e "3. Save the file (Ctrl+X, then Y, then Enter)"
echo -e "4. Reload and restart: \e[1;33msudo systemctl daemon-reload && sudo systemctl restart drosera\e[0m"
echo ""
echo -e "\e[1;36mNext Steps:\e[0m"
echo -e "1. Deploy a trap (if you haven't already) with: \e[1;33mDROSERA_PRIVATE_KEY=$EVM_PRIVATE_KEY drosera apply\e[0m"
echo -e "2. Bloom boost your trap with: \e[1;33mdrosera bloomboost --trap-address YOUR_TRAP_ADDRESS --eth-amount AMOUNT_ETH\e[0m"
echo -e "   (Replace YOUR_TRAP_ADDRESS with your trap address and AMOUNT_ETH with the amount to deposit, e.g., 0.1)"
echo -e "3. Opt-in to your trap with: \e[1;33mdrosera-operator optin --eth-rpc-url $ETH_RPC_URL --eth-private-key $EVM_PRIVATE_KEY --trap-config-address YOUR_TRAP_ADDRESS\e[0m"
echo -e "4. Check your node status at: \e[1;33mhttps://app.drosera.io/trap?trapId=YOUR_TRAP_ADDRESS\e[0m"
echo ""
echo -e "\e[1;33mNote: If you see 'WARN drosera_services::network::service: Failed to gossip message: InsufficientPeers',\nthis is normal and not a problem.\e[0m"
echo ""
echo -e "\e[1;32mThank you for running a Drosera Network node!\e[0m"
