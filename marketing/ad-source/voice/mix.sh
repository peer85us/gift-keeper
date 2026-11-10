#!/bin/bash
# Voice lines placed on the ad timeline, music ducks under the voice
set -e
FF=/opt/homebrew/bin/ffmpeg
cd "$1"
$FF -loglevel error -y -i l1.wav -i l2.wav -i l3.wav -i l4.wav -i l5.wav -i l6.wav -i l7.wav -i l8.wav -i l9.wav -i "$2" -filter_complex "\
[0]adelay=150[a1];[1]adelay=2450[a2];[2]adelay=3700[a3];[3]adelay=5750[a4];[4]adelay=10800[a5];[5]adelay=14300[a6];[6]adelay=18500[a7];[7]adelay=21700[a8];[8]adelay=25800[a9];\
[a1][a2][a3][a4][a5][a6][a7][a8][a9]amix=inputs=9:normalize=0,aresample=44100,\
highpass=f=80,equalizer=f=3500:t=q:w=1.2:g=3,equalizer=f=200:t=q:w=1:g=1.5,acompressor=threshold=-20dB:ratio=3:attack=5:release=120:makeup=2,\
pan=stereo|c0=c0|c1=c0,apad=whole_dur=28.5,asplit=2[v][key];\
[9]aresample=44100,volume=0.55[m];[m][key]sidechaincompress=threshold=0.02:ratio=6:attack=30:release=450[duck];\
[v][duck]amix=inputs=2:normalize=0:duration=first,loudnorm=I=-14:TP=-1.5:LRA=11,atrim=0:28.5[out]" -map "[out]" -ar 44100 -c:a aac -b:a 192k audio.m4a
