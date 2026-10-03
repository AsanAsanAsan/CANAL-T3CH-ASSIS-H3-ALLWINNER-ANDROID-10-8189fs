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

# 準備 kernel
RUN cd kernel-src && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- defconfig

# 手動編譯 modpost（跳過 dtc 和其他工具）
RUN cd kernel-src && \
    make -C scripts/mod modpost 2>&1 || \
    (cd scripts/mod && gcc -o modpost modpost.c file.c sumversion.c 2>&1 || true)

# 確保 modpost 存在
RUN ls -la kernel-src/scripts/mod/modpost || echo "modpost not found, will try alternative"

# 編譯驅動
RUN cd driver-src && \
    make ARCH=arm \
    CROSS_COMPILE=arm-linux-gnueabi- \
    KSRC=../kernel-src \
    KBUILD_EXTRA_SYMBOLS=../kernel-src/Module.symvers \
    EXTRA_CFLAGS="-I$(pwd)" \
    modules

# 蒐集編譯結果
RUN mkdir -p /workspace/output && \
    find /workspace/driver-src -name "*.ko" -type f -exec cp {} /workspace/output/ \; && \
    ls -lh /workspace/output/

EXPOSE 8080
WORKDIR /workspace/output
CMD ["python3", "-m", "http.server", "8080", "--bind", "0.0.0.0"]
