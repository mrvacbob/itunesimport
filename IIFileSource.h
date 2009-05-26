//
//  IIFileSource.h
//  iTunesImport
//
//  Created by Alexander Strange on 1/26/08.
//

#import <Cocoa/Cocoa.h>


@interface IIFileSource : NSObject {
}

- (id)initWithFile:(NSString*)file;
- (NSArray*)filesWithExtension:(NSString*)extension atTopLevel:(BOOL)topLevel; 
- (NSString*)pathToFile:(NSString*)filename;
- (NSData*)dataFromFile:(NSString*)path;
- (BOOL)isValid;
- (BOOL)containsFile:(NSString*)path;
- (NSString*)fileSourceName;
@end

extern IIFileSource *GetFileSourceForPath(NSString *path);