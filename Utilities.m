//
//  Utilities.m
//  iTunesImport
//
//  Created by Alexander Strange on 1/25/08.
//

#import "Utilities.h"
#import "UniversalDetector/UniversalDetector.h"
#import <ImageKit/ImageKit.h>
#include <sys/stat.h>

@implementation NSString (IIAdditions)
-(BOOL) isValidFilename
{
	struct stat st;
	
	int err = stat([self UTF8String], &st);
	return !err || errno != ENOENT;
}
@end

@implementation XADArchive (FileIteration)
-(NSArray *) allEntryNames
{
	int numEntries = [self numberOfEntries];
	NSString *entries[numEntries];
	
	for (int i = 0; i < numEntries; i++) {
		NSString *entry = [self nameOfEntry:i];
		entries[i] = entry;
		//NSRange range = [entry rangeOfString:@"/"];
		//entries[i] = range.length ? [entry substringFromIndex:range.location+1] : @"";
		//NSLog(@"entry: \"%@\" to \"%@\"", entry, entries[i]);
	}
	
	return [NSArray arrayWithObjects:entries count:numEntries];
}
@end

@implementation NSImage (IKImageBrowserItem)
- (NSString *)  imageUID
{
    return [NSString stringWithFormat:@"%p", self];
}

- (NSString *) imageRepresentationType
{
    return IKImageBrowserNSImageRepresentationType;
}

- (id) imageRepresentation
{
    return self;
}
@end

NSMutableString *STStandardizeStringNewlines(NSString *str)
{
	NSMutableString *ms = [NSMutableString stringWithString:str];
	[ms replaceOccurrencesOfString:@"\r\n" withString:@"\n" options:0 range:NSMakeRange(0,[ms length])];
	[ms replaceOccurrencesOfString:@"\r" withString:@"\n" options:0 range:NSMakeRange(0,[ms length])];
	return ms;
}

void STSortMutableArrayStably(NSMutableArray *array, int (*compare)(const void *, const void *))
{
	int count = [array count];
	id  objs[count];
	
	[array getObjects:objs];
	mergesort(objs, count, sizeof(void*), compare);
	[array setArray:[NSArray arrayWithObjects:objs count:count]];
}

NSString *STGetStringWithUnknownEncodingFromData(NSData *data, NSStringEncoding *enc_)
{
	UniversalDetector *ud = [[UniversalDetector alloc] init];
	NSString *res = nil;
	NSStringEncoding enc;
	float conf;
    int unsure;
	NSString *enc_str;
	
	[ud analyzeData:data];
	
	enc = [ud encoding];
	conf = [ud confidence];
	enc_str = [ud MIMECharset];

    unsure = conf < .6 && enc != NSASCIIStringEncoding;
    
	if (unsure) {
		NSLog(@"Guessed encoding \"%s\", but not sure (confidence %f%%).\n",[enc_str UTF8String],conf*100.);
	}
	
	res = [[[NSString alloc] initWithData:data encoding:enc] autorelease];
	
	if (!res) {
		NSLog(@"Failed to load file as guessed encoding %s. (data %@)\n",[enc_str UTF8String], data);
	} else if (unsure) {
        NSLog(@"With guessed encoding: \"%@\"", res);
    }
    
	[ud release];
	
	if (enc_) *enc_ = enc;
	
	return res;
}

extern NSString *STLoadFileWithUnknownEncoding(NSString *path)
{
	NSData *data = [NSData dataWithContentsOfMappedFile:path];
	return STGetStringWithUnknownEncodingFromData(data, NULL);
}
