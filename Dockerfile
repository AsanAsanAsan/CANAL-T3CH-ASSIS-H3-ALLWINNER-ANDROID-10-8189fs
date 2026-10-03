FROM ubuntu:22.04

# 安裝交叉編譯老內核 (Linux 4.9) 所需的工具鏈
RUN apt-get update && apt-get install -y \
    gcc-arm-linux-gnueabi build-essential git bc bison flex libssl-dev python3 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# 1. 複製你上傳到 GitHub 的 Module.symvers
COPY Module.symvers .

# 2. 技術流繞過：利用環境變數拆分拼接網址，防止被系統格式化破壞
ENV GH_HOST="github.com"
ENV GS_HOST="kernel.googlesource.com"

# 3. 正式拉取完全相容的驅動原始碼與 Linux 4.9.y 核心樹
RUN git clone https://${GH_HOST}/jwrdegoede/rtl8189ES_android.git -b rtl8189fs driver-src && \
    git clone --depth 1 https://${GS_HOST}/pub/scm/linux/kernel/git/stable/linux.git -b linux-4.9.y kernel-src

# 4. 基因匹配：將你的 Module.symvers 餵給內核與驅動
RUN cp Module.symvers kernel-src/ && \
    cp Module.symvers driver-src/ && \
    cd kernel-src && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- defconfig && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- modules_prepare

# 5. 正式執行交叉編譯
RUN cd driver-src && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- KSRC=../kernel-src modules && \
    cp 8189fs.ko /workspace/

# 6. 開放 8080 埠口，在部署成功後讓你可以直接下載
EXPOSE 8080
CMD ["python3", "-m", "http.server", "8080"]
