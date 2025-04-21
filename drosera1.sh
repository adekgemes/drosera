#!/bin/bash

# Function to derive public address from private key (simplified placeholder)
derive_address_from_private_key() {
    # In a real scenario, use a tool like `cast` from Foundry or an Ethereum library
    # Here, we simulate it for simplicity (replace with actual derivation if needed)
    echo "0x$(echo $1 | sha256sum | head -c 40)"
}

# Beautiful ASCII Art Intro
echo -e "\e[1;32m"
curl -s https://raw.githubusercontent.com/dlzvy/LOGOTES/main/logo3.sh | bash
sleep 5
echo -e "\e[0m"
echo ""

# Prompt for EVM private key
read -p "Enter your EVM private key (Make sure it's funded with Testnet Holesky ETH): " EVM_PRIVATE_KEY
if [ -z "$EVM_PRIVATE_KEY" ]; then
    echo "Error: EVM private key is required. Exiting."
    exit 1
fi
echo "Deriving your public address in the background..."
EVM_PUBLIC_ADDRESS=$(derive_address_from_private_key "$EVM_PRIVATE_KEY")
echo "Public address derived: $EVM_PUBLIC_ADDRESS"

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
echo "Using IP: $VPS_IP"

# Prompt for Holesky Ethereum RPC URL
read -p "Enter your Holesky Ethereum RPC URL (or press Enter to use default): " ETH_RPC_URL
if [ -z "$ETH_RPC_URL" ]; then
    ETH_RPC_URL="https://ethereum-holesky-rpc.publicnode.com"
    echo "Using default RPC URL: $ETH_RPC_URL"
else
    echo "Using provided RPC URL: $ETH_RPC_URL"
fi

# Prompt for backup RPC URL
read -p "Enter your backup Holesky Ethereum RPC URL (or press Enter to use default): " ETH_BACKUP_RPC_URL
if [ -z "$ETH_BACKUP_RPC_URL" ]; then
    ETH_BACKUP_RPC_URL="https://1rpc.io/holesky"
    echo "Using default backup RPC URL: $ETH_BACKUP_RPC_URL"
else
    echo "Using provided backup RPC URL: $ETH_BACKUP_RPC_URL"
fi

# Step 1: Install Dependencies
echo -e "\n\e[1;33mStep 1: Installing system dependencies...\e[0m"
echo "This ensures your system has all required tools and libraries."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install curl ufw iptables build-essential git wget jq make gcc nano tmux htop pkg-config libssl-dev tar unzip -y

# Step 2: Install Drosera CLI and Operator CLI
echo -e "\n\e[1;33mStep 2: Installing Drosera CLI and Operator CLI...\e[0m"
echo "These tools are needed to deploy and manage your trap."

# Install Drosera CLI
curl -L https://app.drosera.io/install | bash
# Add Drosera CLI to PATH (assuming it installs to ~/.drosera/bin)
export PATH=$PATH:~/.drosera/bin
# Verify installation
droseraup

# Install Operator CLI
cd ~
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
sudo cp drosera-operator /usr/bin
drosera-operator --version

# Step 3: Open Ports
echo -e "\n\e[1;33mStep 3: Opening Ports...\e[0m"
echo "Configuring firewall to allow Drosera traffic."
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp
sudo ufw enable

# Step 4: Register Operator
echo -e "\n\e[1;33mStep 4: Registering Operator...\e[0m"
echo "Registering your operator with the network."
drosera-operator register --eth-rpc-url "$ETH_RPC_URL" --eth-private-key "$EVM_PRIVATE_KEY"

# Step 5: Configure SystemD Service
echo -e "\n\e[1;33mStep 5: Configuring SystemD service...\e[0m"
echo "Creating a systemd service for automatic startup and management."

# Create the systemd service file
echo "Creating systemd service file..."
sudo tee /etc/systemd/system/drosera.service > /dev/null << EOF
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

# Step 6: Run Operator
echo -e "\n\e[1;33mStep 6: Starting the Drosera operator service...\e[0m"
echo "Enabling and starting the service."

# Reload systemd and enable/start service
sudo systemctl daemon-reload
sudo systemctl enable drosera
sudo systemctl start drosera

# Final Instructions
echo -e "\n\e[1;32mSetup Complete!\e[0m"
echo "Your Drosera operator is now running as a systemd service."
echo "You can check the node health with: journalctl -u drosera.service -f"
echo ""
echo "Note: If you see 'WARN drosera_services::network::service: Failed to gossip message: InsufficientPeers'"
echo "      this is normal and not a problem."
echo ""
echo "Optional commands:"
echo "  - Stop node:     sudo systemctl stop drosera"
echo "  - Restart node:  sudo systemctl restart drosera"
echo ""
echo "To opt-in to a trap, use this command (replace TRAP_ADDRESS with actual trap address):"
echo "drosera-operator optin --eth-rpc-url $ETH_RPC_URL --eth-private-key $EVM_PRIVATE_KEY --trap-config-address TRAP_ADDRESS"
echo ""
echo "After opting into a trap, check the liveness of your node at: https://app.drosera.io/trap?trapId=TRAP_ADDRESS"
