FROM alpine:3.18 AS builder

LABEL stage=builder

RUN apk add --no-cache \
    bash \
    build-base \
    cmake \
    git \
    openssl-dev \
    linux-headers \
    python3 \
    libedit-dev \
    zlib-dev \
    curl \
    pcre-dev \
    libxml2-dev \
    && git clone https://github.com/Haivision/srt.git /tmp/srt \
    && cd /tmp/srt \
    && cmake . -DCMAKE_INSTALL_PREFIX=/usr \
    && make -j$(nproc) \
    && make install \
    && git clone https://github.com/tsduck/tsduck.git /tmp/tsduck \
    && cd /tmp/tsduck \
    && make -j$(nproc) NOGITHUB=1 NOTEST=1 NOVATEK=1 NODOC=1 CXXFLAGS_WARNINGS="-Wall" \
    && make install NODOC=1

FROM alpine:3.18

LABEL name="media-tools"

RUN apk add --no-cache \
    ffmpeg \
    net-tools \
    curl \
    bash \
    openssl \
    libedit \
    zlib \
    pcre \
    libxml2 \
    python3

COPY --from=builder /usr/bin/ts* /usr/bin/
COPY --from=builder /usr/bin/srt-* /usr/bin/
COPY --from=builder /usr/lib/libtsduck.so* /usr/lib/
COPY --from=builder /usr/lib/libtscore.so* /usr/lib/
COPY --from=builder /usr/lib/libsrt.so* /usr/lib/
COPY --from=builder /usr/share/tsduck/ /usr/share/tsduck/
COPY scripts/ /app/scripts/

CMD ["/bin/bash"]
