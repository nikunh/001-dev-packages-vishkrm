#!/bin/sh
set -e

echo "Installing Development Packages Feature..."

# Set DEBIAN_FRONTEND to noninteractive to prevent prompts
export DEBIAN_FRONTEND=noninteractive

# Install system dependencies from the original Dockerfile
apt-get update && \
    apt-get install -y --no-install-recommends \
        sudo sshpass locales ca-certificates openssh-client gnupg curl wget file \
        jq build-essential libreadline-dev libncurses5-dev libpcre3-dev libssl-dev \
        python3 python3-venv python3-pip python3-dev \
        docker.io \
        lua5.4 liblua5.4-dev \
        cifs-utils fontconfig unzip zip iputils-ping rsync inotify-tools trash-cli \
        net-tools lastpass-cli direnv tzdata \
        graphviz \
        redis-tools \
        && rm -rf /var/lib/apt/lists/*

# Install yq from GitHub releases
curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/bin/yq && \
    chmod +x /usr/bin/yq

# Install Node.js from the official NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs

# Update npm to the latest version
npm install -g npm@latest

# Install Playwright globally
npm install -g playwright && npx playwright install-deps && playwright install

# Install Python packages
pip install --no-cache-dir pyts uv anaconda python-dotenv diagrams

# Create configuration directories and copy pip.conf
mkdir -p /etc/pip
cp pip.conf /etc/pip/pip.conf

# Create sudoers directory (required by user-setup and other features)
mkdir -p /etc/sudoers.d

echo "Bootstrap Development Packages Feature installed successfully."
