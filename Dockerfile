FROM ubuntu:22.04
SHELL ["/bin/bash", "-c"]

ARG KERNEL_URL=https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.9.170.tar.xz
ARG DRIVER_URL=https://github.com/jwrdegoede/rtl8189ES_linux.git
ARG DRIVER_BRANCH=rtl8189fs

ENV ARCH=arm
ENV CROSS_COMPILE=arm-linux-gnueabihf-

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gcc-9-arm-linux-gnueabihf build-essential bc bison flex libssl-dev \
    python3 wget ca-certificates git sed xz-utils kmod file \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/arm-linux-gnueabihf-gcc-9 /usr/local/bin/arm-linux-gnueabihf-gcc

WORKDIR /workspace
COPY Module.symvers kernel.config ./

# 1. 驅動原始碼（注意：你的 GitHub 倉庫沒有驅動，只有 Module.symvers）
RUN git clone --depth 1 -b ${DRIVER_BRANCH} ${DRIVER_URL} driver-src

# 2. 核心樹
RUN wget -q -O kernel.tar.xz ${KERNEL_URL} && \
    mkdir kernel-src && tar -xf kernel.tar.xz -C kernel-src --strip-components=1 && \
    rm kernel.tar.xz

# 3. 套用盒子的 .config 與 Module.symvers（modpost 會從這裡取得 CRC）
RUN cd kernel-src && \
    cp ../kernel.config .config && \
    touch .scmversion && \
    make olddefconfig && \
    cp ../Module.symvers . && \
    make modules_prepare && \
    mkdir -p /workspace/output && \
    grep -E "^CONFIG_(MODVERSIONS|MODULE_UNLOAD|SMP|PREEMPT|ARM_PATCH_PHYS_VIRT|CFG80211|MMC)=" .config \
      > /workspace/output/config-check.txt; \
    cat include/generated/utsrelease.h >> /workspace/output/config-check.txt; \
    grep -E "sunxi_wlan|sunxi_mmc_rescan|cfg80211_scan_done" ../Module.symvers \
      > /workspace/output/symbols-check.txt || true

# 4. 編譯；失敗也不讓建置中斷，build.log 可下載查看
RUN cd driver-src && \
    sed -i -E 's/^(CONFIG_PLATFORM_I386_PC)[[:space:]]*=.*/\1 = n/' Makefile && \
    sed -i -E 's/^(CONFIG_PLATFORM_ARM_SUN8I)[[:space:]]*=.*/\1 = y/' Makefile && \
    grep -E "^CONFIG_PLATFORM" Makefile > /workspace/output/platform-check.txt; \
    ( make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
        KSRC=/workspace/kernel-src KVER=4.9.170 modules 2>&1 \
        | tee /workspace/output/build.log ) ; \
    for f in $(find . -name '*.ko'); do \
        arm-linux-gnueabihf-strip --strip-debug $f; cp $f /workspace/output/; \
    done; \
    for f in /workspace/output/*.ko; do modinfo $f; done > /workspace/output/modinfo.txt 2>&1 || true

EXPOSE 8080
WORKDIR /workspace/output
CMD ["sh", "-c", "python3 -m http.server ${PORT:-8080} --bind 0.0.0.0"]
