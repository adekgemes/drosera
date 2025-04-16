#!/bin/bash

echo "=== [ Drosera Network Auto Installer ] ==="

echo ">> Updating system..."
sudo apt-get update && sudo apt-get upgrade -y

echo ">> Installing dependencies..."
sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y

echo ">> Removing old Docker versions..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove -y $pkg; done

echo ">> Installing Docker..."
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update -y && sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo docker run hello-world

echo ">> Installing Drosera CLI..."
curl -L https://app.drosera.io/install | bash
source ~/.bashrc

echo ">> Installing Foundry CLI..."
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup

echo ">> Installing Bun..."
curl -fsSL https://bun.sh/install | bash

echo -e "\n=== INSTALLATION COMPLETE ==="
echo "Next steps:"
echo "1. Create your trap: forge init -t drosera-network/trap-foundry-template"
echo "2. Deploy with: DROSERA_PRIVATE_KEY=yourkey drosera apply"
echo "3. Check traps at: https://app.drosera.io"
