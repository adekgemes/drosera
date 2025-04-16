#!/bin/bash

# Display Logo Banner
curl -s https://raw.githubusercontent.com/dlzvy/LOGOTES/main/logo1.sh | bash
sleep 5

# Drosera Network One-Installer Script

# Update and Upgrade System
echo "Updating and upgrading system..."
sudo apt-get update && sudo apt-get upgrade -y

# Install Dependencies
echo "Installing required dependencies..."
sudo apt install -y curl ufw iptables build-essential git wget lz4 jq make gcc nano \
    automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev \
    libleveldb-dev tar clang bsdmainutils ncdu unzip

# Remove existing Docker packages
echo "Preparing Docker installation..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
    sudo apt-get remove $pkg; 
done

# Install Docker
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  \"$(. /etc/os-release && echo "$VERSION_CODENAME")\" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y && sudo apt upgrade -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Test Docker
echo "Testing Docker installation..."
sudo docker run hello-world

# Install Drosera CLI
echo "Installing Drosera CLI..."
curl -L https://app.drosera.io/install | bash
source /root/.bashrc
droseraup

# Install Foundry CLI
echo "Installing Foundry CLI..."
curl -L https://foundry.paradigm.xyz | bash
source /root/.bashrc
foundryup

# Install Bun
echo "Installing Bun..."
curl -fsSL https://bun.sh/install | bash

# Prompt for necessary configurations
read -p "Enter your Github Email: " github_email
read -p "Enter your Github Username: " github_username
read -p "Enter your EVM Wallet Private Key: " private_key
read -p "Enter your Operator Address: " operator_address
read -p "Enter your VPS IP (use localhost if local): " vps_ip

# Setup Git Configuration
git config --global user.email "$github_email"
git config --global user.name "$github_username"

# Prepare Drosera Trap
echo "Setting up Drosera Trap..."
mkdir -p ~/my-drosera-trap
cd ~/my-drosera-trap

# Initialize and Build Trap
forge init -t drosera-network/trap-foundry-template
bun install
forge build

# Deploy Trap
export DROSERA_PRIVATE_KEY="$private_key"
drosera apply

# Configure Trap as Private
cat << EOF >> drosera.toml
private_trap = true
whitelist = ["$operator_address"]
EOF

# Reapply Trap Configuration
drosera apply

# Install Operator CLI
echo "Installing Drosera Operator CLI..."
cd ~
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
sudo cp drosera-operator /usr/bin

# Register Operator
drosera-operator register --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key "$private_key"

# Create Systemd Service
sudo tee /etc/systemd/system/drosera.service > /dev/null <<EOF
[Unit]
Description=drosera node service
After=network-online.target

[Service]
User=$USER
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=$(which drosera-operator) node --db-file-path $HOME/.drosera.db --network-p2p-port 31313 --server-port 31314 \
    --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com \
    --eth-backup-rpc-url https://1rpc.io/holesky \
    --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \
    --eth-private-key "$private_key" \
    --listen-address 0.0.0.0 \
    --network-external-p2p-address "$vps_ip" \
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF

# Configure Firewall
echo "Configuring Firewall..."
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp
sudo ufw enable

# Start Drosera Operator
echo "Starting Drosera Operator..."
sudo systemctl daemon-reload
sudo systemctl enable drosera
sudo systemctl start drosera

echo "Drosera Network setup complete!"
echo "Check node health with: journalctl -u drosera.service -f"
echo "Remember to opt-in your trap in the Drosera dashboard."
