import { type Build } from 'xbuild';

const build: Build = {
    common: {
        project: 'dr_libs',
        archs: ['x64'],
        variables: [],
        copy: {
            'dr_libs/dr_flac.h': 'dr_libs/dr_flac.c',
            'dr_libs/dr_mp3.h': 'dr_libs/dr_mp3.c',
            'dr_libs/dr_wav.h': 'dr_libs/dr_wav.c'
        },
        defines: [
            'DR_FLAC_IMPLEMENTATION',
            'DR_MP3_IMPLEMENTATION',
            'DR_WAV_IMPLEMENTATION'
        ],
        options: [],
        subdirectories: [],
        libraries: {
            dr_flac: {
                sources: ['dr_libs/dr_flac.c'],
                outDir: 'dr_flac/libs'
            },
            dr_mp3: {
                sources: ['dr_libs/dr_mp3.c'],
                outDir: 'dr_mp3/libs'
            },
            dr_wav: {
                sources: ['dr_libs/dr_wav.c'],
                outDir: 'dr_wav/libs'
            }
        },
        buildDir: 'build',
        buildOutDir: 'libs',
        buildFlags: []
    },
    platforms: {
        win32: {
            windows: {},
            android: {
                archs: ['x86', 'x86_64', 'armeabi-v7a', 'arm64-v8a'],
            }
        },
        linux: {
            linux: {}
        },
        darwin: {
            macos: {}
        }
    }
}

export default build;