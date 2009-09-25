//
//  CueRendering.h
//  iTunesImport
//
//  Created by Alexander Strange on 5/17/08.
//

#import <Cocoa/Cocoa.h>
#import "IIFileSource.h"

@interface IIWavRenderer : NSObject {
}
- (id)initWithAudioFile:(NSString*)path;
- (unsigned)samples;
- (NSString*)pathForWavWithName:(NSString*)name;
- (NSString*)pathForWavWithName:(NSString*)name fromSample:(unsigned)startSample length:(unsigned)length;
@end

IIWavRenderer *GetRendererForAudioFile(NSString *path);