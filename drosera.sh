#!/bin/bash

# Drosera Network One-Click Installer
# This script automates the installation of the Drosera Network project components

# Text colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display status messages
function echo_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to display success messages
function echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to display error messages
function echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display warning messages
function echo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to prompt for input
function prompt_input() {
    local prompt="$1"
    local variable="$2"
    local default="$3"
    local is_private="$4"
    
    if [ -n "$default" ]; then
        prompt="$prompt (default: $default)"
    fi
    
    if [ "$is_private" = "true" ]; then
        read -p "$prompt: " -s temp_var
        echo
    else
        read -p "$prompt: " temp_var
    fi
    
    if [ -z "$temp_var" ] && [ -n "$default" ]; then
        eval "$variable='$default'"
    else
        eval "$variable='$temp_var'"
    fi
}

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   echo_error "This script must be run as root" 
   echo "Try: sudo $0"
   exit 1
fi

# Print welcome banner
echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}    Drosera Network Installer    ${NC}"
echo -e "${GREEN}=======================================${NC}"
echo ""
echo "This script will install and configure all components of the Drosera Network."
echo ""
echo "Components to be installed:"
echo " - Required system dependencies"
echo " - Docker"
echo " - Drosera CLI & Operator"
echo " - Foundry & Bun"
echo " - Set up and deploy a Trap"
echo " - Configure and run the Operator node"
echo ""
echo_warning "You will need a funded Holesky ETH wallet for this setup!"
echo ""
echo -e "${YELLOW}Press ENTER to continue or CTRL+C to abort${NC}"
read

# Step 1: Install Dependencies
echo_status "Step 1: Installing system dependencies..."
apt-get update && apt-get upgrade -y || {
    echo_error "Failed to update package repositories"
    exit 1
}

apt-get install -y curl ufw iptables build-essential git wget lz4 jq make gcc nano automake \
    autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang \
    bsdmainutils ncdu unzip libleveldb-dev || {
    echo_error "Failed to install dependencies"
    exit 1
}
echo_success "System dependencies installed"

# Step 2: Install Docker
echo_status "Step 2: Installing Docker..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
    apt-get remove -y $pkg 2>/dev/null
done

apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update && apt-get upgrade -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || {
    echo_error "Failed to install Docker"
    exit 1
}

echo_status "Testing Docker installation..."
docker run hello-world || {
    echo_error "Docker test failed"
    exit 1
}
echo_success "Docker installed and tested successfully"

# Step 3: Install Drosera CLI
echo_status "Step 3: Installing Drosera CLI..."
curl -L https://app.drosera.io/install | bash
echo 'source /root/.bashrc' >> /root/.bashrc
source /root/.bashrc
droseraup
echo_success "Drosera CLI installed"

# Step 4: Install Foundry CLI
echo_status "Step 4: Installing Foundry CLI..."
curl -L https://foundry.paradigm.xyz | bash
source /root/.bashrc
foundryup
echo_success "Foundry CLI installed"

# Step 5: Install Bun
echo_status "Step 5: Installing Bun..."
curl -fsSL https://bun.sh/install | bash
echo_success "Bun installed"

# Step 6: Set up Git configuration
echo_status "Step 6: Setting up Git configuration..."
prompt_input "Enter your GitHub email" GITHUB_EMAIL
prompt_input "Enter your GitHub username" GITHUB_USERNAME

git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"
echo_success "Git configured with email: $GITHUB_EMAIL and username: $GITHUB_USERNAME"

# Step 7: Create and set up Trap
echo_status "Step 7: Setting up Trap..."
mkdir -p ~/my-drosera-trap
cd ~/my-drosera-trap

echo_status "Initializing Trap..."
forge init -t drosera-network/trap-foundry-template || {
    echo_error "Failed to initialize Trap"
    exit 1
}

echo_status "Compiling Trap..."
bun install
forge build
echo_success "Trap compiled"

# Step 8: Deploy Trap
echo_status "Step 8: Deploying Trap (requires Holesky ETH)..."
prompt_input "Enter your EVM wallet private key (used for deploying the Trap)" DROSERA_PRIVATE_KEY "xxx" true

export DROSERA_PRIVATE_KEY
echo_warning "When prompted, type 'ofc' and press Enter to confirm deployment"
drosera apply

# Step 9: Install Operator CLI
echo_status "Step 9: Installing Drosera Operator CLI..."
cd ~
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz || {
    echo_error "Failed to download Drosera Operator"
    exit 1
}

tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
./drosera-operator --version || {
    echo_error "Drosera Operator installation failed"
    exit 1
}

cp drosera-operator /usr/bin/
echo_success "Drosera Operator installed"

# Step 10: Register Operator
echo_status "Step 10: Registering Operator..."
drosera-operator register --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key "$DROSERA_PRIVATE_KEY" || {
    echo_warning "Operator registration may have failed, please check the output above"
}

# Step 11: Create Operator systemd service
echo_status "Step 11: Creating Operator systemd service..."
prompt_input "Enter your VPS IP address (or localhost for local setup)" VPS_IP

cat > /etc/systemd/system/drosera.service << EOF
[Unit]
Description=drosera node service
After=network-online.target

[Service]
User=root
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=$(which drosera-operator) node --db-file-path /root/.drosera.db --network-p2p-port 31313 --server-port 31314 \
    --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com \
    --eth-backup-rpc-url https://1rpc.io/holesky \
    --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \
    --eth-private-key ${DROSERA_PRIVATE_KEY} \
    --listen-address 0.0.0.0 \
    --network-external-p2p-address ${VPS_IP} \
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF
echo_success "Created systemd service file"

# Step 12: Configure firewall
echo_status "Step 12: Configuring firewall..."
ufw allow ssh
ufw allow 22
ufw allow 31313/tcp
ufw allow 31314/tcp
echo "y" | ufw enable
echo_success "Firewall configured"

# Step 13: Start Operator node
echo_status "Step 13: Starting Operator node..."
systemctl daemon-reload
systemctl enable drosera
systemctl start drosera
echo_success "Operator node started"

# Step 14: Check Trap setup
echo_status "Step 14: Whitelist your operator in the Trap..."
cd ~/my-drosera-trap
prompt_input "Enter your EVM wallet address to whitelist as operator" OPERATOR_ADDRESS

echo -e "\nprivate_trap = true\nwhitelist = [\"$OPERATOR_ADDRESS\"]" >> drosera.toml
export DROSERA_PRIVATE_KEY
drosera apply
echo_success "Operator whitelisted in the Trap"

# Print summary
echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}    Installation Complete    ${NC}"
echo -e "${GREEN}=======================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Check your node health with: journalctl -u drosera.service -f"
echo "2. Visit https://app.drosera.io/ to connect your wallet"
echo "3. Find your Trap in the 'Traps Owned' section"
echo "4. Boost your Trap with Holesky ETH using the 'Send Bloom Boost' option"
echo "5. Opt-in your Operator to the Trap from the dashboard"
echo ""
echo "Useful commands:"
echo " - Check node logs: journalctl -u drosera.service -f"
echo " - Stop node: sudo systemctl stop drosera"
echo " - Restart node: sudo systemctl restart drosera"
echo " - Run a dry run: drosera dryrun"
echo ""
echo -e "${GREEN}Thank you for installing Drosera Network!${NC}"
