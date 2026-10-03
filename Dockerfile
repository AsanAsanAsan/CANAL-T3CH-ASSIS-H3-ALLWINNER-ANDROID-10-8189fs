FROM ubuntu:22.04

# 安裝交叉編譯老內核 (Linux 4.9) 所需的工具鏈
RUN apt-get update && apt-get install -y \
    gcc-arm-linux-gnueabi build-essential git bc bison flex libssl-dev python3 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# 1. 複製你上傳到 GitHub 的 Module.symvers
COPY Module.symvers .

# 2. 拉取社群維護的 8189fs Android 驅動源碼
# 3. 拉取 Linux 4.9.y 穩定版內核樹（用來獲取配置框架）
RUN git clone https://github.com -b rtl8189fs driver-src && \
    git clone --depth 1 https://googlesource.com -b linux-4.9.y kernel-src

# 4. 基因匹配：將你的 Module.symvers 餵給內核與驅動
RUN cp Module.symvers kernel-src/ && \
    cp Module.symvers driver-src/ && \
    cd kernel-src && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- defconfig && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- modules_prepare

# 5. 正式執行編譯
RUN cd driver-src && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- KSRC=../kernel-src modules && \
    cp 8189fs.ko /workspace/

# 6. 開放 8080 埠口，在部署成功後把網頁瀏覽器打開，讓你可以直接點擊下載
EXPOSE 8080
CMD ["python3", "-m", "http.server", "8080"]
