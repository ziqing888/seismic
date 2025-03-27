#!/bin/bash

# 定义颜色代码
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

echo -e "${BLUE}🌟 欢迎使用 Counter Seismic 合约部署脚本！🌟${NC}"
echo -e "${BLUE}📍 当前任务：在 VPS 上部署到 devnet，稳稳当当！${NC}"

# 设置严格模式
set -e
set -o pipefail
set -u

# 日志文件
LOG_FILE="/var/log/deploy_log_$(date +%Y%m%d_%H%M%S).txt"
echo -e "${YELLOW}📜 日志将记录到 $LOG_FILE${NC}"
sudo mkdir -p /var/log
sudo chmod 777 /var/log  # 临时权限，生产环境可调整
exec > >(tee -a "$LOG_FILE") 2>&1

# 错误处理
handle_error() {
    echo -e "${RED}❌ 哎呀，出大事了！脚本在第 $1 行挂了，错误码：$2${NC}"
    echo -e "${YELLOW}👉 别慌，检查 $LOG_FILE 或联系我吧！${NC}"
    exit 1
}
trap 'handle_error $LINENO "$?"' ERR

# 切换到主目录
cd ~

# 第一步：检查和更新系统
echo -e "${BLUE}🚀 第一步：检查系统和基础装备...${NC}"
if ! dpkg -l | grep -q curl || ! dpkg -l | grep -q git || ! dpkg -l | grep -q build-essential || ! dpkg -l | grep -q jq; then
    echo -e "${YELLOW}🛠️ 发现缺少工具，更新并安装中...${NC}"
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl git build-essential jq
else
    echo -e "${GREEN}👍 工具已齐全，跳过安装！${NC}"
fi
echo -e "${GREEN}✅ 系统检查完毕，工具箱已备齐！${NC}"

# 第二步：检查和安装 Rust
echo -e "${BLUE}🛠️ 第二步：检查 Rust 环境...${NC}"
if ! command -v rustc &> /dev/null; then
    echo -e "${YELLOW}🔧 Rust 还没装？马上搞定...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.70.0
    source "$HOME/.cargo/env"
    echo -e "${GREEN}🎉 Rust 安装成功，版本 1.70.0，稳如老狗！${NC}"
else
    echo -e "${GREEN}👍 Rust 已就位，版本是：$(rustc --version)${NC}"
fi

# 第三步：检查和安装 sfoundryup 及 scast
echo -e "${BLUE}🔧 第三步：检查 sfoundryup 和 scast 环境...${NC}"
if ! command -v sfoundryup &> /dev/null || ! command -v scast &> /dev/null; then
    echo -e "${YELLOW}🚀 sfoundryup 或 scast 未安装，重新安装中...${NC}"
    curl -L --retry 3 --retry-delay 5 -H "Accept: application/vnd.github.v3.raw" \
         "https://api.github.com/repos/SeismicSystems/seismic-foundry/contents/sfoundryup/install?ref=seismic" | bash || {
        echo -e "${RED}❌ sfoundryup 下载失败，网络不给力？再试试吧！${NC}"; exit 1;
    }
    export PATH="$HOME/.seismic/bin:$PATH"
    echo 'export PATH="$HOME/.seismic/bin:$PATH"' >> "$HOME/.bashrc"
    set +u
    source "$HOME/.bashrc" || echo -e "${YELLOW}⚠️ source .bashrc 有点小问题，但不影响大局${NC}"
    set -u
    sfoundryup || { echo -e "${RED}❌ sfoundryup 更新失败，检查网络或权限！${NC}"; exit 1; }
    if ! command -v scast &> /dev/null; then
        echo -e "${RED}❌ scast 仍未安装，可能 sfoundryup 未正确更新工具！${NC}"
        exit 1
    fi
    echo -e "${GREEN}🎯 sfoundryup 和 scast 就位，环境整好了！${NC}"
else
    echo -e "${GREEN}👍 sfoundryup 和 scast 已安装，环境就绪！${NC}"
fi

# 第四步：管理 try-devnet 仓库
echo -e "${BLUE}📦 第四步：检查 try-devnet 仓库...${NC}"
if [ ! -d "try-devnet" ]; then
    echo -e "${YELLOW}🔄 try-devnet 还没下载？cloning 一波...${NC}"
    git clone --recurse-submodules https://github.com/SeismicSystems/try-devnet.git
    echo -e "${GREEN}✅ 仓库已到手，干得漂亮！${NC}"
else
    echo -e "${YELLOW}🔄 try-devnet 已存在，更新一下最新版本...${NC}"
    cd try-devnet
    git pull
    git submodule update --init --recursive
    cd ..
    echo -e "${GREEN}✅ 更新完成，新鲜出炉！${NC}"
fi

# 第五步：部署合约
echo -e "${BLUE}🏗️ 第五步：部署合约，走起！${NC}"
cd try-devnet/packages/contract/ || {
    echo -e "${RED}❌ 合约目录跑哪儿去了？检查 try-devnet/packages/contract 吧！${NC}"; exit 1;
}
bash script/deploy.sh
echo -e "${GREEN}🎉 合约部署成功，牛气冲天！${NC}"

# 第六步：设置 CLI 和 Bun
echo -e "${BLUE}📲 第六步：搞定 CLI，Bun 来助阵...${NC}"
cd ~/try-devnet/packages/cli/ || {
    echo -e "${RED}❌ CLI 目录找不到了，路径有问题？${NC}"; exit 1;
}
if ! command -v bun &> /dev/null; then
    echo -e "${YELLOW}🛠️ Bun 还没装？马上安排...${NC}"
    curl -fsSL https://bun.sh/install | bash || {
        echo -e "${RED}❌ Bun 安装失败，网络或权限问题？${NC}"; exit 1;
    }
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$HOME/.bashrc"
    echo -e "${GREEN}🎉 Bun 安装成功，快如闪电！${NC}"
else
    echo -e "${GREEN}👍 Bun 已就位，准备就绪！${NC}"
fi
bun install
echo -e "${GREEN}✅ CLI 配置完成，Bun 真香！${NC}"

# 第七步：执行交易
echo -e "${BLUE}💸 第七步：跑个交易试试水...${NC}"
bash script/transact.sh
echo -e "${GREEN}🎊 交易搞定，完美收官！${NC}"

# 胜利宣言
echo -e "${GREEN}🌈 恭喜你！部署和交易全部顺利完成！${NC}"
echo -e "${YELLOW}👀 日志已保存到 $LOG_FILE，有啥问题随时找我聊～${NC}"
