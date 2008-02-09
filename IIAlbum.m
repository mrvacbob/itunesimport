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

static NSInteger TrackOrderComparison(id a_, id b_, void *context)
{
	TrackTags *a = a_, *b = b_;
	
	if (a->num && !b->num) return NSOrderedDescending;
	if (!a->num && b->num) return NSOrderedAscending;
	
	if (a->num > b->num) return NSOrderedDescending;
	if (b->num > a->num) return NSOrderedAscending;
	
	if (!a->internalName) return NSOrderedAscending;
	if (!b->internalName) return NSOrderedDescending;
	
	return [a->internalName compare:b->internalName options:NSNumericSearch|NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch|NSWidthInsensitiveSearch|NSForcedOrderingSearch];
}

static void CanonicalizeTags(AlbumTags *tags)
{
	// fixup track numbers
	[tags->tracks sortUsingFunction:TrackOrderComparison context:nil];
	
	NSUInteger i, count = [tags->tracks count];
	for (i = 0; i < count; i++) {
		TrackTags *tt = [tags->tracks objectAtIndex:i];
		tt->num = i+1;
	}
}

@implementation TrackTags
-(id) init
{
	if (self = [super init]) {
		tid=num=year=0;
		title=artist=composer=genre=comment=nil;
	}
	
	return self;
}
@end

@implementation AlbumTags
-(id) init
{
	if (self = [super init]) {
		title=artist=composer=genre=comment=nil;
		year=0;
		tracks=nil;
	}
	
	return self;
}
@end

@implementation IIAlbum
- (id)initWithFileSource:(IIFileSource *)fs {return nil;}
- (unsigned)trackCount {return [tags->tracks count];}
- (NSArray*)trackNames {return nil;}
- (BOOL) isValid {return NO;}
- (AlbumTags*)tags {return tags;}
- (NSString*)pathToTrackWithTags:(int)track shouldReencode:(BOOL *)reencode {return nil;}
@end

@interface IIPrerippedAlbum : IIAlbum {
	BOOL unicode;
}

- (id)initWithFileSource:(IIFileSource *)fs extension:(NSString *)ext lossless:(BOOL)lossless;
- (void)getAlbumTags;
@end

@interface IICuesheetAlbum : IIAlbum {
	NSDictionary *cueDict;
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
	
	tags = ParseAlbumTrackTags(fullPaths, unicode);
	CanonicalizeTags(tags);
}

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
	
	tags = [[AlbumTags alloc] init];
	NSMutableArray *trackarray = [[NSMutableArray array] retain];
	
#define set(name, field) tags->field = [[cueDict objectForKey:@"" # name] retain];
#define seti(name, field) tags->field = [[cueDict objectForKey:@"" # name] intValue];
	
	seti(Year, year);
	set(Title, title);
	set(Performer, artist);
	set(Songwriter, composer);
	set(Genre, genre);
	NSMutableString *com = [NSMutableString string];
	NSString *discid, *cuecom;
	discid = [cueDict objectForKey:@"Discid"];
	cuecom = [cueDict objectForKey:@"Comment"];

	if (discid) {[com appendFormat:@"%@\n", discid];}
	if (cuecom) [com appendString:cuecom];
	
	tags->comment = [com retain];
	
#undef set
#undef seti
	
	for (NSDictionary *track in [cueDict objectForKey:@"Tracks"]) {
		TrackTags *tracktags = [[[TrackTags alloc] init] autorelease];
		
#define set(name, field) tracktags->field = [[track objectForKey:@"" # name] retain];
#define seti(name, field) tracktags->field = [[track objectForKey:@"" # name] intValue];
		
		seti(Track, tid);
		tracktags->num = tracktags->tid;
		seti(Year, year);
		set(Title, title);
		set(Performer, artist);
		set(Songwriter, composer);
		set(Genre, genre);
		
		tracktags->internalName = [tracktags->title retain];
		[trackarray addObject:tracktags];
	}
	
	tags->tracks = trackarray;
	CanonicalizeTags(tags);
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