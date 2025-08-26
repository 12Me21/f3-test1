set -e
cd ~/Code/mame2/twelve
make
cp test.bin ~/Code/mame2/roms/all/twelve-test1.bin
cd ~/Code/mame2
~/Code/mame2/taito_f3 -nokeepaspect -nofilter -nounevenstretch -window -nomaximize -intscalex 2 -intscaley 2 -skip_gameinfo twelvetest1 "$@"
