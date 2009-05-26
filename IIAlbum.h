//
//  IIAlbum.h
//  iTunesImport
//
//  Created by Alexander Strange on 1/30/08.
//

#import <Cocoa/Cocoa.h>
#import "IIFileSource.h"

@interface TrackTags : NSObject {
@public;
	int tid;
	int num;
	int year;
	NSString *title, *artist, *composer, *genre, *comment, *internalName;
}
@end

@interface AlbumTags : NSObject {
@public;
	NSString *title, *artist, *composer, *genre, *comment;
	int year;
	NSMutableArray *tracks;
}
@end

@interface IIAlbum : NSObject {
	IIFileSource *fileSource;
	NSArray *fileNames;
	AlbumTags *tags;
}

- (id)initWithFileSource:(IIFileSource *)fs;
- (unsigned)trackCount;
- (AlbumTags*)tags;
- (BOOL)isValid;
- (BOOL)shouldReencode;
- (NSString*)pathToTrackWithID:(int)track;
- (IIFileSource*)fileSource;
- (void)recanonicalizeTags;
@end

extern IIAlbum *GetAlbumForFileSource(IIFileSource *fs);