using System;
using System.Diagnostics;
using static DRLibs.DRMp3;
using static DRLibs.DRWav;
using static DRLibs.DRFlac;

namespace example;

class Program
{
	static void flac()
	{
		Debug.WriteLine($"dr_flac version: {StringView(drflac_version_string())}");

		// Failed to open FLAC file
		drflac* pFlac = drflac_open_file("resource/samplerate39k.flac", null);

		if (pFlac == null)
		{
			Debug.WriteLine("failed to open file");
		} else
		{
			drflac_int32* pSamples = (.)Internal.StdMalloc((.)pFlac.totalPCMFrameCount * pFlac.channels * sizeof(drflac_int32));
			drflac_uint64 numberOfInterleavedSamplesActuallyRead = drflac_read_pcm_frames_s32(pFlac, pFlac.totalPCMFrameCount, pSamples);

			Debug.WriteLine($"numberOfInterleavedSamplesActuallyRead: {numberOfInterleavedSamplesActuallyRead}");
		}
	}

	static void mp3()
	{
		Debug.WriteLine($"dr_mp3 version: {StringView(drmp3_version_string())}");

		drmp3 mp3 = .();

		if (drmp3_init_file(&mp3, "resource/TownTheme.mp3", null) == 0)
		{
				// Failed to open file
		} else
		{
			Debug.WriteLine($"{mp3.sampleRate} {mp3.channels}");
		}
	}

	static void wav()
	{
		uint channels;
		uint sampleRate;
		uint64 totalPCMFrameCount;
		float* pSampleData = drwav_open_file_and_read_pcm_frames_f32("resource/laser1.wav", &channels, &sampleRate, &totalPCMFrameCount, null);
		if (pSampleData == null)
		{
			Debug.WriteLine("error");
			// Error opening and reading WAV file.
		}

		drwav_free(pSampleData, null);

		uint32 major = 0;
		uint32 minor = 0;
		uint32 patch = 0;
		drwav_version(&major, &minor, &patch);

		Debug.WriteLine($"dr_wav version: {StringView(drwav_version_string())}");
	}

	public static int Main(String[] args)
	{
		flac();
		mp3();
		wav();

		return 0;
	}
}