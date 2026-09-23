# aarch64 build environment for Wellenrennen.
# Ubuntu 22.04 keeps glibc (2.35) and libstdc++ (GCC 12) older than
# KNULLI's (glibc 2.40, libstdc++ 6.0.32), so nothing from the system
# needs to be bundled. Clang comes from apt.llvm.org (upstream requires Clang).
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg lsb-release software-properties-common \
      git cmake ninja-build python3 python3-venv python3-dev build-essential \
      file binutils-mips-linux-gnu \
      libstdc++-12-dev libgtk-3-dev libdbus-1-dev pkg-config \
      libx11-dev libxrandr-dev libwayland-dev libxkbcommon-dev \
      libvulkan-dev libegl1-mesa-dev libgles2-mesa-dev zlib1g-dev libpng-dev libzstd-dev libfreetype-dev \
      unzip zip rsync \
 && curl -fsSL https://apt.llvm.org/llvm.sh -o /tmp/llvm.sh \
 && bash /tmp/llvm.sh 18 \
 && ln -sf /usr/bin/clang-18 /usr/local/bin/clang \
 && ln -sf /usr/bin/clang++-18 /usr/local/bin/clang++ \
 && ln -sf /usr/bin/lld-18 /usr/local/bin/ld.lld \
 && rm -rf /var/lib/apt/lists/*

# RT64 needs SDL >= 2.26 (SDL_GetWindowSizeInPixels); 22.04 ships 2.0.20.
# Build the same release the port bundles at runtime (2.30.9, X11 + Vulkan).
RUN curl -fsSL https://github.com/libsdl-org/SDL/releases/download/release-2.30.9/SDL2-2.30.9.tar.gz \
      | tar xz -C /tmp \
 && cmake -S /tmp/SDL2-2.30.9 -B /tmp/sdl-build -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr/local -DSDL_STATIC=OFF -DSDL_TEST=OFF \
 && cmake --build /tmp/sdl-build && cmake --install /tmp/sdl-build \
 && ldconfig && rm -rf /tmp/SDL2-2.30.9 /tmp/sdl-build
