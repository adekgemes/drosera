#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Display custom logo
curl -s https://raw.githubusercontent.com/dlzvy/LOGOTES/main/logo3.sh | bash
sleep 5

# Function to display progress
progress() {
  echo -e "${YELLOW}[PROGRESS]${NC} $1"
}

# Function to display success
success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to display error
error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}

# Input validation function
validate_not_empty() {
  if [ -z "$1" ]; then
    error "$2 cannot be empty!"
  fi
}

# Collect user information
echo "Please provide the following information:"
read -p "Enter your Private Key (with Holesky ETH): " PRIVATE_KEY
validate_not_empty "$PRIVATE_KEY" "Private Key"

# Ask user if they want to use a default public RPC or enter their own
echo -e "${YELLOW}RPC Configuration (Holesky Testnet)${NC}"
echo "1) Use public RPC (not recommended for production)"
echo "2) Enter your own RPC (recommended - Alchemy or QuickNode)"
read -p "Select an option [1-2]: " RPC_OPTION

if [ "$RPC_OPTION" = "1" ]; then
  ETH_RPC="https://ethereum-holesky-rpc.publicnode.com"
  echo -e "${YELLOW}Using public RPC: ${ETH_RPC}${NC}"
  echo -e "${YELLOW}Warning: Public RPCs can be unreliable. Consider using your own RPC for better performance.${NC}"
elif [ "$RPC_OPTION" = "2" ]; then
  read -p "Enter your ETH RPC URL (Holesky): " ETH_RPC
  validate_not_empty "$ETH_RPC" "ETH RPC URL"
else
  error "Invalid option. Please select 1 or 2."
fi

read -p "Enter your GitHub Email: " GITHUB_EMAIL
validate_not_empty "$GITHUB_EMAIL" "GitHub Email"

read -p "Enter your GitHub Username: " GITHUB_USERNAME
validate_not_empty "$GITHUB_USERNAME" "GitHub Username"

read -p "Enter your VPS Public IP Address: " PUBLIC_IP
validate_not_empty "$PUBLIC_IP" "VPS Public IP"

# Install dependencies
progress "Installing system dependencies..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y

# Install Docker
progress "Installing Docker..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done

sudo apt-get update
sudo apt-get install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y && sudo apt upgrade -y
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Test Docker
progress "Testing Docker installation..."
sudo docker run hello-world
success "Docker installed successfully"

# Install Drosera CLI
progress "Installing Drosera CLI..."
curl -L https://app.drosera.io/install | bash
source $HOME/.bashrc
droseraup
success "Drosera CLI installed"

# Install Foundry
progress "Installing Foundry..."
curl -L https://foundry.paradigm.xyz | bash
source $HOME/.bashrc
foundryup
success "Foundry installed"

# Install Bun
progress "Installing Bun..."
curl -fsSL https://bun.sh/install | bash
source $HOME/.bashrc
success "Bun installed"

# Setup GitHub configuration
progress "Configuring Git..."
git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"
success "Git configured"

# Create and deploy trap
progress "Setting up Drosera Trap..."
mkdir -p $HOME/my-drosera-trap
cd $HOME/my-drosera-trap

forge init -t drosera-network/trap-foundry-template
bun install
forge build

# Deploy trap
progress "Deploying trap to Holesky network..."
DROSERA_PRIVATE_KEY=$PRIVATE_KEY drosera apply --eth-rpc-url $ETH_RPC

# Save the trap address for later use
TRAP_ADDRESS=$(cat $HOME/my-drosera-trap/.drosera/trap.json | jq -r '.address')
success "Trap deployed at address: $TRAP_ADDRESS"

# Make trap private and whitelist operator
progress "Setting up private trap and whitelisting operator..."
cat >> $HOME/my-drosera-trap/drosera.toml << EOF

private_trap = true
whitelist = ["$(echo $PRIVATE_KEY | cut -c 3- | xargs -I {} cast wallet address {}0x)"]
EOF

DROSERA_PRIVATE_KEY=$PRIVATE_KEY drosera apply --eth-rpc-url $ETH_RPC
success "Trap configured as private with operator whitelisted"

# Install and setup operator
progress "Setting up Drosera Operator..."
cd $HOME
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
sudo cp drosera-operator /usr/bin
success "Drosera Operator CLI installed"

# Register operator
progress "Registering operator..."
drosera-operator register --eth-rpc-url $ETH_RPC --eth-private-key $PRIVATE_KEY
success "Operator registered"

# Configure firewall
progress "Configuring firewall..."
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp
sudo ufw --force enable
success "Firewall configured"

# Set up Docker for operator
progress "Setting up Docker for operator..."
mkdir -p $HOME/Drosera-Network
cd $HOME/Drosera-Network

cat > .env << EOF
ETH_PRIVATE_KEY=$PRIVATE_KEY
PUBLIC_IP=$PUBLIC_IP
EOF

cat > docker-compose.yaml << EOF
version: '3'
services:
  drosera:
    container_name: drosera-node
    image: ghcr.io/drosera-network/drosera-operator:latest
    restart: unless-stopped
    environment:
      - RUST_LOG=info
      - ETH_PRIVATE_KEY=\${ETH_PRIVATE_KEY}
      - PUBLIC_IP=\${PUBLIC_IP}
      - DROSERA_ETH_RPC_URL=$ETH_RPC
    ports:
      - 31313:31313/tcp
      - 31314:31314/tcp
    volumes:
      - ./data:/root/.drosera
EOF

# Start the operator
progress "Starting Drosera Operator..."
docker compose up -d
success "Drosera Operator started successfully"

# Create quick management script
cat > $HOME/drosera-manager.sh << 'EOF'
#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

check_status() {
  if [ "$(docker ps -q -f name=drosera-node)" ]; then
    echo -e "${GREEN}Drosera Node is running${NC}"
  else
    echo -e "${RED}Drosera Node is not running${NC}"
  fi
}

case "$1" in
  status)
    check_status
    ;;
  logs)
    docker logs -f drosera-node
    ;;
  restart)
    cd $HOME/Drosera-Network && docker compose down -v && docker compose up -d
    echo -e "${GREEN}Drosera Node restarted${NC}"
    ;;
  stop)
    cd $HOME/Drosera-Network && docker compose down -v
    echo -e "${YELLOW}Drosera Node stopped${NC}"
    ;;
  start)
    cd $HOME/Drosera-Network && docker compose up -d
    echo -e "${GREEN}Drosera Node started${NC}"
    ;;
  dryrun)
    cd $HOME/my-drosera-trap && DROSERA_PRIVATE_KEY=$ETH_PRIVATE_KEY drosera dryrun --eth-rpc-url $ETH_RPC
    ;;
  change-rpc)
    read -p "Enter new ETH RPC URL (Holesky): " NEW_RPC
    if [ -n "$NEW_RPC" ]; then
      sed -i "s|DROSERA_ETH_RPC_URL=.*|DROSERA_ETH_RPC_URL=$NEW_RPC|g" $HOME/Drosera-Network/docker-compose.yaml
      echo -e "${GREEN}RPC URL updated to: $NEW_RPC${NC}"
      echo -e "${YELLOW}Restart the node to apply changes with: drosera-manager restart${NC}"
    else
      echo -e "${RED}RPC URL cannot be empty!${NC}"
    fi
    ;;
  *)
    echo "Usage: $0 {status|logs|restart|stop|start|dryrun|change-rpc}"
    exit 1
    ;;
esac
EOF

chmod +x $HOME/drosera-manager.sh
sudo cp $HOME/drosera-manager.sh /usr/local/bin/drosera-manager

# Final information
echo -e "\n${GREEN}=== INSTALLATION COMPLETE ===${NC}"
echo -e "\n${YELLOW}IMPORTANT INFORMATION:${NC}"
echo -e "Trap Address: ${GREEN}$TRAP_ADDRESS${NC}"
echo -e "Operator Address: ${GREEN}$(echo $PRIVATE_KEY | cut -c 3- | xargs -I {} cast wallet address {}0x)${NC}"
echo -e "RPC URL: ${GREEN}$ETH_RPC${NC}"
echo -e "\n${YELLOW}NEXT STEPS:${NC}"
echo -e "1. Visit ${GREEN}https://app.drosera.io/${NC} and connect your wallet"
echo -e "2. Add some Holesky ETH to your trap using the 'Send Bloom Boost' button"
echo -e "3. Run ${GREEN}drosera-manager dryrun${NC} to fetch blocks"
echo -e "\n${YELLOW}MANAGEMENT COMMANDS:${NC}"
echo -e "Use ${GREEN}drosera-manager${NC} with the following options:"
echo -e "  ${GREEN}status${NC}  - Check if the node is running"
echo -e "  ${GREEN}logs${NC}    - View node logs"
echo -e "  ${GREEN}restart${NC} - Restart the node"
echo -e "  ${GREEN}stop${NC}    - Stop the node"
echo -e "  ${GREEN}start${NC}   - Start the node"
echo -e "  ${GREEN}dryrun${NC}  - Run dryrun to fetch blocks"
echo -e "  ${GREEN}change-rpc${NC} - Change the RPC URL"
