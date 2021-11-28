#!/bin/bash

pushd ./assets/sounds

for f in *.wav; do
	filename="${f%.*}"
	ffmpeg -y -i $f -acodec libvorbis ${filename}.ogg
done

popd
