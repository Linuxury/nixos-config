#!/usr/bin/env bash
# Rename all images in subfolders based on their folder name
# Place this script inside the "Wallpapers" folder

set -e  # exit on error

# Loop over each subfolder in current directory
for dir in */; do
    [ -d "$dir" ] || continue  # skip if not a directory
    folder_name=$(basename "$dir")
    count=1

    # Loop over image files
    shopt -s nullglob
    for file in "$dir"*.[jJ][pP][gG] "$dir"*.[jJ][pP][eE][gG] "$dir"*.[pP][nN][gG]; do
        [ -f "$file" ] || continue
        ext="${file##*.}"
        new_name="${dir}${folder_name} - $(printf "%02d" $count).${ext,,}"  # lowercase extension
        mv -i "$file" "$new_name"
        count=$((count + 1))
    done
done
