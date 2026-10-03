FROM ubuntu:22.04

# 安裝編譯 4.9 內核所需的工具鏈，並補上解壓縮必備的 wget 與 unzip
RUN apt-get update && apt-get install -y \
    gcc-arm-linux-gnueabi build-essential bc bison flex libssl-dev python3 wget unzip && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# 1. 複製你上傳到 GitHub 的 Module.symvers
COPY Module.symvers .

# 2. 完全繞過 git 指令！直接用 wget 下載公開原始碼的 ZIP 壓縮包並靜態解壓
RUN wget -q -O driver.zip "https://github.com" && \
    unzip -q driver.zip && mv rtl8189ES_android-rtl8189fs driver-src && rm driver.zip

# 3. 同理，用靜態方式拉取 Google 官方穩定的 Linux 4.9.y 核心分支
RUN wget -q -O kernel.zip "https://googlesource.com" && \
    mkdir kernel-src && tar -xzf kernel.zip -C kernel-src && rm kernel.zip

# 4. 進行基因匹配：將你的 Module.symvers 餵給內核與驅動
RUN cp Module.symvers kernel-src/ && \
    cp Module.symvers driver-src/ && \
    cd kernel-src && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- defconfig && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- modules_prepare

# 5. 正式執行客製化驅動編譯
RUN cd driver-src && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- KSRC=../kernel-src modules && \
    cp 8189fs.ko /workspace/

# 6. 開放 8080 埠口，在部署成功後把網頁瀏覽器打開供你下載
EXPOSE 8080
CMD ["python3", "-m", "http.server", "8080"]
