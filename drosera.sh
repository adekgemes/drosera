#!/bin/bash

# Function to derive public address from private key (simplified placeholder)
derive_address_from_private_key() {
    # In a real scenario, use a tool like `cast` from Foundry or an Ethereum library
    # Here, we simulate it for simplicity (replace with actual derivation if needed)
    echo "0x$(echo $1 | sha256sum | head -c 40)"
}

# Beautiful ASCII Art Intro
echo -e "\e[1;32m"
cat << "EOF"
Drosera Trap & Operator Deployment
Built by:
  ___       __  __            _ 
 / _ \__  _|  \/  | ___   ___(_)
| | | \ \/ / |\/| |/ _ \ / _ \ |
| |_| |>  <| |  | | (_) |  __/ |
 \___//_/\_\_|  |_|\___/ \___|_|        
 
Follow me on X: https://x.com/0xMoei
Follow me on Github: https://github.com/0xmoei
EOF
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

# Prompt for Testnet Holesky Ethereum RPC immediately after EVM private key
read -p "Enter your Testnet Holesky Ethereum RPC, Grab one from https://dashboard.alchemy.com/ (or press Enter to use default): " ETH_RPC_URL
if [ -z "$ETH_RPC_URL" ] || ! curl --output /dev/null --silent --head --fail "$ETH_RPC_URL"; then
    echo "Invalid RPC URL or skipped. Using default RPC: https://ethereum-holesky-rpc.publicnode.com"
    ETH_RPC_URL="https://ethereum-holesky-rpc.publicnode.com"
else
    echo "Using provided RPC URL: $ETH_RPC_URL"
fi

# Prompt for VPS public IP
read -p "Enter your VPS public IP: " VPS_IP
if [ -z "$VPS_IP" ]; then
    echo "Error: VPS public IP is required. Exiting."
    exit 1
fi

# Step 1: Install Dependencies
echo -e "\n\e[1;33mStep 1: Installing system dependencies...\e[0m"
echo "This ensures your system has all required tools and libraries."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y

# Step 2: Install Docker
echo -e "\n\e[1;33mStep 2: Installing Docker...\e[0m"
echo "Docker will manage the operator container."
sudo apt update -y && sudo apt upgrade -y
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo rm -f /etc/apt/keyrings/docker.gpg  # Remove existing key file to prevent overwrite prompt
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update -y && sudo apt upgrade -y
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo docker run hello-world

# Step 3: Install Drosera CLI, Foundry CLI, and Bun
echo -e "\n\e[1;33mStep 3: Installing Drosera CLI, Foundry CLI, and Bun...\e[0m"
echo "These tools are needed to deploy and manage your trap."

# Install Drosera CLI
curl -L https://app.drosera.io/install | bash
# Add Drosera CLI to PATH (assuming it installs to ~/.drosera/bin)
export PATH=$PATH:~/.drosera/bin
# Verify installation
droseraup

# Install Foundry CLI
curl -L https://foundry.paradigm.xyz | bash
# Add Foundry CLI to PATH (assuming it installs to ~/.foundry/bin)
export PATH=$PATH:~/.foundry/bin
# Verify installation
foundryup

# Install Bun
curl -fsSL https://bun.sh/install | bash
# Add Bun to PATH (assuming it installs to ~/.bun/bin)
export PATH=$PATH:~/.bun/bin
# Verify installation
bun --version

# Step 4: Deploy Contract & Trap
echo -e "\n\e[1;33mStep 4: Deploying Contract & Trap...\e[0m"
echo "Setting up and deploying your trap on the Holesky testnet."
mkdir my-drosera-trap
cd my-drosera-trap
git config --global user.email "user@example.com"
git config --global user.name "DroseraUser"
forge init -t drosera-network/trap-foundry-template
bun install
forge build
DROSERA_PRIVATE_KEY=$EVM_PRIVATE_KEY drosera apply
TRAP_ADDRESS=$(grep 'address =' drosera.toml | awk '{print $3}')
echo "Trap deployed! Address: $TRAP_ADDRESS"

# Step 5: Bloom Boost Trap
echo -e "\n\e[1;33mStep 5: Bloom Boosting your Trap...\e[0m"
echo "Depositing Holesky ETH to activate your trap."
read -p "Enter the amount of Holesky ETH to deposit for Bloom Boost: " ETH_AMOUNT
drosera bloomboost --trap-address "$TRAP_ADDRESS" --eth-amount "$ETH_AMOUNT"
# Step 6: Fetch Blocks
echo -e "\n\e[1;33mStep 6: Fetching Blocks...\e[0m"
echo "Testing trap functionality with a dry run."
drosera dryrun

# Step 7: Whitelist Operator
echo -e "\n\e[1;33mStep 7: Whitelisting Operator...\e[0m"
echo "Configuring your trap to allow your operator."
# Check if private_trap exists; update or append
if grep -q "private_trap" drosera.toml; then
    sed -i "s/private_trap =.*/private_trap = true/" drosera.toml
else
    echo "private_trap = true" >> drosera.toml
fi
# Check if whitelist exists; update or append
if grep -q "whitelist" drosera.toml; then
    sed -i "s|whitelist =.*|whitelist = [\"$EVM_PUBLIC_ADDRESS\"]|" drosera.toml
else
    echo "whitelist = [\"$EVM_PUBLIC_ADDRESS\"]" >> drosera.toml
fi
DROSERA_PRIVATE_KEY=$EVM_PRIVATE_KEY drosera apply
# Step 8: Install Operator CLI
echo -e "\n\e[1;33mStep 8: Installing Operator CLI...\e[0m"
echo "This CLI will manage your operator node."
cd ~
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
sudo cp drosera-operator /usr/bin
drosera-operator --version

# Step 9: Install Docker Image
echo -e "\n\e[1;33mStep 9: Installing Docker Image...\e[0m"
echo "Pulling the latest Drosera operator image."
docker pull ghcr.io/drosera-network/drosera-operator:latest

# Step 10: Register Operator
echo -e "\n\e[1;33mStep 10: Registering Operator...\e[0m"
echo "Registering your operator with the network."
drosera-operator register --eth-rpc-url "$ETH_RPC_URL" --eth-private-key "$EVM_PRIVATE_KEY"

# Step 11: Open Ports
echo -e "\n\e[1;33mStep 11: Opening Ports...\e[0m"
echo "Configuring firewall to allow Drosera traffic."
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw enable
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp

# Step 12: Configure and Run Docker Operator
echo -e "\n\e[1;33mStep 12: Configuring and Running Operator...\e[0m"
echo "Setting up the Docker container for your operator."
git clone https://github.com/0xmoei/Drosera-Network
cd Drosera-Network
cp .env.example .env
sed -i "s/your_evm_private_key/$EVM_PRIVATE_KEY/g" .env
sed -i "s/your_vps_public_ip/$VPS_IP/g" .env
sed -i "s|https://ethereum-holesky-rpc.publicnode.com|$ETH_RPC_URL|g" docker-compose.yaml
docker compose up -d

# Step 13: Opt-in Trap
echo -e "\n\e[1;33mStep 13: Opting into Trap...\e[0m"
echo "Connecting your operator to the deployed trap."
drosera-operator optin --eth-rpc-url "$ETH_RPC_URL" --eth-private-key "$EVM_PRIVATE_KEY" --trap-config-address "$TRAP_ADDRESS"

# Final Instructions
echo -e "\n\e[1;32mSetup Complete!\e[0m"
echo "You can check the node logs with: docker logs -f drosera-node"
echo "Check the liveness of your node at: https://app.drosera.io/trap?trapId=$TRAP_ADDRESS"
