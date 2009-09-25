//
//  IITemporaryFile.h
//  iTunesImport
//
//  Created by Alexander Strange on 9/24/09.
//  Copyright 2009 iThink Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


/* Delete a file with the given name when dealloced.
 * The file's creation is left to the client.
 * So this isn't really actually a temporary file class.
 */
@interface IITemporaryFile : NSObject {
    NSString *path;
}
+ (IITemporaryFile*)temporaryFileWithName:(NSString*)name;
- (NSString*)path;
@end
