#!/bin/bash
export GEOMETRY="$SCREEN_WIDTH""x""$SCREEN_HEIGHT""x""$SCREEN_DEPTH"

REMOTE_HOST_ADDR=""
REMOTE_HOST_PORT=""
REMOTE_HOST_PARAM=""

function shutdown {
  kill -s SIGTERM $NODE_PID
  wait $NODE_PID
}

if [ ! -e /opt/selenium/config.json ]; then
  echo No Selenium Node configuration file, the node-base image is not intended to be run directly. 1>&2
  exit 1
fi

if [ ! -z "$HOST_ADDR" ] && [ ! -z "$HOST_PORT" ]; then
  REMOTE_HOST_ADDR=$HOST_ADDR
  REMOTE_HOST_PORT=$HOST_PORT
elif [ ! -z "$HUB_PORT_4444_TCP_ADDR" ]; then
  REMOTE_HOST_ADDR=$HUB_PORT_4444_TCP_ADDR
  REMOTE_HOST_PORT=$HUB_PORT_4444_TCP_PORT
else
  echo Not linked with a running Hub container 1>&2
  exit 1
fi

if [ ! -z "$REMOTE_HOST" ]; then
  echo "REMOTE_HOST variable is set, appending -remoteHost"
  REMOTE_HOST_PARAM="-remoteHost $REMOTE_HOST"
fi

# TODO: Look into http://www.seleniumhq.org/docs/05_selenium_rc.jsp#browser-side-logs
sudo -E -i -u seluser \
  DISPLAY=$DISPLAY \
  xvfb-run --server-args="$DISPLAY -screen 0 $GEOMETRY -ac +extension RANDR" \
  java -jar /opt/selenium/selenium-server-standalone.jar \
    ${JAVA_OPTS} \
    -role node \
    -hub http://$REMOTE_HOST_ADDR:$REMOTE_HOST_PORT/grid/register \
    ${REMOTE_HOST_PARAM} \
    -nodeConfig /opt/selenium/config.json &
NODE_PID=$!

trap shutdown SIGTERM SIGINT
for i in $(seq 1 10)
do
  xdpyinfo -display $DISPLAY >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    break
  fi
  echo Waiting xvfb...
  sleep 0.5
done

fluxbox -display $DISPLAY &
x11vnc -forever -usepw -shared -rfbport 5900 -display $DISPLAY &

wait $NODE_PID
