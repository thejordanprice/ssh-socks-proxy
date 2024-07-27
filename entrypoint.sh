#!/bin/bash

# Function to establish the SSH tunnel
establish_tunnel() {
    ssh -N -F /etc/ssh/ssh_config remote-ssh-server &
    SSH_PID=$!
}

# Function to check the SSH tunnel
check_tunnel() {
    if ! ps -p $SSH_PID > /dev/null; then
        echo "SSH tunnel is down. Reconnecting..."
        establish_tunnel
    else
        echo "SSH tunnel is running."
    fi
}

# Function to configure iptables rules
configure_iptables() {
    # Flush existing rules
    iptables -F
    iptables -t nat -F
    iptables -t mangle -F
    iptables -X

    # Allow traffic on localhost
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT

    # Allow established and related connections
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Allow traffic to the SSH server
    iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT

    # Allow traffic through the SOCKS proxy (assuming port 1080)
    iptables -A OUTPUT -p tcp --dport 1080 -j ACCEPT

    # Block all other traffic
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT DROP
}

# Start the SSH tunnel initially
establish_tunnel

# Configure iptables rules
configure_iptables

# Start the Dante SOCKS proxy server
danted -f /etc/danted.conf &

# Keep checking the SSH tunnel health
while true; do
    check_tunnel
    sleep 10  # Check every 10 seconds
done
