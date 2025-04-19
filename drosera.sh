if [ "$INSTALL_METHOD" -eq "1" ]; then
    print_message "Setting up operator using Docker..."
    
    systemctl stop drosera 2>/dev/null
    systemctl disable drosera 2>/dev/null
    
    cd ~
    git clone https://github.com/0xmoei/Drosera-Network
    cd Drosera-Network
    cp .env.example .env
    
    sed -i "s|your_evm_private_key|$DROSERA_PRIVATE_KEY|g" .env
    sed -i "s|your_vps_public_ip|$VPS_IP|g" .env
    
    sed -i "s|https://ethereum-holesky-rpc.publicnode.com|$PRIMARY_RPC_URL|g" .env
    if [ -n "$BACKUP_RPC_URL" ]; then
        sed -i "s|https://1rpc.io/holesky|$BACKUP_RPC_URL|g" .env
    fi
    
    docker compose up -d
    check_success "Docker operator setup"
    
    print_message "To view operator logs, run: docker compose logs -f"
    
elif [ "$INSTALL_METHOD" -eq "2" ]; then
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
    
    print_message "To view operator logs, run: journalctl -u drosera.service -f"
else
    print_error "Invalid installation method selected. Choose 1 for Docker or 2 for SystemD."
    exit 1
fi

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
