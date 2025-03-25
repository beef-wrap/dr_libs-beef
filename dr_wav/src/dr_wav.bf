/*
WAV audio loader and writer. Choice of public domain or MIT-0. See license statements at the end of this file.
dr_wav - v0.13.17 - 2024-12-17

David Reid - mackron@gmail.com

GitHub: https://github.com/mackron/dr_libs
*/

/*
Introduction
============
This is a single file library. To use it, do something like the following in one .c file.

	```c
	#define DR_WAV_IMPLEMENTATION
	#include "dr_wav.h"
	```

You can then #include this file in other parts of the program as you would with any other header file. Do something like the following to read audio data:

	```c
	drwav wav;
	if (!drwav_init_file(&wav, "my_song.wav", NULL)) {
		// Error opening WAV file.
	}

	drwav_int32* pDecodedInterleavedPCMFrames = malloc(wav.totalPCMFrameCount * wav.channels * sizeof(drwav_int32));
	size_t numberOfSamplesActuallyDecoded = drwav_read_pcm_frames_s32(&wav, wav.totalPCMFrameCount, pDecodedInterleavedPCMFrames);

	...

	drwav_uninit(&wav);
	```

If you just want to quickly open and read the audio data in a single operation you can do something like this:

	```c
	unsigned int channels;
	unsigned int sampleRate;
	drwav_uint64 totalPCMFrameCount;
	float* pSampleData = drwav_open_file_and_read_pcm_frames_f32("my_song.wav", &channels, &sampleRate, &totalPCMFrameCount, NULL);
	if (pSampleData == NULL) {
		// Error opening and reading WAV file.
	}

	...

	drwav_free(pSampleData, NULL);
	```

The examples above use versions of the API that convert the audio data to a consistent format (32-bit signed PCM, in this case), but you can still output the
audio data in its internal format (see notes below for supported formats):

	```c
	size_t framesRead = drwav_read_pcm_frames(&wav, wav.totalPCMFrameCount, pDecodedInterleavedPCMFrames);
	```

You can also read the raw bytes of audio data, which could be useful if dr_wav does not have native support for a particular data format:

	```c
	size_t bytesRead = drwav_read_raw(&wav, bytesToRead, pRawDataBuffer);
	```

dr_wav can also be used to output WAV files. This does not currently support compressed formats. To use this, look at `drwav_init_write()`,
`drwav_init_file_write()`, etc. Use `drwav_write_pcm_frames()` to write samples, or `drwav_write_raw()` to write raw data in the "data" chunk.

	```c
	drwav_data_format format;
	format.container = drwav_container_riff;     // <-- drwav_container_riff = normal WAV files, drwav_container_w64 = Sony Wave64.
	format.format = DR_WAVE_FORMAT_PCM;          // <-- Any of the DR_WAVE_FORMAT_* codes.
	format.channels = 2;
	format.sampleRate = 44100;
	format.bitsPerSample = 16;
	drwav_init_file_write(&wav, "data/recording.wav", &format, NULL);

	...

	drwav_uint64 framesWritten = drwav_write_pcm_frames(pWav, frameCount, pSamples);
	```

Note that writing to AIFF or RIFX is not supported.

dr_wav has support for decoding from a number of different encapsulation formats. See below for details.


Build Options
=============
#define these options before including this file.

#define DR_WAV_NO_CONVERSION_API
  Disables conversion APIs such as `drwav_read_pcm_frames_f32()` and `drwav_s16_to_f32()`.

#define DR_WAV_NO_STDIO
  Disables APIs that initialize a decoder from a file such as `drwav_init_file()`, `drwav_init_file_write()`, etc.

#define DR_WAV_NO_WCHAR
  Disables all functions ending with `_w`. Use this if your compiler does not provide wchar.h. Not required if DR_WAV_NO_STDIO is also defined.


Supported Encapsulations
========================
- RIFF (Regular WAV)
- RIFX (Big-Endian)
- AIFF (Does not currently support ADPCM)
- RF64
- W64

Note that AIFF and RIFX do not support write mode, nor do they support reading of metadata.


Supported Encodings
===================
- Unsigned 8-bit PCM
- Signed 12-bit PCM
- Signed 16-bit PCM
- Signed 24-bit PCM
- Signed 32-bit PCM
- IEEE 32-bit floating point
- IEEE 64-bit floating point
- A-law and u-law
- Microsoft ADPCM
- IMA ADPCM (DVI, format code 0x11)

8-bit PCM encodings are always assumed to be unsigned. Signed 8-bit encoding can only be read with `drwav_read_raw()`.

Note that ADPCM is not currently supported with AIFF. Contributions welcome.


Notes
=====
- Samples are always interleaved.
- The default read function does not do any data conversion. Use `drwav_read_pcm_frames_f32()`, `drwav_read_pcm_frames_s32()` and `drwav_read_pcm_frames_s16()`
  to read and convert audio data to 32-bit floating point, signed 32-bit integer and signed 16-bit integer samples respectively.
- dr_wav will try to read the WAV file as best it can, even if it's not strictly conformant to the WAV format.
*/

using System;
using System.Interop;

namespace drlibs;

public static class drwav
{
	typealias size_t = uint;
	typealias ssize_t = int;
	typealias wchar_t = c_wchar;

	/* Sized Types */
	typealias drwav_int8 = c_char;
	typealias drwav_uint8 = c_uchar;
	typealias drwav_int16 = c_short;
	typealias drwav_uint16 = c_ushort;
	typealias drwav_int32 = c_int;
	typealias drwav_uint32 = c_uint;
	typealias drwav_int64 = c_longlong;
	typealias drwav_uint64 = c_ulonglong;
	typealias drwav_uintptr = c_uintptr;
	typealias drwav_bool8 = drwav_uint8;
	typealias drwav_bool32 = drwav_uint32;
	/* End Sized Types */

	/* Result Codes */
	typealias drwav_result = drwav_int32;

	const int DRWAV_SUCCESS = 0;
	const int DRWAV_ERROR = -1; /* A generic error. */
	const int DRWAV_INVALID_ARGS = -2;
	const int DRWAV_INVALID_OPERATION = -3;
	const int DRWAV_OUT_OF_MEMORY = -4;
	const int DRWAV_OUT_OF_RANGE = -5;
	const int DRWAV_ACCESS_DENIED = -6;
	const int DRWAV_DOES_NOT_EXIST = -7;
	const int DRWAV_ALREADY_EXISTS = -8;
	const int DRWAV_TOO_MANY_OPEN_FILES = -9;
	const int DRWAV_INVALID_FILE = -10;
	const int DRWAV_TOO_BIG = -11;
	const int DRWAV_PATH_TOO_LONG = -12;
	const int DRWAV_NAME_TOO_LONG = -13;
	const int DRWAV_NOT_DIRECTORY = -14;
	const int DRWAV_IS_DIRECTORY = -15;
	const int DRWAV_DIRECTORY_NOT_EMPTY = -16;
	const int DRWAV_END_OF_FILE = -17;
	const int DRWAV_NO_SPACE = -18;
	const int DRWAV_BUSY = -19;
	const int DRWAV_IO_ERROR = -20;
	const int DRWAV_INTERRUPT = -21;
	const int DRWAV_UNAVAILABLE = -22;
	const int DRWAV_ALREADY_IN_USE = -23;
	const int DRWAV_BAD_ADDRESS = -24;
	const int DRWAV_BAD_SEEK = -25;
	const int DRWAV_BAD_PIPE = -26;
	const int DRWAV_DEADLOCK = -27;
	const int DRWAV_TOO_MANY_LINKS = -28;
	const int DRWAV_NOT_IMPLEMENTED = -29;
	const int DRWAV_NO_MESSAGE = -30;
	const int DRWAV_BAD_MESSAGE = -31;
	const int DRWAV_NO_DATA_AVAILABLE = -32;
	const int DRWAV_INVALID_DATA = -33;
	const int DRWAV_TIMEOUT = -34;
	const int DRWAV_NO_NETWORK = -35;
	const int DRWAV_NOT_UNIQUE = -36;
	const int DRWAV_NOT_SOCKET = -37;
	const int DRWAV_NO_ADDRESS = -38;
	const int DRWAV_BAD_PROTOCOL = -39;
	const int DRWAV_PROTOCOL_UNAVAILABLE = -40;
	const int DRWAV_PROTOCOL_NOT_SUPPORTED = -41;
	const int DRWAV_PROTOCOL_FAMILY_NOT_SUPPORTED = -42;
	const int DRWAV_ADDRESS_FAMILY_NOT_SUPPORTED = -43;
	const int DRWAV_SOCKET_NOT_SUPPORTED = -44;
	const int DRWAV_CONNECTION_RESET = -45;
	const int DRWAV_ALREADY_CONNECTED = -46;
	const int DRWAV_NOT_CONNECTED = -47;
	const int DRWAV_CONNECTION_REFUSED = -48;
	const int DRWAV_NO_HOST = -49;
	const int DRWAV_IN_PROGRESS = -50;
	const int DRWAV_CANCELLED = -51;
	const int DRWAV_MEMORY_ALREADY_MAPPED = -52;
	const int DRWAV_AT_END = -53;
	/* End Result Codes */

	/* Common data formats. */
	const int DR_WAVE_FORMAT_PCM = 0x1;
	const int DR_WAVE_FORMAT_ADPCM = 0x2;
	const int DR_WAVE_FORMAT_IEEE_FLOAT = 0x3;
	const int DR_WAVE_FORMAT_ALAW = 0x6;
	const int DR_WAVE_FORMAT_MULAW = 0x7;
	const int DR_WAVE_FORMAT_DVI_ADPCM = 0x11;
	const int DR_WAVE_FORMAT_EXTENSIBLE = 0xFFFE;

	/* Flags to pass into drwav_init_ex(), etc. */
	const int DRWAV_SEQUENTIAL = 0x00000001;
	const int DRWAV_WITH_METADATA = 0x00000002;

	[CLink] public static extern void drwav_version(drwav_uint32* pMajor, drwav_uint32* pMinor, drwav_uint32* pRevision);
	[CLink] public static extern char8* drwav_version_string();

	/* Allocation Callbacks */
	[CRepr]
	struct drwav_allocation_callbacks
	{
		void* pUserData;
		function void* onMalloc(size_t sz, void* pUserData);
		function void* onRealloc(void* p, size_t sz, void* pUserData);
		function void onFree(void* p, void* pUserData);
	}
	/* End Allocation Callbacks */

	public enum drwav_seek_origin : c_int
	{
		drwav_seek_origin_start,
		drwav_seek_origin_current
	}

	public enum drwav_container : c_int
	{
		drwav_container_riff,
		drwav_container_rifx,
		drwav_container_w64,
		drwav_container_rf64,
		drwav_container_aiff
	}

	[CRepr]
	struct drwav_chunk_header
	{
		[Union] struct
		{
			drwav_uint8[4] fourcc;
			drwav_uint8[16] guid;
		} id;

		/* The size in bytes of the chunk. */
		drwav_uint64 sizeInBytes;

		/*
		RIFF = 2 byte alignment.
		W64  = 8 byte alignment.
		*/
		uint paddingSize;
	}

	[CRepr]
	struct drwav_fmt
	{
		/*
		The format tag exactly as specified in the wave file's "fmt" chunk. This can be used by applications
		that require support for data formats not natively supported by dr_wav.
		*/
		drwav_uint16 formatTag;

		/* The number of channels making up the audio data. When this is set to 1 it is mono, 2 is stereo, etc. */
		drwav_uint16 channels;

		/* The sample rate. Usually set to something like 44100. */
		drwav_uint32 sampleRate;

		/* Average bytes per second. You probably don't need this, but it's left here for informational purposes. */
		drwav_uint32 avgBytesPerSec;

		/* Block align. This is equal to the number of channels * bytes per sample. */
		drwav_uint16 blockAlign;

		/* Bits per sample. */
		drwav_uint16 bitsPerSample;

		/* The size of the extended data. Only used internally for validation, but left here for informational purposes. */
		drwav_uint16 extendedSize;

		/*
		The number of valid bits per sample. When <formatTag> is equal to WAVE_FORMAT_EXTENSIBLE, <bitsPerSample>
		is always rounded up to the nearest multiple of 8. This variable contains information about exactly how
		many bits are valid per sample. Mainly used for informational purposes.
		*/
		drwav_uint16 validBitsPerSample;

		/* The channel mask. Not used at the moment. */
		drwav_uint32 channelMask;

		/* The sub-format, exactly as specified by the wave file. */
		drwav_uint8[16] subFormat;
	}

	[CRepr]
	public static extern drwav_uint16 drwav_fmt_get_format(drwav_fmt* pFMT);


	/*
	Callback for when data is read. Return value is the number of bytes actually read.

	pUserData   [in]  The user data that was passed to drwav_init() and family.
	pBufferOut  [out] The output buffer.
	bytesToRead [in]  The number of bytes to read.

	Returns the number of bytes actually read.

	A return value of less than bytesToRead indicates the end of the stream. Do _not_ return from this callback until
	either the entire bytesToRead is filled or you have reached the end of the stream.
	*/
	function size_t drwav_read_proc(void* pUserData, void* pBufferOut, size_t bytesToRead);

	/*
	Callback for when data is written. Returns value is the number of bytes actually written.

	pUserData    [in]  The user data that was passed to drwav_init_write() and family.
	pData        [out] A pointer to the data to write.
	bytesToWrite [in]  The number of bytes to write.

	Returns the number of bytes actually written.

	If the return value differs from bytesToWrite, it indicates an error.
	*/
	function size_t drwav_write_proc(void* pUserData, void* pData, size_t bytesToWrite);

	/*
	Callback for when data needs to be seeked.

	pUserData [in] The user data that was passed to drwav_init() and family.
	offset    [in] The number of bytes to move, relative to the origin. Will never be negative.
	origin    [in] The origin of the seek - the current position or the start of the stream.

	Returns whether or not the seek was successful.

	Whether or not it is relative to the beginning or current position is determined by the "origin" parameter which will be either drwav_seek_origin_start or
	drwav_seek_origin_current.
	*/
	function drwav_bool32 drwav_seek_proc(void* pUserData, int offset, drwav_seek_origin origin);

	/*
	Callback for when drwav_init_ex() finds a chunk.

	pChunkUserData    [in] The user data that was passed to the pChunkUserData parameter of drwav_init_ex() and family.
	onRead            [in] A pointer to the function to call when reading.
	onSeek            [in] A pointer to the function to call when seeking.
	pReadSeekUserData [in] The user data that was passed to the pReadSeekUserData parameter of drwav_init_ex() and family.
	pChunkHeader      [in] A pointer to an object containing basic header information about the chunk. Use this to identify the chunk.
	container         [in] Whether or not the WAV file is a RIFF or Wave64 container. If you're unsure of the difference, assume RIFF.
	pFMT              [in] A pointer to the object containing the contents of the "fmt" chunk.

	Returns the number of bytes read + seeked.

	To read data from the chunk, call onRead(), passing in pReadSeekUserData as the first parameter. Do the same for seeking with onSeek(). The return value must
	be the total number of bytes you have read _plus_ seeked.

	Use the `container` argument to discriminate the fields in `pChunkHeader->id`. If the container is `drwav_container_riff` or `drwav_container_rf64` you should
	use `id.fourcc`, otherwise you should use `id.guid`.

	The `pFMT` parameter can be used to determine the data format of the wave file. Use `drwav_fmt_get_format()` to get the sample format, which will be one of the
	`DR_WAVE_FORMAT_*` identifiers.

	The read pointer will be sitting on the first byte after the chunk's header. You must not attempt to read beyond the boundary of the chunk.
	*/
	function drwav_uint64 drwav_chunk_proc(void* pChunkUserData, drwav_read_proc onRead, drwav_seek_proc onSeek, void* pReadSeekUserData, drwav_chunk_header* pChunkHeader, drwav_container container, drwav_fmt* pFMT);


	/* Structure for internal use. Only used for loaders opened with drwav_init_memory(). */
	[CRepr]
	struct drwav__memory_stream
	{
		drwav_uint8* data;
		size_t dataSize;
		size_t currentReadPos;
	}

	/* Structure for internal use. Only used for writers opened with drwav_init_memory_write(). */
	[CRepr]
	struct drwav__memory_stream_write
	{
		void** ppData;
		size_t* pDataSize;
		size_t dataSize;
		size_t dataCapacity;
		size_t currentWritePos;
	}

	[CRepr]
	struct drwav_data_format
	{
		drwav_container container; /* RIFF, W64. */
		drwav_uint32 format; /* DR_WAVE_FORMAT_* */
		drwav_uint32 channels;
		drwav_uint32 sampleRate;
		drwav_uint32 bitsPerSample;
	}

	public enum drwav_metadata_type : c_int
	{
		drwav_metadata_type_none                        = 0,

		/*
		Unknown simply means a chunk that drwav does not handle specifically. You can still ask to
		receive these chunks as metadata objects. It is then up to you to interpret the chunk's data.
		You can also write unknown metadata to a wav file. Be careful writing unknown chunks if you
		have also edited the audio data. The unknown chunks could represent offsets/sizes that no
		longer correctly correspond to the audio data.
		*/
		drwav_metadata_type_unknown                     = 1 << 0,

		/* Only 1 of each of these metadata items are allowed in a wav file. */
		drwav_metadata_type_smpl                        = 1 << 1,
		drwav_metadata_type_inst                        = 1 << 2,
		drwav_metadata_type_cue                         = 1 << 3,
		drwav_metadata_type_acid                        = 1 << 4,
		drwav_metadata_type_bext                        = 1 << 5,

		/*
		Wav files often have a LIST chunk. This is a chunk that contains a set of subchunks. For this
		higher-level metadata API, we don't make a distinction between a regular chunk and a LIST
		subchunk. Instead, they are all just 'metadata' items.

		There can be multiple of these metadata items in a wav file.
		*/
		drwav_metadata_type_list_label                  = 1 << 6,
		drwav_metadata_type_list_note                   = 1 << 7,
		drwav_metadata_type_list_labelled_cue_region    = 1 << 8,

		drwav_metadata_type_list_info_software          = 1 << 9,
		drwav_metadata_type_list_info_copyright         = 1 << 10,
		drwav_metadata_type_list_info_title             = 1 << 11,
		drwav_metadata_type_list_info_artist            = 1 << 12,
		drwav_metadata_type_list_info_comment           = 1 << 13,
		drwav_metadata_type_list_info_date              = 1 << 14,
		drwav_metadata_type_list_info_genre             = 1 << 15,
		drwav_metadata_type_list_info_album             = 1 << 16,
		drwav_metadata_type_list_info_tracknumber       = 1 << 17,

		/* Other type constants for convenience. */
		drwav_metadata_type_list_all_info_strings       = drwav_metadata_type_list_info_software
			| drwav_metadata_type_list_info_copyright
			| drwav_metadata_type_list_info_title
			| drwav_metadata_type_list_info_artist
			| drwav_metadata_type_list_info_comment
			| drwav_metadata_type_list_info_date
			| drwav_metadata_type_list_info_genre
			| drwav_metadata_type_list_info_album
			| drwav_metadata_type_list_info_tracknumber,

		drwav_metadata_type_list_all_adtl               = drwav_metadata_type_list_label
			| drwav_metadata_type_list_note
			| drwav_metadata_type_list_labelled_cue_region,

		drwav_metadata_type_all                         = -2, /*0xFFFFFFFF & ~drwav_metadata_type_unknown,*/
		drwav_metadata_type_all_including_unknown       = -1 /*0xFFFFFFFF,*/
	}

	/*
	Sampler Metadata

	The sampler chunk contains information about how a sound should be played in the context of a whole
	audio production, and when used in a sampler. See https://en.wikipedia.org/wiki/Sample-based_synthesis.
	*/
	public enum drwav_smpl_loop_type : c_int
	{
		drwav_smpl_loop_type_forward  = 0,
		drwav_smpl_loop_type_pingpong = 1,
		drwav_smpl_loop_type_backward = 2
	}

	[CRepr]
	struct drwav_smpl_loop
	{
		/* The ID of the associated cue point, see drwav_cue and drwav_cue_point. As with all cue point IDs, this can correspond to a label chunk to give this loop a name, see drwav_list_label_or_note. */
		drwav_uint32 cuePointId;

		/* See drwav_smpl_loop_type. */
		drwav_uint32 type;

		/* The byte offset of the first sample to be played in the loop. */
		drwav_uint32 firstSampleByteOffset;

		/* The byte offset into the audio data of the last sample to be played in the loop. */
		drwav_uint32 lastSampleByteOffset;

		/* A value to represent that playback should occur at a point between samples. This value ranges from 0 to UINT32_MAX. Where a value of 0 means no fraction, and a value of (UINT32_MAX / 2) would mean half a sample. */
		drwav_uint32 sampleFraction;

		/* Number of times to play the loop. 0 means loop infinitely. */
		drwav_uint32 playCount;
	}

	[CRepr]
	struct drwav_smpl
	{
		/* IDs for a particular MIDI manufacturer. 0 if not used. */
		drwav_uint32 manufacturerId;
		drwav_uint32 productId;

		/* The period of 1 sample in nanoseconds. */
		drwav_uint32 samplePeriodNanoseconds;

		/* The MIDI root note of this file. 0 to 127. */
		drwav_uint32 midiUnityNote;

		/* The fraction of a semitone up from the given MIDI note. This is a value from 0 to UINT32_MAX, where 0 means no change and (UINT32_MAX / 2) is half a semitone (AKA 50 cents). */
		drwav_uint32 midiPitchFraction;

		/* Data relating to SMPTE standards which are used for syncing audio and video. 0 if not used. */
		drwav_uint32 smpteFormat;
		drwav_uint32 smpteOffset;

		/* drwav_smpl_loop loops. */
		drwav_uint32 sampleLoopCount;

		/* Optional sampler-specific data. */
		drwav_uint32 samplerSpecificDataSizeInBytes;

		drwav_smpl_loop* pLoops;
		drwav_uint8* pSamplerSpecificData;
	}

	/*
	Instrument Metadata

	The inst metadata contains data about how a sound should be played as part of an instrument. This
	commonly read by samplers. See https://en.wikipedia.org/wiki/Sample-based_synthesis.
	*/
	[CRepr]
	struct drwav_inst
	{
		drwav_int8 midiUnityNote; /* The root note of the audio as a MIDI note number. 0 to 127. */
		drwav_int8 fineTuneCents; /* -50 to +50 */
		drwav_int8 gainDecibels; /* -64 to +64 */
		drwav_int8 lowNote; /* 0 to 127 */
		drwav_int8 highNote; /* 0 to 127 */
		drwav_int8 lowVelocity; /* 1 to 127 */
		drwav_int8 highVelocity; /* 1 to 127 */
	}

	/*
	Cue Metadata

	Cue points are markers at specific points in the audio. They often come with an associated piece of
	drwav_list_label_or_note metadata which contains the text for the marker.
	*/
	[CRepr]
	struct drwav_cue_point
	{
		/* Unique identification value. */
		drwav_uint32 id;

		/* Set to 0. This is only relevant if there is a 'playlist' chunk - which is not supported by dr_wav. */
		drwav_uint32 playOrderPosition;

		/* Should always be "data". This represents the fourcc value of the chunk that this cue point corresponds to. dr_wav only supports a single data chunk so this should always be "data". */
		drwav_uint8[4] dataChunkId;

		/* Set to 0. This is only relevant if there is a wave list chunk. dr_wav, like lots of readers/writers, do not support this. */
		drwav_uint32 chunkStart;

		/* Set to 0 for uncompressed formats. Else the last byte in compressed wave data where decompression can begin to find the value of the corresponding sample value. */
		drwav_uint32 blockStart;

		/* For uncompressed formats this is the byte offset of the cue point into the audio data. For compressed formats this is relative to the block specified with blockStart. */
		drwav_uint32 sampleByteOffset;
	}

	[CRepr]
	struct drwav_cue
	{
		drwav_uint32 cuePointCount;
		drwav_cue_point* pCuePoints;
	}

	/*
	Acid Metadata

	This chunk contains some information about the time signature and the tempo of the audio.
	*/
	public enum drwav_acid_flag : c_int
	{
		drwav_acid_flag_one_shot      = 1, /* If this is not set, then it is a loop instead of a one-shot. */
		drwav_acid_flag_root_note_set = 2,
		drwav_acid_flag_stretch       = 4,
		drwav_acid_flag_disk_based    = 8,
		drwav_acid_flag_acidizer      = 16 /* Not sure what this means. */
	}

	[CRepr]
	struct drwav_acid
	{
		/* A bit-field, see drwav_acid_flag. */
		drwav_uint32 flags;

		/* Valid if flags contains drwav_acid_flag_root_note_set. It represents the MIDI root note the file - a value from 0 to 127. */
		drwav_uint16 midiUnityNote;

		/* Reserved values that should probably be ignored. reserved1 seems to often be 128 and reserved2 is 0. */
		drwav_uint16 reserved1;
		float reserved2;

		/* Number of beats. */
		drwav_uint32 numBeats;

		/* The time signature of the audio. */
		drwav_uint16 meterDenominator;
		drwav_uint16 meterNumerator;

		/* Beats per minute of the track. Setting a value of 0 suggests that there is no tempo. */
		float tempo;
	}

	/*
	Cue Label or Note metadata

	These are 2 different types of metadata, but they have the exact same format. Labels tend to be the
	more common and represent a short name for a cue point. Notes might be used to represent a longer
	comment.
	*/
	[CRepr]
	struct drwav_list_label_or_note
	{
		/* The ID of a cue point that this label or note corresponds to. */
		drwav_uint32 cuePointId;

		/* Size of the string not including any null terminator. */
		drwav_uint32 stringLength;

		/* The string. The *init_with_metadata functions null terminate this for convenience. */
		char8* pString;
	}

	/*
	BEXT metadata, also known as Broadcast Wave Format (BWF)

	This metadata adds some extra description to an audio file. You must check the version field to
	determine if the UMID or the loudness fields are valid.
	*/
	[CRepr]
	struct drwav_bext
	{
		/*
		These top 3 fields, and the umid field are actually defined in the standard as a statically
		sized buffers. In order to reduce the size of this struct (and therefore the union in the
		metadata struct), we instead store these as pointers.
		*/
		char8* pDescription; /* Can be NULL or a null-terminated string, must be <= 256 characters. */
		char8* pOriginatorName; /* Can be NULL or a null-terminated string, must be <= 32 characters. */
		char8* pOriginatorReference; /* Can be NULL or a null-terminated string, must be <= 32 characters. */
		char8[10] pOriginationDate; /* ASCII "yyyy:mm:dd". */
		char8[8] pOriginationTime; /* ASCII "hh:mm:ss". */
		drwav_uint64 timeReference; /* First sample count since midnight. */
		drwav_uint16 version; /* Version of the BWF, check this to see if the fields below are valid. */

		/*
		Unrestricted ASCII characters containing a collection of strings terminated by CR/LF. Each
		string shall contain a description of a coding process applied to the audio data.
		*/
		char8* pCodingHistory;
		drwav_uint32 codingHistorySize;

		/* Fields below this point are only valid if the version is 1 or above. */
		drwav_uint8* pUMID; /* Exactly 64 bytes of SMPTE UMID */

		/* Fields below this point are only valid if the version is 2 or above. */
		drwav_uint16 loudnessValue; /* Integrated Loudness Value of the file in LUFS (multiplied by 100). */
		drwav_uint16 loudnessRange; /* Loudness Range of the file in LU (multiplied by 100). */
		drwav_uint16 maxTruePeakLevel; /* Maximum True Peak Level of the file expressed as dBTP (multiplied by 100). */
		drwav_uint16 maxMomentaryLoudness; /* Highest value of the Momentary Loudness Level of the file in LUFS (multiplied by 100). */
		drwav_uint16 maxShortTermLoudness; /* Highest value of the Short-Term Loudness Level of the file in LUFS (multiplied by 100). */
	}

	/*
	Info Text Metadata

	There a many different types of information text that can be saved in this format. This is where
	things like the album name, the artists, the year it was produced, etc are saved. See
	drwav_metadata_type for the full list of types that dr_wav supports.
	*/
	[CRepr]
	struct drwav_list_info_text
	{
		/* Size of the string not including any null terminator. */
		drwav_uint32 stringLength;

		/* The string. The *init_with_metadata functions null terminate this for convenience. */
		char8* pString;
	}

	/*
	Labelled Cue Region Metadata

	The labelled cue region metadata is used to associate some region of audio with text. The region
	starts at a cue point, and extends for the given number of samples.
	*/
	[CRepr]
	struct drwav_list_labelled_cue_region
	{
		/* The ID of a cue point that this object corresponds to. */
		drwav_uint32 cuePointId;

		/* The number of samples from the cue point forwards that should be considered this region */
		drwav_uint32 sampleLength;

		/* Four characters used to say what the purpose of this region is. */
		drwav_uint8[4] purposeId;

		/* Unsure of the exact meanings of these. It appears to be acceptable to set them all to 0. */
		drwav_uint16 country;
		drwav_uint16 language;
		drwav_uint16 dialect;
		drwav_uint16 codePage;

		/* Size of the string not including any null terminator. */
		drwav_uint32 stringLength;

		/* The string. The *init_with_metadata functions null terminate this for convenience. */
		char8* pString;
	}

	/*
	Unknown Metadata

	This chunk just represents a type of chunk that dr_wav does not understand.

	Unknown metadata has a location attached to it. This is because wav files can have a LIST chunk
	that contains subchunks. These LIST chunks can be one of two types. An adtl list, or an INFO
	list. This is used to specify the location of a chunk that dr_wav currently doesn't support.
	*/
	public enum drwav_metadata_location : c_int
	{
		drwav_metadata_location_invalid,
		drwav_metadata_location_top_level,
		drwav_metadata_location_inside_info_list,
		drwav_metadata_location_inside_adtl_list
	}

	[CRepr]
	struct drwav_unknown_metadata
	{
		drwav_uint8[4] id;
		drwav_metadata_location chunkLocation;
		drwav_uint32 dataSizeInBytes;
		drwav_uint8* pData;
	}

	/*
	Metadata is saved as a union of all the supported types.
	*/
	[CRepr]
	struct drwav_metadata
	{
		/* Determines which item in the union is valid. */
		drwav_metadata_type type; [Union] struct
		{
			drwav_cue cue;
			drwav_smpl smpl;
			drwav_acid acid;
			drwav_inst inst;
			drwav_bext bext;
			drwav_list_label_or_note labelOrNote; /* List label or list note. */
			drwav_list_labelled_cue_region labelledCueRegion;
			drwav_list_info_text infoText; /* Any of the list info types. */
			drwav_unknown_metadata unknown;
		} data;
	}

	[CRepr]
	struct drwav
	{
		/* A pointer to the function to call when more data is needed. */
		drwav_read_proc onRead;

		/* A pointer to the function to call when data needs to be written. Only used when the drwav object is opened in write mode. */
		drwav_write_proc onWrite;

		/* A pointer to the function to call when the wav file needs to be seeked. */
		drwav_seek_proc onSeek;

		/* The user data to pass to callbacks. */
		void* pUserData;

		/* Allocation callbacks. */
		drwav_allocation_callbacks allocationCallbacks;

		/* Whether or not the WAV file is formatted as a standard RIFF file or W64. */
		drwav_container container;

		/* Structure containing format information exactly as specified by the wav file. */
		drwav_fmt fmt;

		/* The sample rate. Will be set to something like 44100. */
		drwav_uint32 sampleRate;

		/* The number of channels. This will be set to 1 for monaural streams, 2 for stereo, etc. */
		drwav_uint16 channels;

		/* The bits per sample. Will be set to something like 16, 24, etc. */
		drwav_uint16 bitsPerSample;

		/* Equal to fmt.formatTag, or the value specified by fmt.subFormat if fmt.formatTag is equal to 65534 (WAVE_FORMAT_EXTENSIBLE). */
		drwav_uint16 translatedFormatTag;

		/* The total number of PCM frames making up the audio data. */
		drwav_uint64 totalPCMFrameCount;
		/* The size in bytes of the data chunk. */
		drwav_uint64 dataChunkDataSize;

		/* The position in the stream of the first data byte of the data chunk. This is used for seeking. */
		drwav_uint64 dataChunkDataPos;

		/* The number of bytes remaining in the data chunk. */
		drwav_uint64 bytesRemaining;

		/* The current read position in PCM frames. */
		drwav_uint64 readCursorInPCMFrames;

		/*
		Only used in sequential write mode. Keeps track of the desired size of the "data" chunk at the point of initialization time. Always
		set to 0 for non-sequential writes and when the drwav object is opened in read mode. Used for validation.
		*/
		drwav_uint64 dataChunkDataSizeTargetWrite;

		/* Keeps track of whether or not the wav writer was initialized in sequential mode. */
		drwav_bool32 isSequentialWrite;

		/* A array of metadata. This is valid after the *init_with_metadata call returns. It will be valid until drwav_uninit() is called. You can take ownership of this data with drwav_take_ownership_of_metadata(). */
		drwav_metadata* pMetadata;
		drwav_uint32 metadataCount;

		/* A hack to avoid a DRWAV_MALLOC() when opening a decoder with drwav_init_memory(). */
		drwav__memory_stream memoryStream;
		drwav__memory_stream_write memoryStreamWrite;

		/* Microsoft ADPCM specific data. */
		struct
		{
			drwav_uint32 bytesRemainingInBlock;
			drwav_uint16[2] predictor;
			drwav_int32[2] delta;
			drwav_int32[4] cachedFrames; /* Samples are stored in this cache during decoding. */
			drwav_uint32 cachedFrameCount;
			drwav_int32[2][2] prevFrames; /* The previous 2 samples for each channel (2 channels at most). */
		} msadpcm;

		/* IMA ADPCM specific data. */
		struct
		{
			drwav_uint32 bytesRemainingInBlock;
			drwav_int32[2]  predictor;
			drwav_int32[2]  stepIndex;
			drwav_int32[16]  cachedFrames; /* Samples are stored in this cache during decoding. */
			drwav_uint32 cachedFrameCount;
		} ima;

		/* AIFF specific data. */
		struct
		{
			drwav_bool8 isLE; /* Will be set to true if the audio data is little-endian encoded. */
			drwav_bool8 isUnsigned; /* Only used for 8-bit samples. When set to true, will be treated as unsigned. */
		} aiff;
	}


	/*
	Initializes a pre-allocated drwav object for reading.

	pWav                         [out]          A pointer to the drwav object being initialized.
	onRead                       [in]           The function to call when data needs to be read from the client.
	onSeek                       [in]           The function to call when the read position of the client data needs to move.
	onChunk                      [in, optional] The function to call when a chunk is enumerated at initialized time.
	pUserData, pReadSeekUserData [in, optional] A pointer to application defined data that will be passed to onRead and onSeek.
	pChunkUserData               [in, optional] A pointer to application defined data that will be passed to onChunk.
	flags                        [in, optional] A set of flags for controlling how things are loaded.

	Returns true if successful; false otherwise.

	Close the loader with drwav_uninit().

	This is the lowest level function for initializing a WAV file. You can also use drwav_init_file() and drwav_init_memory()
	to open the stream from a file or from a block of memory respectively.

	Possible values for flags:
	  DRWAV_SEQUENTIAL: Never perform a backwards seek while loading. This disables the chunk callback and will cause this function
						to return as soon as the data chunk is found. Any chunks after the data chunk will be ignored.

	drwav_init() is equivalent to "drwav_init_ex(pWav, onRead, onSeek, NULL, pUserData, NULL, 0);".

	The onChunk callback is not called for the WAVE or FMT chunks. The contents of the FMT chunk can be read from pWav->fmt
	after the function returns.

	See also: drwav_init_file(), drwav_init_memory(), drwav_uninit()
	*/
	[CLink] public static extern drwav_bool32 drwav_init(drwav* pWav, drwav_read_proc onRead, drwav_seek_proc onSeek, void* pUserData, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_bool32 drwav_init_ex(drwav* pWav, drwav_read_proc onRead, drwav_seek_proc onSeek, drwav_chunk_proc onChunk, void* pReadSeekUserData, void* pChunkUserData, drwav_uint32 flags, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_bool32 drwav_init_with_metadata(drwav* pWav, drwav_read_proc onRead, drwav_seek_proc onSeek, void* pUserData, drwav_uint32 flags, drwav_allocation_callbacks* pAllocationCallbacks);

	/*
	Initializes a pre-allocated drwav object for writing.

	onWrite               [in]           The function to call when data needs to be written.
	onSeek                [in]           The function to call when the write position needs to move.
	pUserData             [in, optional] A pointer to application defined data that will be passed to onWrite and onSeek.
	metadata, numMetadata [in, optional] An array of metadata objects that should be written to the file. The array is not edited. You are responsible for this metadata memory and it must maintain valid until drwav_uninit() is called.

	Returns true if successful; false otherwise.

	Close the writer with drwav_uninit().

	This is the lowest level function for initializing a WAV file. You can also use drwav_init_file_write() and drwav_init_memory_write()
	to open the stream from a file or from a block of memory respectively.

	If the total sample count is known, you can use drwav_init_write_sequential(). This avoids the need for dr_wav to perform
	a post-processing step for storing the total sample count and the size of the data chunk which requires a backwards seek.

	See also: drwav_init_file_write(), drwav_init_memory_write(), drwav_uninit()
	*/
	[CLink] public static extern drwav_bool32 drwav_init_write(drwav* pWav, drwav_data_format* pFormat, drwav_write_proc onWrite, drwav_seek_proc onSeek, void* pUserData, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_bool32 drwav_init_write_sequential(drwav* pWav, drwav_data_format* pFormat, drwav_uint64 totalSampleCount, drwav_write_proc onWrite, void* pUserData, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_bool32 drwav_init_write_sequential_pcm_frames(drwav* pWav, drwav_data_format* pFormat, drwav_uint64 totalPCMFrameCount, drwav_write_proc onWrite, void* pUserData, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_bool32 drwav_init_write_with_metadata(drwav* pWav, drwav_data_format* pFormat, drwav_write_proc onWrite, drwav_seek_proc onSeek, void* pUserData, drwav_allocation_callbacks* pAllocationCallbacks, drwav_metadata* pMetadata, drwav_uint32 metadataCount);

	/*
	Utility function to determine the target size of the entire data to be written (including all headers and chunks).

	Returns the target size in bytes.

	The metadata argument can be NULL meaning no metadata exists.

	Useful if the application needs to know the size to allocate.

	Only writing to the RIFF chunk and one data chunk is currently supported.

	See also: drwav_init_write(), drwav_init_file_write(), drwav_init_memory_write()
	*/
	[CLink] public static extern drwav_uint64 drwav_target_write_size_bytes(drwav_data_format* pFormat, drwav_uint64 totalFrameCount, drwav_metadata* pMetadata, drwav_uint32 metadataCount);

	/*
	Take ownership of the metadata objects that were allocated via one of the init_with_metadata() function calls. The init_with_metdata functions perform a single heap allocation for this metadata.

	Useful if you want the data to persist beyond the lifetime of the drwav object.

	You must free the data returned from this function using drwav_free().
	*/
	[CLink] static extern drwav_metadata* drwav_take_ownership_of_metadata(drwav* pWav);

	/*
	Uninitializes the given drwav object.

	Use this only for objects initialized with drwav_init*() functions (drwav_init(), drwav_init_ex(), drwav_init_write(), drwav_init_write_sequential()).
	*/
	[CLink] public static extern drwav_result drwav_uninit(drwav* pWav);


	/*
	Reads raw audio data.

	This is the lowest level function for reading audio data. It simply reads the given number of
	bytes of the raw internal sample data.

	Consider using drwav_read_pcm_frames_s16(), drwav_read_pcm_frames_s32() or drwav_read_pcm_frames_f32() for
	reading sample data in a consistent format.

	pBufferOut can be NULL in which case a seek will be performed.

	Returns the number of bytes actually read.
	*/
	[CLink] public static extern size_t drwav_read_raw(drwav* pWav, size_t bytesToRead, void* pBufferOut);

	/*
	Reads up to the specified number of PCM frames from the WAV file.

	The output data will be in the file's internal format, converted to native-endian byte order. Use
	drwav_read_pcm_frames_s16/f32/s32() to read data in a specific format.

	If the return value is less than <framesToRead> it means the end of the file has been reached or
	you have requested more PCM frames than can possibly fit in the output buffer.

	This function will only work when sample data is of a fixed size and uncompressed. If you are
	using a compressed format consider using drwav_read_raw() or drwav_read_pcm_frames_s16/s32/f32().

	pBufferOut can be NULL in which case a seek will be performed.
	*/
	[CLink] public static extern drwav_uint64 drwav_read_pcm_frames(drwav* pWav, drwav_uint64 framesToRead, void* pBufferOut);
	[CLink] public static extern drwav_uint64 drwav_read_pcm_frames_le(drwav* pWav, drwav_uint64 framesToRead, void* pBufferOut);
	[CLink] public static extern drwav_uint64 drwav_read_pcm_frames_be(drwav* pWav, drwav_uint64 framesToRead, void* pBufferOut);

	/*
	Seeks to the given PCM frame.

	Returns true if successful; false otherwise.
	*/
	[CLink] public static extern drwav_bool32 drwav_seek_to_pcm_frame(drwav* pWav, drwav_uint64 targetFrameIndex);

	/*
	Retrieves the current read position in pcm frames.
	*/
	[CLink] public static extern drwav_result drwav_get_cursor_in_pcm_frames(drwav* pWav, drwav_uint64* pCursor);

	/*
	Retrieves the length of the file.
	*/
	[CLink] public static extern drwav_result drwav_get_length_in_pcm_frames(drwav* pWav, drwav_uint64* pLength);


	/*
	Writes raw audio data.

	Returns the number of bytes actually written. If this differs from bytesToWrite, it indicates an error.
	*/
	[CLink] public static extern size_t drwav_write_raw(drwav* pWav, size_t bytesToWrite, void* pData);

	/*
	Writes PCM frames.

	Returns the number of PCM frames written.

	Input samples need to be in native-endian byte order. On big-endian architectures the input data will be converted to
	little-endian. Use drwav_write_raw() to write raw audio data without performing any conversion.
	*/
	[CLink] public static extern drwav_uint64 drwav_write_pcm_frames(drwav* pWav, drwav_uint64 framesToWrite, void* pData);
	[CLink] public static extern drwav_uint64 drwav_write_pcm_frames_le(drwav* pWav, drwav_uint64 framesToWrite, void* pData);
	[CLink] public static extern drwav_uint64 drwav_write_pcm_frames_be(drwav* pWav, drwav_uint64 framesToWrite, void* pData);

	/* Conversion Utilities */

#if !DR_WAV_NO_CONVERSION_API
	/*
	Reads a chunk of audio data and converts it to signed 16-bit PCM samples.

	pBufferOut can be NULL in which case a seek will be performed.

	Returns the number of PCM frames actually read.

	If the return value is less than <framesToRead> it means the end of the file has been reached.
	*/
	[CLink] public static extern drwav_uint64 drwav_read_pcm_frames_s16(drwav* pWav, drwav_uint64 framesToRead, drwav_int16* pBufferOut);
	[CLink] public static extern drwav_uint64 drwav_read_pcm_frames_s16le(drwav* pWav, drwav_uint64 framesToRead, drwav_int16* pBufferOut);
	[CLink] public static extern drwav_uint64 drwav_read_pcm_frames_s16be(drwav* pWav, drwav_uint64 framesToRead, drwav_int16* pBufferOut);

	/* Low-level function for converting unsigned 8-bit PCM samples to signed 16-bit PCM samples. */
	[CLink] public static extern void drwav_u8_to_s16(drwav_int16* pOut, drwav_uint8* pIn, size_t sampleCount);

	/* Low-level function for converting signed 24-bit PCM samples to signed 16-bit PCM samples. */
	[CLink] public static extern void drwav_s24_to_s16(drwav_int16* pOut, drwav_uint8* pIn, size_t sampleCount);

	/* Low-level function for converting signed 32-bit PCM samples to signed 16-bit PCM samples. */
	[CLink] public static extern void drwav_s32_to_s16(drwav_int16* pOut, drwav_int32* pIn, size_t sampleCount);

	/* Low-level function for converting IEEE 32-bit floating point samples to signed 16-bit PCM samples. */
	[CLink] public static extern void drwav_f32_to_s16(drwav_int16* pOut, float* pIn, size_t sampleCount);

	/* Low-level function for converting IEEE 64-bit floating point samples to signed 16-bit PCM samples. */
	[CLink] public static extern void drwav_f64_to_s16(drwav_int16* pOut, double* pIn, size_t sampleCount);

	/* Low-level function for converting A-law samples to signed 16-bit PCM samples. */
	[CLink] public static extern void drwav_alaw_to_s16(drwav_int16* pOut, drwav_uint8* pIn, size_t sampleCount);

	/* Low-level function for converting u-law samples to signed 16-bit PCM samples. */
	[CLink] public static extern void drwav_mulaw_to_s16(drwav_int16* pOut, drwav_uint8* pIn, size_t sampleCount);


	/*
	Reads a chunk of audio data and converts it to IEEE 32-bit floating point samples.

	pBufferOut can be NULL in which case a seek will be performed.

	Returns the number of PCM frames actually read.

	If the return value is less than <framesToRead> it means the end of the file has been reached.
	*/
	[CLink] public static extern drwav_uint64 drwav_read_pcm_frames_f32(drwav* pWav, drwav_uint64 framesToRead, float* pBufferOut);
	[CLink] public static extern drwav_uint64 drwav_read_pcm_frames_f32le(drwav* pWav, drwav_uint64 framesToRead, float* pBufferOut);
	[CLink] public static extern drwav_uint64 drwav_read_pcm_frames_f32be(drwav* pWav, drwav_uint64 framesToRead, float* pBufferOut);

	/* Low-level function for converting unsigned 8-bit PCM samples to IEEE 32-bit floating point samples. */
	[CLink] public static extern void drwav_u8_to_f32(float* pOut, drwav_uint8* pIn, size_t sampleCount);

	/* Low-level function for converting signed 16-bit PCM samples to IEEE 32-bit floating point samples. */
	[CLink] public static extern void drwav_s16_to_f32(float* pOut, drwav_int16* pIn, size_t sampleCount);

	/* Low-level function for converting signed 24-bit PCM samples to IEEE 32-bit floating point samples. */
	[CLink] public static extern void drwav_s24_to_f32(float* pOut, drwav_uint8* pIn, size_t sampleCount);

	/* Low-level function for converting signed 32-bit PCM samples to IEEE 32-bit floating point samples. */
	[CLink] public static extern void drwav_s32_to_f32(float* pOut, drwav_int32* pIn, size_t sampleCount);

	/* Low-level function for converting IEEE 64-bit floating point samples to IEEE 32-bit floating point samples. */
	[CLink] public static extern void drwav_f64_to_f32(float* pOut, double* pIn, size_t sampleCount);

	/* Low-level function for converting A-law samples to IEEE 32-bit floating point samples. */
	[CLink] public static extern void drwav_alaw_to_f32(float* pOut, drwav_uint8* pIn, size_t sampleCount);

	/* Low-level function for converting u-law samples to IEEE 32-bit floating point samples. */
	[CLink] public static extern void drwav_mulaw_to_f32(float* pOut, drwav_uint8* pIn, size_t sampleCount);


	/*
	Reads a chunk of audio data and converts it to signed 32-bit PCM samples.

	pBufferOut can be NULL in which case a seek will be performed.

	Returns the number of PCM frames actually read.

	If the return value is less than <framesToRead> it means the end of the file has been reached.
	*/
	[CLink] public static extern drwav_uint64 drwav_read_pcm_frames_s32(drwav* pWav, drwav_uint64 framesToRead, drwav_int32* pBufferOut);
	[CLink] public static extern drwav_uint64 drwav_read_pcm_frames_s32le(drwav* pWav, drwav_uint64 framesToRead, drwav_int32* pBufferOut);
	[CLink] public static extern drwav_uint64 drwav_read_pcm_frames_s32be(drwav* pWav, drwav_uint64 framesToRead, drwav_int32* pBufferOut);

	/* Low-level function for converting unsigned 8-bit PCM samples to signed 32-bit PCM samples. */
	[CLink] public static extern void drwav_u8_to_s32(drwav_int32* pOut, drwav_uint8* pIn, size_t sampleCount);

	/* Low-level function for converting signed 16-bit PCM samples to signed 32-bit PCM samples. */
	[CLink] public static extern void drwav_s16_to_s32(drwav_int32* pOut, drwav_int16* pIn, size_t sampleCount);

	/* Low-level function for converting signed 24-bit PCM samples to signed 32-bit PCM samples. */
	[CLink] public static extern void drwav_s24_to_s32(drwav_int32* pOut, drwav_uint8* pIn, size_t sampleCount);

	/* Low-level function for converting IEEE 32-bit floating point samples to signed 32-bit PCM samples. */
	[CLink] public static extern void drwav_f32_to_s32(drwav_int32* pOut, float* pIn, size_t sampleCount);

	/* Low-level function for converting IEEE 64-bit floating point samples to signed 32-bit PCM samples. */
	[CLink] public static extern void drwav_f64_to_s32(drwav_int32* pOut, double* pIn, size_t sampleCount);

	/* Low-level function for converting A-law samples to signed 32-bit PCM samples. */
	[CLink] public static extern void drwav_alaw_to_s32(drwav_int32* pOut, drwav_uint8* pIn, size_t sampleCount);

	/* Low-level function for converting u-law samples to signed 32-bit PCM samples. */
	[CLink] public static extern void drwav_mulaw_to_s32(drwav_int32* pOut, drwav_uint8* pIn, size_t sampleCount);

#endif /* DR_WAV_NO_CONVERSION_API */ 


	/* High-Level Convenience Helpers */

#if !DR_WAV_NO_STDIO
	/*
	Helper for initializing a wave file for reading using stdio.

	This holds the internal FILE object until drwav_uninit() is called. Keep this in mind if you're caching drwav
	objects because the operating system may restrict the number of file handles an application can have open at
	any given time.
	*/
	[CLink] public static extern drwav_bool32 drwav_init_file(drwav* pWav, char8* filename, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_bool32 drwav_init_file_ex(drwav* pWav, char8* filename, drwav_chunk_proc onChunk, void* pChunkUserData, drwav_uint32 flags, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_bool32 drwav_init_file_w(drwav* pWav, wchar_t* filename, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_bool32 drwav_init_file_ex_w(drwav* pWav, wchar_t* filename, drwav_chunk_proc onChunk, void* pChunkUserData, drwav_uint32 flags, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_bool32 drwav_init_file_with_metadata(drwav* pWav, char8* filename, drwav_uint32 flags, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_bool32 drwav_init_file_with_metadata_w(drwav* pWav, wchar_t* filename, drwav_uint32 flags, drwav_allocation_callbacks* pAllocationCallbacks);


	/*
	Helper for initializing a wave file for writing using stdio.

	This holds the internal FILE object until drwav_uninit() is called. Keep this in mind if you're caching drwav
	objects because the operating system may restrict the number of file handles an application can have open at
	any given time.
	*/
	[CLink] public static extern drwav_bool32 drwav_init_file_write(drwav* pWav, char8* filename, drwav_data_format* pFormat, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_bool32 drwav_init_file_write_sequential(drwav* pWav, char8* filename, drwav_data_format* pFormat, drwav_uint64 totalSampleCount, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_bool32 drwav_init_file_write_sequential_pcm_frames(drwav* pWav, char8* filename, drwav_data_format* pFormat, drwav_uint64 totalPCMFrameCount, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_bool32 drwav_init_file_write_w(drwav* pWav, wchar_t* filename, drwav_data_format* pFormat, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_bool32 drwav_init_file_write_sequential_w(drwav* pWav, wchar_t* filename, drwav_data_format* pFormat, drwav_uint64 totalSampleCount, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_bool32 drwav_init_file_write_sequential_pcm_frames_w(drwav* pWav, wchar_t* filename, drwav_data_format* pFormat, drwav_uint64 totalPCMFrameCount, drwav_allocation_callbacks* pAllocationCallbacks);
 #endif  /* DR_WAV_NO_STDIO */

	/*
	Helper for initializing a loader from a pre-allocated memory buffer.

	This does not create a copy of the data. It is up to the application to ensure the buffer remains valid for
	the lifetime of the drwav object.

	The buffer should contain the contents of the entire wave file, not just the sample data.
	*/
	[CLink] public static extern drwav_bool32 drwav_init_memory(drwav* pWav, void* data, size_t dataSize, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_bool32 drwav_init_memory_ex(drwav* pWav, void* data, size_t dataSize, drwav_chunk_proc onChunk, void* pChunkUserData, drwav_uint32 flags, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_bool32 drwav_init_memory_with_metadata(drwav* pWav, void* data, size_t dataSize, drwav_uint32 flags, drwav_allocation_callbacks* pAllocationCallbacks);

	/*
	Helper for initializing a writer which outputs data to a memory buffer.

	dr_wav will manage the memory allocations, however it is up to the caller to free the data with drwav_free().

	The buffer will remain allocated even after drwav_uninit() is called. The buffer should not be considered valid
	until after drwav_uninit() has been called.
	*/
	[CLink] public static extern drwav_bool32 drwav_init_memory_write(drwav* pWav, void** ppData, size_t* pDataSize, drwav_data_format* pFormat, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_bool32 drwav_init_memory_write_sequential(drwav* pWav, void** ppData, size_t* pDataSize, drwav_data_format* pFormat, drwav_uint64 totalSampleCount, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_bool32 drwav_init_memory_write_sequential_pcm_frames(drwav* pWav, void** ppData, size_t* pDataSize, drwav_data_format* pFormat, drwav_uint64 totalPCMFrameCount, drwav_allocation_callbacks* pAllocationCallbacks);


#if !DR_WAV_NO_CONVERSION_API
	/*
	Opens and reads an entire wav file in a single operation.

	The return value is a heap-allocated buffer containing the audio data. Use drwav_free() to free the buffer.
	*/
	[CLink] public static extern drwav_int16* drwav_open_and_read_pcm_frames_s16(drwav_read_proc onRead, drwav_seek_proc onSeek, void* pUserData, uint* channelsOut, uint* sampleRateOut, drwav_uint64* totalFrameCountOut, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern float* drwav_open_and_read_pcm_frames_f32(drwav_read_proc onRead, drwav_seek_proc onSeek, void* pUserData, uint* channelsOut, uint* sampleRateOut, drwav_uint64* totalFrameCountOut, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_int32* drwav_open_and_read_pcm_frames_s32(drwav_read_proc onRead, drwav_seek_proc onSeek, void* pUserData, uint* channelsOut, uint* sampleRateOut, drwav_uint64* totalFrameCountOut, drwav_allocation_callbacks* pAllocationCallbacks);

#if !DR_WAV_NO_STDIO
	/*
	Opens and decodes an entire wav file in a single operation.

	The return value is a heap-allocated buffer containing the audio data. Use drwav_free() to free the buffer.
	*/
	[CLink] public static extern drwav_int16* drwav_open_file_and_read_pcm_frames_s16(char8* filename, uint* channelsOut, uint* sampleRateOut, drwav_uint64* totalFrameCountOut, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern float* drwav_open_file_and_read_pcm_frames_f32(char8* filename, uint* channelsOut, uint* sampleRateOut, drwav_uint64* totalFrameCountOut, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_int32* drwav_open_file_and_read_pcm_frames_s32(char8* filename, uint* channelsOut, uint* sampleRateOut, drwav_uint64* totalFrameCountOut, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_int16* drwav_open_file_and_read_pcm_frames_s16_w(wchar_t* filename, uint* channelsOut, uint* sampleRateOut, drwav_uint64* totalFrameCountOut, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern float* drwav_open_file_and_read_pcm_frames_f32_w(wchar_t* filename, uint* channelsOut, uint* sampleRateOut, drwav_uint64* totalFrameCountOut, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_int32* drwav_open_file_and_read_pcm_frames_s32_w(wchar_t* filename, uint* channelsOut, uint* sampleRateOut, drwav_uint64* totalFrameCountOut, drwav_allocation_callbacks* pAllocationCallbacks);
 #endif
	/*
	Opens and decodes an entire wav file from a block of memory in a single operation.

	The return value is a heap-allocated buffer containing the audio data. Use drwav_free() to free the buffer.
	*/
	[CLink] public static extern drwav_int16* drwav_open_memory_and_read_pcm_frames_s16(void* data, size_t dataSize, uint* channelsOut, uint* sampleRateOut, drwav_uint64* totalFrameCountOut, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern float* drwav_open_memory_and_read_pcm_frames_f32(void* data, size_t dataSize, uint* channelsOut, uint* sampleRateOut, drwav_uint64* totalFrameCountOut, drwav_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drwav_int32* drwav_open_memory_and_read_pcm_frames_s32(void* data, size_t dataSize, uint* channelsOut, uint* sampleRateOut, drwav_uint64* totalFrameCountOut, drwav_allocation_callbacks* pAllocationCallbacks);
 #endif

	/* Frees data that was allocated internally by dr_wav. */
	[CLink] public static extern void drwav_free(void* p, drwav_allocation_callbacks* pAllocationCallbacks);

	/* Converts bytes from a wav stream to a sized type of native endian. */
	[CLink] public static extern drwav_uint16 drwav_bytes_to_u16(drwav_uint8* data);
	[CLink] public static extern drwav_int16 drwav_bytes_to_s16(drwav_uint8* data);
	[CLink] public static extern drwav_uint32 drwav_bytes_to_u32(drwav_uint8* data);
	[CLink] public static extern drwav_int32 drwav_bytes_to_s32(drwav_uint8* data);
	[CLink] public static extern drwav_uint64 drwav_bytes_to_u64(drwav_uint8* data);
	[CLink] public static extern drwav_int64 drwav_bytes_to_s64(drwav_uint8* data);
	[CLink] public static extern float drwav_bytes_to_f32(drwav_uint8* data);

	/* Compares a GUID for the purpose of checking the type of a Wave64 chunk. */
	[CLink] public static extern drwav_bool32 drwav_guid_equal(drwav_uint8[16] a, drwav_uint8[16] b);

	/* Compares a four-character-code for the purpose of checking the type of a RIFF chunk. */
	[CLink] public static extern drwav_bool32 drwav_fourcc_equal(drwav_uint8* a, char8* b);
}