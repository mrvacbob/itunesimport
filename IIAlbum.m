//
//  IIAlbum.m
//  iTunesImport
//
//  Created by Alexander Strange on 1/30/08.
//

#import "IIAlbum.h"
#import "TagParsing.h"
#import "CueParsing.h"
#import "Utilities.h"
#import "IIWavRenderer.h"

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

static NSString *TrackNameFilter(NSString *name)
{
	name = [name lastPathComponent];
	NSRange extRange = [name rangeOfString:@"." options:NSBackwardsSearch];
	
	if (extRange.length > 0) name = [name substringToIndex:extRange.location];
	
	return name;
}

static void CanonicalizeTags(AlbumTags *tags, IIAlbum *album)
{
	// fixup track numbers
	[tags->tracks sortUsingFunction:TrackOrderComparison context:nil];
	
	NSUInteger i, count = [tags->tracks count];
    
    if (!count) return;
    
	for (i = 0; i < count; i++) {
		TrackTags *tt = [tags->tracks objectAtIndex:i];
		tt->num = i+1;
		if (![tt->title length]) tt->title = [TrackNameFilter(tt->internalName) retain];
	}
	
	id last;
	
#define SamenessFilter(field) \
	last = ((TrackTags*)[tags->tracks objectAtIndex:0])->field; \
	for (i = 1; i < count; i++) if (![((TrackTags*)[tags->tracks objectAtIndex:i])->field isEqual:last]) break; \
	if (i == count) tags->field = [last retain]; \
	for (TrackTags *tt in tags->tracks) {if ([tt->field isEqualToString:tags->field]) {[tt->field release]; tt->field = nil;}}
	
	SamenessFilter(artist);
	SamenessFilter(genre);
	SamenessFilter(composer);
    
    if (![tags->title length]) tags->title = [[[[album fileSource] fileSourceName] lastPathComponent] retain];
    
    for (i = 0; i < count; i++) {
        TrackTags *tt = [tags->tracks objectAtIndex:i];
        if ([tt->artist length] && ![tt->artist isEqualToString:tags->artist])
            tags->hasAlbumArtist = YES;
    }
}


enum {
	kCueIndex = 0,
	kLastLossyIndex = 3,
    kLastAcceptedIndex = 5
};

static NSString * const knownExts[] = {@".cue", @".mp3", @".ogg", @".m4a", @".wav", @".aiff", @".flac", @".tta", @".mka", @".ape", @".wv", @".tak"};

static BOOL isExtLossless(NSString *path)
{
    int i;
    
    for (i = 0; i < sizeof(knownExts)/sizeof(knownExts[0]); i++) {
        if ([path hasSuffix:knownExts[i]])
            return i > kLastLossyIndex;
    }
    
    return NO;
}

static BOOL isExtAcceptedByITunes(NSString *path)
{
    int i;
    
    for (i = 0; i < sizeof(knownExts)/sizeof(knownExts[0]); i++) {
        if ([path hasSuffix:knownExts[i]])
            return i <= kLastAcceptedIndex;
    }
    
    return YES;
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

-(void) dealloc
{
	[title release];
	[artist release];
	[composer release];
	[genre release];
	[comment release];
	[internalName release];
	[super dealloc];
}
@end

@implementation AlbumTags
-(id) init
{
	if (self = [super init]) {
		title=artist=composer=genre=comment=nil;
		year=0;
		tracks=nil;
        hasAlbumArtist=NO;
	}
	
	return self;
}

-(void) dealloc
{
	[title release];
	[artist release];
	[composer release];
	[genre release];
	[comment release];
	[tracks release];
	[super dealloc];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [tracks count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{	
	TrackTags *tt = [tracks objectAtIndex:row];
	NSString *c = [tableColumn identifier];
	
	if ([c isEqualToString:@"Number"]) return [NSNumber numberWithUnsignedInt:tt->num];
	else if ([c isEqualToString:@"Title"]) return tt->title;
	else if ([c isEqualToString:@"Artist"]) return tt->artist;
	else if ([c isEqualToString:@"Composer"]) return tt->composer;
	else if ([c isEqualToString:@"Genre"]) return tt->genre;
	
	return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    TrackTags *tt = [tracks objectAtIndex:row];
	NSString *c = [tableColumn identifier];

    if ([c isEqualToString:@"Number"]) tt->num = [object intValue];
	else if ([c isEqualToString:@"Title"]) {[tt->title release]; tt->title = [object retain];}
	else if ([c isEqualToString:@"Artist"]) {[tt->artist release]; tt->artist = [object retain];}
	else if ([c isEqualToString:@"Composer"]) {[tt->composer release]; tt->composer = [object retain];}
	else if ([c isEqualToString:@"Genre"]) {[tt->genre release]; tt->genre = [object retain];}
}
@end

@implementation IIAlbum
- (id)initWithFileSource:(IIFileSource *)fs {return nil;}
- (unsigned)trackCount {return [tags->tracks count];}
- (BOOL) isValid {return NO;}
- (AlbumTags*)tags {return tags;}
- (NSString*)pathToTrackWithID:(int)track {return nil;}
- (IIFileSource*)fileSource {return fileSource;}
- (BOOL)shouldReencode {return NO;}

- (void)recanonicalizeTags
{
    CanonicalizeTags(tags, self);
}

- (void)dealloc
{
	[fileSource release];
	[fileNames release];
	[tags release];
	[super dealloc];
}
@end

@interface IIPrerippedAlbum : IIAlbum {
	BOOL unicode, lossless, accepted;
}

- (id)initWithFileSource:(IIFileSource *)fs extension:(NSString *)ext;
- (void)getAlbumTags;
@end

@interface IICuesheetAlbum : IIAlbum {
	NSDictionary *cueDict;
    NSArray *tracks;
	IIWavRenderer *cueRenderer;
}

- (void)findBestCuesheet;
@end

@implementation IIPrerippedAlbum
- (id)initWithFileSource:(IIFileSource *)fs extension:(NSString *)ext
{
	if (self = [super init]) {
		fileSource = [fs retain];
		fileNames = [[fs filesWithExtension:ext atTopLevel:YES] retain];
		unicode = ![ext isEqualToString:@".mp3"]; // xxx eh
        lossless = isExtLossless(ext);
        accepted = isExtAcceptedByITunes(ext);
		[self getAlbumTags];
	}
	
	return self;
}

-(NSString*)description
{
	return [NSString stringWithFormat:@"A pre-ripped album with %d files",[fileNames count]];
}

- (void)getAlbumTags
{
	NSMutableArray *fullPaths = [NSMutableArray array];
	
	for (NSString *filename in fileNames) {
		[fullPaths addObject:[fileSource pathToFile:filename]];
	}
	
	tags = ParseAlbumTrackTags(fullPaths, unicode);
    [self recanonicalizeTags];
}

- (BOOL)isValid {return YES;}

- (BOOL)shouldReencode {return lossless;}

- (NSString*)pathToTrackWithID:(int)track {
    NSString *path = [fileSource pathToFile:[fileNames objectAtIndex:track]];
    
    if (!accepted) {
        IIWavRenderer *renderer = GetRendererForAudioFile(path);
        NSString *trackWavName = [NSString stringWithFormat:@"track%d.wav", track];
        
        path = [renderer pathForWavWithName:trackWavName];
    }
    
    return path;
}
@end

@implementation IICuesheetAlbum
- (id)initWithFileSource:(IIFileSource *)fs
{
	if (self = [super init]) {
		fileSource = [fs retain];
		fileNames = [[fs filesWithExtension:@".cue" atTopLevel:YES] retain];
		[self findBestCuesheet];
        tracks = [cueDict objectForKey:@"Tracks"];
	}
	
	return self;
}

-(NSString*)description
{
	return [NSString stringWithFormat:@"A cuesheet album named \"%@\" with %d tracks", [cueDict objectForKey:@"Title"], [[cueDict objectForKey:@"Tracks"] count]];
}

-(void) dealloc
{
	[cueDict release];
	if (cueRenderer) [cueRenderer release];
	[super dealloc];
}

-(void) findBestCuesheet
{	
	NSDictionary *best=nil;
	unsigned bestTagCount=0;
    IIWavRenderer *bestRenderer=nil;
    
	for (NSString *cueName in fileNames) {
		NSDictionary *dict = ParseCuesheet(STGetStringWithUnknownEncodingFromData([fileSource dataFromFile:cueName], NULL));
        
        if (![dict objectForKey:@"Tracks"]) {
            NSLog(@"no tracks");
            continue;
        }
        NSString *cueWav = [dict objectForKey:@"File"];
		if (!cueWav) {
            NSLog(@"no filename");
            continue;
        }
        if (![fileSource containsFile:cueWav ignoringExtension:YES]) {
            NSLog(@"no audio");
            continue;
        }
        IIWavRenderer *renderer = GetRendererForAudioFile([fileSource pathToFile:cueWav]);
        if (!renderer) {
            NSLog(@"QT couldn't open audio");
            continue;
        }
        
        unsigned thisTagCount = CountCuesheetTags(dict);
        
		if (thisTagCount > bestTagCount) {
            best = dict;
            bestRenderer = renderer;
            bestTagCount = thisTagCount;
        }
	}
    cueRenderer = [bestRenderer retain];
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
    NSString *date;
	NSString *discid, *cuecom;
	discid = [cueDict objectForKey:@"Discid"];
	cuecom = [cueDict objectForKey:@"Comment"];
    date   = [cueDict objectForKey:@"Date"];

	if (discid) {[com appendFormat:@"%@\n", discid];}
	if (cuecom) [com appendString:cuecom];
    if (date && !tags->year) tags->year = [[NSCalendarDate dateWithNaturalLanguageString:date] yearOfCommonEra];
	
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
	[self recanonicalizeTags];
}

- (BOOL)shouldReencode {return YES;}

- (NSString*)pathToTrackWithID:(int)track {
    NSString *trackWavName = [NSString stringWithFormat:@"track%d.wav", track];
    UInt32 start, len;

    GetTrackStartLen(tracks, [cueRenderer samples], track, &start, &len);
    
	return [cueRenderer pathForWavWithName:trackWavName fromSample:start length:len];
}
@end

IIAlbum *GetAlbumForFileSource(IIFileSource *fs)
{
	const unsigned exts = sizeof(knownExts)/sizeof(NSString*);
	unsigned extCount[exts], i;
	
	bzero(extCount, sizeof(extCount));

	for (i = 0; i < sizeof(knownExts)/sizeof(NSString*); i++) {
		extCount[i] = [[fs filesWithExtension:knownExts[i] atTopLevel:YES] count];
	}

	if (extCount[kCueIndex] > 0) {
		IICuesheetAlbum *album = [[[IICuesheetAlbum alloc] initWithFileSource:fs] autorelease];
		
		if (album) return album;
	}
	
	for (i = 1; i < exts; i++) {
		if (extCount[i] == 0) continue;
		
		IIPrerippedAlbum *album = [[[IIPrerippedAlbum alloc] initWithFileSource:fs extension:knownExts[i]] autorelease];
		
		return album;
	}
	
	return nil;
}