//
//  IIFileSource.m
//  iTunesImport
//
//  Created by Alexander Strange on 1/26/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "IIFileSource.h"
#import "XADMaster/XADArchive.h"
#import "Utilities.h"
#import <sys/stat.h>

static NSArray *FilterExtensions(NSArray *files, NSString *ext, BOOL topLevel)
{
	NSMutableIndexSet *is = [NSMutableIndexSet indexSet];
	
	unsigned count = [files count], i;
	
	for (i = 0; i < count; i++) {
		NSString *fn = [files objectAtIndex:i];
		if (topLevel && [fn rangeOfString:@"/"].length > 0) continue;
		if (ext && ![fn hasSuffix:ext]) continue;
		
		[is addIndex:i];
	}
	
	NSArray *ret = [files objectsAtIndexes:is];
	//NSLog(@"FE in: %@", files);
	//NSLog(@"FE for \"%@\": %@", ext, ret);
	return ret;
}

@implementation IIFileSource
-(id)initWithFile:(NSString*)file {return nil;}
-(NSArray*)filesWithExtension:(NSString*)extension atTopLevel:(BOOL)topLevel {return nil;}
-(NSString*)pathToFile:(NSString*)filename {return nil;}
-(NSData*)dataFromFile:(NSString*)path {return nil;}
-(BOOL) isValid {return NO;}
-(BOOL)containsFile:(NSString*)path {return NO;}
@end

@interface IIXADFileSource : IIFileSource {
	XADArchive *xad;
	XADError error;
	NSArray *archiveNames;
	NSMutableArray *temporaryFilePaths;
}
@end

@interface IIFSFileSource : IIFileSource {
	NSString *baseName;
	NSArray *allSubpaths, *contents;
}
@end

@implementation IIFSFileSource
-(id) initWithFile:(NSString*)file
{
	if (self = [super init]) {
		baseName = [file retain];
		allSubpaths = contents = nil;
	}
	
	return self;
}

-(BOOL) isValid
{
	struct stat st;
	
	return (stat([baseName UTF8String], &st) != -1 || errno != ENOENT) && ((st.st_mode & S_IFMT) == S_IFDIR);
}

-(NSArray*)filesWithExtension:(NSString*)extension atTopLevel:(BOOL)topLevel
{
	NSFileManager *manager = [NSFileManager defaultManager];
	
	return FilterExtensions(topLevel ? (contents ? contents : (contents = [[manager contentsOfDirectoryAtPath:baseName error:nil] retain])) : (allSubpaths ? allSubpaths : (allSubpaths = [[manager subpathsOfDirectoryAtPath:baseName error:nil] retain])), extension, NO);
}

-(BOOL)containsFile:(NSString*)path
{
	struct stat st;
	
	return stat([[baseName stringByAppendingPathComponent:path] UTF8String], &st) != -1;
}

-(NSString*)pathToFile:(NSString*)filename
{
	return [baseName stringByAppendingPathComponent:filename];
}

-(NSData*)dataFromFile:(NSString*)path
{
	return [NSData dataWithContentsOfMappedFile:[baseName stringByAppendingPathComponent:path]];
}
@end

@implementation IIXADFileSource
-(id) initWithFile:(NSString*)file
{
	if (self = [super init]) {
		xad = [[XADArchive alloc] initWithFile:file delegate:self error:&error];
		archiveNames = [[xad allEntryNames] retain];
		temporaryFilePaths = [[NSMutableArray alloc] init];
	}
	
	return self;
}

-(BOOL) isValid
{
	return !error && ![xad isCorrupted];
}

-(NSArray*)filesWithExtension:(NSString*)extension atTopLevel:(BOOL)topLevel
{
	return FilterExtensions([xad allEntryNames], extension, topLevel);
}

-(BOOL)containsFile:(NSString*)path
{
	return [archiveNames containsObject:path];
}

-(NSString*)pathToFile:(NSString*)filename
{
	NSString *tempPath = NSTemporaryDirectory();
	NSString *archiveTempDir = [tempPath stringByAppendingPathComponent:[xad filename]];
	
	int idx = [archiveNames indexOfObject:filename];

	if (idx != INT_MAX) [xad extractEntry:idx to:archiveTempDir];
	
	NSString *tempFile = [archiveTempDir stringByAppendingPathComponent:[xad nameOfEntry:idx]];
	
	[temporaryFilePaths addObject:tempFile];
	
	return tempFile;
}

-(NSData*)dataFromFile:(NSString*)path
{
	int idx = [archiveNames indexOfObject:path];

	return (idx != INT_MAX) ? [xad contentsOfEntry:idx] : nil;
}
@end

IIFileSource *GetFileSourceForPath(NSString *path)
{
	IIFileSource *fs = [[IIFSFileSource alloc] initWithFile:path];
	
	if (![fs isValid]) fs = [[IIXADFileSource alloc] initWithFile:path];
	if (![fs isValid]) return nil;
	
	return [fs autorelease];
}