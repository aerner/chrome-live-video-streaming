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

sudo /etc/init.d/dbus start > /dev/null 2>&1

pulseaudio -D

pacmd load-module module-virtual-sink sink_name=v1
pacmd set-default-sink v1
pacmd set-default-source v1.monitor

#--force-device-scale-factor=2
xvfb-run --server-num 99 --server-args="-ac -screen 0 1280x720x24" \
    google-chrome-stable --disable-gpu --no-sandbox --disable-setuid-sandbox --kiosk \
    --hide-scrollbars --disable-notifications \
    --disable-infobars --no-first-run \
    --lang="$LANGUAGE" \
    --start-fullscreen --window-size=1280,720 \
    $GRAB_URL > /dev/null 2>&1 &

#if not wait, audio/video not sync (why?)
echo "Waiting some time to confirm chrome is running"
sleep 10

# ffmpeg config variables
res_input="1280x720" # input resolution
res_output="1280x720" # output resolution
fps="60" # target FPS
gop="1200" # i-frame interval, should be double of fps
gop_min="60" # min i-frame interval, should be equal to fps
probesize="42M" # https://stackoverflow.com/a/57904380
threads="0" # max 6
cbr="${V_BITRATE:-2000k}" # constant bitrate (should be between 1000k–3000k)
quality="ultrafast" # one of the many FFmpeg presets
audio_bitrate="${A_BITRATE:-256k}"
loglevel="verbose" # supress unecessary information from printing

ffmpeg -loglevel "${loglevel}" -thread_queue_size 512 -draw_mouse 0 \
        -f x11grab -r ${fps} -s "${res_input}" -probesize ${probesize} -i :99 \
        -f alsa -ac 2 -i default -b:a ${audio_bitrate} \
        -vcodec libx264 -acodec aac -g ${gop} -keyint_min ${gop_min} -b:v ${cbr} -bufsize ${cbr} \
        -s ${res_output} -preset "${quality}" -tune film \
        -pix_fmt yuv420p \
        -threads ${threads} -strict normal \
        -f flv $RTMP_URL



