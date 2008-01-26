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