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

# Variabel global untuk RPC URL
ETH_RPC_URL="https://ethereum-holesky-rpc.publicnode.com"
ETH_BACKUP_RPC_URL="https://1rpc.io/holesky"

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

function configure_rpc {
    line
    echo -e "${YELLOW}Konfigurasi RPC URL...${NC}"
    line
    
    read -p "Masukkan Ethereum RPC URL [default: $ETH_RPC_URL]: " input_rpc
    if [ -n "$input_rpc" ]; then
        ETH_RPC_URL=$input_rpc
    fi
    
    read -p "Masukkan Backup Ethereum RPC URL [default: $ETH_BACKUP_RPC_URL]: " input_backup_rpc
    if [ -n "$input_backup_rpc" ]; then
        ETH_BACKUP_RPC_URL=$input_backup_rpc
    fi
    
    echo -e "${GREEN}RPC URL dikonfigurasi:${NC}"
    echo -e "Primary: ${BLUE}$ETH_RPC_URL${NC}"
    echo -e "Backup: ${BLUE}$ETH_BACKUP_RPC_URL${NC}"
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
    
    echo -e "${YELLOW}Melakukan source bash profile...${NC}"
    
    # Ekspor PATH untuk CLI yang baru diinstal
    echo 'export PATH="$HOME/.drosera/bin:$PATH"' >> $HOME/.bashrc
    export PATH="$HOME/.drosera/bin:$PATH"
    
    echo -e "${GREEN}Drosera CLI berhasil diinstall!${NC}"
    echo -e "${YELLOW}Catatan: Jalankan 'source /root/.bashrc' secara manual jika mengalami masalah dengan command drosera${NC}"
}

function install_foundry {
    line
    echo -e "${YELLOW}Menginstall Foundry CLI...${NC}"
    line
    
    curl -L https://foundry.paradigm.xyz | bash
    check_status $?
    
    echo -e "${YELLOW}Melakukan source bash profile...${NC}"
    
    # Ekspor PATH untuk CLI yang baru diinstal
    echo 'export PATH="$HOME/.foundry/bin:$PATH"' >> $HOME/.bashrc
    export PATH="$HOME/.foundry/bin:$PATH"
    
    echo -e "${GREEN}Foundry CLI berhasil diinstall!${NC}"
    echo -e "${YELLOW}Catatan: Jalankan 'source /root/.bashrc' secara manual jika mengalami masalah dengan command foundry${NC}"
}

function install_bun {
    line
    echo -e "${YELLOW}Menginstall Bun...${NC}"
    line
    
    curl -fsSL https://bun.sh/install | bash
    check_status $?
    
    echo -e "${YELLOW}Melakukan source bash profile...${NC}"
    
    # Ekspor PATH untuk CLI yang baru diinstal
    echo 'export PATH="$HOME/.bun/bin:$PATH"' >> $HOME/.bashrc
    export PATH="$HOME/.bun/bin:$PATH"
    
    echo -e "${GREEN}Bun berhasil diinstall!${NC}"
    echo -e "${YELLOW}Catatan: Jalankan 'source /root/.bashrc' secara manual jika mengalami masalah dengan command bun${NC}"
}

function update_drosera_cli {
    line
    echo -e "${YELLOW}Memperbarui Drosera CLI...${NC}"
    line
    
    # Gunakan path langsung ke droseraup
    if [ -f "$HOME/.drosera/bin/droseraup" ]; then
        echo -e "${YELLOW}Menjalankan droseraup...${NC}"
        $HOME/.drosera/bin/droseraup
    else
        echo -e "${RED}droseraup tidak ditemukan. Pastikan Drosera CLI sudah terinstal dengan benar.${NC}"
    fi
}

function update_foundry_cli {
    line
    echo -e "${YELLOW}Memperbarui Foundry CLI...${NC}"
    line
    
    # Gunakan path langsung ke foundryup
    if [ -f "$HOME/.foundry/bin/foundryup" ]; then
        echo -e "${YELLOW}Menjalankan foundryup...${NC}"
        $HOME/.foundry/bin/foundryup
    else
        echo -e "${RED}foundryup tidak ditemukan. Pastikan Foundry CLI sudah terinstal dengan benar.${NC}"
    fi
}

function setup_trap {
    line
    echo -e "${YELLOW}Menyiapkan Trap...${NC}"
    line
    
    # Ekspor PATH untuk CLI yang baru diinstal
    export PATH="$HOME/.drosera/bin:$HOME/.foundry/bin:$HOME/.bun/bin:$PATH"
    
    # Perbarui CLI jika tersedia
    update_drosera_cli
    update_foundry_cli
    
    # Membuat direktori untuk trap
    mkdir -p $HOME/my-drosera-trap
    cd $HOME/my-drosera-trap
    
    # Konfigurasi Git
    read -p "Masukkan Github Email Anda: " GITHUB_EMAIL
    read -p "Masukkan Github Username Anda: " GITHUB_USERNAME
    
    git config --global user.email "$GITHUB_EMAIL"
    git config --global user.name "$GITHUB_USERNAME"
    
    # Initialize trap
    if [ -f "$HOME/.foundry/bin/forge" ]; then
        $HOME/.foundry/bin/forge init -t drosera-network/trap-foundry-template
    else
        forge init -t drosera-network/trap-foundry-template
    fi
    check_status $?
    
    # Compile trap
    if [ -f "$HOME/.bun/bin/bun" ]; then
        $HOME/.bun/bin/bun install
    else
        bun install
    fi
    
    if [ -f "$HOME/.foundry/bin/forge" ]; then
        $HOME/.foundry/bin/forge build
    else
        forge build
    fi
    
    echo -e "${GREEN}Trap berhasil disiapkan!${NC}"
}

function deploy_trap {
    line
    echo -e "${YELLOW}Mendeploy Trap...${NC}"
    line
    
    # Ekspor PATH untuk CLI yang baru diinstal
    export PATH="$HOME/.drosera/bin:$HOME/.foundry/bin:$HOME/.bun/bin:$PATH"
    
    # Perbarui CLI jika tersedia
    update_drosera_cli
    
    cd $HOME/my-drosera-trap
    
    # Masukkan private key
    read -sp "Masukkan EVM wallet private key Anda: " PRIVATE_KEY
    echo ""
    
    # Deploy trap
    if [ -f "$HOME/.drosera/bin/drosera" ]; then
        DROSERA_PRIVATE_KEY=$PRIVATE_KEY $HOME/.drosera/bin/drosera apply
    else
        DROSERA_PRIVATE_KEY=$PRIVATE_KEY drosera apply
    fi
    
    echo -e "${GREEN}Trap berhasil dideploy! Pastikan Anda memeriksa dashboard Drosera.${NC}"
    echo -e "${GREEN}Kunjungi https://app.drosera.io/ untuk melihat trap Anda.${NC}"
}

function config_whitelist_operator {
    line
    echo -e "${YELLOW}Mengkonfigurasi Whitelist Operator...${NC}"
    line
    
    # Ekspor PATH untuk CLI yang baru diinstal
    export PATH="$HOME/.drosera/bin:$HOME/.foundry/bin:$HOME/.bun/bin:$PATH"
    
    # Perbarui CLI jika tersedia
    update_drosera_cli
    
    cd $HOME/my-drosera-trap
    
    # Masukkan alamat operator
    read -p "Masukkan alamat Operator Anda (EVM Wallet Public Address): " OPERATOR_ADDRESS
    
    # Edit file konfigurasi
    echo "private_trap = true" >> drosera.toml
    echo "whitelist = [\"$OPERATOR_ADDRESS\"]" >> drosera.toml
    
    # Update konfigurasi trap
    read -sp "Masukkan EVM wallet private key Anda: " PRIVATE_KEY
    echo ""
    
    if [ -f "$HOME/.drosera/bin/drosera" ]; then
        DROSERA_PRIVATE_KEY=$PRIVATE_KEY $HOME/.drosera/bin/drosera apply
    else
        DROSERA_PRIVATE_KEY=$PRIVATE_KEY drosera apply
    fi
    
    echo -e "${GREEN}Whitelist Operator berhasil dikonfigurasi!${NC}"
}

function install_operator_cli {
    line
    echo -e "${YELLOW}Menginstall Operator CLI...${NC}"
    line
    
    # Ekspor PATH untuk CLI yang baru diinstal
    export PATH="$HOME/.drosera/bin:$HOME/.foundry/bin:$HOME/.bun/bin:$PATH"
    
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
    
    # Ekspor PATH untuk CLI yang baru diinstal
    export PATH="$HOME/.drosera/bin:$HOME/.foundry/bin:$HOME/.bun/bin:$PATH"
    
    # Masukkan private key
    read -sp "Masukkan EVM wallet private key Anda: " PRIVATE_KEY
    echo ""
    
    drosera-operator register --eth-rpc-url $ETH_RPC_URL --eth-private-key $PRIVATE_KEY
    
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
    
    # Ekspor PATH untuk CLI yang baru diinstal
    export PATH="$HOME/.drosera/bin:$HOME/.foundry/bin:$HOME/.bun/bin:$PATH"
    
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
    
    # Edit .env file untuk menggunakan RPC kustom
    sed -i "s|ETH_RPC_URL=.*|ETH_RPC_URL=$ETH_RPC_URL|g" .env
    sed -i "s|ETH_BACKUP_RPC_URL=.*|ETH_BACKUP_RPC_URL=$ETH_BACKUP_RPC_URL|g" .env
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
    
    # Ekspor PATH untuk CLI yang baru diinstal
    export PATH="$HOME/.drosera/bin:$HOME/.foundry/bin:$HOME/.bun/bin:$PATH"
    
    # Masukkan konfigurasi
    read -sp "Masukkan EVM wallet private key Anda: " PRIVATE_KEY
    echo ""
    read -p "Masukkan IP publik VPS Anda (atau 0.0.0.0 untuk sistem lokal): " VPS_IP
    
    # Menyimpan private key ke file terpisah (Metode yang lebih aman)
    echo "$PRIVATE_KEY" > $HOME/.drosera-private-key
    sudo chmod 600 $HOME/.drosera-private-key
    
    # Buat file service menggunakan file private key
    sudo bash -c "cat > /etc/systemd/system/drosera.service << EOF
[Unit]
Description=drosera node service
After=network-online.target

[Service]
User=$USER
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=$(which drosera-operator) node --db-file-path $HOME/.drosera.db --network-p2p-port 31313 --server-port 31314 \\
    --eth-rpc-url $ETH_RPC_URL \\
    --eth-backup-rpc-url $ETH_BACKUP_RPC_URL \\
    --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \\
    --eth-private-key-file $HOME/.drosera-private-key \\
    --listen-address 0.0.0.0 \\
    --network-external-p2p-address $VPS_IP \\
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF"
    
    # Reload systemd
    sudo systemctl daemon-reload
    sudo systemctl enable drosera
    
    # Start systemd
    echo -e "${YELLOW}Memulai service drosera...${NC}"
    sudo systemctl start drosera
    
    # Cek status service
    sleep 3
    if systemctl is-active --quiet drosera; then
        echo -e "${GREEN}Service drosera berhasil dijalankan!${NC}"
    else
        echo -e "${RED}Service drosera gagal dijalankan. Memeriksa log...${NC}"
        journalctl -u drosera.service --no-pager --lines=10
        
        echo -e "${YELLOW}Jika service gagal dijalankan, coba perbarui file service dengan cara alternatif berikut:${NC}"
        echo -e "${BLUE}1. sudo nano /etc/systemd/system/drosera.service${NC}"
        echo -e "${BLUE}2. Edit parameter private key dengan format yang benar${NC}"
        echo -e "${BLUE}3. sudo systemctl daemon-reload${NC}"
        echo -e "${BLUE}4. sudo systemctl restart drosera${NC}"
    fi
    
    echo -e "${GREEN}Operator berhasil diinstall dengan SystemD!${NC}"
    echo -e "${YELLOW}Untuk melihat logs: ${NC}journalctl -u drosera.service -f"
}

function send_bloom {
    line
    echo -e "${YELLOW}Mengirim Bloom...${NC}"
    line
    
    # Ekspor PATH untuk CLI yang baru diinstal
    export PATH="$HOME/.drosera/bin:$HOME/.foundry/bin:$HOME/.bun/bin:$PATH"
    
    # Perbarui CLI jika tersedia
    update_drosera_cli
    
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

function setup_trap_environment {
    line
    echo -e "${YELLOW}Setup Trap Environment (Drosera, Foundry, Bun CLI)...${NC}"
    line
    
    # Instalasi CLI
    install_drosera_cli
    install_foundry
    install_bun
    
    # Ekspor PATH untuk CLI yang baru diinstal
    export PATH="$HOME/.drosera/bin:$HOME/.foundry/bin:$HOME/.bun/bin:$PATH"
    
    echo -e "${GREEN}Setup Trap Environment berhasil diselesaikan!${NC}"
    echo -e "${YELLOW}PERHATIAN: Anda perlu menjalankan 'source /root/.bashrc' secara manual sebelum melanjutkan ke langkah berikutnya!${NC}"
    echo -e "${YELLOW}Atau restart terminal Anda untuk memuat perubahan PATH.${NC}"
    
    # Beri pesan bahwa perlu me-restart shell atau source .bashrc
    read -p "Apakah Anda ingin menjalankan 'source /root/.bashrc' sekarang? (y/n): " restart_shell
    if [[ "$restart_shell" == "y" || "$restart_shell" == "Y" ]]; then
        source /root/.bashrc
        echo -e "${GREEN}Bash profile telah di-source.${NC}"
    else
        echo -e "${YELLOW}Silakan jalankan 'source /root/.bashrc' sebelum melanjutkan.${NC}"
    fi
}

function reload_bashrc {
    line
    echo -e "${YELLOW}Memuat ulang bash profile...${NC}"
    line
    
    source /root/.bashrc
    
    # Ekspor PATH lagi untuk memastikan
    export PATH="$HOME/.drosera/bin:$HOME/.foundry/bin:$HOME/.bun/bin:$PATH"
    
    echo -e "${GREEN}Bash profile telah dimuat ulang. PATH sudah diperbarui.${NC}"
    echo -e "${YELLOW}PATH saat ini: ${NC}$PATH"
    
    # Cek ketersediaan command
    if command -v drosera &> /dev/null; then
        echo -e "${GREEN}Drosera CLI tersedia.${NC}"
    else
        echo -e "${RED}Drosera CLI tidak tersedia dalam PATH.${NC}"
    fi
    
    if command -v forge &> /dev/null; then
        echo -e "${GREEN}Foundry CLI tersedia.${NC}"
    else
        echo -e "${RED}Foundry CLI tidak tersedia dalam PATH.${NC}"
    fi
    
    if command -v bun &> /dev/null; then
        echo -e "${GREEN}Bun tersedia.${NC}"
    else
        echo -e "${RED}Bun tidak tersedia dalam PATH.${NC}"
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
    echo -e "${GREEN}3.${NC} Konfigurasi RPC URL"
    echo -e "${GREEN}4.${NC} Setup Trap Environment (Drosera, Foundry, Bun CLI)"
    echo -e "${GREEN}5.${NC} Reload Bash Profile"
    echo -e "${GREEN}6.${NC} Setup and Deploy Trap"
    echo -e "${GREEN}7.${NC} Configure Whitelist Operator"
    echo -e "${GREEN}8.${NC} Install Operator CLI"
    echo -e "${GREEN}9.${NC} Register Operator"
    echo -e "${GREEN}10.${NC} Open Required Ports"
    echo -e "${GREEN}11.${NC} Install Operator (Docker)"
    echo -e "${GREEN}12.${NC} Install Operator (SystemD)"
    echo -e "${GREEN}13.${NC} Send Bloom & Run Dryrun"
    echo -e "${GREEN}14.${NC} Opt-in Trap in Dashboard"
    echo -e "${GREEN}15.${NC} Check Node Status"
    echo -e "${GREEN}16.${NC} Full Installation (Steps 1-14)"
    echo -e "${GREEN}0.${NC} Exit"
    line
    
    read -p "Masukkan pilihan Anda: " choice
    
    case $choice in
        1) install_dependencies ;;
        2) install_docker ;;
        3) configure_rpc ;;
        4) setup_trap_environment ;;
        5) reload_bashrc ;;
        6) 
            # Ekspor PATH untuk CLI yang baru diinstal
            export PATH="$HOME/.drosera/bin:$HOME/.foundry/bin:$HOME/.bun/bin:$PATH"
            setup_trap
            deploy_trap
            ;;
        7) config_whitelist_operator ;;
        8) install_operator_cli ;;
        9) register_operator ;;
        10) open_ports ;;
        11) install_docker_operator ;;
        12) install_systemd_operator ;;
        13) send_bloom ;;
        14) opt_in_trap ;;
        15) check_node_status ;;
        16)
            install_dependencies
            install_docker
            configure_rpc
            setup_trap_environment
            
            # Perlu reload bash profile untuk memuat perubahan PATH
            reload_bashrc
            
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
