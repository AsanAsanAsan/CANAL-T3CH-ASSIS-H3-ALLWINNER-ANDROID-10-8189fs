FROM ubuntu:22.04
SHELL ["/bin/bash", "-c"]

ARG KERNEL_URL=https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.9.170.tar.xz
ARG DRIVER_URL=https://github.com/jwrdegoede/rtl8189ES_linux.git
ARG DRIVER_BRANCH=rtl8189fs

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gcc-9-arm-linux-gnueabihf build-essential bc bison flex libssl-dev \
    python3 wget ca-certificates git sed xz-utils kmod file \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/arm-linux-gnueabihf-gcc-9 /usr/local/bin/arm-linux-gnueabihf-gcc

WORKDIR /workspace
RUN mkdir -p /workspace/output
COPY Module.symvers kernel.config platform_ARM_SUNnI_sdio.c ./

# 1. 驅動原始碼與核心樹
RUN git clone --depth 1 -b ${DRIVER_BRANCH} ${DRIVER_URL} driver-src
RUN wget -q -O kernel.tar.xz ${KERNEL_URL} && \
    mkdir kernel-src && tar -xf kernel.tar.xz -C kernel-src --strip-components=1 && \
    rm kernel.tar.xz

# 2. 準備核心：套用盒子的 .config 與 Module.symvers
#    HOSTCC 必須寫在 make 命令列（用 ENV 會被核心 Makefile 蓋掉）
RUN cd kernel-src && \
    cp ../kernel.config .config && touch .scmversion && \
    ( make ARCH=arm olddefconfig && \
      cp ../Module.symvers . && \
      make ARCH=arm HOSTCC="gcc -fcommon" modules_prepare ) \
      > /workspace/output/prepare.log 2>&1 ; \
    tail -n 15 /workspace/output/prepare.log ; \
    cp ../Module.symvers . ; true

# 3. 修補驅動：換平台檔、選平台、移除會造成遞迴的那一行
RUN cd driver-src && \
    cp ../platform_ARM_SUNnI_sdio.c platform/platform_ARM_SUNnI_sdio.c && \
    sed -i -E 's/^(CONFIG_PLATFORM_I386_PC)[[:space:]]*=.*/\1 = n/' Makefile && \
    sed -i -E 's/^(CONFIG_PLATFORM_ARM_SUN8I_W5P1)[[:space:]]*=.*/\1 = y/' Makefile && \
    sed -i -E 's/^EXTRA_CFLAGS \+= \$\(ccflags-y\)/# removed (recursive on 4.9): &/' Makefile && \
    grep -E "^CONFIG_PLATFORM_(I386_PC|ARM_SUN8I)" Makefile > /workspace/output/platform-check.txt

# 4. 編譯、瘦身、輸出（失敗也不中斷，看 build.log）
RUN cd driver-src && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
         KSRC=/workspace/kernel-src KVER=4.9.170 modules \
         > /workspace/output/build.log 2>&1 ; \
    tail -n 25 /workspace/output/build.log ; \
    for f in $(find . -name '*.ko'); do \
        arm-linux-gnueabihf-strip --strip-debug $f ; cp $f /workspace/output/ ; \
    done ; \
    for f in /workspace/output/*.ko; do modinfo $f ; done \
        > /workspace/output/modinfo.txt 2>&1 ; \
    grep -E "sunxi_wlan|sunxi_mmc_rescan" /workspace/kernel-src/Module.symvers \
        > /workspace/output/symbols-check.txt ; \
    ls -l /workspace/output ; true

EXPOSE 8080
WORKDIR /workspace/output
CMD ["sh", "-c", "python3 -m http.server ${PORT:-8080} --bind 0.0.0.0"]
