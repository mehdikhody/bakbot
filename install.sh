#!/bin/bash

# ─────────────────────────────────────────────
#  Bakbot Installer
#  Backs up files via Telegram on a schedule
# ─────────────────────────────────────────────

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
plain='\033[0m'

REPO="mehdikhody/bakbot"
APP_NAME="bakbot"
INSTALL_DIR="/usr/local/bin"
SERVICE_FILE="/etc/systemd/system/${APP_NAME}.service"
CONFIG_FILE="/etc/${APP_NAME}/config"

# ── Privilege check ───────────────────────────
[[ $EUID -ne 0 ]] && echo -e "${red}Error:${plain} Please run this script as root (sudo)." && exit 1

# ── Detect architecture ───────────────────────
detect_arch() {
    case "$(uname -m)" in
        x86_64 | amd64)       echo "amd64" ;;
        aarch64 | arm64)      echo "arm64" ;;
        *)
            echo -e "${red}Unsupported architecture: $(uname -m)${plain}" >&2
            exit 1
            ;;
    esac
}

# ── Detect OS ─────────────────────────────────
detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$ID"
    else
        echo -e "${red}Cannot detect OS. /etc/os-release not found.${plain}" >&2
        exit 1
    fi
}

# ── Install dependencies ──────────────────────
install_deps() {
    local release="$1"
    echo -e "${blue}Installing dependencies...${plain}"
    case "$release" in
        ubuntu | debian | armbian)
            apt-get update -qq && apt-get install -y -q curl unzip ;;
        fedora | rhel | almalinux | rocky)
            dnf install -y -q curl unzip ;;
        centos)
            yum install -y curl unzip ;;
        arch | manjaro)
            pacman -Sy --noconfirm curl unzip ;;
        *)
            echo -e "${yellow}Unknown distro '${release}'. Assuming curl and unzip are already installed.${plain}" ;;
    esac
}

# ── Fetch latest release tag from GitHub ──────
fetch_latest_version() {
    local version
    version=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
        | grep '"tag_name":' \
        | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ -z "$version" ]]; then
        echo -e "${red}Failed to fetch latest version from GitHub. Check your internet connection.${plain}" >&2
        exit 1
    fi
    echo "$version"
}

# ── Download and install the binary ───────────
install_binary() {
    local version="$1"
    local arch="$2"
    local tmp_dir
    tmp_dir=$(mktemp -d)

    local filename="${APP_NAME}-linux-${arch}-${version}.zip"
    local url="https://github.com/${REPO}/releases/download/${version}/${filename}"

    echo -e "${blue}Downloading ${APP_NAME} ${version} (${arch})...${plain}"
    curl -fL --progress-bar -o "${tmp_dir}/${filename}" "$url"
    if [[ $? -ne 0 ]]; then
        echo -e "${red}Download failed. URL: ${url}${plain}"
        rm -rf "$tmp_dir"
        exit 1
    fi

    echo -e "${blue}Installing binary to ${INSTALL_DIR}/${APP_NAME}...${plain}"
    unzip -q "${tmp_dir}/${filename}" -d "${tmp_dir}"
    install -m 755 "${tmp_dir}/${APP_NAME}-linux-${arch}-${version}/${APP_NAME}" "${INSTALL_DIR}/${APP_NAME}"
    rm -rf "$tmp_dir"
    echo -e "${green}Binary installed successfully.${plain}"
}

# ── Prompt for bakbot options ─────────────────
prompt_config() {
    echo ""
    echo -e "┌──────────────────────────────────────────────────┐"
    echo -e "│            ${blue}Bakbot Configuration${plain}                  │"
    echo -e "└──────────────────────────────────────────────────┘"

    # Token
    while true; do
        read -rp "$(echo -e "${green}Telegram Bot Token${plain} (-t): ")" BOT_TOKEN
        BOT_TOKEN="${BOT_TOKEN// /}"
        [[ -n "$BOT_TOKEN" ]] && break
        echo -e "${red}Token cannot be empty.${plain}"
    done

    # Chat ID
    while true; do
        read -rp "$(echo -e "${green}Telegram Chat ID${plain} (-c): ")" CHAT_ID
        CHAT_ID="${CHAT_ID// /}"
        [[ "$CHAT_ID" =~ ^-?[0-9]+$ ]] && break
        echo -e "${red}Chat ID must be a number (can be negative for groups).${plain}"
    done

    # File path
    while true; do
        read -rp "$(echo -e "${green}File path to backup${plain} (-f): ")" FILE_PATH
        FILE_PATH="${FILE_PATH// /}"
        [[ -e "$FILE_PATH" ]] && break
        echo -e "${red}File or directory not found: ${FILE_PATH}${plain}"
    done

    # Schedule
    echo ""
    echo -e "${blue}Predefined schedules:${plain}"
    echo -e "  1) @hourly    — every hour"
    echo -e "  2) @daily     — every day at midnight ${yellow}(default)${plain}"
    echo -e "  3) @weekly    — every Sunday at midnight"
    echo -e "  4) @monthly   — first day of each month"
    echo -e "  5) Custom     — enter a cron expression manually"
    read -rp "Choose schedule [1-5, default 2]: " SCHEDULE_CHOICE
    case "${SCHEDULE_CHOICE}" in
        1) SCHEDULE="@hourly" ;;
        3) SCHEDULE="@weekly" ;;
        4) SCHEDULE="@monthly" ;;
        5)
            read -rp "Enter cron expression (e.g. '0 0 3 * * *' for 3am daily): " SCHEDULE
            [[ -z "$SCHEDULE" ]] && SCHEDULE="@daily"
            ;;
        *) SCHEDULE="@daily" ;;
    esac
    echo -e "${green}Schedule set to: ${SCHEDULE}${plain}"

    # Proxy (optional)
    read -rp "$(echo -e "${green}Proxy URL${plain} (-p) [leave empty to skip]: ")" PROXY_URL
    PROXY_URL="${PROXY_URL// /}"
}

# ── Write config file ─────────────────────────
write_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" <<EOF
# Bakbot configuration
# Generated by install.sh — edit and restart the service to apply changes

TOKEN=${BOT_TOKEN}
CHAT_ID=${CHAT_ID}
FILE=${FILE_PATH}
SCHEDULE=${SCHEDULE}
PROXY=${PROXY_URL}
EOF
    chmod 600 "$CONFIG_FILE"
    echo -e "${green}Config written to ${CONFIG_FILE}${plain}"
}

# ── Write systemd service ─────────────────────
write_service() {
    local exec_start="${INSTALL_DIR}/${APP_NAME} --token \${TOKEN} --file \${FILE} --chatId \${CHAT_ID} --schedule \"\${SCHEDULE}\""
    if [[ -n "$PROXY_URL" ]]; then
        exec_start+=" --proxy \${PROXY}"
    fi

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Bakbot — Telegram file backup service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=${CONFIG_FILE}
ExecStart=${INSTALL_DIR}/${APP_NAME} \\
    --token \${TOKEN} \\
    --file \${FILE} \\
    --chatId \${CHAT_ID} \\
    --schedule "\${SCHEDULE}" \\
$([ -n "$PROXY_URL" ] && echo "    --proxy \${PROXY} \\")
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${APP_NAME}

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 "$SERVICE_FILE"
    echo -e "${green}Service file written to ${SERVICE_FILE}${plain}"
}

# ── Enable and start the service ──────────────
enable_service() {
    systemctl daemon-reload
    systemctl enable "${APP_NAME}"
    systemctl restart "${APP_NAME}"

    sleep 2
    if systemctl is-active --quiet "${APP_NAME}"; then
        echo -e "${green}${APP_NAME} service is running.${plain}"
    else
        echo -e "${red}Service failed to start. Check logs with:${plain}"
        echo -e "  journalctl -u ${APP_NAME} -n 50"
    fi
}

# ── Print summary ─────────────────────────────
print_summary() {
    echo ""
    echo -e "┌──────────────────────────────────────────────────┐"
    echo -e "│          ${green}Bakbot installed successfully!${plain}          │"
    echo -e "├──────────────────────────────────────────────────┤"
    printf  "│  %-20s %-27s │\n" "File:"      "$FILE_PATH"
    printf  "│  %-20s %-27s │\n" "Chat ID:"   "$CHAT_ID"
    printf  "│  %-20s %-27s │\n" "Schedule:"  "$SCHEDULE"
    [[ -n "$PROXY_URL" ]] && \
    printf  "│  %-20s %-27s │\n" "Proxy:"     "$PROXY_URL"
    echo -e "├──────────────────────────────────────────────────┤"
    echo -e "│  ${blue}Useful commands:${plain}                                 │"
    echo -e "│  systemctl status  ${APP_NAME}                         │"
    echo -e "│  systemctl restart ${APP_NAME}                         │"
    echo -e "│  systemctl stop    ${APP_NAME}                         │"
    echo -e "│  journalctl -u     ${APP_NAME} -f                      │"
    echo -e "│  nano ${CONFIG_FILE}          │"
    echo -e "└──────────────────────────────────────────────────┘"
    echo ""
}

# ── Main ──────────────────────────────────────
main() {
    echo ""
    echo -e "${green}  ____        _    _           _   ${plain}"
    echo -e "${green} | __ )  __ _| | _| |__   ___ | |_ ${plain}"
    echo -e "${green} |  _ \ / _\` | |/ / '_ \ / _ \| __|${plain}"
    echo -e "${green} | |_) | (_| |   <| |_) | (_) | |_ ${plain}"
    echo -e "${green} |____/ \__,_|_|\_\_.__/ \___/ \__|${plain}"
    echo ""
    echo -e "  Telegram backup bot installer"
    echo ""

    local os arch version
    os=$(detect_os)
    arch=$(detect_arch)

    echo -e "${blue}OS:${plain}   $os"
    echo -e "${blue}Arch:${plain} $arch"

    install_deps "$os"

    version=$(fetch_latest_version)
    echo -e "${blue}Latest version:${plain} $version"

    install_binary "$version" "$arch"
    prompt_config
    write_config
    write_service
    enable_service
    print_summary
}

main "$@"