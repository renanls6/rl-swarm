#!/bin/bash

# Definindo as variáveis principais
FRONTEND_DIR="/path/to/frontend"
SERVER_DIR="/path/to/server"
HUGGINGFACE_TOKEN="your_huggingface_token_here"

# Função para verificar o token Hugging Face
verify_huggingface_token() {
    huggingface-cli whoami > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "❌ Token Hugging Face inválido. Verifique e tente novamente."
        exit 1
    fi
    echo "✅ Token Hugging Face validado com sucesso."
}

# Função para instalar o ngrok se necessário
install_ngrok() {
    if ! command -v ngrok &> /dev/null; then
        echo "🔧 Instalando ngrok..."
        curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
        echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
        sudo apt update && sudo apt install ngrok
    else
        echo "✅ Ngrok já está instalado."
    fi
}

# Função para autenticação com Hugging Face
authenticate_huggingface() {
    if [ -z "$HUGGINGFACE_TOKEN" ]; then
        echo "🔑 Autenticando com Hugging Face..."
        huggingface-cli login
    else
        echo "✅ Token Hugging Face fornecido."
    fi
}

# Função para instalar o Node.js e npm
install_node() {
    echo "🔧 Instalando Node.js e npm..."
    curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
    sudo apt-get install -y nodejs
    sudo apt-get install -y npm
}

# Função para configurar o servidor Node.js
setup_node_server() {
    echo "🔧 Instalando dependências do frontend..."
    cd $FRONTEND_DIR
    npm install
}

# Função para iniciar o frontend
start_frontend() {
    echo "🔧 Iniciando o servidor frontend..."
    npm run dev &
}

# Função para configurar e iniciar o Hivemind
start_hivemind() {
    echo "🔧 Iniciando o treinamento distribuído com Hivemind..."
    python3 -m hivemind.run_server \
        --num-experts $(nproc) \
        --batch-size 64 \
        --cuda-visible-devices 0 \
        --port 5000
}

# Função para configurar e iniciar o túnel ngrok
start_ngrok_tunnel() {
    echo "🔧 Iniciando o túnel ngrok..."
    ngrok http 5000 &
}

# Função principal para executar todas as etapas
main() {
    # Atualizar e instalar dependências
    echo "🔧 Atualizando o sistema..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl git

    # Verificar o token do Hugging Face
    verify_huggingface_token

    # Instalar ngrok
    install_ngrok

    # Instalar Node.js e dependências do frontend
    install_node
    setup_node_server

    # Autenticar Hugging Face
    authenticate_huggingface

    # Iniciar o frontend
    start_frontend

    # Iniciar Hivemind
    start_hivemind

    # Iniciar túnel ngrok
    start_ngrok_tunnel

    echo "✅ Configuração concluída com sucesso!"
}

# Chama a função principal
main
