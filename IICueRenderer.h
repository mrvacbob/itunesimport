//
//  CueRendering.h
//  iTunesImport
//
//  Created by Alexander Strange on 5/17/08.
//

#import <Cocoa/Cocoa.h>
#import "IIFileSource.h"


@interface IICueRenderer : NSObject {
	NSArray *tracks;
}

- (id)initWithAlbumPath:(NSString*)path tracks:(NSArray*)tracks;
- (NSString*)pathForTrackWithID:(int)track;
@end

IICueRenderer *IICueRendererForCuesheetWav(NSDictionary *cuesheet, IIFileSource *fileSource);