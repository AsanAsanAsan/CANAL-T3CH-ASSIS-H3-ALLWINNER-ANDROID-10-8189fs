FROM ubuntu:22.04

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

COPY Module.symvers .

RUN git clone --branch rtl8189fs --depth 1 \
    https://github.com/jwrdegoede/rtl8189ES_linux.git driver-src

RUN wget -q -O linux-4.9.tar.xz \
    https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.9.170.tar.xz && \
    mkdir -p kernel-src && \
    tar -xf linux-4.9.tar.xz -C kernel-src --strip-components=1 && \
    rm linux-4.9.tar.xz

RUN cp Module.symvers kernel-src/ && \
    cp Module.symvers driver-src/

RUN cd driver-src && \
    sed -i 's/ccflags-y += \${ccflags-y}/# Removed recursive ccflags-y/g' Makefile && \
    sed -i 's/EXTRA_CFLAGS += \${EXTRA_CFLAGS}/# Removed recursive EXTRA_CFLAGS/g' Makefile

# 最小化 kernel 準備
RUN cd kernel-src && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- defconfig

# 生成必要的配置檔案
RUN cd kernel-src && \
    mkdir -p include/config include/generated/uapi/linux && \
    grep "^CONFIG_" .config > include/config/auto.conf && \
    echo "#define LINUX_VERSION_CODE 263330" > include/generated/uapi/linux/version.h && \
    touch include/generated/autoconf.h

# 編譯驅動 - 輸出完整錯誤
RUN cd driver-src && \
    make ARCH=arm \
    CROSS_COMPILE=arm-linux-gnueabi- \
    KSRC=../kernel-src \
    KBUILD_EXTRA_SYMBOLS=../kernel-src/Module.symvers \
    EXTRA_CFLAGS="-I$(pwd)" \
    modules 2>&1 | tee /workspace/build.log || cat /workspace/build.log

# 蒐集編譯結果並輸出診斷信息
RUN echo "=== Build Log ===" && \
    cat /workspace/build.log | tail -50 && \
    echo "=== Checking for .ko files ===" && \
    find /workspace/driver-src -name "*.ko" -type f && \
    mkdir -p /workspace/output && \
    find /workspace/driver-src -name "*.ko" -type f -exec cp {} /workspace/output/ \; || echo "No .ko files found" && \
    echo "=== Output directory ===" && \
    ls -lh /workspace/output/ || echo "Output directory is empty"

EXPOSE 8080
WORKDIR /workspace/output
CMD ["python3", "-m", "http.server", "8080", "--bind", "0.0.0.0"]
