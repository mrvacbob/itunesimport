//
//  Utilities.h
//  iTunesImport
//
//  Created by Alexander Strange on 1/25/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XADMaster/XADArchive.h>

@interface NSString (IIAdditions)
-(BOOL) isValidFilename;
@end

@interface XADArchive (FileIteration)
-(NSArray*) allEntryNames;
@end

extern NSMutableString *STStandardizeStringNewlines(NSString *str);
extern NSString *STLoadFileWithUnknownEncoding(NSString *path);
extern NSString *STGetStringWithUnknownEncodingFromData(NSData *data, NSStringEncoding *enc_);