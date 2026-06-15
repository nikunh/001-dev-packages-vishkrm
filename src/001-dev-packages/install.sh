#!/bin/bash
# NOTE: Must use bash (not zsh) since this script INSTALLS zsh
# Uses bash (not sh) because we need process substitution for logging (line 18)
set -e

# Logging mechanism for debugging
LOG_FILE="/tmp/001-dev-packages-install.log"
log_debug() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Initialize logging
log_debug "=== 001-DEV-PACKAGES INSTALL STARTED ==="
chmod 0666 "$LOG_FILE" 2>/dev/null || true
log_debug "Script path: $0"
log_debug "PWD: $(pwd)"
log_debug "Environment: USER=$USER HOME=$HOME"

# Redirect all output to log file while still showing on console
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Installing Development Packages Feature..."

# Set DEBIAN_FRONTEND to noninteractive to prevent prompts
export DEBIAN_FRONTEND=noninteractive

# Install system dependencies from the original Dockerfile
apt-get update && \
    apt-get install -y --no-install-recommends \
        sudo sshpass locales ca-certificates openssh-client openssh-server gnupg curl wget file \
        jq build-essential libreadline-dev libncurses5-dev libpcre3-dev libssl-dev \
        python3 python3-venv python3-pip python3-dev \
        docker.io \
        lua5.4 liblua5.4-dev \
        cifs-utils fontconfig unzip zip iputils-ping rsync inotify-tools trash-cli \
        net-tools direnv tzdata \
        graphviz \
        redis-tools \
        zsh \
        cron \
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

# Build and install LastPass CLI from source (v1.6.1)
# The apt version is outdated and has SSL certificate issues
echo "Building LastPass CLI from source..."
apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    pkg-config \
    libcurl4-openssl-dev \
    libxml2-dev \
    pinentry-curses \
    xclip \
    && rm -rf /var/lib/apt/lists/*

cd /tmp && \
    curl -L https://github.com/lastpass/lastpass-cli/releases/download/v1.6.1/lastpass-cli-1.6.1.tar.gz -o lastpass-cli.tar.gz && \
    tar xzf lastpass-cli.tar.gz && \
    cd lastpass-cli-1.6.1 && \
    mkdir -p build && \
    cd build && \
    cmake .. && \
    make && \
    make install && \
    cd /tmp && \
    rm -rf lastpass-cli-1.6.1 lastpass-cli.tar.gz

echo "LastPass CLI v1.6.1 installed successfully"

# Install Python packages including pipx for aider dependency
echo "Installing Python packages..."
python3 -m pip install --no-cache-dir pipx pyts uv anaconda python-dotenv diagrams

# Report installed packages to vishkrm-config fragment system
echo "Reporting Python packages to vishkrm-config fragment system..."
mkdir -p /usr/local/lib/vishkrm-config/fragments/packages
cat << 'EOF' > /usr/local/lib/vishkrm-config/fragments/packages/python-packages.fragment
# Python Packages Fragment - 001-dev-packages feature
PYTHON_PACKAGES="pipx pyts uv anaconda python-dotenv diagrams"
PYTHON_PACKAGES_STATUS="installed"
PYTHON_PACKAGES_VERSION="$(python3 --version 2>&1)"
PIPX_VERSION="$(pipx --version 2>&1 || echo 'not available')"
EOF

# Create configuration directories and copy pip.conf (temporarily disabled)
# mkdir -p /etc/pip
# cp pip.conf /etc/pip/pip.conf

# Create sudoers directory (required by user-setup and other features)
mkdir -p /etc/sudoers.d

# Configure SSHD for container use
mkdir -p /var/run/sshd
mkdir -p /etc/ssh/sshd_config.d

# Create a basic SSHD configuration that works in containers
# Use environment variables with sensible defaults
SSH_PORT=${SSH_PORT:-2222}
DEVPOD_USERNAME=${DEVPOD_USERNAME:-${_REMOTE_USER:-vishkrm}}

cat > /etc/ssh/sshd_config.d/devcontainer.conf << EOF
# DevContainer SSHD Configuration
Port $SSH_PORT
ListenAddress 0.0.0.0
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
AllowUsers $DEVPOD_USERNAME
X11Forwarding yes
PrintMotd no
PrintLastLog no
TCPKeepAlive yes
ClientAliveInterval 120
ClientAliveCountMax 3
UsePAM yes
# Required for running in container without systemd
PidFile /var/run/sshd.pid
EOF


log_debug "=== 001-DEV-PACKAGES INSTALL COMPLETED ==="
echo "Bootstrap Development Packages Feature installed successfully."
