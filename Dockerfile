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
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY Module.symvers .
COPY kernel-headers.tar.gz .  # 假設你已經從設備取出 kernel headers

RUN git clone --branch rtl8189fs --depth 1 \
    https://github.com/jwrdegoede/rtl8189ES_linux.git driver-src

# 用設備上的 kernel headers
RUN tar -xzf kernel-headers.tar.gz -C . && \
    mv kernel-headers kernel-src

RUN cp Module.symvers kernel-src/ && \
    cp Module.symvers driver-src/

RUN cd driver-src && \
    sed -i 's/ccflags-y += \${ccflags-y}/# Removed recursive ccflags-y/g' Makefile && \
    sed -i 's/EXTRA_CFLAGS += \${EXTRA_CFLAGS}/# Removed recursive EXTRA_CFLAGS/g' Makefile

# 直接編譯，不需要 defconfig
RUN cd driver-src && \
    make ARCH=arm \
    CROSS_COMPILE=arm-linux-gnueabi- \
    KSRC=../kernel-src \
    KBUILD_EXTRA_SYMBOLS=../kernel-src/Module.symvers \
    EXTRA_CFLAGS="-I$(pwd)" \
    modules

RUN mkdir -p /workspace/output && \
    find /workspace/driver-src -name "*.ko" -exec cp {} /workspace/output/ \; && \
    ls -lh /workspace/output/

EXPOSE 8080
WORKDIR /workspace/output
CMD ["python3", "-m", "http.server", "8080", "--bind", "0.0.0.0"]
