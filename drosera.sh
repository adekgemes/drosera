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

# Manually source the updated PATH
if [ -f "/root/.bashrc" ]; then
    source /root/.bashrc
fi
export PATH="$HOME/.drosera/bin:$PATH"

# Try to run droseraup if available, otherwise continue
print_yellow "Running droseraup if available..."
if command -v droseraup &> /dev/null; then
    droseraup
    print_green "Drosera CLI installed via droseraup."
else
    print_yellow "droseraup not found, proceeding without it..."
fi

print_yellow "Installing Foundry..."
curl -L https://foundry.paradigm.xyz | bash
check_error "installing Foundry"

# Source the updated PATH for foundry
if [ -f "/root/.bashrc" ]; then
    source /root/.bashrc
fi
export PATH="$HOME/.foundry/bin:$PATH"

# Try to run foundryup if available
print_yellow "Running foundryup if available..."
if command -v foundryup &> /dev/null; then
    foundryup
    print_green "Foundry installed via foundryup."
else
    print_yellow "foundryup not found, trying to find it in common locations..."
    if [ -f "$HOME/.foundry/bin/foundryup" ]; then
        $HOME/.foundry/bin/foundryup
        print_green "Foundry installed via local foundryup."
    else
        print_yellow "foundryup not found, proceeding without it..."
    fi
fi

print_yellow "Installing Bun..."
curl -fsSL https://bun.sh/install | bash
check_error "installing Bun"

# Source the updated PATH for bun
if [ -f "/root/.bashrc" ]; then
    source /root/.bashrc
fi
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

print_yellow "Setting up Drosera trap project..."
mkdir -p my-drosera-trap
cd my-drosera-trap

git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"

# Check for forge and use it with explicit path if necessary
print_yellow "Initializing trap foundry template..."
if command -v forge &> /dev/null; then
    forge init -t drosera-network/trap-foundry-template
    check_error "initializing trap foundry template"
elif [ -f "$HOME/.foundry/bin/forge" ]; then
    $HOME/.foundry/bin/forge init -t drosera-network/trap-foundry-template
    check_error "initializing trap foundry template with local forge"
else
    print_red "forge command not found. Please install Foundry manually and try again."
    exit 1
fi

# Check for bun and use it with explicit path if necessary
print_yellow "Installing dependencies with bun..."
if command -v bun &> /dev/null; then
    bun install
    check_error "running bun install"
elif [ -f "$HOME/.bun/bin/bun" ]; then
    $HOME/.bun/bin/bun install
    check_error "running bun install with local bun"
else
    print_red "bun command not found. Please install Bun manually and try again."
    exit 1
fi

# Build the project with forge
print_yellow "Building the project..."
if command -v forge &> /dev/null; then
    forge build
    check_error "running forge build"
elif [ -f "$HOME/.foundry/bin/forge" ]; then
    $HOME/.foundry/bin/forge build
    check_error "running forge build with local forge"
else
    print_red "forge command not found. Please install Foundry manually and try again."
    exit 1
fi

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
