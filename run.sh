set -e
cd ~/Code/mame2/twelve
make
cp test2.main.bin ~/Code/mame2/roms/all/twelve-test1.bin
cp audiocpu3.audio.bin ~/Code/mame2/roms/all/twelve-audiocpu1

cd ~/Code/mame2
~/Code/mame2/taito_f3 -nokeepaspect -nofilter -nounevenstretch -window -nomaximize -intscalex 2 -intscaley 2 -skip_gameinfo twelvetest1 "$@" |& while read x
do
	echo "$x" | grep -Po 'tx send: \K..' | tr ' ' '0' | xxd -r -p 
done
