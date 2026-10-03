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
    patch \
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

# 直接修改 lex 和 yacc 源文件 (不是 shipped 版本)
# 修復 dtc-lexer.lex - 移除全局 yylloc 聲明
RUN cd kernel-src && \
    sed -i '/^int yylloc;$/d' scripts/dtc/dtc-lexer.lex && \
    sed -i '/^YYLTYPE yylloc;$/d' scripts/dtc/dtc-lexer.lex

# 修復 dtc-parser.tab - 將 yylloc 改成 static
RUN cd kernel-src && \
    sed -i 's/^int yylloc;$/static int yylloc;/' scripts/dtc/dtc-parser.tab.c && \
    sed -i 's/^YYLTYPE yylloc;$/static YYLTYPE yylloc;/' scripts/dtc/dtc-parser.tab.c

# 刪除 shipped 文件強制重新生成
RUN cd kernel-src && \
    rm -f scripts/dtc/dtc-lexer.lex.c_shipped && \
    rm -f scripts/dtc/dtc-parser.tab.c_shipped && \
    rm -f scripts/dtc/dtc-parser.tab.h_shipped

RUN cd driver-src && \
    sed -i 's/ccflags-y += \${ccflags-y}/# Removed recursive ccflags-y/g' Makefile && \
    sed -i 's/EXTRA_CFLAGS += \${EXTRA_CFLAGS}/# Removed recursive EXTRA_CFLAGS/g' Makefile

RUN cd kernel-src && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- defconfig && \
    make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi- modules_prepare

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
