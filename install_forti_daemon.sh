#!/bin/bash

exec < /dev/tty

# Step 1: Install openfortivpn via Homebrew
echo "Installing openfortivpn..."
brew install openfortivpn

# Step 2: Prompt the user for VPN details
read -p "Enter the VPN server IP: " SERVER_IP
read -p "Enter the VPN server port: " SERVER_PORT
read -p "Enter your VPN username: " USER_ID
read -sp "Enter your VPN password: " USER_PASSWORD
echo ""
read -p "Enter the trusted certificate hash: " CERT_HASH

# Step 3: Create a configuration file for openfortivpn
CONFIG_FILE="$HOME/.openfortivpn/config"
mkdir -p $(dirname "$CONFIG_FILE")

echo "
host = $SERVER_IP
port = $SERVER_PORT
username = $USER_ID
password = $USER_PASSWORD
trusted-cert = $CERT_HASH
" > $CONFIG_FILE

echo "Configuration saved to $CONFIG_FILE"


# Step 4: Add the openfortivpn command to the sudoers file for no-password execution
SUDOERS_ENTRY="$USER ALL=(ALL) NOPASSWD: /opt/homebrew/bin/openfortivpn"
SUDOERS_FILE="/etc/sudoers.d/openfortivpn"

echo "Adding $USER to sudoers for openfortivpn..."

if [ ! -f "$SUDOERS_FILE" ]; then
    echo "$SUDOERS_ENTRY" | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 440 "$SUDOERS_FILE"
    echo "Sudoers entry added: $SUDOERS_FILE"
else
    echo "Sudoers entry already exists: $SUDOERS_FILE"
fi

# Step 5: Create a launch agent to run openfortivpn as a daemon with sudo
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/com.openfortivpn.daemon.plist"

cat <<EOL > "$LAUNCH_AGENT_PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.openfortivpn.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/sudo</string>
        <string>/opt/homebrew/bin/openfortivpn</string>
        <string>--config=$CONFIG_FILE</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/openfortivpn.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/openfortivpn.err</string>
</dict>
</plist>
EOL

echo "Launch agent created at $LAUNCH_AGENT_PLIST"

# Step 6: Define aliases in the .zshrc configuration file
ZSHRC_FILE="$HOME/.zshrc"

cat <<EOL >> "$ZSHRC_FILE"

# Aliases to control openfortivpn daemon with sudo
alias forti-on='sudo launchctl load -w $LAUNCH_AGENT_PLIST'
alias forti-off='sudo launchctl unload -w $LAUNCH_AGENT_PLIST'
alias forti-status='launchctl list | grep com.openfortivpn.daemon'

EOL

echo "Aliases added to $ZSHRC_FILE"

# Step 7: Source the .zshrc configuration file to apply aliases immediately
echo "You can now use 'forti-on', 'forti-off', and 'forti-status' to control the VPN daemon."
