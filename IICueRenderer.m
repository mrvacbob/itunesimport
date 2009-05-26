//
//  CueRendering.m
//  iTunesImport
//
//  Created by Alexander Strange on 5/17/08.
//

#import "IICueRenderer.h"
#import "QuickTimeUtils.h"

static AudioStreamBasicDescription CDASBD = {
	44100,
	kAudioFormatLinearPCM,
	kAudioFormatFlagIsSignedInteger|kAudioFormatFlagIsPacked,
	sizeof(SInt16) * 2,
	1,
	sizeof(SInt16) * 2,
	2,
	sizeof(SInt16) * 8
};

static AudioStreamBasicDescription SetCDDAASBD(MovieAudioExtractionRef aeref)
{
	AudioChannelLayout layout = (AudioChannelLayout){kAudioChannelLayoutTag_Stereo};
	MovieAudioExtractionSetProperty(aeref, kQTPropertyClass_MovieAudioExtraction_Audio, kQTMovieAudioExtractionAudioPropertyID_AudioChannelLayout, sizeof(AudioChannelLayout), &layout);
	MovieAudioExtractionSetProperty(aeref, kQTPropertyClass_MovieAudioExtraction_Audio, kQTMovieAudioExtractionAudioPropertyID_AudioStreamBasicDescription, sizeof(AudioStreamBasicDescription), &CDASBD);
	return CDASBD;
}

static UInt32 ParseCuesheetTime(NSString *time)
{
	UInt32 m,s,f;
	sscanf([time UTF8String], "%u:%u:%u", &m, &s, &f);
	
	UInt32 res = f * (44100/75) + s * 44100 + m * 44100 * 60;
	//NSLog(@"%@ -> %u = %f s",time,res, res / 44100.0);
	return res;
}

static void GetTrackStartLen(NSArray *tracks, UInt32 albumLen, int track, UInt32 *start, UInt32 *len)
{
	NSDictionary *thisTrack = [tracks objectAtIndex:track-1], *nextTrack = (track < [tracks count]) ? [tracks objectAtIndex:track] : nil;
	NSString *startString = [thisTrack objectForKey:@"Index 01"], *endString = [nextTrack objectForKey:@"Index 01"];
	UInt32 endTime;
    
	*start = ParseCuesheetTime(startString);
	endTime = endString ? ParseCuesheetTime(endString) : albumLen;
	*len = endTime - *start;
	
    NSLog(@"track %d start %u len %u samples", track, *start, *len);
}

static void WriteWavTo(NSString *path, short *buf, UInt32 len)
{
	UInt32 byteLen = len*2*sizeof(SInt16);
	
	struct wav_header {
		FourCharCode riff;
		UInt32 totalSize;
		FourCharCode wave;
		FourCharCode fmt_;
		FourCharCode fmtLen;
		short		 twocc;
		short		 channels;
		UInt32		 srate;
		UInt32		 bps;
		short		 bytesPerFrame;
		short		 bits;
		FourCharCode data;
		UInt32		 dataLen;
	} __attribute__((packed)) wav = {
		EndianU32_NtoB('RIFF'),
		EndianU32_NtoL(byteLen + 8 + 8 + 0x10),
		EndianU32_NtoB('WAVE'),
		EndianU32_NtoB('fmt '),
		EndianU32_NtoL(0x10),
		EndianU16_NtoL(0x01),
		EndianU16_NtoL(2),
		EndianU32_NtoL(44100),
		EndianU32_NtoL(44100*2*2),
		EndianU16_NtoL(4),
		EndianU16_NtoL(16),
		EndianU32_NtoB('data'),
		EndianU32_NtoL(byteLen)
	};
	
	FILE *f = fopen([path UTF8String], "wb");
	fwrite(&wav, sizeof(wav), 1, f);
	fwrite(buf, 1, byteLen, f);
	fclose(f);
}

@implementation IICueRenderer
- (id)initWithAlbumPath:(NSString*)path tracks:(NSArray*)tracks {return nil;}
- (NSString*)pathForTrackWithID:(int)track {return nil;}
@end

@interface IIQTCueRenderer : IICueRenderer
{
	MovieAudioExtractionRef aeref;
    Movie movie;
	UInt32 length;
	
	AudioStreamBasicDescription asbd;
}
@end

@implementation IIQTCueRenderer
- (id)initWithAlbumPath:(NSString*)path tracks:(NSArray*)tracks_
{
	if (self = [super init]) {
		InitializeQuickTime();
		GetMovieFromCFStringRef((CFStringRef)path, &movie);
		SetMovieActive(movie, YES);
		
		MovieAudioExtractionBegin(movie, 0, &aeref);
		asbd = SetCDDAASBD(aeref);
		SetMovieTimeScale(movie, asbd.mSampleRate);
		length = GetMovieExtractionDuration(movie) * asbd.mSampleRate;
		tracks = [tracks_ retain];
		temporaryFilePaths = [[NSMutableArray alloc] init];
		
		//NSLog(@"length = %f s %u samples", GetMovieExtractionDuration(movie), length);
	}
	
	return self;
}

-(void)dealloc
{
	MovieAudioExtractionEnd(aeref);
	DisposeMovie(movie);
	[tracks release];
	
	NSFileManager *manager = [NSFileManager defaultManager];
	
	for (NSString *path in temporaryFilePaths) { //xxx temporary
		[manager removeItemAtPath:path error:nil];
	}
	
	[temporaryFilePaths release];
	
	[super dealloc];
}

- (UInt32) decompressFrom:(UInt32)from into:(short*)buf length:(UInt32)len
{
	OSErr err;
	
	TimeRecord t;
	t.scale = asbd.mSampleRate;
	t.base = GetMovieTimeBase(movie);
	t.value.hi = 0;
	t.value.lo = from;
	
	err = MovieAudioExtractionSetProperty(aeref,
									kQTPropertyClass_MovieAudioExtraction_Movie,
									kQTMovieAudioExtractionMoviePropertyID_CurrentTime,
									sizeof(t), &t);
	//if (err) NSLog(@"upon SetProperty, err %d, err2 %d", err, GetMoviesError());
	
	AudioBufferList bufList = (AudioBufferList){1,{2,len*sizeof(SInt16)*2,buf}};
	
	UInt32 realLen = len, flags;
	
	err = MovieAudioExtractionFillBuffer(aeref, &realLen, &bufList, &flags);
	
	//if (err) NSLog(@"upon FillBuffer, err %d, err2 %d", err, GetMoviesError());
	
	return realLen;
}

- (NSString*)pathForTrackWithID:(int)track
{
	UInt32 trackStart, trackLen;
	NSString *tempPath;
		
	GetTrackStartLen(tracks, length, track, &trackStart, &trackLen);
	tempPath = [NSString stringWithFormat:@"%@/track%d.wav", NSTemporaryDirectory(), track];
	
	short *buf = malloc(trackLen * sizeof(SInt16) * 2);

	UInt32 len = [self decompressFrom:trackStart into:buf length:trackLen];
	
	//NSLog(@"requested %d samples got %d samples",trackLen,len);
	
	WriteWavTo(tempPath, buf, len);
	
	free(buf);
	
	[temporaryFilePaths addObject:tempPath];
	
	return tempPath;
}
@end

IICueRenderer *IICueRendererForCuesheetWav(NSDictionary *cuesheet, IIFileSource *fileSource)
{
	return [[IIQTCueRenderer alloc] initWithAlbumPath:[fileSource pathToFile:[cuesheet objectForKey:@"File"]] tracks:[cuesheet objectForKey:@"Tracks"]];
} 