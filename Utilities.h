//
//  Utilities.h
//  iTunesImport
//
//  Created by Alexander Strange on 1/25/08.
//

#import <Cocoa/Cocoa.h>
#import <XADMaster/XADArchive.h>

@interface NSString (IIAdditions)
-(BOOL) isValidFilename;
@end

@interface XADArchive (FileIteration)
-(NSArray*) allEntryNames;
@end

#ifdef __cplusplus
extern "C" {
#endif

extern NSMutableString *STStandardizeStringNewlines(NSString *str);
extern NSString *STLoadFileWithUnknownEncoding(NSString *path);
extern NSString *STGetStringWithUnknownEncodingFromData(NSData *data, NSStringEncoding *enc_);

#ifdef __cplusplus
};
#endif