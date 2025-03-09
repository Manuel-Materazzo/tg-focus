# Stage 1: Build the application
FROM ubuntu:20.04 AS builder

# Install dependencies
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:ubuntu-toolchain-r/test && \
    apt-get update && \
    apt-get install -y \
    bash \
    git \
    gcc-11 \
    g++-11 \
    cmake \
    tzdata \
    php-cli \
    wget \
    zlib1g-dev \
    gperf \
    libssl-dev \
    dos2unix && \
    rm -rf /var/lib/apt/lists/*

# Set GCC 11 as the default compiler
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 100 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 100

# Clone and build TDLib
RUN mkdir -p /app/tg-focus/3rd/tdlib
RUN git clone https://github.com/tdlib/td.git /app/tg-focus/3rd/tdlib && \
    cd /app/tg-focus/3rd/tdlib && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr/local .. && \
    cmake --build . --target install


# Install toml11
RUN git clone https://github.com/ToruNiina/toml11.git /app/tg-focus/3rd/toml11 && \
    cd /app/tg-focus/3rd/toml11 && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    cmake --build . --target install

# Set the working directory
WORKDIR /app/tg-focus

# Copy the application files
COPY . .

# Convert line endings of dev/sync-versions.bash to Unix format and ensure correct permissions
RUN dos2unix dev/sync-versions.bash && \
    chmod +x dev/sync-versions.bash


# Build the application
RUN Td_DIR=/usr/local cmake -B build && \
    bash -x dev/sync-versions.bash && \
    cmake --build build -j$(nproc) && \
    TZ=UTC ctest --test-dir build

# Stage 2: Create the runtime image
FROM ubuntu:20.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    bash \
    tzdata \
    libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# Copy the built application from the builder stage
COPY --from=builder /app/tg-focus/build /app/build

# Set the working directory
WORKDIR /app

# Define the entrypoint
ENTRYPOINT ["/app/build/tg-focus"]

# Example command to run the application
CMD ["--help"]