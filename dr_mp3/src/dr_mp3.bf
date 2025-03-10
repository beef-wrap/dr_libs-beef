/*
MP3 audio decoder. Choice of public domain or MIT-0. See license statements at the end of this file.
dr_mp3 - v0.6.40 - 2024-12-17

David Reid - mackron@gmail.com

GitHub: https://github.com/mackron/dr_libs

Based on minimp3 (https://github.com/lieff/minimp3) which is where the real work was done. See the bottom of this file for differences between minimp3 and dr_mp3.
*/

/*
RELEASE NOTES - VERSION 0.6
===========================
Version 0.6 includes breaking changes with the configuration of decoders. The ability to customize the number of output channels and the sample rate has been
removed. You must now use the channel count and sample rate reported by the MP3 stream itself, and all channel and sample rate conversion must be done
yourself.


Changes to Initialization
-------------------------
Previously, `drmp3_init()`, etc. took a pointer to a `drmp3_config` object that allowed you to customize the output channels and sample rate. This has been
removed. If you need the old behaviour you will need to convert the data yourself or just not upgrade. The following APIs have changed.

	`drmp3_init()`
	`drmp3_init_memory()`
	`drmp3_init_file()`


Miscellaneous Changes
---------------------
Support for loading a file from a `wchar_t` string has been added via the `drmp3_init_file_w()` API.
*/

/*
Introduction
=============
dr_mp3 is a single file library. To use it, do something like the following in one .c file.

	```c
	#define DR_MP3_IMPLEMENTATION
	#include "dr_mp3.h"
	```

You can then #include this file in other parts of the program as you would with any other header file. To decode audio data, do something like the following:

	```c
	drmp3 mp3;
	if (!drmp3_init_file(&mp3, "MySong.mp3", NULL)) {
		// Failed to open file
	}

	...

	drmp3_uint64 framesRead = drmp3_read_pcm_frames_f32(pMP3, framesToRead, pFrames);
	```

The drmp3 object is transparent so you can get access to the channel count and sample rate like so:

	```
	drmp3_uint32 channels = mp3.channels;
	drmp3_uint32 sampleRate = mp3.sampleRate;
	```

The example above initializes a decoder from a file, but you can also initialize it from a block of memory and read and seek callbacks with
`drmp3_init_memory()` and `drmp3_init()` respectively.

You do not need to do any annoying memory management when reading PCM frames - this is all managed internally. You can request any number of PCM frames in each
call to `drmp3_read_pcm_frames_f32()` and it will return as many PCM frames as it can, up to the requested amount.

You can also decode an entire file in one go with `drmp3_open_and_read_pcm_frames_f32()`, `drmp3_open_memory_and_read_pcm_frames_f32()` and
`drmp3_open_file_and_read_pcm_frames_f32()`.


Build Options
=============
#define these options before including this file.

#define DR_MP3_NO_STDIO
  Disable drmp3_init_file(), etc.

#define DR_MP3_NO_SIMD
  Disable SIMD optimizations.
*/

using System;
using System.Interop;

namespace drlibs;

public static class drmp3
{
	public typealias size_t = uint;
	public typealias ssize_t = int;
	public typealias wchar_t = c_wchar;

	/* Sized Types */
	public typealias drmp3_int8 = c_char;
	public typealias drmp3_uint8 = c_uchar;
	public typealias drmp3_int16 = c_short;
	public typealias drmp3_uint16 = c_ushort;
	public typealias drmp3_int32 = c_int;
	public typealias drmp3_uint32 = c_uint;
	public typealias drmp3_int64 = c_longlong;
	public typealias drmp3_uint64 = c_ulonglong;
	public typealias drmp3_uintptr = c_uintptr;
	public typealias drmp3_bool8 = drmp3_uint8;
	public typealias drmp3_bool32 = drmp3_uint32;
	// /* End Sized Types */

	/* Result Codes */
	public typealias drmp3_result = drmp3_int32;

	const c_int DRMP3_SUCCESS =                        0;
	const c_int DRMP3_ERROR =                         -1; /* A generic error. */
	const c_int DRMP3_INVALID_ARGS =                  -2;
	const c_int DRMP3_INVALID_OPERATION =             -3;
	const c_int DRMP3_OUT_OF_MEMORY =                 -4;
	const c_int DRMP3_OUT_OF_RANGE =                  -5;
	const c_int DRMP3_ACCESS_DENIED =                 -6;
	const c_int DRMP3_DOES_NOT_EXIST =                -7;
	const c_int DRMP3_ALREADY_EXISTS =                -8;
	const c_int DRMP3_TOO_MANY_OPEN_FILES =           -9;
	const c_int DRMP3_INVALID_FILE =                  -10;
	const c_int DRMP3_TOO_BIG =                       -11;
	const c_int DRMP3_PATH_TOO_LONG =                 -12;
	const c_int DRMP3_NAME_TOO_LONG =                 -13;
	const c_int DRMP3_NOT_DIRECTORY =                 -14;
	const c_int DRMP3_IS_DIRECTORY =                  -15;
	const c_int DRMP3_DIRECTORY_NOT_EMPTY =           -16;
	const c_int DRMP3_END_OF_FILE =                   -17;
	const c_int DRMP3_NO_SPACE =                      -18;
	const c_int DRMP3_BUSY =                          -19;
	const c_int DRMP3_IO_ERROR =                      -20;
	const c_int DRMP3_INTERRUPT =                     -21;
	const c_int DRMP3_UNAVAILABLE =                   -22;
	const c_int DRMP3_ALREADY_IN_USE =                -23;
	const c_int DRMP3_BAD_ADDRESS =                   -24;
	const c_int DRMP3_BAD_SEEK =                      -25;
	const c_int DRMP3_BAD_PIPE =                      -26;
	const c_int DRMP3_DEADLOCK =                      -27;
	const c_int DRMP3_TOO_MANY_LINKS =                -28;
	const c_int DRMP3_NOT_IMPLEMENTED =               -29;
	const c_int DRMP3_NO_MESSAGE =                    -30;
	const c_int DRMP3_BAD_MESSAGE =                   -31;
	const c_int DRMP3_NO_DATA_AVAILABLE =             -32;
	const c_int DRMP3_INVALID_DATA =                  -33;
	const c_int DRMP3_TIMEOUT =                       -34;
	const c_int DRMP3_NO_NETWORK =                    -35;
	const c_int DRMP3_NOT_UNIQUE =                    -36;
	const c_int DRMP3_NOT_SOCKET =                    -37;
	const c_int DRMP3_NO_ADDRESS =                    -38;
	const c_int DRMP3_BAD_PROTOCOL =                  -39;
	const c_int DRMP3_PROTOCOL_UNAVAILABLE =          -40;
	const c_int DRMP3_PROTOCOL_NOT_SUPPORTED =        -41;
	const c_int DRMP3_PROTOCOL_FAMILY_NOT_SUPPORTED = -42;
	const c_int DRMP3_ADDRESS_FAMILY_NOT_SUPPORTED =  -43;
	const c_int DRMP3_SOCKET_NOT_SUPPORTED =          -44;
	const c_int DRMP3_CONNECTION_RESET =              -45;
	const c_int DRMP3_ALREADY_CONNECTED =             -46;
	const c_int DRMP3_NOT_CONNECTED =                 -47;
	const c_int DRMP3_CONNECTION_REFUSED =            -48;
	const c_int DRMP3_NO_HOST =                       -49;
	const c_int DRMP3_IN_PROGRESS =                   -50;
	const c_int DRMP3_CANCELLED =                     -51;
	const c_int DRMP3_MEMORY_ALREADY_MAPPED =         -52;
	const c_int DRMP3_AT_END =                        -53;
	/* End Result Codes */

	const c_int DRMP3_MAX_PCM_FRAMES_PER_MP3_FRAME =  1152;
	const c_int DRMP3_MAX_SAMPLES_PER_FRAME = DRMP3_MAX_PCM_FRAMES_PER_MP3_FRAME * 2;

	[CLink] public static extern void drmp3_version(drmp3_uint32* pMajor, drmp3_uint32* pMinor, drmp3_uint32* pRevision);
	[CLink] public static extern char8* drmp3_version_string();

	/* Allocation Callbacks */
	[CRepr]
	public struct drmp3_allocation_callbacks
	{
		void* pUserData;
		function void* onMalloc(size_t sz, void* pUserData);
		function void* onRealloc(void* p, size_t sz, void* pUserData);
		function void  onFree(void* p, void* pUserData);
	};
	/* End Allocation Callbacks */

	/*
	Low Level Push API
	==================
	*/
	[CRepr]
	public struct drmp3dec_frame_info
	{
		c_int frame_bytes;
		c_int channels;
		c_int hz;
		c_int layer;
		c_int bitrate_kbp;
	};

	[CRepr]
	public struct drmp3dec
	{
		float[2][9 * 32] mdct_overlap;
		float[15 * 2 * 32] qmf_state;
		c_int reserv;
		c_int free_format_bytes;
		drmp3_uint8[4] header;
		drmp3_uint8[511] reserv_buf;
	};

	// /* Initializes a low level decoder. */
	[CLink] public static extern void drmp3dec_init(drmp3dec* dec);

	// /* Reads a frame from a low level decoder. */
	[CLink] public static extern c_int drmp3dec_decode_frame(drmp3dec* dec, drmp3_uint8* mp3, c_int mp3_bytes, void* pcm, drmp3dec_frame_info* info);

	// /* Helper for converting between f32 and s16. */
	[CLink] public static extern void drmp3dec_f32_to_s16(float* in_val, drmp3_int16* out_val, size_t num_samples);

	/*
	Main API (Pull API)
	===================
	*/
	[CRepr]
	public enum drmp3_seek_origin
	{
		drmp3_seek_origin_start,
		drmp3_seek_origin_current
	};

	[CRepr]
	public struct drmp3_seek_point
	{
		drmp3_uint64 seekPosInBytes; /* Points to the first byte of an MP3 frame. */
		drmp3_uint64 pcmFrameIndex; /* The index of the PCM frame this seek point targets. */
		drmp3_uint16 mp3FramesToDiscard; /* The number of whole MP3 frames to be discarded before pcmFramesToDiscard. */
		drmp3_uint16 pcmFramesToDiscard; /* The number of leading samples to read and discard. These are discarded after mp3FramesToDiscard. */
	};

	/*
	Callback for when data is read. Return value is the number of bytes actually read.

	pUserData   [in]  The user data that was passed to drmp3_init(), drmp3_open() and family.
	pBufferOut  [out] The output buffer.
	bytesToRead [in]  The number of bytes to read.

	Returns the number of bytes actually read.

	A return value of less than bytesToRead indicates the end of the stream. Do _not_ return from this callback until
	either the entire bytesToRead is filled or you have reached the end of the stream.
	*/
	public function size_t drmp3_read_proc(void* pUserData, void* pBufferOut, size_t bytesToRead);

	/*
	Callback for when data needs to be seeked.

	pUserData [in] The user data that was passed to drmp3_init(), drmp3_open() and family.
	offset    [in] The number of bytes to move, relative to the origin. Will never be negative.
	origin    [in] The origin of the seek - the current position or the start of the stream.

	Returns whether or not the seek was successful.

	Whether or not it is relative to the beginning or current position is determined by the "origin" parameter which
	will be either drmp3_seek_origin_start or drmp3_seek_origin_current.
	*/
	public function drmp3_bool32 drmp3_seek_proc(void* pUserData, c_int offset, drmp3_seek_origin origin);

	[CRepr]
	public struct drmp3_config
	{
		drmp3_uint32 channels;
		drmp3_uint32 sampleRate;
	};

	[CRepr]
	public struct drmp3
	{
		public drmp3dec decoder;
		public drmp3_uint32 channels;
		public drmp3_uint32 sampleRate;
		public drmp3_read_proc onRead;
		public drmp3_seek_proc onSeek;
		public void* pUserData;
		public drmp3_allocation_callbacks allocationCallbacks;
		public drmp3_uint32 mp3FrameChannels; /* The number of channels in the currently loaded MP3 frame. Internal use only. */
		public drmp3_uint32 mp3FrameSampleRate; /* The sample rate of the currently loaded MP3 frame. Internal use only. */
		public drmp3_uint32 pcmFramesConsumedInMP3Frame;
		public drmp3_uint32 pcmFramesRemainingInMP3Frame;
		public drmp3_uint8[sizeof(float) * DRMP3_MAX_SAMPLES_PER_FRAME] pcmFrames; /* <-- Multipled by sizeof(float) to ensure there's enough room for DR_MP3_FLOAT_OUTPUT. */
		public drmp3_uint64 currentPCMFrame; /* The current PCM frame, globally, based on the output sample rate. Mainly used for seeking. */
		public drmp3_uint64 streamCursor; /* The current byte the decoder is sitting on in the raw stream. */
		public drmp3_seek_point* pSeekPoints; /* NULL by default. Set with drmp3_bind_seek_table(). Memory is owned by the client. dr_mp3 will never attempt to free this pointer. */
		public drmp3_uint32 seekPointCount; /* The number of items in pSeekPoints. When set to 0 assumes to no seek table. Defaults to zero. */
		public size_t dataSize;
		public size_t dataCapacity;
		public size_t dataConsumed;
		public drmp3_uint8* pData;
		public drmp3_bool32 atEnd = 1;

		public struct memory
		{
			drmp3_uint8* pData;
			size_t dataSize;
			size_t currentReadPos;
		}; /* Only used for decoders that were opened against a block of memory. */
	};

	/*
	Initializes an MP3 decoder.

	onRead    [in]           The function to call when data needs to be read from the client.
	onSeek    [in]           The function to call when the read position of the client data needs to move.
	pUserData [in, optional] A pointer to application defined data that will be passed to onRead and onSeek.

	Returns true if successful; false otherwise.

	Close the loader with drmp3_uninit().

	See also: drmp3_init_file(), drmp3_init_memory(), drmp3_uninit()
	*/
	[CLink] public static extern drmp3_bool32 drmp3_init(drmp3* pMP3, drmp3_read_proc onRead, drmp3_seek_proc onSeek, void* pUserData, drmp3_allocation_callbacks* pAllocationCallbacks);

	/*
	Initializes an MP3 decoder from a block of memory.

	This does not create a copy of the data. It is up to the application to ensure the buffer remains valid for
	the lifetime of the drmp3 object.

	The buffer should contain the contents of the entire MP3 file.
	*/
	[CLink] public static extern drmp3_bool32 drmp3_init_memory(drmp3* pMP3, void* pData, size_t dataSize, drmp3_allocation_callbacks* pAllocationCallbacks);

#if !DR_MP3_NO_STDIO
	/*
	Initializes an MP3 decoder from a file.

	This holds the internal FILE object until drmp3_uninit() is called. Keep this in mind if you're caching drmp3
	objects because the operating system may restrict the number of file handles an application can have open at
	any given time.
	*/
	[CLink] public static extern drmp3_bool32 drmp3_init_file(drmp3* pMP3, char8* pFilePath, drmp3_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drmp3_bool32 drmp3_init_file_w(drmp3* pMP3, wchar_t* pFilePath, drmp3_allocation_callbacks* pAllocationCallbacks);
#endif

	/*
	Uninitializes an MP3 decoder.
	*/
	[CLink] public static extern void drmp3_uninit(drmp3* pMP3);

	/*
	Reads PCM frames as interleaved 32-bit IEEE floating point PCM.

	Note that framesToRead specifies the number of PCM frames to read, _not_ the number of MP3 frames.
	*/
	[CLink] public static extern drmp3_uint64 drmp3_read_pcm_frames_f32(drmp3* pMP3, drmp3_uint64 framesToRead, float* pBufferOut);

	/*
	Reads PCM frames as interleaved signed 16-bit integer PCM.

	Note that framesToRead specifies the number of PCM frames to read, _not_ the number of MP3 frames.
	*/
	[CLink] public static extern drmp3_uint64 drmp3_read_pcm_frames_s16(drmp3* pMP3, drmp3_uint64 framesToRead, drmp3_int16* pBufferOut);

	/*
	Seeks to a specific frame.

	Note that this is _not_ an MP3 frame, but rather a PCM frame.
	*/
	[CLink] public static extern drmp3_bool32 drmp3_seek_to_pcm_frame(drmp3* pMP3, drmp3_uint64 frameIndex);

	/*
	Calculates the total number of PCM frames in the MP3 stream. Cannot be used for infinite streams such as internet
	radio. Runs in linear time. Returns 0 on error.
	*/
	[CLink] public static extern drmp3_uint64 drmp3_get_pcm_frame_count(drmp3* pMP3);

	/*
	Calculates the total number of MP3 frames in the MP3 stream. Cannot be used for infinite streams such as internet
	radio. Runs in linear time. Returns 0 on error.
	*/
	[CLink] public static extern drmp3_uint64 drmp3_get_mp3_frame_count(drmp3* pMP3);

	/*
	Calculates the total number of MP3 and PCM frames in the MP3 stream. Cannot be used for infinite streams such as internet
	radio. Runs in linear time. Returns 0 on error.

	This is equivalent to calling drmp3_get_mp3_frame_count() and drmp3_get_pcm_frame_count() except that it's more efficient.
	*/
	[CLink] public static extern drmp3_bool32 drmp3_get_mp3_and_pcm_frame_count(drmp3* pMP3, drmp3_uint64* pMP3FrameCount, drmp3_uint64* pPCMFrameCount);

	/*
	Calculates the seekpoints based on PCM frames. This is slow.

	pSeekpoint count is a pointer to a uint32 containing the seekpoint count. On input it contains the desired count.
	On output it contains the actual count. The reason for this design is that the client may request too many
	seekpoints, in which case dr_mp3 will return a corrected count.

	Note that seektable seeking is not quite sample exact when the MP3 stream contains inconsistent sample rates.
	*/
	[CLink] public static extern drmp3_bool32 drmp3_calculate_seek_points(drmp3* pMP3, drmp3_uint32* pSeekPointCount, drmp3_seek_point* pSeekPoints);

	/*
	Binds a seek table to the decoder.

	This does _not_ make a copy of pSeekPoints - it only references it. It is up to the application to ensure this
	remains valid while it is bound to the decoder.

	Use drmp3_calculate_seek_points() to calculate the seek points.
	*/
	[CLink] public static extern drmp3_bool32 drmp3_bind_seek_table(drmp3* pMP3, drmp3_uint32 seekPointCount, drmp3_seek_point* pSeekPoints);


	/*
	Opens an decodes an entire MP3 stream as a single operation.

	On output pConfig will receive the channel count and sample rate of the stream.

	Free the returned pointer with drmp3_free().
	*/
	[CLink] public static extern float* drmp3_open_and_read_pcm_frames_f32(drmp3_read_proc onRead, drmp3_seek_proc onSeek, void* pUserData, drmp3_config* pConfig, drmp3_uint64* pTotalFrameCount, drmp3_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drmp3_int16* drmp3_open_and_read_pcm_frames_s16(drmp3_read_proc onRead, drmp3_seek_proc onSeek, void* pUserData, drmp3_config* pConfig, drmp3_uint64* pTotalFrameCount, drmp3_allocation_callbacks* pAllocationCallbacks);

	[CLink] public static extern float* drmp3_open_memory_and_read_pcm_frames_f32(void* pData, size_t dataSize, drmp3_config* pConfig, drmp3_uint64* pTotalFrameCount, drmp3_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drmp3_int16* drmp3_open_memory_and_read_pcm_frames_s16(void* pData, size_t dataSize, drmp3_config* pConfig, drmp3_uint64* pTotalFrameCount, drmp3_allocation_callbacks* pAllocationCallbacks);

#if !DR_MP3_NO_STDIO
	[CLink] public static extern float* drmp3_open_file_and_read_pcm_frames_f32(char8* filePath, drmp3_config* pConfig, drmp3_uint64* pTotalFrameCount, drmp3_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drmp3_int16* drmp3_open_file_and_read_pcm_frames_s16(char8* filePath, drmp3_config* pConfig, drmp3_uint64* pTotalFrameCount, drmp3_allocation_callbacks* pAllocationCallbacks);
#endif

	/*
	Allocates a block of memory on the heap.
	*/
	[CLink] public static extern void* drmp3_malloc(size_t sz, drmp3_allocation_callbacks* pAllocationCallbacks);

	/*
	Frees any memory that was allocated by a public drmp3 API.
	*/
	[CLink] public static extern void drmp3_free(void* p, drmp3_allocation_callbacks* pAllocationCallbacks);
}