FROM debian:11.5-slim

# Build arguments
ARG VERSION
ARG CHANNEL
ARG TARGETPLATFORM
ARG BUILDPLATFORM

# Runtime environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    ZSHARK_VERSION=${VERSION} \
    ZSHARK_DEVICE=0 \
    ZSHARK_VNC_DISPLAY=0 \
    ZSHARK_VNC_PASSWORD=changeme \
    ZSHARK_VNC_PASSWORD_FILE=0 \
    ZSHARK_VNC_PORT=5900 \
    ZSHARK_NOVNC_PORT=6080 \
    ZSHARK_UID=1000 \
    ZSHARK_GID=1000 \
    ZSHARK_START_VERBOSE=0

# Install zshark dependencies
RUN apt-get update && \
    apt-get install -y \
	gosu \
        curl \
        kmod \
	libatomic1 \
        libcap2-bin \
        libqt5core5a \
        libqt5gui5 \
        libqt5network5 \
        libqt5serialport5 \
        libqt5sql5 \
        libqt5websockets5 \
        libqt5widgets5 \
	libqt5qml5 \
        libssl1.1 \
        lsof \
        sqlite3 \
        tigervnc-standalone-server \
        tigervnc-common \
        novnc \
        websockify \
        openbox \
        xfonts-base \
        xfonts-scalable && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Workaround required on amd64 to address issue #292
RUN if [ "${TARGETPLATFORM}" = "linux/amd64" ] ; then \
    apt-get update && \
    apt-get install -y \
        binutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    strip --remove-section=.note.ABI-tag /usr/lib/x86_64-linux-gnu/libQt5Core.so.5 ; fi

# Add start.sh and Conbee udev data; set execute permissions
COPY root /
RUN chmod +x /start.sh && \
    chmod +x /firmware-update.sh

# Make user
RUN groupadd -g ${ZSHARK_GID} "zshark" && \
    useradd -u ${ZSHARK_UID} -g "zshark" -G dialout -ms /bin/bash "zshark"

# Add zshark, install zshark, make OTAU dir
COPY download-zshark.sh /

RUN chmod +x /download-zshark.sh && /download-zshark.sh ${VERSION} ${TARGETPLATFORM}

RUN dpkg -i /zshark.deb && \
    chown root:root /usr/bin/zshark* && \
    setcap CAP_NET_BIND_SERVICE=+eip /usr/bin/zshark && \
    rm -f /zshark.deb

VOLUME [ "/opt/zshark" ]

EXPOSE ${ZSHARK_VNC_PORT} ${ZSHARK_NOVNC_PORT}

ENTRYPOINT [ "/start.sh" ]
