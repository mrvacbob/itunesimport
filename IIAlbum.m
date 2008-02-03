//
//  IIAlbum.m
//  iTunesImport
//
//  Created by Alexander Strange on 1/30/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "IIAlbum.h"

@implementation IIAlbum
- (id)initWithFileSource:(IIFileSource *)fs {return nil;}
- (unsigned)trackCount {return 0;}
- (NSArray*)trackNames {return nil;}
-(BOOL) isValid {return NO;}
@end

@interface IIPrerippedAlbum : IIAlbum {
}

- (id)initWithFileSource:(IIFileSource *)fs extension:(NSString *)ext lossless:(BOOL)lossless;
@end

@interface IICuesheetAlbum : IIAlbum {
}
@end

@implementation IIPrerippedAlbum
- (id)initWithFileSource:(IIFileSource *)fs extension:(NSString *)ext lossless:(BOOL)lossless
{
	if (self = [super init]) {
		fileSource = [fs retain];
		fileNames = [[fs filesWithExtension:ext atTopLevel:YES] retain];
	}
	
	return self;
}

-(unsigned) trackCount {return [fileNames count];}
-(NSArray*) trackNames {return fileNames;}
-(BOOL) isValid {return YES;}
@end

@implementation IICuesheetAlbum
- (id)initWithFileSource:(IIFileSource *)fs
{
	if (self = [super init]) {
		fileSource = [fs retain];
		fileNames = [[fs filesWithExtension:@".cue" atTopLevel:YES] retain];
	}
	
	return self;
}

@end

enum {
	kCueIndex = 0,
	kLastLossyIndex = 3
};

IIAlbum *GetAlbumForFileSource(IIFileSource *fs)
{
	static NSString * const extList[] = {@".cue", @".mp3", @".ogg", @".m4a", @".flac", @".ape", @".tta", @".wv"};
	const unsigned exts = sizeof(extList)/sizeof(NSString*);
	unsigned extCount[exts], i;
	
	bzero(extCount, sizeof(extCount));

	for (i = 0; i < sizeof(extList)/sizeof(NSString*); i++) {
		extCount[i] = [[fs filesWithExtension:extList[i] atTopLevel:YES] count];
	}
	
	if (extCount[kCueIndex] > 0) {
		IICuesheetAlbum *album = [[[IICuesheetAlbum alloc] initWithFileSource:fs] autorelease];
		
		if (album) return album;
	}
	
	for (i = 1; i < exts; i++) {
		if (extCount[i] == 0) continue;
		
		IIPrerippedAlbum *album = [[[IIPrerippedAlbum alloc] initWithFileSource:fs extension:extList[i] lossless:(i > kLastLossyIndex)] autorelease];
		
		return album;
	}
	
	return nil;
}