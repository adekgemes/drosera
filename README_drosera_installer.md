# Drosera Network Auto Installer

This repository provides an **automated shell script** to install all necessary dependencies for participating in the [Drosera Network](https://github.com/0xmoei/Drosera-Network) testnet.

## 🚀 Features

- System update & upgrade
- Installation of:
  - Essential build tools
  - Docker Engine & Docker Compose
  - Drosera CLI
  - Foundry CLI
  - Bun runtime
- One-command execution (via `curl | bash`)

## 📦 Usage

You can execute the installation script with a single command:

```bash
curl -sL https://raw.githubusercontent.com/<USERNAME>/drosera-installer/main/install.sh | bash
```

> ⚠️ Replace `<USERNAME>` with your actual GitHub username.

## 📁 What It Installs

- `build-essential`, `curl`, `git`, `jq`, etc.
- Docker Engine & containerd
- Drosera CLI (latest)
- Foundry toolchain
- Bun (JavaScript runtime)

## ✅ Post Installation

After installation, you can begin setting up your trap:

```bash
forge init -t drosera-network/trap-foundry-template
bun install
forge build
DROSERA_PRIVATE_KEY=yourkey drosera apply
```

Check your deployed trap at [https://app.drosera.io](https://app.drosera.io)

---

MIT License © 2025
