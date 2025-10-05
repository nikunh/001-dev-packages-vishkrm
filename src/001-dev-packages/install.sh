#!/bin/bash
# NOTE: Must use bash (not zsh) since this script INSTALLS zsh
# Uses bash (not sh) because we need process substitution for logging (line 18)
set -e

# Logging mechanism for debugging
LOG_FILE="/tmp/001-dev-packages-install.log"
log_debug() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $*" >> "$LOG_FILE"
}

# Initialize logging
log_debug "=== 001-DEV-PACKAGES INSTALL STARTED ==="
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

# Report installed packages to babaji-config fragment system
echo "Reporting Python packages to babaji-config fragment system..."
mkdir -p /usr/local/lib/babaji-config/fragments/packages
cat << 'EOF' > /usr/local/lib/babaji-config/fragments/packages/python-packages.fragment
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
DEVPOD_USERNAME=${DEVPOD_USERNAME:-babaji}

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

# Install shellinator-enhance script for dynamic private feature loading
echo "Installing shellinator-enhance script..."
cat > /usr/local/bin/shellinator-enhance << 'ENHANCE_EOF'
#!/usr/bin/env zsh
# Shellinator Enhance - Dynamic Private Feature Loader
# This script loads private features after establishing secure tunnel connection

set -e

# Configuration
PRIVATE_REGISTRY="${PRIVATE_REGISTRY:-registry.nikun.net}"
GITEA_URL="${GITEA_URL:-https://gitea.nikun.net}"
NEXUS_URL="${NEXUS_URL:-https://nexus.nikun.net}"
ENHANCE_DIR="$HOME/.shellinator-enhance"
LOG_FILE="$ENHANCE_DIR/enhance.log"
STATE_FILE="$ENHANCE_DIR/state"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "$1" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "$1"
}

init_enhance() {
    mkdir -p "$ENHANCE_DIR"
    touch "$LOG_FILE"
    [[ ! -f "$STATE_FILE" ]] && echo "not_enhanced" > "$STATE_FILE"
}

check_private_access() {
    log "${BLUE}Checking private network access...${NC}"
    if curl -s --max-time 5 "$GITEA_URL/api/v1/version" >/dev/null 2>&1 || \
       curl -s --max-time 5 "https://$PRIVATE_REGISTRY/v2/" >/dev/null 2>&1; then
        log "${GREEN}✓ Private network accessible${NC}"
        return 0
    else
        log "${YELLOW}⚠ Private network not accessible${NC}"
        return 1
    fi
}

install_private_features() {
    log "${BLUE}Installing private features...${NC}"

    # Download and install personal aliases
    local ALIASES_URL="$GITEA_URL/api/v1/repos/nikun/shellinator-private/raw/personal-aliases/.ohmyzsh_aliases_private.zshrc"
    mkdir -p "$HOME/.ohmyzsh_source_load_scripts"

    if curl -s --max-time 10 "$ALIASES_URL" -o "$HOME/.ohmyzsh_source_load_scripts/.personal_aliases.zshrc" 2>/dev/null; then
        log "${GREEN}✓ Personal aliases installed${NC}"
    fi

    # Download and install NAS connector
    local NAS_URL="$GITEA_URL/api/v1/repos/nikun/shellinator-private/raw/nas-connector/connect-nas.sh"
    if curl -s --max-time 10 "$NAS_URL" -o "/tmp/connect-nas.sh" 2>/dev/null; then
        if [[ -w "/usr/local/bin" ]]; then
            mv /tmp/connect-nas.sh /usr/local/bin/connect-nas
            chmod +x /usr/local/bin/connect-nas
        else
            sudo mv /tmp/connect-nas.sh /usr/local/bin/connect-nas
            sudo chmod +x /usr/local/bin/connect-nas
        fi
        log "${GREEN}✓ NAS connector installed${NC}"
    fi

    echo "enhanced" > "$STATE_FILE"
    log "${GREEN}✅ Private features installed successfully${NC}"

    echo ""
    echo "${GREEN}════════════════════════════════════════${NC}"
    echo "${GREEN}✨ Shellinator Enhanced!${NC}"
    echo "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo "Private features now available:"
    echo "  • Personal aliases and SSH configs"
    echo "  • NAS connector (connect-nas)"
    echo ""
    echo "Run 'reload' or start a new shell to activate."
    echo ""
}

check_enhanced_state() {
    [[ -f "$STATE_FILE" ]] && grep -q "enhanced" "$STATE_FILE"
}

main() {
    init_enhance

    case "${1:-}" in
        --check)
            (
                sleep 10
                if ! check_enhanced_state && check_private_access; then
                    install_private_features
                fi
            ) &
            ;;
        --force)
            echo "not_enhanced" > "$STATE_FILE"
            check_private_access && install_private_features || \
                log "${RED}Cannot reach private infrastructure${NC}"
            ;;
        --status)
            if check_enhanced_state; then
                log "${GREEN}✓ Environment enhanced${NC}"
            else
                log "${YELLOW}⚠ Environment not enhanced${NC}"
            fi
            ;;
        *)
            if check_enhanced_state; then
                log "${GREEN}✓ Already enhanced${NC}"
            elif check_private_access; then
                install_private_features
            else
                log "${YELLOW}Cannot reach private network${NC}"
                log "Establish tunnel: cloudflared tunnel run --token YOUR_TOKEN"
                log "Then run: shellinator-enhance"
            fi
            ;;
    esac
}

main "$@"
ENHANCE_EOF

chmod +x /usr/local/bin/shellinator-enhance

log_debug "=== 001-DEV-PACKAGES INSTALL COMPLETED ==="
echo "Bootstrap Development Packages Feature installed successfully."
