//
//  TagParsing.h
//  iTunesImport
//
//  Created by Alexander Strange on 2/7/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#ifdef __cplusplus
extern "C" {
#endif
	
extern NSDictionary *ParseAlbumTrackTags(NSArray *trackFiles, BOOL unicode);

#ifdef __cplusplus
};
#endif