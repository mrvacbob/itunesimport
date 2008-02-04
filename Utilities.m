//
//  Utilities.m
//  iTunesImport
//
//  Created by Alexander Strange on 1/25/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "Utilities.h"
#import "UniversalDetector/UniversalDetector.h"
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

static BOOL DifferentiateLatin12(const unsigned char *data, int length)
{
	// generated from french/german (latin1) and hungarian/slovak (latin2)
	
	const short frequencies[] = {
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
		504, 1024, -192, -403, 433, -1106, -1376, -865, 447, -1894, -1550, 878, -2285, -385, 1616, -1292, 
		27, -2306, -1328, 57, 402, 194, -338, -1509, 0, 944, 1471, 0, 0, 0, 0, 0, 
		0, 1891, 1663, 2461, 226, -4595, -1174, -1672, -1096, 2218, 3418, 4572, -1075, 2244, -2666, 855, 
		279, -4997, -3202, -4819, -627, -1330, 855, -1276, -2190, 3607, 810, 0, 1555, 0, 0, 0, 
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 618, 0, 0, 0, 357, 0, 
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4220, 0, -1279, 504, 4677, 0, 
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2366, 0, 0, 0, 0, 0, 
		0, 0, 0, 0, 0, 0, 1747, 0, 0, 0, 5936, 0, 0, 0, 0, 0, 
		-1107, 0, 0, 798, -639, 0, 0, -1107, 874, -751, 0, 0, 0, 0, 1953, 0, 
		0, 0, 0, 0, 0, 0, 0, 0, 874, 0, 0, 0, 0, 0, 713, -1567, 
		-3675, 6370, 2120, 10526, -1107, 0, 0, -2306, -598, -3012, -3262, 0, 5571, 6644, 2104, 1595, 
	0, 0, 798, 1070, -1430, 0, -1567, 0, 4280, 1004, 713, -904, -1107, 3288, 4539, 0};
	
	int frcount = 0;
	
	while (length--) {
		frcount += frequencies[*data++];
	}
	
	return frcount <= 0;
}

NSString *STGetStringWithUnknownEncodingFromData(NSData *data, NSStringEncoding *enc_)
{
	UniversalDetector *ud = [[UniversalDetector alloc] init];
	NSString *res = nil;
	NSStringEncoding enc;
	float conf;
	NSString *enc_str;
	BOOL latin2;
	
	[ud analyzeData:data];
	
	enc = [ud encoding];
	conf = [ud confidence];
	enc_str = [ud MIMECharset];
	latin2 = [enc_str isEqualToString:@"windows-1250"];
	
	if (latin2) {
		if (DifferentiateLatin12([data bytes], [data length])) { // seems to actually be latin1
			enc = NSWindowsCP1252StringEncoding;
			enc_str = @"windows-1252";
		}
	}
	
	if (conf < .6 || latin2) {
		NSLog(@"Guessed encoding \"%s\", but not sure (confidence %f%%).\n",[enc_str UTF8String],conf*100.);
	}
	
	res = [[[NSString alloc] initWithData:data encoding:enc] autorelease];
	
	if (!res) {
		if (latin2) {
			NSLog(@"Encoding %s failed, retrying.\n",[enc_str UTF8String]);
			enc = (enc == NSWindowsCP1252StringEncoding) ? NSWindowsCP1250StringEncoding : NSWindowsCP1252StringEncoding;
			res = [[[NSString alloc] initWithData:data encoding:enc] autorelease];
			if (!res) NSLog(@"Both of latin1/2 failed.\n",[enc_str UTF8String]);
		} else NSLog(@"Failed to load file as guessed encoding %s.\n",[enc_str UTF8String]);
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
