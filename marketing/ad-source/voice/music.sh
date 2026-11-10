#!/bin/bash
# Background music bed: C - Am - F - G looping, made from plain tones (no copyright)
set -e
FF=/opt/homebrew/bin/ffmpeg
cd "$1"; LEN=$2
chords=("261.63 329.63 392.00" "220.00 261.63 329.63" "174.61 220.00 261.63" "196.00 246.94 293.66")
n=$(python3 -c "import math;print(math.ceil($LEN/2.7))")
: > pads.txt
for ((i=0;i<n;i++)); do
  set -- ${chords[$((i%4))]}
  $FF -loglevel error -y -f lavfi -i "aevalsrc=0.18*sin(2*PI*$1*t)+0.15*sin(2*PI*$2*t)+0.15*sin(2*PI*$3*t)+0.12*sin(PI*$1*t)+0.04*sin(4*PI*$2*t):s=44100:d=2.7" -af "afade=t=in:d=0.5,afade=t=out:st=2.0:d=0.7,lowpass=f=1800" pad$i.wav
  echo "file 'pad$i.wav'" >> pads.txt
done
$FF -loglevel error -y -f concat -i pads.txt -af "aecho=0.8:0.6:120:0.3,atrim=0:$LEN,afade=t=out:st=$(python3 -c "print($LEN-1.3)"):d=1.3,pan=stereo|c0=c0|c1=c0,loudnorm=I=-20:TP=-2" -ar 44100 -c:a aac -b:a 160k music.m4a
