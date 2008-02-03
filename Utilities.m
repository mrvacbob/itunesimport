//
//  Utilities.m
//  iTunesImport
//
//  Created by Alexander Strange on 1/25/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "Utilities.h"
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
		NSRange range = [entry rangeOfString:@"/"];
		entries[i] = range.length ? [entry substringFromIndex:range.location+1] : @"";
	}
	
	return [NSArray arrayWithObjects:entries count:numEntries];
}
@end