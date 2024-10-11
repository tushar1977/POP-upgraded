#!/bin/bash

# Function to print the introduction
print_intro() {
  echo -e "\033[94m"
  figlet -f /usr/share/figlet/starwars.flf "POP-MINING UPGRADE"
  echo -e "\033[0m"

  echo -e "\033[92m📡 Upgrading POP-MINING\033[0m"   # Green color for the description 
  echo -e "\033[96m👨‍💻 Created by: Cipher\033[0m"  # Cyan color for the creator
  echo -e "\033[95m🔧 Rebuilding PoP Mining Containers...\033[0m"  # Magenta color for the upgrade message

  echo "════════════════════════════════════════════════════════════" 
  echo "║       Follow us for updates and support:                 ║"
  echo "║                                                          ║"
  echo "║     Twitter:                                             ║"
  echo "║     https://twitter.com/cipher_airdrop                   ║"
  echo "║                                                          ║"
  echo "║     Telegram:                                            ║"
  echo "║     - https://t.me/+tFmYJSANTD81MzE1                     ║"
  echo "╚════════════════════════════════════════════════════════════"
}

# Call the introduction function
print_intro

# Function to print messages in purple
show() {
    echo -e "\033[1;35m$1\033[0m"
}

# Step 1: Stop all old containers
show "Stopping all old PoP mining containers..."
docker ps --filter "name=pop_mining_" --format "{{.ID}}" | xargs -I {} docker stop {}

# Step 2: Remove old containers
show "Removing old PoP mining containers..."
docker ps -a --filter "name=pop_mining_" --format "{{.ID}}" | xargs -I {} docker rm {}

# Step 3: Download the latest version of popmd
LATEST_VERSION="v0.4.4"
ARCH=$(uname -m)

show "Downloading the latest popmd binaries for version $LATEST_VERSION..."

if [ "$ARCH" == "x86_64" ]; then
    wget --quiet --show-progress "https://github.com/hemilabs/heminetwork/releases/download/$LATEST_VERSION/heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz" -O "heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz"
    tar -xzf "heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz" -C ./ 
    mv heminetwork_${LATEST_VERSION}_linux_amd64/keygen ./keygen
    mv heminetwork_${LATEST_VERSION}_linux_amd64/popmd ./popmd
elif [ "$ARCH" == "arm64" ]; then
    wget --quiet --show-progress "https://github.com/hemilabs/heminetwork/releases/download/$LATEST_VERSION/heminetwork_${LATEST_VERSION}_linux_arm64.tar.gz" -O "heminetwork_${LATEST_VERSION}_linux_arm64.tar.gz"
    tar -xzf "heminetwork_${LATEST_VERSION}_linux_arm64.tar.gz" -C ./
    mv heminetwork_${LATEST_VERSION}_linux_arm64/keygen ./keygen
    mv heminetwork_${LATEST_VERSION}_linux_arm64/popmd ./popmd
else
    show "Unsupported architecture: $ARCH"
    exit 1
fi

show "New binaries for version $LATEST_VERSION downloaded."

# Step 4: Ask user for number of containers to upgrade
echo
show "How many PoP mining containers do you want to upgrade?"
read -p "Enter the number of containers: " instance_count

# Step 5: Ask if the user wants to use SOCKS5 proxies
echo
read -p "Do you want to use SOCKS5 proxies for the containers? (y/N): " use_proxy

# Step 6: Upgrade containers with existing wallets
for i in $(seq 1 $instance_count); do
    wallet_file="wallet_$i.json"
    if [ -f "$wallet_file" ]; then
        show "Upgrading container for Wallet $i..."

        # Extract private key from the wallet JSON file
        priv_key=$(jq -r '.private_key' "$wallet_file")

        if [[ -z "$priv_key" ]]; then
            show "Failed to retrieve private key from $wallet_file."
            exit 1
        fi

        # Step 7: Ask for SOCKS5 proxy for each instance if user opted to use proxy
        if [[ "$use_proxy" =~ ^[Yy]$ ]]; then
            echo
            read -p "Enter SOCKS5 proxy for container $i (format: socks5://username:password@IP:port): " socks5_proxy
        fi

        # Step 8: Create Dockerfile for the new container
        mkdir -p "pop_container_$i"
        cp keygen popmd pop_container_$i/  # Copy binaries into container directory
        cat << EOF > "pop_container_$i/Dockerfile"
FROM ubuntu:latest
RUN apt-get update && apt-get install -y wget jq curl
COPY ./keygen /usr/local/bin/keygen
COPY ./popmd /usr/local/bin/popmd
RUN chmod +x /usr/local/bin/keygen /usr/local/bin/popmd
WORKDIR /app
CMD ["popmd"]
EOF

        # Step 9: Build the new Docker image
        docker build -t pop_container_$i ./pop_container_$i

        # Step 10: Run the Docker container with or without SOCKS5 proxy
        if [[ "$use_proxy" =~ ^[Yy]$ ]]; then
            docker run -d --name pop_mining_$i --env POPM_BTC_PRIVKEY="$priv_key" --env POPM_STATIC_FEE=150 --env POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public --env ALL_PROXY="socks5://$socks5_proxy" pop_container_$i
            show "PoP mining container $i upgraded with SOCKS5 proxy: $socks5_proxy."
        else
            docker run -d --name pop_mining_$i --env POPM_BTC_PRIVKEY="$priv_key" --env POPM_STATIC_FEE=150 --env POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public pop_container_$i
            show "PoP mining container $i upgraded without a proxy."
        fi
    else
        show "Wallet file $wallet_file does not exist. Skipping..."
    fi
done

show "All PoP mining containers have been successfully upgraded to version $LATEST_VERSION."
