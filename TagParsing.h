//
//  TagParsing.h
//  iTunesImport
//
//  Created by Alexander Strange on 2/7/08.
//

#import <Cocoa/Cocoa.h>
#import "IIAlbum.h"

#ifdef __cplusplus
extern "C" {
#endif
	
extern AlbumTags *ParseAlbumTrackTags(NSArray *trackFiles, BOOL unicode);

#ifdef __cplusplus
};
#endif