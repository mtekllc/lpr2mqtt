FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive

# Install base packages + dependencies for openalpr and runtime tools
RUN apt-get update && apt-get install -y \
    git \
    cmake \
    make \
    g++ \
    libopencv-dev \
    liblog4cplus-dev \
    libcurl4-openssl-dev \
    iwatch \
    imagemagick \
    mosquitto-clients \
    jq \
    bash \
    coreutils \
    libtesseract-dev tesseract-ocr tesseract-ocr-eng \
    tcpdump net-tools strace libmosquitto-dev \
    && rm -rf /var/lib/apt/lists/*

# Build OpenALPR from source

WORKDIR /opt
RUN git clone https://github.com/openalpr/openalpr.git && \
    cd openalpr/src && \
    mkdir build && \
    cd build && \
    cmake \
    -DCMAKE_INSTALL_PREFIX:PATH=/usr \
    -DCMAKE_INSTALL_SYSCONFDIR:PATH=/etc \
    -DTesseract_INCLUDE_CCMAIN_DIR=/usr/include/tesseract \
    -DTesseract_INCLUDE_CCUTIL_DIR=/usr/include/tesseract \
    .. && \
    make && \
    make install && \
    ldconfig

# Working directory for app

WORKDIR /app
COPY mqtt-ppd /app/mqtt-ppd
COPY mqtt-ppd-install.sh /app/mqtt-ppd-install.sh
RUN chmod 755 mqtt-ppd-install.sh && ./mqtt-ppd-install.sh 1

# Copy your script into container
COPY alpr_monitor.sh /app/alpr_monitor.sh

# Make it executable
RUN chmod +x /app/alpr_monitor.sh

# Set environment variables
ENV WATCH_DIR=/input
ENV TROUBLE_DIR=/input/trouble
ENV PIPE=/tmp/mqtt_pipe
ENV MQTT_HOST=localhost
ENV MQTT_TOPIC=your/topic

# Create folders
RUN mkdir -p /input /input/trouble

# Set the entrypoint
ENTRYPOINT ["/app/alpr_monitor.sh"]
