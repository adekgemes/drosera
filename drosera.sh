#!/bin/bash

# ------------ Input Manual ------------
read -p "Masukkan email GitHub Anda: " GITHUB_EMAIL
read -p "Masukkan username GitHub Anda: " GITHUB_USERNAME
read -p "Masukkan private key dompet EVM Anda: " PRIVATE_KEY
read -p "Masukkan public address Operator Anda: " OPERATOR_ADDRESS
read -p "Masukkan IP VPS publik Anda (atau 0.0.0.0 untuk lokal): " VPS_IP
read -p "Masukkan RPC URL utama (contoh: https://ethereum-holesky-rpc.publicnode.com): " MAIN_RPC
read -p "Masukkan RPC URL backup (contoh: https://1rpc.io/holesky): " BACKUP_RPC
# --------------------------------------

echo "🔧 Updating & Installing dependencies..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y

echo "🐳 Installing Docker..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done
sudo apt-get install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update && sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

echo "✅ Docker Installed. Running hello-world test..."
sudo docker run hello-world

echo "💻 Installing Drosera CLI..."
curl -L https://app.drosera.io/install | bash
source ~/.bashrc
droseraup

echo "📦 Installing Foundry CLI..."
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup

echo "🍞 Installing Bun..."
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc

echo "🔨 Setup Trap..."
mkdir -p ~/my-drosera-trap && cd ~/my-drosera-trap
git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"
forge init -t drosera-network/trap-foundry-template
bun install
forge build

echo "🚀 Deploying Trap..."
DROSERA_PRIVATE_KEY="$PRIVATE_KEY" drosera apply <<< "ofc"

echo "📁 Editing Trap config for Operator..."
cd ~/my-drosera-trap
echo -e "\nprivate_trap = true\nwhitelist = [\"$OPERATOR_ADDRESS\"]" >> drosera.toml
DROSERA_PRIVATE_KEY="$PRIVATE_KEY" drosera apply

echo "📥 Installing Operator CLI..."
cd ~
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
sudo cp drosera-operator /usr/bin
drosera-operator --version

echo "📦 Cloning Operator Repo & Setting up Docker..."
git clone https://github.com/0xmoei/Drosera-Network
cd Drosera-Network
cp .env.example .env
sed -i "s/your_evm_private_key/$PRIVATE_KEY/" .env
sed -i "s/your_vps_public_ip/$VPS_IP/" .env

echo "🐳 Pulling Docker image for Operator..."
docker pull ghcr.io/drosera-network/drosera-operator:latest

echo "🧾 Registering Operator..."
drosera-operator register --eth-rpc-url "$MAIN_RPC" --eth-private-key "$PRIVATE_KEY"

echo "🌐 Configuring Firewall & Ports..."
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp
sudo ufw --force enable

echo "🧠 Membuat SystemD service drosera (bukan Docker)..."
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
    --eth-rpc-url $MAIN_RPC \
    --eth-backup-rpc-url $BACKUP_RPC \
    --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \
    --eth-private-key $PRIVATE_KEY \
    --listen-address 0.0.0.0 \
    --network-external-p2p-address $VPS_IP \
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF

echo "🚀 Menjalankan node Drosera via systemd..."
sudo systemctl daemon-reload
sudo systemctl enable drosera
sudo systemctl start drosera

echo "✅ Instalasi selesai. Periksa status node Anda:"
echo "📡 journalctl -u drosera.service -f"
