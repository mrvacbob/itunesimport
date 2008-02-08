//
//  IIAlbum.m
//  iTunesImport
//
//  Created by Alexander Strange on 1/30/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "IIAlbum.h"
#import "TagParsing.h"
#import "CueParsing.h"
#import "Utilities.h"

@implementation IIAlbum
- (id)initWithFileSource:(IIFileSource *)fs {return nil;}
- (unsigned)trackCount {return 0;}
- (NSArray*)trackNames {return nil;}
-(BOOL) isValid {return NO;}
@end

@interface IIPrerippedAlbum : IIAlbum {
	NSDictionary *albumDict;
	NSArray *tracks;
	BOOL unicode;
}

- (id)initWithFileSource:(IIFileSource *)fs extension:(NSString *)ext lossless:(BOOL)lossless;
- (void)getAlbumTags;
@end

@interface IICuesheetAlbum : IIAlbum {
	NSDictionary *cueDict;
	NSArray *cueTracks;
}

- (void)findBestCuesheet;
@end

@implementation IIPrerippedAlbum
- (id)initWithFileSource:(IIFileSource *)fs extension:(NSString *)ext lossless:(BOOL)lossless
{
	if (self = [super init]) {
		fileSource = [fs retain];
		fileNames = [[fs filesWithExtension:ext atTopLevel:YES] retain];
		unicode = ![ext isEqualToString:@".mp3"];
		[self getAlbumTags];
	}
	
	return self;
}

- (void)getAlbumTags
{
	NSMutableArray *fullPaths = [NSMutableArray array];
	
	for (NSString *filename in fileNames) {
		[fullPaths addObject:[fileSource pathToFile:filename]];
	}
	
	albumDict = ParseAlbumTrackTags(fullPaths, unicode);
	NSLog(@"%@", albumDict);
}

- (unsigned)trackCount {return [fileNames count];}
- (NSArray*)trackNames {return fileNames;}
- (BOOL)isValid {return YES;}
@end

@implementation IICuesheetAlbum
- (id)initWithFileSource:(IIFileSource *)fs
{
	if (self = [super init]) {
		fileSource = [fs retain];
		fileNames = [[fs filesWithExtension:@".cue" atTopLevel:YES] retain];
		[self findBestCuesheet];
	}
	
	return self;
}

-(void) findBestCuesheet
{	
	NSDictionary *best=nil;
	unsigned bestTagCount=0;
	for (NSString *cueName in fileNames) {
		NSDictionary *dict = ParseCuesheet(STGetStringWithUnknownEncodingFromData([fileSource dataFromFile:cueName], NULL));
		NSString *cueWav = [dict objectForKey:@"File"];
		if (!cueWav || ![fileSource containsFile:cueWav] || ![dict objectForKey:@"Tracks"]) continue;
		unsigned thisTagCount = CountCuesheetTags(dict);
		if (thisTagCount > bestTagCount) {best = dict; bestTagCount = thisTagCount;}
	}
	
	cueDict = [best retain];
	cueTracks = [cueDict objectForKey:@"Tracks"];
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