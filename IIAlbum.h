//
//  IIAlbum.h
//  iTunesImport
//
//  Created by Alexander Strange on 1/30/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IIFileSource.h"

@interface IIAlbum : NSObject {
	IIFileSource *fileSource;
	NSArray *fileNames;
}

- (id)initWithFileSource:(IIFileSource *)fs;
- (unsigned)trackCount;
- (NSArray*)trackNames;
- (BOOL)isValid;
@end

extern IIAlbum *GetAlbumForFileSource(IIFileSource *fs);