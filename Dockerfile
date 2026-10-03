FROM ubuntu:22.04

# 安裝交叉編譯 4.9 Linux 內核所需工具
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
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# 1. 複製你的 Module.symvers
COPY Module.symvers .

# 2. 下載 RTL8189FS 驅動原始碼（正確來源）
RUN git clone --branch rtl8189fs --depth 1 \
    https://github.com/jwrdegoede/rtl8189ES_linux.git driver-src

# 3. 下載 Linux 4.9 核心源碼
RUN wget -q -O linux-4.9.tar.xz \
    https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.9.326.tar.xz && \
    mkdir -p kernel-src && \
    tar -xf linux-4.9.tar.xz -C kernel-src --strip-components=1 && \
    rm linux-4.9.tar.xz

# 4. 複製 Module.symvers 到內核與驅動目錄
RUN cp Module.symvers kernel-src/ && \
    cp Module.symvers driver-src/ && \
    test -f kernel-src/Module.symvers && \
    test -f driver-src/Module.symvers

# 5. 準備 Linux 4.9 編譯環境
RUN cd kernel-src && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- defconfig && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- modules_prepare

# 6. 編譯 RTL8189FS 驅動模組
RUN cd driver-src && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- KSRC=../kernel-src modules

# 7. 收集編譯結果
RUN mkdir -p /workspace/output && \
    find /workspace/driver-src -name "*.ko" -exec cp {} /workspace/output/ \; && \
    ls -lh /workspace/output/

EXPOSE 8080

WORKDIR /workspace/output
CMD ["python3", "-m", "http.server", "8080", "--bind", "0.0.0.0"]
