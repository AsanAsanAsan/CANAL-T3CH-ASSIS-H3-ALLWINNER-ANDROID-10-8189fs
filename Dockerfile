FROM ubuntu:22.04

# 安裝編譯 4.9 核心與驅動所需的所有交叉編譯工具鏈
RUN apt-get update && apt-get install -y \
    gcc-arm-linux-gnueabi build-essential git bc bison flex libssl-dev && \
    rm -rf /var/list/apt/lists/*

WORKDIR /workspace

# 把 GitHub 倉庫裡的 Module.symvers 複製進來
COPY Module.symvers .

# 下載驅動原始碼與 Linux 4.9.170 核心樹，並注入您的簽名檔進行基因匹配
RUN git clone https://github.com -b rtl8189fs driver-src && \
    git clone --depth 1 https://googlesource.com -b linux-4.9.y kernel-src && \
    cp Module.symvers kernel-src/ && cp Module.symvers driver-src/

# 配置內核並強制執行交叉編譯
RUN cd kernel-src && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- defconfig && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- modules_prepare && \
    cd ../driver-src && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- KSRC=../kernel-src modules && \
    cp 8189fs.ko /workspace/

# 由於 Railway 部署完必須運行一個持續的服務，我們讓它印出成功訊息後啟動一個網頁服務供您下載
RUN apt-get update && apt-get install -y python3 && \
    echo "--- 驅動編譯完美成功！ ---"

EXPOSE 8080
CMD ["python3", "-m", "http://server", "8080"]
