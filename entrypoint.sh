#!/usr/bin/env bash

if [[ -z "$GRAB_URL" ]]; then
    echo "Must provide GRAB_URL in environment" 1>&2
    exit 1
fi

if [[ -z "$RTMP_URL" ]]; then
    echo "Must provide RTMP_URL in environment" 1>&2
    exit 1
fi




LANGUAGE="${LANGUAGE:-en}"
RESOLUTION="${RESOLUTION:-1920x1080}"
FPS="${FPS:-24}"
LOG_LEVEL="${LOG_LEVEL:-error}"
V_BITRATE="${V_BITRATE:-3000k}"
A_BITRATE="${A_BITRATE:-256k}"




sudo /etc/init.d/dbus start > /dev/null 2>&1

pulseaudio -D

pacmd load-module module-virtual-sink sink_name=v1
pacmd set-default-sink v1
pacmd set-default-source v1.monitor

# --force-device-scale-factor=2
xvfb-run --server-num 99 --server-args="-ac -screen 0, ${RESOLUTION}x24" \
    google-chrome-stable --no-sandbox --disable-setuid-sandbox --kiosk \
    --hide-scrollbars --disable-notifications \
    --disable-infobars --no-first-run \
    --lang="$LANGUAGE" \
    --start-fullscreen --window-size=${RESOLUTION//x/,} \
    $GRAB_URL > /dev/null 2>&1 &

echo "Waiting some time to confirm chrome is running"
sleep 10


fps=$FPS # target FPS
gop=$((FPS*2)) # i-frame interval, should be double of fps
gop_min=$FPS # min i-frame interval, should be equal to fps

probesize="42M" # https://stackoverflow.com/a/57904380
threads="0" # max 6

cbr=${V_BITRATE} # constant bitrate (should be between 1000k–3000k)
audio_bitrate=${A_BITRATE}
quality="ultrafast" # one of the many FFmpeg presets

# # -tune film

ffmpeg -loglevel ${LOG_LEVEL} -thread_queue_size 512 -draw_mouse 0 \
        -f x11grab -r ${fps} -s ${RESOLUTION} -probesize ${probesize} -i :99 \
        -f alsa -ac 2 -i default -b:a ${audio_bitrate} \
        -vcodec libx264rgb -acodec aac -g ${gop} -keyint_min ${gop_min} -b:v ${cbr} -bufsize ${cbr} \
        -s ${RESOLUTION} -preset ${quality} \
        -pix_fmt yuv420p \
        -threads ${threads} -strict normal \
        -x264-params keyint=30:scenecut=0 \
        -f flv $RTMP_URL
