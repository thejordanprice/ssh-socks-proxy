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
