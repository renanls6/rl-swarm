#!/bin/bash

ROOT=$PWD

RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;95m'
BLUE='\033[0;94m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_step() {
    echo -e "\n${CYAN}${BOLD}Step $1: $2${NC}"
}

check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Success!${NC}"
    else
        echo -e "${RED}✗ Failed! Please check errors above and try again.${NC}"
        exit 1
    fi
}

# Export environment variables
export PUB_MULTI_ADDRS
export PEER_MULTI_ADDRS
export HOST_MULTI_ADDRS
export IDENTITY_PATH
export ORG_ID
export HF_HUB_DOWNLOAD_TIMEOUT=120

# Set default values for environment variables if not already defined
DEFAULT_PUB_MULTI_ADDRS=""
PUB_MULTI_ADDRS=${PUB_MULTI_ADDRS:-$DEFAULT_PUB_MULTI_ADDRS}

DEFAULT_PEER_MULTI_ADDRS="/ip4/38.101.215.13/tcp/30002/p2p/QmQ2gEXoPJg6iMBSUFWGzAabS2VhnzuS782Y637hGjfsRJ"
PEER_MULTI_ADDRS=${PEER_MULTI_ADDRS:-$DEFAULT_PEER_MULTI_ADDRS}

DEFAULT_HOST_MULTI_ADDRS="/ip4/0.0.0.0/tcp/38331"
HOST_MULTI_ADDRS=${HOST_MULTI_ADDRS:-$DEFAULT_HOST_MULTI_ADDRS}

DEFAULT_IDENTITY_PATH="$ROOT"/swarm.pem
IDENTITY_PATH=${IDENTITY_PATH:-$DEFAULT_IDENTITY_PATH}

echo -e "\033[38;5;45m\033[1m"
cat << "EOF"
    ██████  ██            ███████ ██     ██  █████  ██████  ███    ███ 
    ██   ██ ██            ██      ██     ██ ██   ██ ██   ██ ████  ████ 
    ██████  ██      █████ ███████ ██  █  ██ ███████ ██████  ██ ████ ██ 
    ██   ██ ██                 ██ ██ ███ ██ ██   ██ ██   ██ ██  ██  ██ 
    ██   ██ ███████       ███████  ███ ███  ██   ██ ██   ██ ██      ██ 
    
          
           JOIN THE COMMUNITY : https://t.me/Nexgenexplore
                                                                
EOF
echo -e "\033[0m"

# Check if userData.json exists
if [ -f "modal-login/temp-data/userData.json" ]; then
    cd modal-login
    source ~/.bashrc

    # Install npm if not present
    if ! command -v npm >/dev/null 2>&1; then
        echo -e "${YELLOW}npm is not installed. Installing Node.js and npm...${NC}"
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs
        source ~/.bashrc
    fi

    echo -e "\n${CYAN}Installing dependencies with npm...${NC}"
    npm install --legacy-peer-deps

    # Start the development server in the background
    echo -e "\n${CYAN}Starting the development server...${NC}"
    npm run dev > server.log 2>&1 &

    SERVER_PID=$!
    MAX_WAIT=60
    counter=0
    while [ $counter -lt $MAX_WAIT ]; do
        if grep -q "Local:        http://localhost:" server.log; then
            PORT=$(grep "Local:        http://localhost:" server.log | sed -n 's/.*http:\/\/localhost:\([0-9]*\).*/\1/p')
            if [ -n "$PORT" ]; then
                echo -e "${GREEN}Server is running successfully on port $PORT\n${NC}"
                break
            fi
        fi
        sleep 1
        counter=$((counter + 1))
    done

    if [ $counter -eq $MAX_WAIT ]; then
        echo -e "${RED}Timeout waiting for server to start.${NC}"
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi
    cd ..

    # Extract ORG_ID from userData.json
    ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' modal-login/temp-data/userData.json)
    if [ -z "$ORG_ID" ]; then
        echo -e "${RED}Failed to extract ORG_ID from userData.json. Exiting...${NC}"
        exit 1
    fi
    echo -e "${CYAN}ORG_ID has been set to: ${BOLD}$ORG_ID\n${NC}"

    # Cleanup function for graceful shutdown
    cleanup() {
        echo -e "${YELLOW}Shutting down server and ngrok...${NC}"
        kill $SERVER_PID 2>/dev/null || echo -e "${YELLOW}Server PID not found.${NC}"
        kill $NGROK_PID 2>/dev/null || echo -e "${YELLOW}ngrok PID not found.${NC}"
        exit 0
    }

    trap cleanup INT

else
    cd modal-login
    source ~/.bashrc
    if ! command -v npm >/dev/null 2>&1; then
        echo -e "${YELLOW}npm is not installed. Installing Node.js and npm...${NC}"
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs
        source ~/.bashrc
    fi
    echo -e "\n${CYAN}Installing dependencies with npm...${NC}"
    npm install --legacy-peer-deps

    # Start the development server in the background
    echo -e "\n${CYAN}Starting the development server...${NC}"
    npm run dev > server.log 2>&1 &

    SERVER_PID=$!
    MAX_WAIT=60
    counter=0
    while [ $counter -lt $MAX_WAIT ]; do
        if grep -q "Local:        http://localhost:" server.log; then
            PORT=$(grep "Local:        http://localhost:" server.log | sed -n 's/.*http:\/\/localhost:\([0-9]*\).*/\1/p')
            if [ -n "$PORT" ]; then
                echo -e "${GREEN}Server is running successfully on port $PORT.${NC}"
                break
            fi
        fi
        sleep 1
        counter=$((counter + 1))
    done

    if [ $counter -eq $MAX_WAIT ]; then
        echo -e "${RED}Timeout waiting for server to start.${NC}"
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi

    # Detect system architecture
    print_step 1 "Detecting system architecture"
    ARCH=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    if [ "$ARCH" = "x86_64" ]; then
        NGROK_ARCH="amd64"
        echo -e "${GREEN}Detected x86_64 architecture.${NC}"
    elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
        NGROK_ARCH="arm64"
        echo -e "${GREEN}Detected ARM64 architecture.${NC}"
    elif [[ "$ARCH" == arm* ]]; then
        NGROK_ARCH="arm"
        echo -e "${GREEN}Detected ARM architecture.${NC}"
    else
        echo -e "${RED}Unsupported architecture: $ARCH. Please use a supported system.${NC}"
        exit 1
    fi

    print_step 2 "Downloading and installing ngrok"
    echo -e "${YELLOW}Downloading ngrok for $OS-$NGROK_ARCH...${NC}"
    wget -q --show-progress "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-$OS-$NGROK_ARCH.tgz"
    check_success

    echo -e "${YELLOW}Extracting ngrok...${NC}"
    tar -xzf "ngrok-v3-stable-$OS-$NGROK_ARCH.tgz"
    check_success

    echo -e "${YELLOW}Moving ngrok to /usr/local/bin/ (requires sudo)...${NC}"
    sudo mv ngrok /usr/local/bin/
    check_success

    echo -e "${YELLOW}Cleaning up temporary files...${NC}"
    rm "ngrok-v3-stable-$OS-$NGROK_ARCH.tgz"
    check_success

    # Authenticate ngrok
    print_step 3 "Authenticating ngrok"
    while true; do
        echo -e "\n${YELLOW}To get your authtoken:${NC}"
        echo -e "${CYAN}1. Visit https://ngrok.com and create an account.${NC}"
        echo -e "${CYAN}2. Go to your dashboard and copy your authtoken.${NC}"
        echo -e "\nEnter your ngrok authtoken: ${BOLD}"
        read -p "Ngrok Authtoken: " NGROK_AUTHTOKEN
        echo -e "${NC}"

        if [ -n "$NGROK_AUTHTOKEN" ]; then
            ngrok config add-authtoken "$NGROK_AUTHTOKEN"
            break
        else
            echo -e "${RED}Please enter a valid authtoken.${NC}"
        fi
    done

    print_step 4 "Running ngrok"
    ngrok tcp 38331 &

    NGROK_PID=$!
    sleep 5

    echo -e "${CYAN}Ngrok is running. Fetching URL...${NC}"

    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')

    if [[ "$NGROK_URL" == *"tcp"* ]]; then
        echo -e "${GREEN}Ngrok public URL: $NGROK_URL${NC}"
    else
        echo -e "${RED}Failed to fetch ngrok URL.${NC}"
        exit 1
    fi

    # Install Python requirements
    echo -e "${CYAN}Installing required Python packages...${NC}"
    pip install -r "$ROOT"/requirements-hivemind.txt > /dev/null
    pip install -r "$ROOT"/requirements.txt > /dev/null

    # Determine config path based on hardware
    if ! which nvidia-smi; then
        CONFIG_PATH="$ROOT/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
    elif [ -n "$CPU_ONLY" ]; then
        CONFIG_PATH="$ROOT/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
    else
        pip install -r "$ROOT"/requirements_gpu.txt > /dev/null
        CONFIG_PATH="$ROOT/hivemind_exp/configs/gpu/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
    fi

    echo -e "${GREEN}>>> Awesome, All packages installed successfully!\n${NC}"

    # Handle Hugging Face token
    if [ -n "${HF_TOKEN}" ]; then
        HUGGINGFACE_ACCESS_TOKEN=${HF_TOKEN}
    else
        read -p "Would you like to push models you train in the RL swarm to the Hugging Face Hub? [y/N] " yn
        yn=${yn:-N}
        case $yn in
            [Yy]* ) read -p "Enter your Hugging Face access token: " HUGGINGFACE_ACCESS_TOKEN;;
            [Nn]* ) HUGGINGFACE_ACCESS_TOKEN="None";;
            * ) echo -e "${YELLOW}>>> No answer was given, so NO models will be pushed to the Hugging Face Hub.${NC}" && HUGGINGFACE_ACCESS_TOKEN="None";;
        esac
    fi

    echo -e "\n${GREEN}${BOLD}Good luck in the swarm! Your training session is about to begin.\n${NC}"

    # Run the Python training script with appropriate parameters
    if [ -n "$ORG_ID" ]; then
        python -m hivemind_exp.gsm8k.train_single_gpu \
            --hf_token "$HUGGINGFACE_ACCESS_TOKEN" \
            --identity_path "$IDENTITY_PATH" \
            --modal_org_id "$ORG_ID" \
            --config "$CONFIG_PATH"
    else
        python -m hivemind_exp.gsm8k.train_single_gpu \
            --hf_token "$HUGGINGFACE_ACCESS_TOKEN" \
            --identity_path "$IDENTITY_PATH" \
            --public_maddr "$PUB_MULTI_ADDRS" \
            --initial_peers "$PEER_MULTI_ADDRS" \
            --host_maddr "$HOST_MULTI_ADDRS" \
            --config "$CONFIG_PATH"
    fi

    wait
fi
