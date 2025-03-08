#!/bin/bash
source ./env.sh

# Configuration parameters
WIDTH=1920
HEIGHT=1080
BITRATE=4000000
FRAMERATE=30

PORT=5602   # UDP port for video streaming
RTSP_PORT=8554  # RTSP server port
RTSP_PATH="stream"  # RTSP access path

LOG_DIR="/tmp/libcamera"

CMD_CSI="/usr/bin/libcamera-vid"
CMD_RTSP="rtp2rtsp_server.py"
PID_FILE_CSI="$LOG_DIR/csi"
PID_FILE_RTSP="$LOG_DIR/rtsp"

script_dir=$(dirname "$(realpath "$0")")

[[ -d "${LOG_DIR}" ]] || mkdir -p "${LOG_DIR}"

# Display help
help() {
    echo "Usage: $0 {start|restart|stop|status|help}"
    echo
    echo "Commands:"
    echo "  start           Start a module"
    echo "  restart         Restart a module"
    echo "  stop            Stop a module"
    echo "  status          Check the status of a module"
    echo "  help            Display this help message"
    echo
}

# Show the status of the module
status() {
    echo "Looking at the status of processes..."
    
    echo ""
    #echo ${CMD_CSI}
    # Check if msposd is running and print PID
    if ps aux | grep "${CMD_CSI}" | grep -v grep; then
        CSI_PID=$(ps aux | grep "${CMD_CSI}" | grep -v grep | awk '{print $2}')
        echo "${CMD_CSI} is running with PID: $CSI_PID"
    else
        echo "${CMD_CSI} is not running."
    fi

    echo ""
    #echo ${CMD_RTSP}
    # Check if msposd is running and print PID
    if ps aux | grep "${CMD_RTSP}" | grep -v grep; then
        RTSP_PID=$(ps aux | grep "${CMD_RTSP}" | grep -v grep | awk '{print $2}')
        echo "${CMD_RTSP} is running with PID: $RTSP_PID"
    else
        echo "${CMD_RTSP} is not running."
    fi
}

# Start the module
start() {

    if [ -f "$PID_FILE_CSI" ]; then
        echo "Module already started."
        status
        exit 1
    fi

    # Start libcamera-vid and pipe the video stream to GStreamer
    ${CMD_CSI} \
          --verbose \
          --inline \
          --width $WIDTH \
          --height $HEIGHT \
          --bitrate $BITRATE \
          --framerate $FRAMERATE \
          --hflip \
          --vflip \
          --timeout 0 \
          -o - 2> /dev/null | \
        /usr/bin/gst-launch-1.0 \
          -v fdsrc ! h264parse ! rtph264pay config-interval=1 pt=35 ! \
          udpsink sync=false host=127.0.0.1 port=$PORT &
    echo $! > $PID_FILE_CSI

    # wait for rtp stabilize
    sleep 3

    python3 ${script_dir}/${CMD_RTSP} &
    echo $! > $PID_FILE_RTSP
}

# Stop the module
stop() {
    if [ -f "$PID_FILE_CSI" ]; then
        PID=$(cat "$PID_FILE_CSI")
        
        # check if pid exist
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID"
            echo "csi stopped."
        else
            echo "Process with PID $PID not found."
        fi
        
        rm -f "$PID_FILE_CSI"
    fi

    if [ -f "$PID_FILE_RTSP" ]; then
        PID=$(cat "$PID_FILE_RTSP")
        
        # check if pid exist
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID"
            echo "rtsp stopped."
        else
            echo "Process with PID $PID not found."
        fi
        
        rm -f "$PID_FILE_RTSP"
    fi
}

# Dispatcher to handle commands
case "$1" in
    start)
        start
        ;;
    restart)
        stop
        sleep 3
        start
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    help)
        help
        ;;
    *)
        echo "Usage: $0 {start|restart|stop|status|help}"
        exit 1
        ;;
esac

# Wait for all background processes to finish
wait

