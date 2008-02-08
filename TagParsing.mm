//
//  TagParsing.mm
//  iTunesImport
//
//  Created by Alexander Strange on 2/7/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TagParsing.h"
#import "Utilities.h"
#import <Taglib/fileref.h>
#import <Taglib/tag.h>
/*
static void f()
{
	NSStringEncoding tagEnc = NSUTF8StringEncoding;
	
	
	if (!unicode) {
		NSMutableData *ud_buffer = [NSMutableData data];
#define ud(x) if (!x.isEmpty()) [ud_buffer appendBytes:x.to8Bit(unicode).data() length:x.size()]; [ud_buffer appendBytes:"\n" length:1];
		ud(title); ud(artist); ud(album); ud(genre); ud(com);
#undef ud	
		STGetStringWithUnknownEncodingFromData(ud_buffer, &tagEnc);
	}
	
}
*/
static NSDictionary *GetRawTrackTags(NSString *track, BOOL unicode)
{
	NSDictionary *ret = [NSMutableDictionary dictionary];
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

NSDictionary *ParseAlbumTrackTags(NSArray *trackFiles, BOOL unicode)
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
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
	
	NSStringEncoding enc;
	STGetStringWithUnknownEncodingFromData(ud_buf, &enc);
	
	for (NSDictionary *track in rawTags) {
		NSMutableDictionary *newTrack = [NSMutableDictionary dictionary];
		for (NSString *key in [track allKeys]) {
			id val = [track objectForKey:key];
			
			if ([val isKindOfClass:[NSData class]]) {
				NSData *data = val;
				[newTrack setObject:[[[[NSString alloc] initWithData:data encoding:enc] autorelease] stringByTrimmingCharactersInSet:ws] forKey:key];
			} else [newTrack setObject:val forKey:key];
		}
		[tracks addObject:newTrack];
	}
	
	[dict setObject:tracks forKey:@"Tracks"];
	
	return dict;
}