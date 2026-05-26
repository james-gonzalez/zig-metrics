# Stage 1: build
# Uses the host platform's Zig to cross-compile for the target platform.
# Produces a fully static binary (musl) so the final image can be scratch.
FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS builder

ARG BUILDPLATFORM
ARG TARGETPLATFORM
ARG ZIG_VERSION=0.16.0

RUN apt-get update && apt-get install -y wget xz-utils && rm -rf /var/lib/apt/lists/*

# Download Zig for the build platform
RUN set -ex; \
    case "${BUILDPLATFORM}" in \
        linux/amd64) ZIG_ARCH="x86_64" ;; \
        linux/arm64) ZIG_ARCH="aarch64" ;; \
        *) echo "Unsupported BUILDPLATFORM: ${BUILDPLATFORM}" && exit 1 ;; \
    esac; \
    wget -q "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-${ZIG_ARCH}-${ZIG_VERSION}.tar.xz" \
         -O /tmp/zig.tar.xz; \
    tar -xf /tmp/zig.tar.xz -C /usr/local; \
    mv /usr/local/zig-linux-${ZIG_ARCH}-${ZIG_VERSION} /usr/local/zig; \
    rm /tmp/zig.tar.xz

ENV PATH="/usr/local/zig:$PATH"

# Map Docker TARGETPLATFORM to a Zig target triple (static musl)
RUN case "${TARGETPLATFORM}" in \
        linux/amd64) echo "x86_64-linux-musl"   > /tmp/zig_target ;; \
        linux/arm64) echo "aarch64-linux-musl"  > /tmp/zig_target ;; \
        *) echo "Unsupported TARGETPLATFORM: ${TARGETPLATFORM}" && exit 1 ;; \
    esac

WORKDIR /app
COPY build.zig build.zig.zon ./
COPY src/ src/

RUN zig build -Doptimize=ReleaseSafe -Dtarget="$(cat /tmp/zig_target)"

# Stage 2: minimal runtime (static binary — no libc needed)
FROM scratch
COPY --from=builder /app/zig-out/bin/zig-metrics /zig-metrics
EXPOSE 9090
ENTRYPOINT ["/zig-metrics"]
