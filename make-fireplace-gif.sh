#!/bin/bash
set -eu

if [ -z "$1" ]; then
  echo "usage: $0 /var/www/html/perf-tests/timestamp-dir/perf-recordings"
  exit 1
fi

now_epoch=$(date +%s)
current_pid=$$
root_directory='/var/tmp/perf-tests/gif-creation'
this_run_dir="${root_directory}/$now_epoch-$current_pid"
if [ ! -d "$this_run_dir" ]; then
  mkdir -p "$this_run_dir"
fi

gif_output="${this_run_dir}/output-${now_epoch}.gif"

height="${HEIGHT:=600}"
width="${WIDTH:=600}"
position="${POS:=+650+445}"
# https://i.ytimg.com/vi/rpnBVISuMbg/maxresdefault.jpg
fireplace_jpg="${BACKGROUND:=/var/www/html/d3/maxresdefault.jpg}"
focus_word=${FOCUS:='\[main'}

# get the flamgegraphs we want
for i in "$@"; do
  perf script --max-stack=50 -i $i | stackcollapse-perf.pl | grep "$focus_word" | flamegraph.pl --title ' ' --hash --minwidth=5 --width=1200 > "${this_run_dir}/$(basename $i)-focus.svg"
done

max_height=$(grep 'svg version' "${this_run_dir}"/*-focus.svg | grep -o 'height="[0-9]*"' | cut -d= -f2 | tr -d '"' | sort -n | tail -n1)
echo "the tallest SVG is $max_height and the gif output is $height"

echo "converting svg to miffs"
for i in ${this_run_dir}/*-focus.svg; do 
  convert "$i" -gravity SouthWest -resize "${width}x${max_height}"\! -flatten -transparent white -interlace None -background black -alpha remove +map -fuzz 10% +set comment "${this_run_dir}"/"$(basename "$i")".miff
done

convert -interlace None "$fireplace_jpg" +repage -interlace None \( "${this_run_dir}/*.miff" -alpha remove +set comment -background black -fuzz 10% +map -morph 3 -interlace None -background black -loop 0 -delay 20 -repage "$position" -write mpr:flame -delete 0--1 \) \( mpr:flame -resize ${width}x${height}\! -repage $position -write mpr:flame \) -interlace None -background black -delete 1--1 mpr:flame -coalesce -delete 0 -loop 0 -deconstruct -duplicate 1,-2-1 -layers Optimize "${this_run_dir}/final.gif"

echo "Gif is located at $gif_output"
