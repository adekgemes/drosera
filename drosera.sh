#!/bin/bash

# Drosera Network One-Click Installer
# This script automates the installation of Drosera Network node

# Display logo
curl -s https://raw.githubusercontent.com/dlzvy/LOGOTES/main/logo1.sh | bash
sleep 5

# Text colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command executed successfully
check_success() {
    if [ $? -eq 0 ]; then
        print_message "$1 completed successfully."
    else
        print_error "$1 failed. Exiting..."
        exit 1
    fi
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Get user information
read -p "Enter your EVM wallet private key (for Drosera operations): " DROSERA_PRIVATE_KEY
read -p "Enter your VPS public IP address: " VPS_IP
read -p "Enter your GitHub email: " GITHUB_EMAIL
read -p "Enter your GitHub username: " GITHUB_USERNAME
read -p "Choose installation method (1 for Docker, 2 for SystemD): " INSTALL_METHOD

# Validate private key
if [[ ! $DROSERA_PRIVATE_KEY =~ ^[0-9a-fA-F]{64}$ ]]; then
    print_warning "Private key format looks unusual. Make sure it's correct (64 hex characters without '0x' prefix)."
    read -p "Continue anyway? (y/n): " CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Validate IP address
if [[ ! $VPS_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_error "Invalid IP address format. Please use a valid IPv4 address."
    exit 1
fi

# Start installation
print_message "Starting Drosera Network installation..."

# Update system
print_message "Updating system packages..."
apt-get update && apt-get upgrade -y
check_success "System update"

# Install dependencies
print_message "Installing dependencies..."
apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y
check_success "Dependencies installation"

# Install Docker
print_message "Installing Docker..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do apt-get remove $pkg -y; done

apt-get update
apt-get install ca-certificates curl gnupg -y
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update -y && apt upgrade -y
apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
check_success "Docker installation"

# Test Docker
print_message "Testing Docker installation..."
docker run hello-world
check_success "Docker test"

# Install Drosera CLI
print_message "Installing Drosera CLI..."
curl -L https://app.drosera.io/install | bash
source /root/.bashrc
droseraup
check_success "Drosera CLI installation"

# Install Foundry CLI
print_message "Installing Foundry CLI..."
curl -L https://foundry.paradigm.xyz | bash
source /root/.bashrc
foundryup
check_success "Foundry CLI installation"

# Install Bun
print_message "Installing Bun..."
curl -fsSL https://bun.sh/install | bash
source /root/.bashrc
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
check_success "Bun installation"

# Set up the trap
print_message "Setting up Drosera Trap..."
mkdir -p my-drosera-trap
cd my-drosera-trap

# Configure Git
git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"

# Initialize Trap
print_message "Initializing Trap..."
forge init -t drosera-network/trap-foundry-template
check_success "Trap initialization"

# Compile Trap
print_message "Compiling Trap..."
bun install
forge build
check_success "Trap compilation"

# Deploy Trap
print_message "Deploying Trap..."
echo "DROSERA_PRIVATE_KEY=$DROSERA_PRIVATE_KEY drosera apply"
echo "When prompted, type 'ofc' and press Enter"
DROSERA_PRIVATE_KEY=$DROSERA_PRIVATE_KEY drosera apply

# Make the trap private and whitelist operator
print_message "Configuring private trap..."
cat >> drosera.toml << EOF

private_trap = true
whitelist = ["$(echo $DROSERA_PRIVATE_KEY | python3 -c "import sys, web3; pk = sys.stdin.read().strip(); w3 = web3.Web3(); print(w3.eth.account.from_key(pk).address)")"]
EOF

print_message "Updating trap configuration..."
DROSERA_PRIVATE_KEY=$DROSERA_PRIVATE_KEY drosera apply

# Install Operator CLI
print_message "Installing Operator CLI..."
cd ~
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
cp drosera-operator /usr/bin/
chmod +x /usr/bin/drosera-operator
check_success "Operator CLI installation"

# Test operator CLI
drosera-operator --version
check_success "Operator CLI test"

# Pull Docker image
print_message "Pulling Drosera Operator Docker image..."
docker pull ghcr.io/drosera-network/drosera-operator:latest
check_success "Docker image pull"

# Register operator
print_message "Registering operator..."
drosera-operator register --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key $DROSERA_PRIVATE_KEY
check_success "Operator registration"

# Configure firewall
print_message "Configuring firewall..."
ufw allow ssh
ufw allow 22
ufw allow 31313/tcp
ufw allow 31314/tcp
ufw --force enable
check_success "Firewall configuration"

# Install and run operator based on chosen method
if [ "$INSTALL_METHOD" -eq "1" ]; then
    # Docker method
    print_message "Setting up operator using Docker..."
    
    # Stop systemd service if running
    systemctl stop drosera 2>/dev/null
    systemctl disable drosera 2>/dev/null
    
    # Clone repository
    cd ~
    git clone https://github.com/0xmoei/Drosera-Network
    cd Drosera-Network
    cp .env.example .env
    
    # Update .env file
    sed -i "s/your_evm_private_key/$DROSERA_PRIVATE_KEY/g" .env
    sed -i "s/your_vps_public_ip/$VPS_IP/g" .env
    
    # Start Docker container
    docker compose up -d
    check_success "Docker operator setup"
    
    print_message "Operator logs (press Ctrl+C to exit logs):"
    docker compose logs -f
    
elif [ "$INSTALL_METHOD" -eq "2" ]; then
    # SystemD method
    print_message "Setting up operator using SystemD..."
    
    # Create service file
    tee /etc/systemd/system/drosera.service > /dev/null <<EOF
[Unit]
Description=drosera node service
After=network-online.target

[Service]
User=$USER
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=$(which drosera-operator) node --db-file-path $HOME/.drosera.db --network-p2p-port 31313 --server-port 31314 \\
    --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com \\
    --eth-backup-rpc-url https://1rpc.io/holesky \\
    --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \\
    --eth-private-key $DROSERA_PRIVATE_KEY \\
    --listen-address 0.0.0.0 \\
    --network-external-p2p-address $VPS_IP \\
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF
    
    # Start service
    systemctl daemon-reload
    systemctl enable drosera
    systemctl start drosera
    check_success "SystemD operator setup"
    
    print_message "Operator logs (press Ctrl+C to exit logs):"
    journalctl -u drosera.service -f
else
    print_error "Invalid installation method selected. Choose 1 for Docker or 2 for SystemD."
    exit 1
fi

# Print completion message
print_message "=========================================================="
print_message "Drosera Network installation completed!"
print_message "What to do next:"
print_message "1. Connect your Drosera EVM wallet at: https://app.drosera.io/"
print_message "2. Click on 'Traps Owned' to see your deployed Traps"
print_message "3. Open your Trap and click 'Send Bloom Boost' to deposit some Holesky ETH"
print_message "4. Click 'Opt-in' to connect your operator to the Trap"
print_message "5. Run 'drosera dryrun' to fetch blocks"
print_message "=========================================================="
print_message "Docker commands (if using Docker method):"
print_message "- To stop: cd ~/Drosera-Network && docker compose down -v"
print_message "- To restart: cd ~/Drosera-Network && docker compose up -d"
print_message "SystemD commands (if using SystemD method):"
print_message "- To stop: sudo systemctl stop drosera"
print_message "- To restart: sudo systemctl restart drosera"
print_message "- To view logs: journalctl -u drosera.service -f"
print_message "=========================================================="
