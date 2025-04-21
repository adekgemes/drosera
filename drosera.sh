#!/bin/bash

# Warna
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ganti logo
clear
curl -s https://raw.githubusercontent.com/dlzvy/LOGOTES/main/logo3.sh | bash
sleep 5

function line {
  echo -e "${GREEN}--------------------------------------------------------------------------------${NC}"
}

function check_status() {
    if [[ $1 -eq 0 ]]; then
        echo -e "${GREEN}Berhasil!${NC}"
    else
        echo -e "${RED}Gagal!${NC}"
        exit 1
    fi
}

function install_dependencies {
    line
    echo -e "${YELLOW}Menginstall Dependencies...${NC}"
    line
    
    sudo apt-get update && sudo apt-get upgrade -y
    check_status $?
    
    sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y
    check_status $?
    
    echo -e "${GREEN}Dependencies berhasil diinstall!${NC}"
}

function install_docker {
    line
    echo -e "${YELLOW}Menginstall Docker...${NC}"
    line
    
    # Hapus docker lama jika ada
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg -y; done
    
    # Install Docker
    sudo apt-get update
    sudo apt-get install ca-certificates curl gnupg -y
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt update -y && sudo apt upgrade -y
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
    
    # Test Docker
    sudo docker run hello-world
    check_status $?
    
    echo -e "${GREEN}Docker berhasil diinstall!${NC}"
}

function install_drosera_cli {
    line
    echo -e "${YELLOW}Menginstall Drosera CLI...${NC}"
    line
    
    curl -L https://app.drosera.io/install | bash
    check_status $?
    
    source /root/.bashrc
    droseraup
    
    echo -e "${GREEN}Drosera CLI berhasil diinstall!${NC}"
}

function install_foundry {
    line
    echo -e "${YELLOW}Menginstall Foundry CLI...${NC}"
    line
    
    curl -L https://foundry.paradigm.xyz | bash
    check_status $?
    
    source /root/.bashrc
    foundryup
    
    echo -e "${GREEN}Foundry CLI berhasil diinstall!${NC}"
}

function install_bun {
    line
    echo -e "${YELLOW}Menginstall Bun...${NC}"
    line
    
    curl -fsSL https://bun.sh/install | bash
    check_status $?
    
    source /root/.bashrc
    
    echo -e "${GREEN}Bun berhasil diinstall!${NC}"
}

function setup_trap {
    line
    echo -e "${YELLOW}Menyiapkan Trap...${NC}"
    line
    
    # Membuat direktori untuk trap
    mkdir -p $HOME/my-drosera-trap
    cd $HOME/my-drosera-trap
    
    # Konfigurasi Git
    read -p "Masukkan Github Email Anda: " GITHUB_EMAIL
    read -p "Masukkan Github Username Anda: " GITHUB_USERNAME
    
    git config --global user.email "$GITHUB_EMAIL"
    git config --global user.name "$GITHUB_USERNAME"
    
    # Initialize trap
    forge init -t drosera-network/trap-foundry-template
    check_status $?
    
    # Compile trap
    bun install
    forge build
    
    echo -e "${GREEN}Trap berhasil disiapkan!${NC}"
}

function deploy_trap {
    line
    echo -e "${YELLOW}Mendeploy Trap...${NC}"
    line
    
    cd $HOME/my-drosera-trap
    
    # Masukkan private key
    read -sp "Masukkan EVM wallet private key Anda: " PRIVATE_KEY
    echo ""
    
    # Deploy trap
    DROSERA_PRIVATE_KEY=$PRIVATE_KEY drosera apply
    
    echo -e "${GREEN}Trap berhasil dideploy! Pastikan Anda memeriksa dashboard Drosera.${NC}"
    echo -e "${GREEN}Kunjungi https://app.drosera.io/ untuk melihat trap Anda.${NC}"
}

function config_whitelist_operator {
    line
    echo -e "${YELLOW}Mengkonfigurasi Whitelist Operator...${NC}"
    line
    
    cd $HOME/my-drosera-trap
    
    # Masukkan alamat operator
    read -p "Masukkan alamat Operator Anda (EVM Wallet Public Address): " OPERATOR_ADDRESS
    
    # Edit file konfigurasi
    echo "private_trap = true" >> drosera.toml
    echo "whitelist = [\"$OPERATOR_ADDRESS\"]" >> drosera.toml
    
    # Update konfigurasi trap
    read -sp "Masukkan EVM wallet private key Anda: " PRIVATE_KEY
    echo ""
    
    DROSERA_PRIVATE_KEY=$PRIVATE_KEY drosera apply
    
    echo -e "${GREEN}Whitelist Operator berhasil dikonfigurasi!${NC}"
}

function install_operator_cli {
    line
    echo -e "${YELLOW}Menginstall Operator CLI...${NC}"
    line
    
    cd $HOME
    
    # Download
    curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
    
    # Install
    tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
    check_status $?
    
    # Periksa versi
    ./drosera-operator --version
    
    # Pindahkan ke path global
    sudo cp drosera-operator /usr/bin
    
    # Install Docker image
    docker pull ghcr.io/drosera-network/drosera-operator:latest
    
    echo -e "${GREEN}Operator CLI berhasil diinstall!${NC}"
}

function register_operator {
    line
    echo -e "${YELLOW}Mendaftarkan Operator...${NC}"
    line
    
    # Masukkan private key
    read -sp "Masukkan EVM wallet private key Anda: " PRIVATE_KEY
    echo ""
    
    drosera-operator register --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key $PRIVATE_KEY
    
    echo -e "${GREEN}Operator berhasil didaftarkan!${NC}"
}

function open_ports {
    line
    echo -e "${YELLOW}Membuka Port yang Diperlukan...${NC}"
    line
    
    # Enable firewall
    sudo ufw allow ssh
    sudo ufw allow 22
    sudo ufw enable
    
    # Allow Drosera ports
    sudo ufw allow 31313/tcp
    sudo ufw allow 31314/tcp
    
    echo -e "${GREEN}Port berhasil dibuka!${NC}"
}

function install_docker_operator {
    line
    echo -e "${YELLOW}Menginstall Operator dengan Docker...${NC}"
    line
    
    # Stop dan disable systemd jika berjalan
    sudo systemctl stop drosera 2>/dev/null
    sudo systemctl disable drosera 2>/dev/null
    
    cd $HOME
    git clone https://github.com/0xmoei/Drosera-Network
    cd Drosera-Network
    cp .env.example .env
    
    # Masukkan konfigurasi
    read -sp "Masukkan EVM wallet private key Anda: " PRIVATE_KEY
    echo ""
    read -p "Masukkan IP publik VPS Anda: " VPS_IP
    
    # Edit .env file
    sed -i "s/your_evm_private_key/$PRIVATE_KEY/g" .env
    sed -i "s/your_vps_public_ip/$VPS_IP/g" .env
    
    # Jalankan operator
    docker compose up -d
    
    echo -e "${GREEN}Operator berhasil diinstall dengan Docker!${NC}"
    echo -e "${YELLOW}Untuk melihat logs: ${NC}docker logs -f drosera-node"
}

function install_systemd_operator {
    line
    echo -e "${YELLOW}Menginstall Operator dengan SystemD...${NC}"
    line
    
    # Masukkan konfigurasi
    read -sp "Masukkan EVM wallet private key Anda: " PRIVATE_KEY
    echo ""
    read -p "Masukkan IP publik VPS Anda (atau 0.0.0.0 untuk sistem lokal): " VPS_IP
    
    # Buat file service
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
    --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com \
    --eth-backup-rpc-url https://1rpc.io/holesky \
    --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \
    --eth-private-key $PRIVATE_KEY \
    --listen-address 0.0.0.0 \
    --network-external-p2p-address $VPS_IP \
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd
    sudo systemctl daemon-reload
    sudo systemctl enable drosera
    
    # Start systemd
    sudo systemctl start drosera
    
    echo -e "${GREEN}Operator berhasil diinstall dengan SystemD!${NC}"
    echo -e "${YELLOW}Untuk melihat logs: ${NC}journalctl -u drosera.service -f"
}

function send_bloom {
    line
    echo -e "${YELLOW}Mengirim Bloom...${NC}"
    line
    
    echo -e "${GREEN}Untuk mengirim bloom boost, silakan mengunjungi dashboard Drosera:${NC}"
    echo -e "${BLUE}https://app.drosera.io/${NC}"
    
    echo -e "${YELLOW}1. Hubungkan wallet Drosera EVM Anda${NC}"
    echo -e "${YELLOW}2. Klik pada Traps Owned untuk melihat trap Anda${NC}"
    echo -e "${YELLOW}3. Klik pada Send Bloom Boost dan deposit Holesky ETH${NC}"
    
    echo -e "${GREEN}Setelah mengirim bloom boost, Anda dapat menjalankan:${NC}"
    echo -e "${BLUE}drosera dryrun${NC}"
}

function opt_in_trap {
    line
    echo -e "${YELLOW}Opt-in Trap di Dashboard...${NC}"
    line
    
    echo -e "${GREEN}Untuk menghubungkan operator ke trap, silakan kunjungi dashboard Drosera:${NC}"
    echo -e "${BLUE}https://app.drosera.io/${NC}"
    
    echo -e "${YELLOW}Klik pada Opt in untuk menghubungkan operator Anda ke trap${NC}"
}

function check_node_status {
    line
    echo -e "${YELLOW}Memeriksa Status Node...${NC}"
    line
    
    # Periksa apakah menggunakan Docker atau SystemD
    if docker ps | grep -q "drosera-node"; then
        echo -e "${GREEN}Node berjalan menggunakan Docker${NC}"
        docker logs --tail 50 drosera-node
    elif systemctl is-active --quiet drosera; then
        echo -e "${GREEN}Node berjalan menggunakan SystemD${NC}"
        journalctl -u drosera.service --no-pager --lines=50
    else
        echo -e "${RED}Node tidak berjalan!${NC}"
    fi
}

function show_menu {
    clear
    curl -s https://raw.githubusercontent.com/dlzvy/LOGOTES/main/logo3.sh | bash
    
    line
    echo -e "${YELLOW}Drosera Network Installer Menu${NC}"
    line
    echo -e "${GREEN}1.${NC} Install Dependencies"
    echo -e "${GREEN}2.${NC} Install Docker"
    echo -e "${GREEN}3.${NC} Setup Trap Environment (Drosera, Foundry, Bun CLI)"
    echo -e "${GREEN}4.${NC} Setup and Deploy Trap"
    echo -e "${GREEN}5.${NC} Configure Whitelist Operator"
    echo -e "${GREEN}6.${NC} Install Operator CLI"
    echo -e "${GREEN}7.${NC} Register Operator"
    echo -e "${GREEN}8.${NC} Open Required Ports"
    echo -e "${GREEN}9.${NC} Install Operator (Docker)"
    echo -e "${GREEN}10.${NC} Install Operator (SystemD)"
    echo -e "${GREEN}11.${NC} Send Bloom & Run Dryrun"
    echo -e "${GREEN}12.${NC} Opt-in Trap in Dashboard"
    echo -e "${GREEN}13.${NC} Check Node Status"
    echo -e "${GREEN}14.${NC} Full Installation (Steps 1-12)"
    echo -e "${GREEN}0.${NC} Exit"
    line
    
    read -p "Masukkan pilihan Anda: " choice
    
    case $choice in
        1) install_dependencies ;;
        2) install_docker ;;
        3) 
            install_drosera_cli
            install_foundry
            install_bun
            ;;
        4) 
            setup_trap
            deploy_trap
            ;;
        5) config_whitelist_operator ;;
        6) install_operator_cli ;;
        7) register_operator ;;
        8) open_ports ;;
        9) install_docker_operator ;;
        10) install_systemd_operator ;;
        11) send_bloom ;;
        12) opt_in_trap ;;
        13) check_node_status ;;
        14)
            install_dependencies
            install_docker
            install_drosera_cli
            install_foundry
            install_bun
            setup_trap
            deploy_trap
            config_whitelist_operator
            install_operator_cli
            register_operator
            open_ports
            
            echo -e "${YELLOW}Pilih metode instalasi operator:${NC}"
            echo -e "${GREEN}1.${NC} Docker"
            echo -e "${GREEN}2.${NC} SystemD"
            read -p "Pilihan Anda: " op_choice
            
            if [ "$op_choice" == "1" ]; then
                install_docker_operator
            else
                install_systemd_operator
            fi
            
            send_bloom
            opt_in_trap
            ;;
        0) exit 0 ;;
        *) echo -e "${RED}Pilihan tidak valid!${NC}" ; sleep 2 ; show_menu ;;
    esac
    
    if [ $choice -ne 0 ]; then
        echo
        read -p "Tekan Enter untuk kembali ke menu..."
        show_menu
    fi
}

# Jalankan menu utama
show_menu
