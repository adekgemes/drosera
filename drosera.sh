#!/bin/bash

curl -s https://raw.githubusercontent.com/dlzvy/LOGOTES/main/logo3.sh | bash
sleep 5

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_success() {
    if [ $? -eq 0 ]; then
        print_message "$1 completed successfully."
    else
        print_error "$1 failed. Exiting..."
        exit 1
    fi
}

if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

read -p "Enter your EVM wallet private key (for Drosera operations): " DROSERA_PRIVATE_KEY
read -p "Enter your VPS public IP address: " VPS_IP
read -p "Enter your GitHub email: " GITHUB_EMAIL
read -p "Enter your GitHub username: " GITHUB_USERNAME

read -p "Do you want to use custom RPC endpoints? (y/n): " USE_CUSTOM_RPC
if [[ $USE_CUSTOM_RPC =~ ^[Yy]$ ]]; then
    read -p "Enter your primary Holesky RPC URL: " PRIMARY_RPC_URL
    read -p "Enter your backup Holesky RPC URL (press Enter to skip): " BACKUP_RPC_URL
    
    if [ -z "$PRIMARY_RPC_URL" ]; then
        print_error "Primary RPC URL cannot be empty"
        exit 1
    fi
else
    PRIMARY_RPC_URL="https://ethereum-holesky-rpc.publicnode.com"
    BACKUP_RPC_URL="https://1rpc.io/holesky"
fi

if [[ ! $DROSERA_PRIVATE_KEY =~ ^[0-9a-fA-F]{64}$ ]]; then
    print_warning "Private key format looks unusual. Make sure it's correct (64 hex characters without '0x' prefix)."
    read -p "Continue anyway? (y/n): " CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

if [[ ! $VPS_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_error "Invalid IP address format. Please use a valid IPv4 address."
    exit 1
fi

print_message "Starting Drosera Network installation..."

print_message "Updating system packages..."
apt-get update && apt-get upgrade -y
check_success "System update"

print_message "Installing dependencies..."
apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev python3-pip -y
pip3 install web3
check_success "Dependencies installation"

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

print_message "Testing Docker installation..."
docker run hello-world
check_success "Docker test"

print_message "Installing Drosera CLI..."
curl -L https://app.drosera.io/install | bash
source $HOME/.bashrc
export PATH="$HOME/.drosera/bin:$PATH"
# Instead of calling droseraup directly, check if it exists
if [ -f "$HOME/.drosera/bin/droseraup" ]; then
    $HOME/.drosera/bin/droseraup
elif [ -f "$HOME/.local/bin/droseraup" ]; then
    $HOME/.local/bin/droseraup
else
    print_warning "droseraup command not found, but continuing with installation"
fi
check_success "Drosera CLI installation"

print_message "Installing Foundry CLI..."
curl -L https://foundry.paradigm.xyz | bash
source $HOME/.bashrc
export PATH="$HOME/.foundry/bin:$PATH"
# Check if foundryup exists
if [ -f "$HOME/.foundry/bin/foundryup" ]; then
    $HOME/.foundry/bin/foundryup
else
    print_warning "foundryup command not found, but continuing with installation"
fi
check_success "Foundry CLI installation"

print_message "Installing Bun..."
curl -fsSL https://bun.sh/install | bash
source $HOME/.bashrc
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
check_success "Bun installation"

print_message "Setting up Drosera Trap..."
mkdir -p my-drosera-trap
cd my-drosera-trap

git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"

print_message "Initializing Trap..."
if command -v forge &> /dev/null; then
    forge init -t drosera-network/trap-foundry-template
else
    $HOME/.foundry/bin/forge init -t drosera-network/trap-foundry-template
fi
check_success "Trap initialization"

print_message "Compiling Trap..."
if command -v bun &> /dev/null; then
    bun install
else
    $HOME/.bun/bin/bun install
fi

if command -v forge &> /dev/null; then
    forge build
else
    $HOME/.foundry/bin/forge build
fi
check_success "Trap compilation"

print_message "Deploying Trap..."
echo "When prompted, type 'ofc' and press Enter"
if command -v drosera &> /dev/null; then
    DROSERA_PRIVATE_KEY=$DROSERA_PRIVATE_KEY drosera apply
else
    DROSERA_PRIVATE_KEY=$DROSERA_PRIVATE_KEY $HOME/.drosera/bin/drosera apply || DROSERA_PRIVATE_KEY=$DROSERA_PRIVATE_KEY $HOME/.local/bin/drosera apply
fi

print_message "Configuring private trap..."
cat >> drosera.toml << EOF

private_trap = true
whitelist = ["$(echo $DROSERA_PRIVATE_KEY | python3 -c "import sys, web3; pk = sys.stdin.read().strip(); w3 = web3.Web3(); print(w3.eth.account.from_key(pk).address)")"]
EOF

print_message "Updating trap configuration..."
if command -v drosera &> /dev/null; then
    DROSERA_PRIVATE_KEY=$DROSERA_PRIVATE_KEY drosera apply
else
    DROSERA_PRIVATE_KEY=$DROSERA_PRIVATE_KEY $HOME/.drosera/bin/drosera apply || DROSERA_PRIVATE_KEY=$DROSERA_PRIVATE_KEY $HOME/.local/bin/drosera apply
fi

print_message "Installing Operator CLI..."
cd ~
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
cp drosera-operator /usr/bin/
chmod +x /usr/bin/drosera-operator
check_success "Operator CLI installation"

drosera-operator --version
check_success "Operator CLI test"

print_message "Pulling Drosera Operator Docker image..."
docker pull ghcr.io/drosera-network/drosera-operator:latest
check_success "Docker image pull"

print_message "Registering operator..."
drosera-operator register --eth-rpc-url "$PRIMARY_RPC_URL" --eth-private-key $DROSERA_PRIVATE_KEY
check_success "Operator registration"

print_message "Configuring firewall..."
ufw allow ssh
ufw allow 22
ufw allow 31313/tcp
ufw allow 31314/tcp
ufw --force enable
check_success "Firewall configuration"

print_message "Setting up operator using SystemD..."

BACKUP_RPC_PARAM=""
if [ -n "$BACKUP_RPC_URL" ]; then
    BACKUP_RPC_PARAM="--eth-backup-rpc-url $BACKUP_RPC_URL"
fi

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
    --eth-rpc-url $PRIMARY_RPC_URL \\
    $BACKUP_RPC_PARAM \\
    --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \\
    --eth-private-key $DROSERA_PRIVATE_KEY \\
    --listen-address 0.0.0.0 \\
    --network-external-p2p-address $VPS_IP \\
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable drosera
systemctl start drosera
check_success "SystemD operator setup"

print_message "=========================================================="
print_message "Drosera Network installation completed!"
print_message "What to do next:"
print_message "1. Connect your Drosera EVM wallet at: https://app.drosera.io/"
print_message "2. Click on 'Traps Owned' to see your deployed Traps"
print_message "3. Open your Trap and click 'Send Bloom Boost' to deposit some Holesky ETH"
print_message "4. Click 'Opt-in' to connect your operator to the Trap"
print_message "5. Run 'drosera dryrun' to fetch blocks"
print_message "=========================================================="
print_message "RPC Configuration:"
print_message "- Primary RPC: $PRIMARY_RPC_URL"
if [ -n "$BACKUP_RPC_URL" ]; then
    print_message "- Backup RPC: $BACKUP_RPC_URL"
else
    print_message "- No backup RPC configured"
fi
print_message "=========================================================="
print_message "Useful Commands:"
print_message "- Check status: systemctl status drosera"
print_message "- View logs: journalctl -u drosera.service -f"
print_message "- Stop service: sudo systemctl stop drosera"
print_message "- Restart service: sudo systemctl restart drosera"
print_message "- Check operator version: drosera-operator --version"
print_message "- Check registration: drosera-operator whoami --eth-rpc-url $PRIMARY_RPC_URL"
print_message "=========================================================="

# Let the information stay visible for a while
print_message "Installation complete. This window will remain open so you can note down the information."
print_message "Press Ctrl+C when you're ready to close."
sleep infinity
