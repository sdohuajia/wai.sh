#!/bin/bash

# 一键安装脚本
# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 权限运行此脚本: sudo $0"
  exit 1
fi

# 检查网络连接
if ! ping -c 1 google.com &> /dev/null; then
  echo "错误: 无网络连接，请检查网络后重试"
  exit 1
fi

# 更新系统软件包
echo "正在更新系统软件包..."
apt update && apt upgrade -y || { echo "错误: 系统更新失败"; exit 1; }

# 安装通用工具和依赖
echo "正在安装通用工具和依赖..."
apt install -y screen curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip || { echo "错误: 工具安装失败"; exit 1; }

# 安装 Python
echo "正在安装 Python..."
apt install -y python3 python3-pip python3-venv python3-dev || { echo "错误: Python 安装失败"; exit 1; }

# 安装 Node.js
echo "正在安装 Node.js..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash - || { echo "错误: Node.js 源设置失败"; exit 1; }
apt install -y nodejs || { echo "错误: Node.js 安装失败"; exit 1; }
node -v || { echo "错误: Node.js 未正确安装"; exit 1; }

# 安装 Yarn
echo "正在安装 Yarn..."
npm install -g yarn || { echo "错误: Yarn 安装失败"; exit 1; }
yarn -v || { echo "错误: Yarn 未正确安装"; exit 1; }

# 检测并安装 NVIDIA 驱动程序 (版本 550.90.07)
echo "正在检测 NVIDIA GPU 和驱动..."
if ! lspci | grep -i nvidia &> /dev/null; then
  echo "未检测到 NVIDIA GPU，跳过驱动和 CUDA 安装"
else
  # 检查是否已安装 NVIDIA 驱动
  if nvidia-smi &> /dev/null; then
    CURRENT_VERSION=$(nvidia-smi --query --display=DRIVER | grep -oP 'Driver Version: \K[0-9.]+')
    if [ "$CURRENT_VERSION" == "550.90.07" ]; then
      echo "NVIDIA 驱动版本 550.90.07 已安装，跳过安装"
    else
      echo "检测到其他版本的 NVIDIA 驱动 ($CURRENT_VERSION)，将安装版本 550.90.07"
    fi
  fi

  # 安装 NVIDIA 驱动依赖
  echo "正在安装 NVIDIA 驱动依赖..."
  apt install -y linux-headers-$(uname -r) dkms || { echo "错误: 驱动依赖安装失败"; exit 1; }

  # 下载并安装 NVIDIA 驱动 550.90.07
  echo "正在下载 NVIDIA 驱动 550.90.07..."
  wget -O NVIDIA-Linux-driver.run http://us.download.nvidia.com/XFree86/Linux-x86_64/550.90.07/NVIDIA-Linux-x86_64-550.90.07.run || { echo "错误: 驱动下载失败"; exit 1; }
  chmod +x NVIDIA-Linux-driver.run
  echo "正在安装 NVIDIA 驱动 550.90.07..."
  ./NVIDIA-Linux-driver.run --silent --dkms || { echo "错误: 驱动安装失败"; exit 1; }
  rm NVIDIA-Linux-driver.run

  # 验证驱动安装
  if nvidia-smi &> /dev/null; then
    INSTALLED_VERSION=$(nvidia-smi --query --display=DRIVER | grep -oP 'Driver Version: \K[0-9.]+')
    if [ "$INSTALLED_VERSION" == "550.90.07" ]; then
      echo "NVIDIA 驱动 550.90.07 安装成功"
    else
      echo "错误: 安装的驱动版本 ($INSTALLED_VERSION) 不匹配预期 (550.90.07)"
      exit 1
    fi
  else
    echo "错误: NVIDIA 驱动安装后无法运行 nvidia-smi"
    exit 1
  fi

  # 检测并安装 CUDA Toolkit 12.4
  echo "正在检测 CUDA Toolkit..."
  if nvcc --version | grep -q "12.4"; then
    echo "CUDA Toolkit 12.4 已安装，跳过安装"
  else
    echo "正在安装 CUDA Toolkit 12.4..."
    # 下载并配置 CUDA 仓库
    wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-wsl-ubuntu.pin || { echo "错误: CUDA 仓库 pin 下载失败"; exit 1; }
    mv cuda-wsl-ubuntu.pin /etc/apt/preferences.d/cuda-repository-pin-600
    wget https://developer.download.nvidia.com/compute/cuda/12.4.0/local_installers/cuda-repo-wsl-ubuntu-12-4-local_12.4.0-1_amd64.deb || { echo "错误: CUDA 安装包下载失败"; exit 1; }
    dpkg -i cuda-repo-wsl-ubuntu-12-4-local_12.4.0-1_amd64.deb || { echo "错误: CUDA 安装包配置失败"; exit 1; }
    cp /var/cuda-repo-wsl-ubuntu-12-4-local/cuda-*-keyring.gpg /usr/share/keyrings/ || { echo "错误: CUDA 密钥配置失败"; exit 1; }
    apt update || { echo "错误: 仓库更新失败"; exit 1; }
    apt install -y cuda-toolkit-12-4 || { echo "错误: CUDA Toolkit 12.4 安装失败"; exit 1; }
    rm cuda-repo-wsl-ubuntu-12-4-local_12.4.0-1_amd64.deb

    # 配置环境变量
    echo 'export PATH=/usr/local/cuda-12.4/bin:$PATH' >> /etc/profile.d/cuda.sh
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.4/lib64:$LD_LIBRARY_PATH' >> /etc/profile.d/cuda.sh
    chmod +x /etc/profile.d/cuda.sh
    source /etc/profile.d/cuda.sh

    # 验证 CUDA 安装
    if nvcc --version | grep -q "12.4"; then
      echo "CUDA Toolkit 12.4 安装成功"
    else
      echo "错误: CUDA Toolkit 12.4 安装失败或版本不匹配"
      exit 1
    fi
  fi
fi

# 安装 w.ai CLI
echo "正在安装 w.ai CLI..."
curl -fsSL https://app.w.ai/install.sh | bash || { echo "错误: w.ai CLI 安装失败"; exit 1; }

# 提示用户输入 W_AI_API_KEY
echo "请输入您的 W_AI_API_KEY："
read -r W_AI_API_KEY
if [ -z "$W_AI_API_KEY" ]; then
  echo "错误: 未提供 W_AI_API_KEY"
  exit 1
fi

# 配置 W_AI_API_KEY 环境变量
echo "正在配置 W_AI_API_KEY..."
echo "export W_AI_API_KEY=$W_AI_API_KEY" >> /etc/profile.d/wai.sh
chmod +x /etc/profile.d/wai.sh
source /etc/profile.d/wai.sh

# 验证 w.ai CLI 安装
if command -v wai &> /dev/null; then
  echo "w.ai CLI 安装成功"
else
  echo "错误: w.ai CLI 未正确安装"
  exit 1
fi

# 运行 wai run
echo "正在运行 wai run..."
wai run || { echo "错误: wai run 执行失败"; exit 1; }

# 清理缓存
echo "正在清理安装缓存..."
apt autoremove -y && apt autoclean

echo "安装和配置完成！"
