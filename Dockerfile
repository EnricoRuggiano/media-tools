FROM alpine:3.18 AS builder

LABEL stage=builder

# Define versions for easyVmaf components
ARG FFMPEG_version=n8.0
ARG VMAF_version=3.0.0
ARG easyVmaf_hash=31c59a444445125265044789d0754db8f39f71be
ARG SRT_version=v1.5.5
ARG TSDUCK_version=v3.43-4549

RUN apk add --no-cache \
    bash \
    build-base \
    cmake \
    git \
    openssl-dev \
    linux-headers \
    python3 \
    python3-dev \
    py3-pip \
    libedit-dev \
    zlib-dev \
    curl \
    pcre-dev \
    libxml2-dev \
    meson \
    ninja \
    pkgconfig \
    nasm \
    yasm \
    wget \
    tar \
    autoconf \
    automake \
    dav1d-dev \
    xxd \
    x264-dev \
    x265-dev \
    && mkdir -p /tmp/vmaf /tmp/ffmpeg /app \
    # ========================================
    # Build SRT (Secure Reliable Transport)
    # Live video streaming protocol library
    # ========================================
    && git clone --branch ${SRT_version} --depth 1 https://github.com/Haivision/srt.git /tmp/srt \
    && cd /tmp/srt \
    && cmake . -DCMAKE_INSTALL_PREFIX=/usr \
    && make -j$(nproc) \
    && make install \
    # ========================================
    # Build TSDuck (MPEG Transport Stream Toolkit)
    # Digital TV transport stream analysis tools
    # ========================================
    && git clone --branch ${TSDUCK_version} --depth 1 https://github.com/tsduck/tsduck.git /tmp/tsduck \
    && cd /tmp/tsduck \
    && make -j$(nproc) NOGITHUB=1 NOTEST=1 NOVATEK=1 NODOC=1 CXXFLAGS_WARNINGS="-Wall" \
    && make install NODOC=1 \
    # ========================================
    # Build libvmaf (Netflix VMAF Library)
    # Video Multi-Method Assessment Fusion for quality measurement
    # ========================================
    && cd /tmp/vmaf \
    && if [ "$VMAF_version" = "master" ] ; \
       then wget https://github.com/Netflix/vmaf/archive/${VMAF_version}.tar.gz && \
       tar -xzf ${VMAF_version}.tar.gz ; \
       else wget https://github.com/Netflix/vmaf/archive/v${VMAF_version}.tar.gz && \
       tar -xzf v${VMAF_version}.tar.gz ; \
       fi \
    && cd vmaf-${VMAF_version}/libvmaf/ \
    && meson build --buildtype release -Dbuilt_in_models=true \
    && ninja -vC build \
    && ninja -vC build test \
    && ninja -vC build install \
    && mkdir -p /usr/local/share/model \
    && cp -R ../model/* /usr/local/share/model \
    # ========================================
    # Build FFmpeg with VMAF and AV1 support
    # Custom build to include VMAF quality assessment
    # ========================================
    && cd /tmp/ffmpeg \
    && export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/lib/" \
    && export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/usr/local/lib/pkgconfig/" \
    && wget https://github.com/FFmpeg/FFmpeg/archive/refs/tags/${FFMPEG_version}.tar.gz \
    && tar -xzf ${FFMPEG_version}.tar.gz \
    && cd FFmpeg-${FFMPEG_version} \
    && ./configure --enable-libvmaf --enable-libsrt --enable-version3 --enable-shared --enable-libdav1d --enable-gpl --enable-libx264 --enable-libx265 \
    && make -j$(nproc) \
    && make install \
    # ========================================
    # Download easyVmaf Python Application
    # User-friendly wrapper for VMAF quality assessment
    # ========================================
    && cd /app \
    && wget https://github.com/gdavila/easyVmaf/archive/${easyVmaf_hash}.tar.gz \
    && tar -xzf ${easyVmaf_hash}.tar.gz \
    && cd easyVmaf-${easyVmaf_hash} \
    && rm -rf video_samples readme \
    && find . ! -name "*.py" -type f -delete \
    # ========================================
    # Cleanup temporary build directories
    # ========================================
    && rm -rf /tmp/vmaf || true \
    && rm -rf /tmp/ffmpeg || true \
    && rm -rf /tmp/srt || true \
    && rm -rf /tmp/tsduck

FROM alpine:3.18

LABEL name="media-tools"

# Set up library paths for VMAF and FFmpeg
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/lib/"

RUN apk add --no-cache \
    net-tools \
    curl \
    bash \
    openssl \
    libedit \
    zlib \
    pcre \
    libxml2 \
    python3 \
    py3-pip \
    dav1d \
    jq \
    x264-libs \
    x265-libs \
    && pip3 install ffmpeg-progress-yield

# Copy compiled libraries and binaries from builder stage
# VMAF models and FFmpeg with VMAF support
COPY --from=builder /usr/local /usr/local/
# TSDuck transport stream tools
COPY --from=builder /usr/bin/ts* /usr/bin/
# SRT streaming protocol tools
COPY --from=builder /usr/bin/srt-* /usr/bin/
# TSDuck shared libraries
COPY --from=builder /usr/lib/libtsduck.so* /usr/lib/
COPY --from=builder /usr/lib/tsduck/ /usr/lib/tsduck/
COPY --from=builder /usr/lib/libtscore.so* /usr/lib/
# SRT shared libraries
COPY --from=builder /usr/lib/libsrt.so* /usr/lib/
# TSDuck data files
COPY --from=builder /usr/share/tsduck/ /usr/share/tsduck/
# easyVmaf Python application
COPY --from=builder /app/easyVmaf-* /app/easyVmaf/
# Local scripts
COPY scripts/ /app/scripts/

# Install easyVmaf wrapper script for global access
RUN cp /app/scripts/easyvmaf.sh /usr/bin/easyvmaf \
    && chmod +x /usr/bin/easyvmaf

CMD ["/bin/bash"]
