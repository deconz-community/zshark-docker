#!/bin/sh

if [ "$ZSHARK_START_VERBOSE" = 1 ]; then
  set -x
fi

echo "[zsharkcommunity/zshark] Starting zshark..."
echo "[zsharkcommunity/zshark] Current zshark version: $ZSHARK_VERSION"
echo "[zsharkcommunity/zshark] Web UI port: $ZSHARK_WEB_PORT"
echo "[zsharkcommunity/zshark] Websockets port: $ZSHARK_WS_PORT"

ZSHARK_OPTS="--auto-connect=1"

echo "[zsharkcommunity/zshark] Using options" $ZSHARK_OPTS


echo "[zsharkcommunity/zshark] Modifying user and group ID"
if [ "$ZSHARK_UID" != 1000 ]; then
  ZSHARK_UID=${ZSHARK_UID:-1000}
  usermod -o -u "$ZSHARK_UID" zshark
fi
if [ "$ZSHARK_GID" != 1000 ]; then
  ZSHARK_GID=${ZSHARK_GID:-1000}
  groupmod -o -g "$ZSHARK_GID" zshark
fi

echo "[zsharkcommunity/zshark] Checking device group ID"
if [ "$ZSHARK_DEVICE" != 0 ]; then
  DEVICE=$ZSHARK_DEVICE
else
 if [ -e /dev/ttyUSB0 ]; then
   DEVICE=/dev/ttyUSB0
 fi
 if [ -e /dev/ttyACM0 ]; then
   DEVICE=/dev/ttyACM0
 fi
 if [ -e /dev/ttyAMA0 ]; then
   DEVICE=/dev/ttyAMA0
 fi
 if [ -e /dev/ttyS0 ]; then
   DEVICE=/dev/ttyS0
 fi
fi

DIALOUTGROUPID=$(stat --printf='%g' $DEVICE)
DIALOUTGROUPID=${DIALOUTGROUPID:-20}
if [ "$DIALOUTGROUPID" != 20 ]; then
  groupmod -o -g "$DIALOUTGROUPID" dialout
fi

#workaround if the group of the device doesn't have any permissions
GROUPPERMISSIONS=$(stat -c "%A" $DEVICE | cut -c 5-7)
if [ "$GROUPPERMISSIONS" = "---" ]; then
  chmod g+rw $DEVICE
fi

if [ "$ZSHARK_VNC_PORT" -lt 5900 ]; then
  echo "[zsharkcommunity/zshark] ERROR - VNC port must be 5900 or greater!"
  exit 1
fi

ZSHARK_VNC_DISPLAY=:$(($ZSHARK_VNC_PORT - 5900))
echo "[zsharkcommunity/zshark] VNC port: $ZSHARK_VNC_PORT"

if [ ! -e /opt/zshark/vnc ]; then
  mkdir -p /opt/zshark/vnc
fi

ln -sfT /opt/zshark/vnc /home/zshark/.vnc
chown zshark:zshark /home/zshark/.vnc
chown zshark:zshark /opt/zshark -R

# Set VNC password
if [ "$ZSHARK_VNC_PASSWORD_FILE" != 0 ] && [ -f "$ZSHARK_VNC_PASSWORD_FILE" ]; then
    ZSHARK_VNC_PASSWORD=$(cat $ZSHARK_VNC_PASSWORD_FILE)
fi

echo "$ZSHARK_VNC_PASSWORD" | tigervncpasswd -f > /opt/zshark/vnc/passwd
chmod 600 /opt/zshark/vnc/passwd
chown zshark:zshark /opt/zshark/vnc/passwd

# Cleanup previous VNC session data
gosu zshark tigervncserver -kill ':*'
gosu zshark tigervncserver -list ':*' -cleanstale
for lock in "/tmp/.X${ZSHARK_VNC_DISPLAY#:}-lock" "/tmp/.X11-unix/X${ZSHARK_VNC_DISPLAY#:}"; do
  [ -e "$lock" ] || continue
  echo "[zsharkcommunity/zshark] WARN - VNC-lock found. Deleting: $lock"
  rm "$lock"
done

# Set VNC security
gosu zshark tigervncserver -SecurityTypes VncAuth,TLSVnc "$ZSHARK_VNC_DISPLAY"

# Export VNC display variable
export DISPLAY=$ZSHARK_VNC_DISPLAY

if [ "$ZSHARK_NOVNC_PORT" = 0 ]; then
  echo "[zsharkcommunity/zshark] noVNC Disabled"
else
  if [ "$ZSHARK_NOVNC_PORT" -lt 6080 ]; then
    echo "[zsharkcommunity/zshark] ERROR - NOVNC port must be 6080 or greater!"
    exit 1
  fi

  # Assert valid SSL certificate
  NOVNC_CERT="/opt/zshark/vnc/novnc.pem"
  if [ -f "$NOVNC_CERT" ]; then
    openssl x509 -noout -in "$NOVNC_CERT" -checkend 0 > /dev/null
    if [ $? != 0 ]; then
      echo "[zsharkcommunity/zshark] The noVNC SSL certificate has expired; generating a new certificate now."
      rm "$NOVNC_CERT"
    fi
  fi
  if [ ! -f "$NOVNC_CERT" ]; then
    openssl req -x509 -nodes -newkey rsa:2048 -keyout "$NOVNC_CERT" -out "$NOVNC_CERT" -days 365 -subj "/CN=zshark"
  fi

  chown zshark:zshark $NOVNC_CERT

  #Start noVNC
  gosu zshark websockify -D --web=/usr/share/novnc/ --cert="$NOVNC_CERT" $ZSHARK_NOVNC_PORT localhost:$ZSHARK_VNC_PORT
  echo "[zsharkcommunity/zshark] NOVNC port: $ZSHARK_NOVNC_PORT"
fi

if [ "$ZSHARK_DEVICE" != 0 ]; then
  ZSHARK_OPTS="$ZSHARK_OPTS --com-port=$ZSHARK_DEVICE"
fi

exec gosu zshark /usr/bin/zshark $ZSHARK_OPTS
