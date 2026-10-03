FROM ubuntu:22.04

# 安裝編譯 Linux 4.9.170 與驅動所需的完整交叉編譯工具鏈
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gcc-arm-linux-gnueabi \
    build-essential \
    bc \
    bison \
    flex \
    libssl-dev \
    python3 \
    wget \
    ca-certificates \
    git \
    sed \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# 複製你的電視盒基因檔
COPY Module.symvers .

# 1. 下載 8189fs Android 專用分支源碼
RUN git clone --branch rtl8189fs --depth 1 \
    https://github.com driver-src

# 2. 下載官方標準的 Linux 4.9.170 完整核心樹（此 CDN 網址非常穩定，Railway 可秒殺下載）
RUN wget -q --no-check-certificate -O linux-4.9.tar.xz \
    https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.9.170.tar.xz && \
    mkdir -p kernel-src && \
    tar -xf linux-4.9.tar.xz -C kernel-src --strip-components=1 && \
    rm linux-4.9.tar.xz

# 3. 事先將簽名檔同步到兩個目錄中
RUN cp Module.symvers kernel-src/ && \
    cp Module.symvers driver-src/

# 建立輸出產物資料夾
RUN mkdir -p /workspace/output

# 保持網頁服務常駐，方便待會編譯完直接用網址下載
EXPOSE 8080
WORKDIR /workspace/output
CMD ["python3", "-m", "http.server", "8080", "--bind", "0.0.0.0"]
