//
//  TagParsing.mm
//  iTunesImport
//
//  Created by Alexander Strange on 2/7/08.
//

#import "TagParsing.h"
#import "Utilities.h"
#import "IIAlbum.h"
#import <Taglib/fileref.h>
#import <Taglib/tag.h>

// the idea of this function seems pretty wrong!
static BOOL TagLibWillCrash(NSString *name)
{
    return [name hasSuffix:@".wav"];
}

static NSDictionary *GetRawTrackTags(NSString *track, BOOL unicode)
{
	NSDictionary *ret = [NSMutableDictionary dictionary];
    
    [ret setValue:track forKey:@"Filename"];
    
    if (TagLibWillCrash(track)) return ret;
    
	TagLib::FileRef file([track UTF8String]);
	TagLib::Tag *tag = file.tag();
	if (!tag || tag->isEmpty()) return ret;
	
	TagLib::String title = tag->title(), artist = tag->artist(), album = tag->album(), com = tag->comment(), genre = tag->genre();

#define add(name, field) if (!field.isEmpty()) [ret setValue:[NSData dataWithBytes:(void*)field.to8Bit(unicode).data() length:field.size()] forKey:@"" # name];
	add(Title, title);
	add(Artist, artist);
	add(Album, album);
	add(Comment, com);
	add(Genre, genre);
#undef add
	
	if (tag->year()) [ret setValue:[NSNumber numberWithUnsignedInt:tag->year()] forKey:@"Year"];	
	if (tag->track()) [ret setValue:[NSNumber numberWithUnsignedInt:tag->track()] forKey:@"Track"];
	
	return ret;
}

static AlbumTags *AlbumTagsFromParsedFields(NSArray *tracks)
{
	AlbumTags *a = [[AlbumTags alloc] init];
	
#define set(name, field) t->field = [[track objectForKey:@"" # name] retain];
#define seti(name, field) t->field = [[track objectForKey:@"" # name] intValue];
	
	NSMutableArray *tracktags = [[NSMutableArray alloc] init];
	
	int i, len = [tracks count];
	for (i = 0; i < len; i++) {
		NSDictionary *track = [tracks objectAtIndex:i];
		TrackTags *t = [[[TrackTags alloc] init] autorelease];
		
		t->tid = i;
		seti(Track, num);
		seti(Year, year);
		set(Title, title);
		set(Artist, artist);
		set(Composer, composer);
		set(Genre, genre);
		set(Comment, comment);
		set(Filename, internalName);
        a->title = [[track objectForKey:@"Album"] retain];
		
		[tracktags addObject:t];
	}
	
	a->tracks = tracktags;
	
	return a;
}

AlbumTags *ParseAlbumTrackTags(NSArray *trackFiles, BOOL unicode)
{
	NSMutableArray *rawTags = [NSMutableArray array], *tracks = [NSMutableArray array];
	NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet];
	
	for (NSString *file in trackFiles) {
		[rawTags addObject:GetRawTrackTags(file, unicode)];
	}

	NSMutableData *ud_buf = [NSMutableData data];
	for (NSDictionary *track in rawTags) {
		for (id tag in [track allValues]) {
			if (![tag isKindOfClass:[NSData class]]) continue;
			[ud_buf appendData:tag];
			[ud_buf appendBytes:"\n" length:1];
		}
	}
	
	NSStringEncoding enc = NSUTF8StringEncoding;
	if ([ud_buf length]) STGetStringWithUnknownEncodingFromData(ud_buf, &enc);
	
	for (NSDictionary *track in rawTags) {
		NSMutableDictionary *newTrack = [NSMutableDictionary dictionary];
		for (NSString *key in [track allKeys]) {
			id val = [track objectForKey:key];
			
			if ([val isKindOfClass:[NSData class]]) {
				NSData *data = val;
				NSString *str = [[[[NSString alloc] initWithData:data encoding:enc] autorelease] stringByTrimmingCharactersInSet:ws];
				if (str) [newTrack setObject:str forKey:key];
			} else [newTrack setObject:val forKey:key];
		}
		[tracks addObject:newTrack];
	}
		
	return AlbumTagsFromParsedFields(tracks);
}