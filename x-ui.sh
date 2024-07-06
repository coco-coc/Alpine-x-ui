#!/bin/bash

# Color definitions
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# Logging functions
function log_debug() {
    echo -e "${yellow}[DEBUG] $* ${plain}"
}

function log_error() {
    echo -e "${red}[ERROR] $* ${plain}"
}

function log_info() {
    echo -e "${green}[INFO] $* ${plain}"
}

# Check if the script is run as root
[[ $EUID -ne 0 ]] && log_error "Error: This script must be run as root!" && exit 1

# Check for required commands
for cmd in curl wget awk grep; do
    command -v $cmd >/dev/null 2>&1 || { log_error "$cmd is required but not installed. Aborting."; exit 1; }
done

# Detect the operating system
if grep -Eqi "alpine" /etc/issue; then
    release="alpine"
else
    log_error "Unsupported operating system. Please contact the script author!" && exit 1
fi

# Determine the OS version
os_version=""
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
elif [[ -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ "$release" == "alpine" && "$os_version" -le 3 ]]; then
    log_error "Please use Alpine 3 or a higher version!" && exit 1
fi

# Helper function for confirmations
confirm() {
    local prompt="$1"
    local default="$2"
    local response

    if [[ -n "$default" ]]; then
        read -p "$prompt [default: $default]: " response
        response=${response:-$default}
    else
        read -p "$prompt [y/n]: " response
    fi

    if [[ "$response" =~ ^[yY]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Functions for different operations
install() {
    bash <(curl -Ls https://raw.githubusercontent.com/Lynn-Becky/Alpine-x-ui/master/install.sh)
    if [[ $? -eq 0 ]]; then
        start
    fi
}

update() {
    if confirm "This will forcibly reinstall the latest version without losing data. Continue?" "n"; then
        bash <(curl -Ls https://raw.githubusercontent.com/Lynn-Becky/Alpine-x-ui/master/install.sh)
        if [[ $? -eq 0 ]]; then
            log_info "Update complete. Restarting panel..."
            restart
        fi
    else
        log_error "Update canceled."
    fi
}

uninstall() {
    if confirm "Are you sure you want to uninstall the panel? This will also uninstall xray." "n"; then
        rc-service x-ui stop
        rc-update delete x-ui
        rm -f /etc/systemd/system/x-ui.service
        rm -rf /etc/x-ui /usr/local/x-ui
        log_info "Uninstallation successful. To remove this script, run 'rm /usr/bin/x-ui -f'."
    else
        log_info "Uninstallation canceled."
    fi
}

reset_user() {
    if confirm "Reset username and password to 'admin'?" "n"; then
        /usr/local/x-ui/x-ui setting -username admin -password admin
        log_info "Username and password reset to 'admin'. Please restart the panel."
        confirm_restart
    fi
}

reset_config() {
    if confirm "Reset all panel settings? Account data will not be lost, and the username and password will not change." "n"; then
        /usr/local/x-ui/x-ui setting -reset
        log_info "All panel settings reset to default. Please restart the panel and use port 54321 to access."
        confirm_restart
    fi
}

confirm_restart() {
    if confirm "Restart the panel? This will also restart xray." "y"; then
        restart
    else
        show_menu
    fi
}

start() {
    rc-service x-ui start
    sleep 2
    check_status
    if [[ $? -eq 0 ]]; then
        log_info "x-ui started successfully."
    else
        log_error "Failed to start x-ui. Check logs for details."
    fi
}

stop() {
    rc-service x-ui stop
    sleep 2
    check_status
    if [[ $? -eq 1 ]]; then
        log_info "x-ui stopped successfully."
    else
        log_error "Failed to stop x-ui. Check logs for details."
    fi
}

restart() {
    rc-service x-ui restart
    sleep 2
    check_status
    if [[ $? -eq 0 ]]; then
        log_info "x-ui restarted successfully."
    else
        log_error "Failed to restart x-ui. Check logs for details."
    fi
}

status() {
    rc-service x-ui status
}

# Check the status of the service
check_status() {
    rc-service x-ui status > /dev/null 2>&1
    case $? in
    0) return 0 ;;
    1) return 1 ;;
    *) return 2 ;;
    esac
}

# Menu
show_menu() {
    echo -e "
  ${green}x-ui Management Script${plain}
  ${green}0.${plain} Exit
  ${green}1.${plain} Install x-ui
  ${green}2.${plain} Update x-ui
  ${green}3.${plain} Uninstall x-ui
  ${green}4.${plain} Reset Username/Password
  ${green}5.${plain} Reset Panel Settings
  ${green}6.${plain} Set Panel Port
  ${green}7.${plain} View Current Panel Settings
  ${green}8.${plain} Start x-ui
  ${green}9.${plain} Stop x-ui
  ${green}10.${plain} Restart x-ui
  ${green}11.${plain} View x-ui Status
  ${green}12.${plain} Install SSL Certificate
"
    read -p "Please choose an option [0-12]: " choice
    case $choice in
    0) exit 0 ;;
    1) install ;;
    2) update ;;
    3) uninstall ;;
    4) reset_user ;;
    5) reset_config ;;
    6) set_port ;;
    7) view_settings ;;
    8) start ;;
    9) stop ;;
    10) restart ;;
    11) status ;;
    12) install_ssl_cert ;;
    *) log_error "Invalid choice. Please enter a number between 0 and 12." ;;
    esac
}

# Check if arguments are provided and call the corresponding function
if [[ $# -gt 0 ]]; then
    case $1 in
    start) start ;;
    stop) stop ;;
    restart) restart ;;
    status) status ;;
    *) log_error "Invalid argument. Use start, stop, restart, or status." ;;
    esac
else
    show_menu
fi
