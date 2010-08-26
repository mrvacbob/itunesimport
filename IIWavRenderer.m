//
//  CueRendering.m
//  iTunesImport
//
//  Created by Alexander Strange on 5/17/08.
//

#import "IIWavRenderer.h"
#import "IITemporaryFile.h"
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

@implementation IIWavRenderer
- (id)initWithAudioFile:(NSString*)path {return nil;}
- (unsigned)samples {return 0;}
- (NSString*)pathForWavWithName:(NSString*)name {return nil;}
- (NSString*)pathForWavWithName:(NSString*)name fromSample:(unsigned)startSample length:(unsigned)length {return nil;}
@end

@interface IIQTWavRenderer : IIWavRenderer
{
	MovieAudioExtractionRef aeref;
    Movie movie;
	UInt32 length;
	
	AudioStreamBasicDescription asbd;
}
@end

@implementation IIQTWavRenderer

- (id)initWithAudioFile:(NSString*)path
{
    if (self = [super init]) {
		InitializeQuickTime();
		GetMovieFromCFStringRef((CFStringRef)path, &movie);
        if (!movie) {
            [self release];
            return nil;
        }
		SetMovieActive(movie, YES);
		
		MovieAudioExtractionBegin(movie, 0, &aeref);
		asbd = SetCDDAASBD(aeref);
		SetMovieTimeScale(movie, asbd.mSampleRate);
		length = GetMovieExtractionDuration(movie) * asbd.mSampleRate;
        
        //tracks = [tracks_ retain];
        
        //NSLog(@"length = %f s %u samples", GetMovieExtractionDuration(movie), length);
    }
    
    return self;
}

-(void)dealloc
{
	MovieAudioExtractionEnd(aeref);
	DisposeMovie(movie);
	//[tracks release];	
	
	[super dealloc];
}

- (unsigned)samples
{
    return length;
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
	if (err) NSLog(@"upon SetProperty, err %d, err2 %d", err, GetMoviesError());
	
	AudioBufferList bufList = (AudioBufferList){1,{2,len*sizeof(SInt16)*2,buf}};
	
	UInt32 realLen = len, flags;
	
	err = MovieAudioExtractionFillBuffer(aeref, &realLen, &bufList, &flags);
	
	if (err) NSLog(@"upon FillBuffer, err %d, err2 %d", err, GetMoviesError());
	
	return realLen;
}

- (NSString*)pathForWavWithName:(NSString*)name fromSample:(unsigned)startSample length:(unsigned)wavLen
{
    SInt16 *buf = malloc(wavLen * sizeof(SInt16) * 2);
    
    UInt32 decompLen = [self decompressFrom:startSample into:buf length:wavLen];
    
    if (decompLen != wavLen)
        NSLog(@"decompression length mismatch: wanted %u got %u", wavLen, (unsigned)decompLen);
    
    // XXX not GC safe
    NSString *tempPath = [[IITemporaryFile temporaryFileWithName:name] path];
    
    WriteWavTo(tempPath, buf, MIN(decompLen, wavLen));
    
    free(buf);
    
    return tempPath;

}

- (NSString*)pathForWavWithName:(NSString*)name 
{
    return [self pathForWavWithName:name fromSample:0 length:length];
}
@end

IIWavRenderer *GetRendererForAudioFile(NSString *path)
{
    return [[[IIQTWavRenderer alloc] initWithAudioFile:path] autorelease];
}