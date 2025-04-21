#!/bin/bash

# Color variables
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to display colored text
print_green() {
    echo -e "${GREEN}$1${NC}"
}

print_yellow() {
    echo -e "${YELLOW}$1${NC}"
}

print_red() {
    echo -e "${RED}$1${NC}"
}

# Error handling function
check_error() {
    if [ $? -ne 0 ]; then
        print_red "Error occurred during: $1"
        exit 1
    fi
}

# Function to get user input with validation
get_input() {
    local prompt="$1"
    local var_name="$2"
    local input=""
    while [ -z "$input" ]; do
        read -p "$prompt" input
        if [ -z "$input" ]; then
            print_red "Input cannot be empty. Please try again."
        fi
    done
    eval "$var_name=\"$input\""
}

# Function to get optional input
get_optional_input() {
    local prompt="$1"
    local var_name="$2"
    local default="$3"
    read -p "$prompt" input
    if [ -z "$input" ]; then
        eval "$var_name=\"$default\""
    else
        eval "$var_name=\"$input\""
    fi
}

clear
# Display custom logo
curl -s https://raw.githubusercontent.com/dlzvy/LOGOTES/main/logo3.sh | bash
sleep 5

print_green "==========================================="
print_green "    Drosera Network Auto Installer Script   "
print_green "==========================================="
echo ""

# Collect user information
print_yellow "Please provide the following information:"
get_input "Enter your Github Email: " GITHUB_EMAIL
get_input "Enter your Github Username: " GITHUB_USERNAME
get_input "Enter your EVM Wallet Public Address (Operator Address): " OPERATOR_ADDRESS
get_input "Enter your Drosera EVM Private Key: " PRIVATE_KEY
get_input "Enter your Primary RPC URL: " PRIMARY_RPC
get_input "Enter your Backup RPC URL: " BACKUP_RPC
get_optional_input "Enter your VPS IP Address (or press Enter for default 0.0.0.0): " VPS_IP "0.0.0.0"

print_yellow "Installing dependencies..."
sudo apt-get update && sudo apt-get upgrade -y
check_error "update and upgrade"

sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y
check_error "installing dependencies"

print_yellow "Setting up Docker..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y && sudo apt upgrade -y
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
check_error "installing Docker"

print_yellow "Testing Docker..."
sudo docker run hello-world
check_error "Docker test"

print_yellow "Installing Drosera..."
curl -L https://app.drosera.io/install | bash
check_error "installing Drosera"

# Properly export the PATH to include the Drosera binaries
print_yellow "Setting up Drosera in PATH..."
export PATH="$HOME/.drosera/bin:$PATH"
if [ -f "/root/.bashrc" ]; then
    source /root/.bashrc
fi

# Install Drosera directly instead of using droseraup
print_yellow "Installing Drosera CLI..."
curl -L https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-cli-v1.16.2-x86_64-unknown-linux-gnu.tar.gz -o drosera-cli.tar.gz
tar -xzf drosera-cli.tar.gz
sudo mv drosera /usr/local/bin/
check_error "installing Drosera CLI"

print_yellow "Installing Foundry..."
curl -L https://foundry.paradigm.xyz | bash
check_error "installing Foundry"

# Source foundryup command
if [ -f "/root/.foundry/bin/foundryup" ]; then
    export PATH="$PATH:/root/.foundry/bin"
    /root/.foundry/bin/foundryup
else
    print_yellow "Foundryup not found at expected location, trying alternative..."
    if [ -f "$HOME/.foundry/bin/foundryup" ]; then
        export PATH="$PATH:$HOME/.foundry/bin"
        $HOME/.foundry/bin/foundryup
    else
        print_red "Could not locate foundryup. Continuing anyway..."
    fi
fi
check_error "running foundryup"

print_yellow "Installing Bun..."
curl -fsSL https://bun.sh/install | bash
check_error "installing Bun"

# Export Bun to PATH
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
if [ -f "/root/.bashrc" ]; then
    source /root/.bashrc
fi

print_yellow "Setting up Drosera trap project..."
mkdir -p my-drosera-trap
cd my-drosera-trap

git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"

# Use direct forge command with full path if needed
if command -v forge &> /dev/null; then
    forge init -t drosera-network/trap-foundry-template
else
    if [ -f "$HOME/.foundry/bin/forge" ]; then
        $HOME/.foundry/bin/forge init -t drosera-network/trap-foundry-template
    else
        print_red "forge command not found. Please install Foundry manually."
        exit 1
    fi
fi
check_error "initializing trap foundry template"

# Run bun install with full path if needed
if command -v bun &> /dev/null; then
    bun install
else
    if [ -f "$HOME/.bun/bin/bun" ]; then
        $HOME/.bun/bin/bun install
    else
        print_red "bun command not found. Please install Bun manually."
        exit 1
    fi
fi
check_error "running bun install"

# Run forge build with full path if needed
if command -v forge &> /dev/null; then
    forge build
else
    if [ -f "$HOME/.foundry/bin/forge" ]; then
        $HOME/.foundry/bin/forge build
    else
        print_red "forge command not found. Please install Foundry manually."
        exit 1
    fi
fi
check_error "running forge build"

print_yellow "Configuring drosera.toml..."
cat <<EOF >> drosera.toml

private_trap = true
whitelist = ["$OPERATOR_ADDRESS"]
EOF
check_error "configuring drosera.toml"

print_yellow "Installing Drosera Operator..."
cd ~
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
check_error "downloading Drosera Operator"

tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
check_error "extracting Drosera Operator"

sudo cp drosera-operator /usr/bin
check_error "moving Drosera Operator to /usr/bin"

print_yellow "Registering Drosera Operator..."
drosera-operator register --eth-rpc-url $PRIMARY_RPC --eth-private-key $PRIVATE_KEY
check_error "registering Drosera Operator"

print_yellow "Configuring firewall..."
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp
echo "y" | sudo ufw enable
check_error "configuring firewall"

print_yellow "Creating systemd service..."
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
    --eth-rpc-url $PRIMARY_RPC \
    --eth-backup-rpc-url $BACKUP_RPC \
    --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \
    --eth-private-key $PRIVATE_KEY \
    --listen-address 0.0.0.0 \
    --network-external-p2p-address $VPS_IP \
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF
check_error "creating systemd service"

print_yellow "Starting Drosera service..."
sudo systemctl daemon-reload
sudo systemctl enable drosera
sudo systemctl start drosera
check_error "starting Drosera service"

print_green "=============================================="
print_green "          Installation Completed!             "
print_green "=============================================="
print_yellow "Next steps:"
print_yellow "1. Connect your Drosera EVM wallet at https://app.drosera.io/"
print_yellow "2. Click on Traps Owned to see your deployed Traps"
print_yellow "3. Bloom Boost your Trap by depositing some Holesky ETH on it"
print_yellow "4. Run 'drosera dryrun' to fetch blocks"
print_yellow "5. Check node health with: journalctl -u drosera.service -f"
echo ""
print_green "Thank you for using the Drosera Network Auto Installer!"
