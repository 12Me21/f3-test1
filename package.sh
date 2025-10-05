set -e
mkdir -p burn
~/Code/landmaker-mods/util/deinterleave.rb -i ./main.main.bin -o burn/main1 burn/main2 burn/main3 burn/main4
~/Code/landmaker-mods/util/deinterleave.rb -i ./audiocpu3.audio.bin -o burn/audio1 burn/audio2
cd burn
zip ../burn$1.zip *
