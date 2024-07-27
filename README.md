# SSH SOCKS Proxy Docker Container

This Docker container sets up an SSH tunnel to a remote server and routes all traffic through the tunnel using a SOCKS5 proxy. The SOCKS5 proxy is exposed to other containers, allowing them to route their traffic through the secure tunnel.

## Files

- **Dockerfile**: Builds the Docker image with necessary packages and configurations.
- **ssh_config**: SSH configuration file to set up the tunnel.
- **danted.conf**: Configuration file for the Dante SOCKS proxy server.
- **entrypoint.sh**: Script to establish the SSH tunnel, configure `iptables`, and start the SOCKS proxy server.

## Usage

### Step 1: Create the Dockerfile and Configuration Files

Save the following content into respective files in a directory.

#### Dockerfile

```
FROM debian:latest

# Install necessary packages
RUN apt-get update && apt-get install -y \
    openssh-client \
    dante-server \
    iptables \
    && rm -rf /var/lib/apt/lists/*

# Copy the configuration files
COPY ssh_config /etc/ssh/ssh_config
COPY danted.conf /etc/danted.conf

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose SOCKS proxy port
EXPOSE 1080

ENTRYPOINT ["/entrypoint.sh"]
```

#### ssh_config

```
Host remote-ssh-server
    HostName your.ssh.server
    User your_username
    Port 22
    IdentityFile /path/to/your/private/key
    DynamicForward 0.0.0.0:1080
```

#### danted.conf

```
logoutput: stderr

internal: 0.0.0.0 port = 1080
external: eth0

socksmethod: username none

user.privileged: root
user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}
```

#### entrypoint.sh

```
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
```

### Step 2: Build the Docker Image

Open a terminal in the directory containing these files and run:

```docker build -t ssh-socks-proxy .```

### Step 3: Run the Docker Container

Use the following command to run the container with the necessary capabilities:

```docker run -d --name ssh-socks-proxy --cap-add=NET_ADMIN -p 1080:1080 ssh-socks-proxy```

### Step 4: Configure Other Containers to Use the SOCKS5 Proxy

When starting other containers, set the environment variable `ALL_PROXY` to `socks5://ssh-socks-proxy:1080`.

Example `docker-compose.yml`:

```
version: '3'
services:
  web:
    image: your-web-image
    environment:
      - ALL_PROXY=socks5://ssh-socks-proxy:1080
    depends_on:
      - ssh-socks-proxy

  ssh-socks-proxy:
    image: ssh-socks-proxy
    ports:
      - "1080:1080"
```

## Additional Notes

- Ensure the SSH server credentials and private key path in `ssh_config` are correct.
- The `--cap-add=NET_ADMIN` flag is necessary for the container to configure `iptables`.
- The Dante SOCKS proxy server listens on port 1080, which is exposed and can be used by other containers.
