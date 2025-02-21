copy dr_libs\dr_flac.h dr_flac.c
clang -c -o dr_flac-windows.lib -target x86_64-pc-windows -fuse-ld=llvm-lib -g -gcodeview -Wall -DDR_FLAC_IMPLEMENTATION dr_flac.c
mkdir dr_flac\libs
move dr_flac-windows.lib dr_flac\libs
del dr_flac.c

copy dr_libs\dr_mp3.h dr_mp3.c
clang -c -o dr_mp3-windows.lib -target x86_64-pc-windows -fuse-ld=llvm-lib -DDR_MP3_IMPLEMENTATION dr_mp3.c
mkdir dr_mp3\libs
move dr_mp3-windows.lib dr_mp3\libs
del dr_mp3.c

copy dr_libs\dr_wav.h dr_wav.c
clang -c -o dr_wav-windows.lib -target x86_64-pc-windows -fuse-ld=llvm-lib -DDR_WAV_IMPLEMENTATION dr_wav.c
mkdir dr_wav\libs
move dr_wav-windows.lib dr_wav\libs
del dr_wav.c