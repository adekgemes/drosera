#!/bin/bash

# Drosera Network One-Click Installer

# Text Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Error handling function
handle_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Success message function
success_message() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Warn message function
warn_message() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check root permissions
if [[ $EUID -ne 0 ]]; then
   handle_error "This script must be run as root. Use: sudo $0"
fi

# Banner
echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}    Drosera Network Installer    ${NC}"
echo -e "${GREEN}=======================================${NC}"

# Prompt for critical inputs
read -p "Enter your GitHub Email: " GITHUB_EMAIL
read -p "Enter your GitHub Username: " GITHUB_USERNAME
read -sp "Enter your EVM Wallet Private Key (Holesky ETH): " DROSERA_PRIVATE_KEY
echo
read -p "Enter your VPS/Local IP (use 'localhost' for local setup): " VPS_IP

# 1. Update and Install Dependencies
echo -e "\n${YELLOW}[STEP 1]${NC} Installing System Dependencies..."
apt-get update && apt-get upgrade -y || handle_error "Failed to update repositories"

apt-get install -y curl ufw iptables build-essential git wget lz4 jq make gcc nano \
    automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev \
    libleveldb-dev tar clang bsdmainutils ncdu unzip || handle_error "Failed to install dependencies"

success_message "System dependencies installed"

# 2. Install Docker
echo -e "\n${YELLOW}[STEP 2]${NC} Installing Docker..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
    apt-get remove -y $pkg 2>/dev/null
done

apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin || handle_error "Docker installation failed"

# Test Docker
docker run hello-world || handle_error "Docker test failed"
success_message "Docker installed and tested"

# 3. Configure Git
echo -e "\n${YELLOW}[STEP 3]${NC} Configuring Git..."
git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"
success_message "Git configured"

# 4. Install Drosera CLI & Tools
echo -e "\n${YELLOW}[STEP 4]${NC} Installing CLI Tools..."
curl -L https://app.drosera.io/install | bash
source /root/.bashrc
droseraup

curl -L https://foundry.paradigm.xyz | bash
source /root/.bashrc
foundryup

curl -fsSL https://bun.sh/install | bash
success_message "Drosera, Foundry, and Bun installed"

# 5. Set up Trap
echo -e "\n${YELLOW}[STEP 5]${NC} Setting up Drosera Trap..."
mkdir -p ~/my-drosera-trap
cd ~/my-drosera-trap

forge init -t drosera-network/trap-foundry-template || handle_error "Trap initialization failed"
bun install
forge build
success_message "Trap compiled"

# 6. Deploy Trap
echo -e "\n${YELLOW}[STEP 6]${NC} Deploying Trap..."
export DROSERA_PRIVATE_KEY="$DROSERA_PRIVATE_KEY"
drosera apply || handle_error "Trap deployment failed"
success_message "Trap deployed"

# 7. Install Operator
echo -e "\n${YELLOW}[STEP 7]${NC} Installing Drosera Operator..."
cd ~
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
cp drosera-operator /usr/bin/
drosera-operator --version || handle_error "Operator installation failed"
success_message "Operator installed"

# 8. Register Operator
echo -e "\n${YELLOW}[STEP 8]${NC} Registering Operator..."
drosera-operator register --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key "$DROSERA_PRIVATE_KEY"
success_message "Operator registered"

# 9. Create Systemd Service
echo -e "\n${YELLOW}[STEP 9]${NC} Creating Operator Systemd Service..."
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
    --eth-private-key $DROSERA_PRIVATE_KEY \
    --listen-address 0.0.0.0 \
    --network-external-p2p-address $VPS_IP \
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF
success_message "Systemd service created"

# 10. Configure Firewall
echo -e "\n${YELLOW}[STEP 10]${NC} Configuring Firewall..."
ufw allow ssh
ufw allow 22
ufw allow 31313/tcp
ufw allow 31314/tcp
echo "y" | ufw enable
success_message "Firewall configured"

# 11. Start Operator
echo -e "\n${YELLOW}[STEP 11]${NC} Starting Operator Node..."
systemctl daemon-reload
systemctl enable drosera
systemctl start drosera
success_message "Operator node started"

# 12. Final Trap Configuration
echo -e "\n${YELLOW}[STEP 12]${NC} Finalizing Trap Configuration..."
cd ~/my-drosera-trap
OPERATOR_ADDRESS=$(drosera-operator wallet address)
echo -e "\nprivate_trap = true\nwhitelist = [\"$OPERATOR_ADDRESS\"]" >> drosera.toml
drosera apply
success_message "Operator whitelisted in Trap"

# Completion Banner
echo -e "\n${GREEN}=======================================${NC}"
echo -e "${GREEN}    Drosera Network Setup Complete    ${NC}"
echo -e "${GREEN}=======================================${NC}"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo "1. Check node health: journalctl -u drosera.service -f"
echo "2. Visit https://app.drosera.io/ to connect wallet"
echo "3. Find your Trap in 'Traps Owned'"
echo "4. Boost Trap with Holesky ETH"
echo "5. Opt-in Operator from dashboard"

exit 0
