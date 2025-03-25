/*
FLAC audio decoder. Choice of public domain or MIT-0. See license statements at the end of this file.
dr_flac - v0.12.43 - 2024-12-17

David Reid - mackron@gmail.com

GitHub: https://github.com/mackron/dr_libs
*/

/*
RELEASE NOTES - v0.12.0
=======================
Version 0.12.0 has breaking API changes including changes to the existing API and the removal of deprecated APIs.


Improved Client-Defined Memory Allocation
-----------------------------------------
The main change with this release is the addition of a more flexible way of implementing custom memory allocation routines. The
existing system of DRFLAC_MALLOC, DRFLAC_REALLOC and DRFLAC_FREE are still in place and will be used by default when no custom
allocation callbacks are specified.

To use the new system, you pass in a pointer to a drflac_allocation_callbacks object to drflac_open() and family, like this:

	void* my_malloc(size_t sz, void* pUserData)
	{
		return malloc(sz);
	}
	void* my_realloc(void* p, size_t sz, void* pUserData)
	{
		return realloc(p, sz);
	}
	void my_free(void* p, void* pUserData)
	{
		free(p);
	}

	...

	drflac_allocation_callbacks allocationCallbacks;
	allocationCallbacks.pUserData = &myData;
	allocationCallbacks.onMalloc  = my_malloc;
	allocationCallbacks.onRealloc = my_realloc;
	allocationCallbacks.onFree    = my_free;
	drflac* pFlac = drflac_open_file("my_file.flac", &allocationCallbacks);

The advantage of this new system is that it allows you to specify user data which will be passed in to the allocation routines.

Passing in null for the allocation callbacks object will cause dr_flac to use defaults which is the same as DRFLAC_MALLOC,
DRFLAC_REALLOC and DRFLAC_FREE and the equivalent of how it worked in previous versions.

Every API that opens a drflac object now takes this extra parameter. These include the following:

	drflac_open()
	drflac_open_relaxed()
	drflac_open_with_metadata()
	drflac_open_with_metadata_relaxed()
	drflac_open_file()
	drflac_open_file_with_metadata()
	drflac_open_memory()
	drflac_open_memory_with_metadata()
	drflac_open_and_read_pcm_frames_s32()
	drflac_open_and_read_pcm_frames_s16()
	drflac_open_and_read_pcm_frames_f32()
	drflac_open_file_and_read_pcm_frames_s32()
	drflac_open_file_and_read_pcm_frames_s16()
	drflac_open_file_and_read_pcm_frames_f32()
	drflac_open_memory_and_read_pcm_frames_s32()
	drflac_open_memory_and_read_pcm_frames_s16()
	drflac_open_memory_and_read_pcm_frames_f32()



Optimizations
-------------
Seeking performance has been greatly improved. A new binary search based seeking algorithm has been introduced which significantly
improves performance over the brute force method which was used when no seek table was present. Seek table based seeking also takes
advantage of the new binary search seeking system to further improve performance there as well. Note that this depends on CRC which
means it will be disabled when DR_FLAC_NO_CRC is used.

The SSE4.1 pipeline has been cleaned up and optimized. You should see some improvements with decoding speed of 24-bit files in
particular. 16-bit streams should also see some improvement.

drflac_read_pcm_frames_s16() has been optimized. Previously this sat on top of drflac_read_pcm_frames_s32() and performed it's s32
to s16 conversion in a second pass. This is now all done in a single pass. This includes SSE2 and ARM NEON optimized paths.

A minor optimization has been implemented for drflac_read_pcm_frames_s32(). This will now use an SSE2 optimized pipeline for stereo
channel reconstruction which is the last part of the decoding process.

The ARM build has seen a few improvements. The CLZ (count leading zeroes) and REV (byte swap) instructions are now used when
compiling with GCC and Clang which is achieved using inline assembly. The CLZ instruction requires ARM architecture version 5 at
compile time and the REV instruction requires ARM architecture version 6.

An ARM NEON optimized pipeline has been implemented. To enable this you'll need to add -mfpu=neon to the command line when compiling.


Removed APIs
------------
The following APIs were deprecated in version 0.11.0 and have been completely removed in version 0.12.0:

	drflac_read_s32()                   -> drflac_read_pcm_frames_s32()
	drflac_read_s16()                   -> drflac_read_pcm_frames_s16()
	drflac_read_f32()                   -> drflac_read_pcm_frames_f32()
	drflac_seek_to_sample()             -> drflac_seek_to_pcm_frame()
	drflac_open_and_decode_s32()        -> drflac_open_and_read_pcm_frames_s32()
	drflac_open_and_decode_s16()        -> drflac_open_and_read_pcm_frames_s16()
	drflac_open_and_decode_f32()        -> drflac_open_and_read_pcm_frames_f32()
	drflac_open_and_decode_file_s32()   -> drflac_open_file_and_read_pcm_frames_s32()
	drflac_open_and_decode_file_s16()   -> drflac_open_file_and_read_pcm_frames_s16()
	drflac_open_and_decode_file_f32()   -> drflac_open_file_and_read_pcm_frames_f32()
	drflac_open_and_decode_memory_s32() -> drflac_open_memory_and_read_pcm_frames_s32()
	drflac_open_and_decode_memory_s16() -> drflac_open_memory_and_read_pcm_frames_s16()
	drflac_open_and_decode_memory_f32() -> drflac_open_memroy_and_read_pcm_frames_f32()

Prior versions of dr_flac operated on a per-sample basis whereas now it operates on PCM frames. The removed APIs all relate
to the old per-sample APIs. You now need to use the "pcm_frame" versions.
*/


/*
Introduction
============
dr_flac is a single file library. To use it, do something like the following in one .c file.

	```c
	#define DR_FLAC_IMPLEMENTATION
	#include "dr_flac.h"
	```

You can then #include this file in other parts of the program as you would with any other header file. To decode audio data, do something like the following:

	```c
	drflac* pFlac = drflac_open_file("MySong.flac", NULL);
	if (pFlac == NULL) {
		// Failed to open FLAC file
	}

	drflac_int32* pSamples = malloc(pFlac->totalPCMFrameCount * pFlac->channels * sizeof(drflac_int32));
	drflac_uint64 numberOfInterleavedSamplesActuallyRead = drflac_read_pcm_frames_s32(pFlac, pFlac->totalPCMFrameCount, pSamples);
	```

The drflac object represents the decoder. It is a transparent type so all the information you need, such as the number of channels and the bits per sample,
should be directly accessible - just make sure you don't change their values. Samples are always output as interleaved signed 32-bit PCM. In the example above
a native FLAC stream was opened, however dr_flac has seamless support for Ogg encapsulated FLAC streams as well.

You do not need to decode the entire stream in one go - you just specify how many samples you'd like at any given time and the decoder will give you as many
samples as it can, up to the amount requested. Later on when you need the next batch of samples, just call it again. Example:

	```c
	while (drflac_read_pcm_frames_s32(pFlac, chunkSizeInPCMFrames, pChunkSamples) > 0) {
		do_something();
	}
	```

You can seek to a specific PCM frame with `drflac_seek_to_pcm_frame()`.

If you just want to quickly decode an entire FLAC file in one go you can do something like this:

	```c
	uint channels;
	uint sampleRate;
	drflac_uint64 totalPCMFrameCount;
	drflac_int32* pSampleData = drflac_open_file_and_read_pcm_frames_s32("MySong.flac", &channels, &sampleRate, &totalPCMFrameCount, NULL);
	if (pSampleData == NULL) {
		// Failed to open and decode FLAC file.
	}

	...

	drflac_free(pSampleData, NULL);
	```

You can read samples as signed 16-bit integer and 32-bit floating-point PCM with the *_s16() and *_f32() family of APIs respectively, but note that these
should be considered lossy.


If you need access to metadata (album art, etc.), use `drflac_open_with_metadata()`, `drflac_open_file_with_metdata()` or `drflac_open_memory_with_metadata()`.
The rationale for keeping these APIs separate is that they're slightly slower than the normal versions and also just a little bit harder to use. dr_flac
reports metadata to the application through the use of a callback, and every metadata block is reported before `drflac_open_with_metdata()` returns.

The main opening APIs (`drflac_open()`, etc.) will fail if the header is not present. The presents a problem in certain scenarios such as broadcast style
streams or internet radio where the header may not be present because the user has started playback mid-stream. To handle this, use the relaxed APIs:

	`drflac_open_relaxed()`
	`drflac_open_with_metadata_relaxed()`

It is not recommended to use these APIs for file based streams because a missing header would usually indicate a corrupt or perverse file. In addition, these
APIs can take a long time to initialize because they may need to spend a lot of time finding the first frame.



Build Options
=============
#define these options before including this file.

#define DR_FLAC_NO_STDIO
  Disable `drflac_open_file()` and family.

#define DR_FLAC_NO_OGG
  Disables support for Ogg/FLAC streams.

#define DR_FLAC_BUFFER_SIZE <number>
  Defines the size of the internal buffer to store data from onRead(). This buffer is used to reduce the number of calls back to the client for more data.
  Larger values means more memory, but better performance. My tests show diminishing returns after about 4KB (which is the default). Consider reducing this if
  you have a very efficient implementation of onRead(), or increase it if it's very inefficient. Must be a multiple of 8.

#define DR_FLAC_NO_CRC
  Disables CRC checks. This will offer a performance boost when CRC is unnecessary. This will disable binary search seeking. When seeking, the seek table will
  be used if available. Otherwise the seek will be performed using brute force.

#define DR_FLAC_NO_SIMD
  Disables SIMD optimizations (SSE on x86/x64 architectures, NEON on ARM architectures). Use this if you are having compatibility issues with your compiler.

#define DR_FLAC_NO_WCHAR
  Disables all functions ending with `_w`. Use this if your compiler does not provide wchar.h. Not required if DR_FLAC_NO_STDIO is also defined.



Notes
=====
- dr_flac does not support changing the sample rate nor channel count mid stream.
- dr_flac is not thread-safe, but its APIs can be called from any thread so long as you do your own synchronization.
- When using Ogg encapsulation, a corrupted metadata block will result in `drflac_open_with_metadata()` and `drflac_open()` returning inconsistent samples due
  to differences in corrupted stream recorvery logic between the two APIs.
*/

using System;
using System.Interop;

namespace drlibs;

public static class drflac
{
	public typealias size_t            = uint;
	public typealias ssize_t           = int;
	public typealias wchar_t           = c_wchar;

	/* Sized Types */
	public typealias drflac_int8        = c_char;
	public typealias drflac_uint8       = c_uchar;
	public typealias drflac_int16       = c_short;
	public typealias drflac_uint16      = c_ushort;
	public typealias drflac_int32       = c_int;
	public typealias drflac_uint32      = c_uint;
	public typealias drflac_int64       = c_longlong;
	public typealias drflac_uint64      = c_ulonglong;
	public typealias drflac_uintptr     = c_uintptr;
	public typealias drflac_bool8       = drflac_uint8;
	public typealias drflac_bool32      = drflac_uint32;
	/* End Sized Types */

	[CLink] public static extern void drflac_version(drflac_uint32* pMajor, drflac_uint32* pMinor, drflac_uint32* pRevision);
	[CLink] public static extern char8* drflac_version_string();

	public function void* dr_flac_on_malloc(size_t sz, void* pUserData);
	public function void* dr_flac_on_realloc(void* p, size_t sz, void* pUserData);
	public function void dr_flac_on_free(void* p, void* pUserData);

	/* Allocation Callbacks */
	[CRepr]
	public struct drflac_allocation_callbacks
	{
		public void* pUserData;
		public dr_flac_on_malloc onMalloc;
		public dr_flac_on_realloc onRealloc;
		public dr_flac_on_free onFree;
	}
	/* End Allocation Callbacks */

	/*
	As data is read from the client it is placed into an internal buffer for fast access. This controls the size of that buffer. Larger values means more speed,
	but also more memory. In my testing there is diminishing returns after about 4KB, but you can fiddle with this to suit your own needs. Must be a multiple of 8.
	*/
	const c_int DR_FLAC_BUFFER_SIZE = 4096;

#if BF_64_BIT
	typealias drflac_cache_t = drflac_uint64;
#else
	typealias drflac_cache_t = drflac_uint32;
#endif

	/* The various metadata block types. */
	const c_int DRFLAC_METADATA_BLOCK_TYPE_STREAMINFO       = 0;
	const c_int DRFLAC_METADATA_BLOCK_TYPE_PADDING          = 1;
	const c_int DRFLAC_METADATA_BLOCK_TYPE_APPLICATION      = 2;
	const c_int DRFLAC_METADATA_BLOCK_TYPE_SEEKTABLE        = 3;
	const c_int DRFLAC_METADATA_BLOCK_TYPE_VORBIS_COMMENT   = 4;
	const c_int DRFLAC_METADATA_BLOCK_TYPE_CUESHEET         = 5;
	const c_int DRFLAC_METADATA_BLOCK_TYPE_PICTURE          = 6;
	const c_int DRFLAC_METADATA_BLOCK_TYPE_INVALID          = 127;

	/* The various picture types specified in the PICTURE block. */
	const c_int DRFLAC_PICTURE_TYPE_OTHER                   = 0;
	const c_int DRFLAC_PICTURE_TYPE_FILE_ICON               = 1;
	const c_int DRFLAC_PICTURE_TYPE_OTHER_FILE_ICON         = 2;
	const c_int DRFLAC_PICTURE_TYPE_COVER_FRONT             = 3;
	const c_int DRFLAC_PICTURE_TYPE_COVER_BACK              = 4;
	const c_int DRFLAC_PICTURE_TYPE_LEAFLET_PAGE            = 5;
	const c_int DRFLAC_PICTURE_TYPE_MEDIA                   = 6;
	const c_int DRFLAC_PICTURE_TYPE_LEAD_ARTIST             = 7;
	const c_int DRFLAC_PICTURE_TYPE_ARTIST                  = 8;
	const c_int DRFLAC_PICTURE_TYPE_CONDUCTOR               = 9;
	const c_int DRFLAC_PICTURE_TYPE_BAND                    = 10;
	const c_int DRFLAC_PICTURE_TYPE_COMPOSER                = 11;
	const c_int DRFLAC_PICTURE_TYPE_LYRICIST                = 12;
	const c_int DRFLAC_PICTURE_TYPE_RECORDING_LOCATION      = 13;
	const c_int DRFLAC_PICTURE_TYPE_DURING_RECORDING        = 14;
	const c_int DRFLAC_PICTURE_TYPE_DURING_PERFORMANCE      = 15;
	const c_int DRFLAC_PICTURE_TYPE_SCREEN_CAPTURE          = 16;
	const c_int DRFLAC_PICTURE_TYPE_BRIGHT_COLORED_FISH     = 17;
	const c_int DRFLAC_PICTURE_TYPE_ILLUSTRATION            = 18;
	const c_int DRFLAC_PICTURE_TYPE_BAND_LOGOTYPE           = 19;
	const c_int DRFLAC_PICTURE_TYPE_PUBLISHER_LOGOTYPE      = 20;

	public enum drflac_container : c_int
	{
		drflac_container_native,
		drflac_container_ogg,
		drflac_container_unknown
	}

	public enum drflac_seek_origin : c_int
	{
		drflac_seek_origin_start,
		drflac_seek_origin_current
	}

	/* The order of members in this structure is important because we map this directly to the raw data within the SEEKTABLE metadata block. */
	[CRepr]
	public struct drflac_seekpoint
	{
		public drflac_uint64 firstPCMFrame;
		public drflac_uint64 flacFrameOffset; /* The offset from the first byte of the header of the first frame. */
		public drflac_uint16 pcmFrameCount;
	}

	[CRepr]
	public struct drflac_streaminfo
	{
		public drflac_uint16 minBlockSizeInPCMFrames;
		public drflac_uint16 maxBlockSizeInPCMFrames;
		public drflac_uint32 minFrameSizeInPCMFrames;
		public drflac_uint32 maxFrameSizeInPCMFrames;
		public drflac_uint32 sampleRate;
		public drflac_uint8 channels;
		public drflac_uint8 bitsPerSample;
		public drflac_uint64 totalPCMFrameCount;
		public drflac_uint8[16] md5;
	}

	[CRepr]
	public struct drflac_metadata
	{
		/*
		The metadata type. Use this to know how to interpret the data below. Will be set to one of the
		DRFLAC_METADATA_BLOCK_TYPE_* tokens.
		*/
		public drflac_uint32 type;

		/*
		A pointer to the raw data. This points to a temporary buffer so don't hold on to it. It's best to
		not modify the contents of this buffer. Use the structures below for more meaningful and structured
		information about the metadata. It's possible for this to be null.
		*/
		public void* pRawData;

		/* The size in bytes of the block and the buffer pointed to by pRawData if it's non-NULL. */
		public drflac_uint32 rawDataSize; public struct
		{
			public drflac_streaminfo streaminfo;

			struct
			{
				public c_int unused;
			} padding;

			struct
			{
				public drflac_uint32 id;
				public void* pData;
				public drflac_uint32 dataSize;
			} application;

			struct
			{
				public drflac_uint32 seekpointCount;
				public drflac_seekpoint* pSeekpoints;
			} seektable;

			struct
			{
				public drflac_uint32 vendorLength;
				public char8* vendor;
				public drflac_uint32 commentCount;
				public void* pComments;
			} vorbis_comment;

			struct
			{
				public char8[128] catalog;
				public drflac_uint64 leadInSampleCount;
				public drflac_bool32 isCD;
				public drflac_uint8 trackCount;
				public void* pTrackData;
			} cuesheet;

			struct
			{
				public drflac_uint32 type;
				public drflac_uint32 mimeLength;
				public char8* mime;
				public drflac_uint32 descriptionLength;
				public char8* description;
				public drflac_uint32 width;
				public drflac_uint32 height;
				public drflac_uint32 colorDepth;
				public drflac_uint32 indexColorCount;
				public drflac_uint32 pictureDataSize;
				public drflac_uint8* pPictureData;
			} picture;
		} data;
	}


	/*
	Callback for when data needs to be read from the client.


	Parameters
	----------
	pUserData (in)
		The user data that was passed to drflac_open() and family.

	pBufferOut (out)
		The output buffer.

	bytesToRead (in)
		The number of bytes to read.


	Return Value
	------------
	The number of bytes actually read.


	Remarks
	-------
	A return value of less than bytesToRead indicates the end of the stream. Do _not_ return from this callback until either the entire bytesToRead is filled or
	you have reached the end of the stream.
	*/
	public function size_t drflac_read_proc(void* pUserData, void* pBufferOut, size_t bytesToRead);

	/*
	Callback for when data needs to be seeked.


	Parameters
	----------
	pUserData (in)
		The user data that was passed to drflac_open() and family.

	offset (in)
		The number of bytes to move, relative to the origin. Will never be negative.

	origin (in)
		The origin of the seek - the current position or the start of the stream.


	Return Value
	------------
	Whether or not the seek was successful.


	Remarks
	-------
	The offset will never be negative. Whether or not it is relative to the beginning or current position is determined by the "origin" parameter which will be
	either drflac_seek_origin_start or drflac_seek_origin_current.

	When seeking to a PCM frame using drflac_seek_to_pcm_frame(), dr_flac may call this with an offset beyond the end of the FLAC stream. This needs to be detected
	and handled by returning DRFLAC_FALSE.
	*/
	public function drflac_bool32 drflac_seek_proc(void* pUserData, c_int offset, drflac_seek_origin origin);

	/*
	Callback for when a metadata block is read.


	Parameters
	----------
	pUserData (in)
		The user data that was passed to drflac_open() and family.

	pMetadata (in)
		A pointer to a structure containing the data of the metadata block.


	Remarks
	-------
	Use pMetadata->type to determine which metadata block is being handled and how to read the data. This
	will be set to one of the DRFLAC_METADATA_BLOCK_TYPE_* tokens.
	*/
	public function void drflac_meta_proc(void* pUserData, drflac_metadata* pMetadata);

	/* Structure for internal use. Only used for decoders opened with drflac_open_memory. */
	[CRepr]
	public struct drflac__memory_stream
	{
		public drflac_uint8* data;
		public size_t dataSize;
		public size_t currentReadPos;
	}

   /* Structure for internal use. Used for bit streaming. */
	[CRepr]
	public struct drflac_bs
	{
		/* The function to call when more data needs to be read. */
		public drflac_read_proc onRead;

		/* The function to call when the current read position needs to be moved. */
		public drflac_seek_proc onSeek;

		/* The user data to pass around to onRead and onSeek. */
		public void* pUserData;


		/*
		The number of unaligned bytes in the L2 cache. This will always be 0 until the end of the stream is hit. At the end of the
		stream there will be a number of bytes that don't cleanly fit in an L1 cache line, so we use this variable to know whether
		or not the bistreamer needs to run on a slower path to read those last bytes. This will never be more than sizeof(drflac_cache_t).
		*/
		public size_t unalignedByteCount;

		/* The content of the unaligned bytes. */
		public drflac_cache_t unalignedCache;

		/* The index of the next valid cache line in the "L2" cache. */
		public drflac_uint32 nextL2Line;

		/* The number of bits that have been consumed by the cache. This is used to determine how many valid bits are remaining. */
		public drflac_uint32 consumedBits;

		/*
		The cached data which was most recently read from the client. There are two levels of cache. Data flows as such:
		Client -> L2 -> L1. The L2 -> L1 movement is aligned and runs on a fast path in just a few instructions.
		*/
		public drflac_cache_t[DR_FLAC_BUFFER_SIZE / sizeof(drflac_cache_t)] cacheL2;
		public drflac_cache_t cache;

		/*
		CRC-16. This is updated whenever bits are read from the bit stream. Manually set this to 0 to reset the CRC. For FLAC, this
		is reset to 0 at the beginning of each frame.
		*/
		public drflac_uint16 crc16;
		public drflac_cache_t crc16Cache; /* A cache for optimizing CRC calculations. This is filled when when the L1 cache is reloaded. */
		public drflac_uint32 crc16CacheIgnoredBytes; /* The number of bytes to ignore when updating the CRC-16 from the CRC-16 cache. */
	}

	[CRepr]
	public struct drflac_subframe
	{
		/* The type of the subframe: SUBFRAME_CONSTANT, SUBFRAME_VERBATIM, SUBFRAME_FIXED or SUBFRAME_LPC. */
		public drflac_uint8 subframeType;

		/* The number of wasted bits per sample as specified by the sub-frame header. */
		public drflac_uint8 wastedBitsPerSample;

		/* The order to use for the prediction stage for SUBFRAME_FIXED and SUBFRAME_LPC. */
		public drflac_uint8 lpcOrder;

		/* A pointer to the buffer containing the decoded samples in the subframe. This pointer is an offset from drflac::pExtraData. */
		public drflac_int32* pSamplesS32;
	}

	[CRepr]
	public struct drflac_frame_header
	{
		/*
		If the stream uses variable block sizes, this will be set to the index of the first PCM frame. If fixed block sizes are used, this will
		always be set to 0. This is 64-bit because the decoded PCM frame number will be 36 bits.
		*/
		public drflac_uint64 pcmFrameNumber;

		/*
		If the stream uses fixed block sizes, this will be set to the frame number. If variable block sizes are used, this will always be 0. This
		is 32-bit because in fixed block sizes, the maximum frame number will be 31 bits.
		*/
		public drflac_uint32 flacFrameNumber;

		/* The sample rate of this frame. */
		public drflac_uint32 sampleRate;

		/* The number of PCM frames in each sub-frame within this frame. */
		public drflac_uint16 blockSizeInPCMFrames;

		/*
		The channel assignment of this frame. This is not always set to the channel count. If interchannel decorrelation is being used this
		will be set to DRFLAC_CHANNEL_ASSIGNMENT_LEFT_SIDE, DRFLAC_CHANNEL_ASSIGNMENT_RIGHT_SIDE or DRFLAC_CHANNEL_ASSIGNMENT_MID_SIDE.
		*/
		public drflac_uint8 channelAssignment;

		/* The number of bits per sample within this frame. */
		public drflac_uint8 bitsPerSample;

		/* The frame's CRC. */
		public drflac_uint8 crc8;
	}

	[CRepr]
	public struct drflac_frame
	{
		/* The header. */
		public drflac_frame_header header;

		/*
		The number of PCM frames left to be read in this FLAC frame. This is initially set to the block size. As PCM frames are read,
		this will be decremented. When it reaches 0, the decoder will see this frame as fully consumed and load the next frame.
		*/
		public drflac_uint32 pcmFramesRemaining;

		/* The list of sub-frames within the frame. There is one sub-frame for each channel, and there's a maximum of 8 channels. */
		public drflac_subframe[8] subframes;
	}

	[CRepr]
	public struct drflac
	{
		/* The function to call when a metadata block is read. */
		public drflac_meta_proc onMeta;

		/* The user data posted to the metadata callback function. */
		public void* pUserDataMD;

		/* Memory allocation callbacks. */
		public drflac_allocation_callbacks allocationCallbacks;

		/* The sample rate. Will be set to something like 44100. */
		public drflac_uint32 sampleRate;

		/*
		The number of channels. This will be set to 1 for monaural streams, 2 for stereo, etc. Maximum 8. This is set based on the
		value specified in the STREAMINFO block.
		*/
		public drflac_uint8 channels;

		/* The bits per sample. Will be set to something like 16, 24, etc. */
		public drflac_uint8 bitsPerSample;

		/* The maximum block size, in samples. This number represents the number of samples in each channel (not combined). */
		public drflac_uint16 maxBlockSizeInPCMFrames;

		/*
		The total number of PCM Frames making up the stream. Can be 0 in which case it's still a valid stream, but just means
		the total PCM frame count is unknown. Likely the case with streams like internet radio.
		*/
		public drflac_uint64 totalPCMFrameCount;

		/* The container type. This is set based on whether or not the decoder was opened from a native or Ogg stream. */
		public drflac_container container;

		/* The number of seekpoints in the seektable. */
		public drflac_uint32 seekpointCount;

		/* Information about the frame the decoder is currently sitting on. */
		public drflac_frame currentFLACFrame;

		/* The index of the PCM frame the decoder is currently sitting on. This is only used for seeking. */
		public drflac_uint64 currentPCMFrame;

		/* The position of the first FLAC frame in the stream. This is only ever used for seeking. */
		public drflac_uint64 firstFLACFramePosInBytes;

		/* A hack to avoid a malloc() when opening a decoder with drflac_open_memory(). */
		public drflac__memory_stream memoryStream;

		/* A pointer to the decoded sample data. This is an offset of pExtraData. */
		public drflac_int32* pDecodedSamples;

		/* A pointer to the seek table. This is an offset of pExtraData, or NULL if there is no seek table. */
		public drflac_seekpoint* pSeekpoints;

		/* Internal use only. Only used with Ogg containers. Points to a drflac_oggbs object. This is an offset of pExtraData. */
		public void* _oggbs;

		/* Internal use only. Used for profiling and testing different seeking modes. */
		[Bitfield(.Public, .Bits(1), "_noSeekTableSeek")]
		[Bitfield(.Public, .Bits(1), "_noBinarySearchSeek")]
		[Bitfield(.Public, .Bits(1), "_noBruteForceSeek")]
		public drflac_bool32 _seek;

		/* The bit streamer. The raw FLAC data is fed through this object. */
		public drflac_bs bs;

		/* Variable length extra data. We attach this to the end of the object so we can avoid unnecessary mallocs. */
		public drflac_uint8[1] pExtraData;
	}


	/*
	Opens a FLAC decoder.


	Parameters
	----------
	onRead (in)
		The function to call when data needs to be read from the client.

	onSeek (in)
		The function to call when the read position of the client data needs to move.

	pUserData (in, optional)
		A pointer to application defined data that will be passed to onRead and onSeek.

	pAllocationCallbacks (in, optional)
		A pointer to application defined callbacks for managing memory allocations.


	Return Value
	------------
	Returns a pointer to an object representing the decoder.


	Remarks
	-------
	Close the decoder with `drflac_close()`.

	`pAllocationCallbacks` can be NULL in which case it will use `DRFLAC_MALLOC`, `DRFLAC_REALLOC` and `DRFLAC_FREE`.

	This function will automatically detect whether or not you are attempting to open a native or Ogg encapsulated FLAC, both of which should work seamlessly
	without any manual intervention. Ogg encapsulation also works with multiplexed streams which basically means it can play FLAC encoded audio tracks in videos.

	This is the lowest level function for opening a FLAC stream. You can also use `drflac_open_file()` and `drflac_open_memory()` to open the stream from a file or
	from a block of memory respectively.

	The STREAMINFO block must be present for this to succeed. Use `drflac_open_relaxed()` to open a FLAC stream where the header may not be present.

	Use `drflac_open_with_metadata()` if you need access to metadata.


	Seek Also
	---------
	drflac_open_file()
	drflac_open_memory()
	drflac_open_with_metadata()
	drflac_close()
	*/
	[CLink] public static extern drflac* drflac_open(drflac_read_proc onRead, drflac_seek_proc onSeek, void* pUserData, drflac_allocation_callbacks* pAllocationCallbacks);

	/*
	Opens a FLAC stream with relaxed validation of the header block.


	Parameters
	----------
	onRead (in)
		The function to call when data needs to be read from the client.

	onSeek (in)
		The function to call when the read position of the client data needs to move.

	container (in)
		Whether or not the FLAC stream is encapsulated using standard FLAC encapsulation or Ogg encapsulation.

	pUserData (in, optional)
		A pointer to application defined data that will be passed to onRead and onSeek.

	pAllocationCallbacks (in, optional)
		A pointer to application defined callbacks for managing memory allocations.


	Return Value
	------------
	A pointer to an object representing the decoder.


	Remarks
	-------
	The same as drflac_open(), except attempts to open the stream even when a header block is not present.

	Because the header is not necessarily available, the caller must explicitly define the container (Native or Ogg). Do not set this to `drflac_container_unknown`
	as that is for internal use only.

	Opening in relaxed mode will continue reading data from onRead until it finds a valid frame. If a frame is never found it will continue forever. To abort,
	force your `onRead` callback to return 0, which dr_flac will use as an indicator that the end of the stream was found.

	Use `drflac_open_with_metadata_relaxed()` if you need access to metadata.
	*/
	[CLink] public static extern drflac* drflac_open_relaxed(drflac_read_proc onRead, drflac_seek_proc onSeek, drflac_container container, void* pUserData, drflac_allocation_callbacks* pAllocationCallbacks);

	/*
	Opens a FLAC decoder and notifies the caller of the metadata chunks (album art, etc.).


	Parameters
	----------
	onRead (in)
		The function to call when data needs to be read from the client.

	onSeek (in)
		The function to call when the read position of the client data needs to move.

	onMeta (in)
		The function to call for every metadata block.

	pUserData (in, optional)
		A pointer to application defined data that will be passed to onRead, onSeek and onMeta.

	pAllocationCallbacks (in, optional)
		A pointer to application defined callbacks for managing memory allocations.


	Return Value
	------------
	A pointer to an object representing the decoder.


	Remarks
	-------
	Close the decoder with `drflac_close()`.

	`pAllocationCallbacks` can be NULL in which case it will use `DRFLAC_MALLOC`, `DRFLAC_REALLOC` and `DRFLAC_FREE`.

	This is slower than `drflac_open()`, so avoid this one if you don't need metadata. Internally, this will allocate and free memory on the heap for every
	metadata block except for STREAMINFO and PADDING blocks.

	The caller is notified of the metadata via the `onMeta` callback. All metadata blocks will be handled before the function returns. This callback takes a
	pointer to a `drflac_metadata` object which is a union containing the data of all relevant metadata blocks. Use the `type` member to discriminate against
	the different metadata types.

	The STREAMINFO block must be present for this to succeed. Use `drflac_open_with_metadata_relaxed()` to open a FLAC stream where the header may not be present.

	Note that this will behave inconsistently with `drflac_open()` if the stream is an Ogg encapsulated stream and a metadata block is corrupted. This is due to
	the way the Ogg stream recovers from corrupted pages. When `drflac_open_with_metadata()` is being used, the open routine will try to read the contents of the
	metadata block, whereas `drflac_open()` will simply seek past it (for the sake of efficiency). This inconsistency can result in different samples being
	returned depending on whether or not the stream is being opened with metadata.


	Seek Also
	---------
	drflac_open_file_with_metadata()
	drflac_open_memory_with_metadata()
	drflac_open()
	drflac_close()
	*/
	[CLink] public static extern drflac* drflac_open_with_metadata(drflac_read_proc onRead, drflac_seek_proc onSeek, drflac_meta_proc onMeta, void* pUserData, drflac_allocation_callbacks* pAllocationCallbacks);

	/*
	The same as drflac_open_with_metadata(), except attempts to open the stream even when a header block is not present.

	See Also
	--------
	drflac_open_with_metadata()
	drflac_open_relaxed()
	*/
	[CLink] public static extern drflac* drflac_open_with_metadata_relaxed(drflac_read_proc onRead, drflac_seek_proc onSeek, drflac_meta_proc onMeta, drflac_container container, void* pUserData, drflac_allocation_callbacks* pAllocationCallbacks);

	/*
	Closes the given FLAC decoder.


	Parameters
	----------
	pFlac (in)
		The decoder to close.


	Remarks
	-------
	This will destroy the decoder object.


	See Also
	--------
	drflac_open()
	drflac_open_with_metadata()
	drflac_open_file()
	drflac_open_file_w()
	drflac_open_file_with_metadata()
	drflac_open_file_with_metadata_w()
	drflac_open_memory()
	drflac_open_memory_with_metadata()
	*/
	[CLink] public static extern void drflac_close(drflac* pFlac);


	/*
	Reads sample data from the given FLAC decoder, output as interleaved signed 32-bit PCM.


	Parameters
	----------
	pFlac (in)
		The decoder.

	framesToRead (in)
		The number of PCM frames to read.

	pBufferOut (out, optional)
		A pointer to the buffer that will receive the decoded samples.


	Return Value
	------------
	Returns the number of PCM frames actually read. If the return value is less than `framesToRead` it has reached the end.


	Remarks
	-------
	pBufferOut can be null, in which case the call will act as a seek, and the return value will be the number of frames seeked.
	*/
	[CLink] public static extern drflac_uint64 drflac_read_pcm_frames_s32(drflac* pFlac, drflac_uint64 framesToRead, drflac_int32* pBufferOut);


	/*
	Reads sample data from the given FLAC decoder, output as interleaved signed 16-bit PCM.


	Parameters
	----------
	pFlac (in)
		The decoder.

	framesToRead (in)
		The number of PCM frames to read.

	pBufferOut (out, optional)
		A pointer to the buffer that will receive the decoded samples.


	Return Value
	------------
	Returns the number of PCM frames actually read. If the return value is less than `framesToRead` it has reached the end.


	Remarks
	-------
	pBufferOut can be null, in which case the call will act as a seek, and the return value will be the number of frames seeked.

	Note that this is lossy for streams where the bits per sample is larger than 16.
	*/
	[CLink] public static extern drflac_uint64 drflac_read_pcm_frames_s16(drflac* pFlac, drflac_uint64 framesToRead, drflac_int16* pBufferOut);

	/*
	Reads sample data from the given FLAC decoder, output as interleaved 32-bit floating point PCM.


	Parameters
	----------
	pFlac (in)
		The decoder.

	framesToRead (in)
		The number of PCM frames to read.

	pBufferOut (out, optional)
		A pointer to the buffer that will receive the decoded samples.


	Return Value
	------------
	Returns the number of PCM frames actually read. If the return value is less than `framesToRead` it has reached the end.


	Remarks
	-------
	pBufferOut can be null, in which case the call will act as a seek, and the return value will be the number of frames seeked.

	Note that this should be considered lossy due to the nature of floating point numbers not being able to exactly represent every possible number.
	*/
	[CLink] public static extern drflac_uint64 drflac_read_pcm_frames_f32(drflac* pFlac, drflac_uint64 framesToRead, float* pBufferOut);

	/*
	Seeks to the PCM frame at the given index.


	Parameters
	----------
	pFlac (in)
		The decoder.

	pcmFrameIndex (in)
		The index of the PCM frame to seek to. See notes below.


	Return Value
	-------------
	`DRFLAC_TRUE` if successful; `DRFLAC_FALSE` otherwise.
	*/
	[CLink] public static extern drflac_bool32 drflac_seek_to_pcm_frame(drflac* pFlac, drflac_uint64 pcmFrameIndex);


#if !DR_FLAC_NO_STDIO
	/*
	Opens a FLAC decoder from the file at the given path.


	Parameters
	----------
	pFileName (in)
		The path of the file to open, either absolute or relative to the current directory.

	pAllocationCallbacks (in, optional)
		A pointer to application defined callbacks for managing memory allocations.


	Return Value
	------------
	A pointer to an object representing the decoder.


	Remarks
	-------
	Close the decoder with drflac_close().


	Remarks
	-------
	This will hold a handle to the file until the decoder is closed with drflac_close(). Some platforms will restrict the number of files a process can have open
	at any given time, so keep this mind if you have many decoders open at the same time.


	See Also
	--------
	drflac_open_file_with_metadata()
	drflac_open()
	drflac_close()
	*/
	[CLink] public static extern drflac* drflac_open_file(char8* pFileName, drflac_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drflac* drflac_open_file_w(wchar_t* pFileName, drflac_allocation_callbacks* pAllocationCallbacks);

	/*
	Opens a FLAC decoder from the file at the given path and notifies the caller of the metadata chunks (album art, etc.)


	Parameters
	----------
	pFileName (in)
		The path of the file to open, either absolute or relative to the current directory.

	pAllocationCallbacks (in, optional)
		A pointer to application defined callbacks for managing memory allocations.

	onMeta (in)
		The callback to fire for each metadata block.

	pUserData (in)
		A pointer to the user data to pass to the metadata callback.

	pAllocationCallbacks (in)
		A pointer to application defined callbacks for managing memory allocations.


	Remarks
	-------
	Look at the documentation for drflac_open_with_metadata() for more information on how metadata is handled.


	See Also
	--------
	drflac_open_with_metadata()
	drflac_open()
	drflac_close()
	*/
	[CLink] public static extern drflac* drflac_open_file_with_metadata(char8* pFileName, drflac_meta_proc onMeta, void* pUserData, drflac_allocation_callbacks* pAllocationCallbacks);
	[CLink] public static extern drflac* drflac_open_file_with_metadata_w(wchar_t* pFileName, drflac_meta_proc onMeta, void* pUserData, drflac_allocation_callbacks* pAllocationCallbacks);
#endif

	/*
	Opens a FLAC decoder from a pre-allocated block of memory


	Parameters
	----------
	pData (in)
		A pointer to the raw encoded FLAC data.

	dataSize (in)
		The size in bytes of `data`.

	pAllocationCallbacks (in)
		A pointer to application defined callbacks for managing memory allocations.


	Return Value
	------------
	A pointer to an object representing the decoder.


	Remarks
	-------
	This does not create a copy of the data. It is up to the application to ensure the buffer remains valid for the lifetime of the decoder.


	See Also
	--------
	drflac_open()
	drflac_close()
	*/
	[CLink] public static extern drflac* drflac_open_memory(void* pData, size_t dataSize, drflac_allocation_callbacks* pAllocationCallbacks);

	/*
	Opens a FLAC decoder from a pre-allocated block of memory and notifies the caller of the metadata chunks (album art, etc.)


	Parameters
	----------
	pData (in)
		A pointer to the raw encoded FLAC data.

	dataSize (in)
		The size in bytes of `data`.

	onMeta (in)
		The callback to fire for each metadata block.

	pUserData (in)
		A pointer to the user data to pass to the metadata callback.

	pAllocationCallbacks (in)
		A pointer to application defined callbacks for managing memory allocations.


	Remarks
	-------
	Look at the documentation for drflac_open_with_metadata() for more information on how metadata is handled.


	See Also
	-------
	drflac_open_with_metadata()
	drflac_open()
	drflac_close()
	*/
	[CLink] public static extern drflac* drflac_open_memory_with_metadata(void* pData, size_t dataSize, drflac_meta_proc onMeta, void* pUserData, drflac_allocation_callbacks* pAllocationCallbacks);

	/* High Level APIs */

	/*
	Opens a FLAC stream from the given callbacks and fully decodes it in a single operation. The return value is a
	pointer to the sample data as interleaved signed 32-bit PCM. The returned data must be freed with drflac_free().

	You can pass in custom memory allocation callbacks via the pAllocationCallbacks parameter. This can be NULL in which
	case it will use DRFLAC_MALLOC, DRFLAC_REALLOC and DRFLAC_FREE.

	Sometimes a FLAC file won't keep track of the total sample count. In this situation the function will continuously
	read samples into a dynamically sized buffer on the heap until no samples are left.

	Do not call this function on a broadcast type of stream (like internet radio streams and whatnot).
	*/
	[CLink] public static extern drflac_int32* drflac_open_and_read_pcm_frames_s32(drflac_read_proc onRead, drflac_seek_proc onSeek, void* pUserData, uint* channels, uint* sampleRate, drflac_uint64* totalPCMFrameCount, drflac_allocation_callbacks* pAllocationCallbacks);

	/* Same as drflac_open_and_read_pcm_frames_s32(), except returns signed 16-bit integer samples. */
	[CLink] public static extern drflac_int16* drflac_open_and_read_pcm_frames_s16(drflac_read_proc onRead, drflac_seek_proc onSeek, void* pUserData, uint* channels, uint* sampleRate, drflac_uint64* totalPCMFrameCount, drflac_allocation_callbacks* pAllocationCallbacks);

	/* Same as drflac_open_and_read_pcm_frames_s32(), except returns 32-bit floating-point samples. */
	[CLink] public static extern float* drflac_open_and_read_pcm_frames_f32(drflac_read_proc onRead, drflac_seek_proc onSeek, void* pUserData, uint* channels, uint* sampleRate, drflac_uint64* totalPCMFrameCount, drflac_allocation_callbacks* pAllocationCallbacks);

#if !DR_FLAC_NO_STDIO
	/* Same as drflac_open_and_read_pcm_frames_s32() except opens the decoder from a file. */
	[CLink] public static extern drflac_int32* drflac_open_file_and_read_pcm_frames_s32(char8* filename, uint* channels, uint* sampleRate, drflac_uint64* totalPCMFrameCount, drflac_allocation_callbacks* pAllocationCallbacks);

	/* Same as drflac_open_file_and_read_pcm_frames_s32(), except returns signed 16-bit integer samples. */
	[CLink] public static extern drflac_int16* drflac_open_file_and_read_pcm_frames_s16(char8* filename, uint* channels, uint* sampleRate, drflac_uint64* totalPCMFrameCount, drflac_allocation_callbacks* pAllocationCallbacks);

	/* Same as drflac_open_file_and_read_pcm_frames_s32(), except returns 32-bit floating-point samples. */
	[CLink] public static extern float* drflac_open_file_and_read_pcm_frames_f32(char8* filename, uint* channels, uint* sampleRate, drflac_uint64* totalPCMFrameCount, drflac_allocation_callbacks* pAllocationCallbacks);
#endif

	/* Same as drflac_open_and_read_pcm_frames_s32() except opens the decoder from a block of memory. */
	[CLink] public static extern drflac_int32* drflac_open_memory_and_read_pcm_frames_s32(void* data, size_t dataSize, uint* channels, uint* sampleRate, drflac_uint64* totalPCMFrameCount, drflac_allocation_callbacks* pAllocationCallbacks);

	/* Same as drflac_open_memory_and_read_pcm_frames_s32(), except returns signed 16-bit integer samples. */
	[CLink] public static extern drflac_int16* drflac_open_memory_and_read_pcm_frames_s16(void* data, size_t dataSize, uint* channels, uint* sampleRate, drflac_uint64* totalPCMFrameCount, drflac_allocation_callbacks* pAllocationCallbacks);

	/* Same as drflac_open_memory_and_read_pcm_frames_s32(), except returns 32-bit floating-point samples. */
	[CLink] public static extern float* drflac_open_memory_and_read_pcm_frames_f32(void* data, size_t dataSize, uint* channels, uint* sampleRate, drflac_uint64* totalPCMFrameCount, drflac_allocation_callbacks* pAllocationCallbacks);

	/*
	Frees memory that was allocated internally by dr_flac.

	Set pAllocationCallbacks to the same object that was passed to drflac_open_*_and_read_pcm_frames_*(). If you originally passed in NULL, pass in NULL for this.
	*/
	[CLink] public static extern void drflac_free(void* p, drflac_allocation_callbacks* pAllocationCallbacks);

	/* Structure representing an iterator for vorbis comments in a VORBIS_COMMENT metadata block. */
	public struct drflac_vorbis_comment_iterator
	{
		public drflac_uint32 countRemaining;
		public char8* pRunningData;
	}

	/*
	Initializes a vorbis comment iterator. This can be used for iterating over the vorbis comments in a VORBIS_COMMENT
	metadata block.
	*/
	[CLink] public static extern void drflac_init_vorbis_comment_iterator(drflac_vorbis_comment_iterator* pIter, drflac_uint32 commentCount, void* pComments);

	/*
	Goes to the next vorbis comment in the given iterator. If null is returned it means there are no more comments. The
	returned string is NOT null terminated.
	*/
	[CLink] public static extern char8* drflac_next_vorbis_comment(drflac_vorbis_comment_iterator* pIter, drflac_uint32* pCommentLengthOut);


	/* Structure representing an iterator for cuesheet tracks in a CUESHEET metadata block. */
	public struct drflac_cuesheet_track_iterator
	{
		public drflac_uint32 countRemaining;
		public char8* pRunningData;
	}

	/* The order of members here is important because we map this directly to the raw data within the CUESHEET metadata block. */
	public struct drflac_cuesheet_track_index
	{
		public drflac_uint64 offset;
		public drflac_uint8 index;
		public drflac_uint8[3] reserved;
	}

	public struct drflac_cuesheet_track
	{
		public drflac_uint64 offset;
		public drflac_uint8 trackNumber;
		public char8[12] ISRC;
		public drflac_bool8 isAudio;
		public drflac_bool8 preEmphasis;
		public drflac_uint8 indexCount;
		public drflac_cuesheet_track_index* pIndexPoints;
	}

	/*
	Initializes a cuesheet track iterator. This can be used for iterating over the cuesheet tracks in a CUESHEET metadata
	block.
	*/
	[CLink] public static extern void drflac_init_cuesheet_track_iterator(drflac_cuesheet_track_iterator* pIter, drflac_uint32 trackCount, void* pTrackData);

	/* Goes to the next cuesheet track in the given iterator. If DRFLAC_FALSE is returned it means there are no more comments. */
	[CLink] public static extern drflac_bool32 drflac_next_cuesheet_track(drflac_cuesheet_track_iterator* pIter, drflac_cuesheet_track* pCuesheetTrack);
}