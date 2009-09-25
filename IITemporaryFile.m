//
//  IITemporaryFile.m
//  iTunesImport
//
//  Created by Alexander Strange on 9/24/09.
//  Copyright 2009 iThink Software. All rights reserved.
//

#import "IITemporaryFile.h"


@implementation IITemporaryFile
- (id)initWithName:(NSString*)name
{
    if (self = [super init]) {
        path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    }
    
    return self;
}

- (void)dealloc
{
    //is this an unlink()? i hope so
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    [super dealloc];
}

- (NSString*)path
{
    return path;
}

+ (IITemporaryFile*)temporaryFileWithName:(NSString*)name
{
    return [[[IITemporaryFile alloc] initWithName:name] autorelease];
}
@end
