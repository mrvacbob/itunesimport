//
//  IIFileSource.m
//  iTunesImport
//
//  Created by Alexander Strange on 1/26/08.
//

#import "IIFileSource.h"
#import "IITemporaryFile.h"
#import "XADMaster/XADArchive.h"
#import "Utilities.h"
#import <sys/stat.h>

// topLevel - ignore files in subfolders
// checkBaseName -
// NO  - template is an extension (.wav) and it finds all files with that extension
// YES - template is a filename and it finds all files with that name. topLevel must be NO
static NSArray *FilterExtensions(NSArray *files, NSString *template, BOOL topLevel, BOOL checkBaseName)
{
	NSMutableIndexSet *is = [NSMutableIndexSet indexSet];
	
	unsigned count = [files count], i;
	
	if (checkBaseName)
		template = [template stringByDeletingPathExtension];
	
	for (i = 0; i < count; i++) {
		NSString *fn = [files objectAtIndex:i];
		if (topLevel) 
            if ([fn rangeOfString:@"/"].length > 0)
                continue;
        
        if (template) {
            BOOL match = checkBaseName ? [[fn commonPrefixWithString:template options:0] length] : [fn hasSuffix:template];
            
            if (!match)
                continue;
        }
		
		[is addIndex:i];
	}
	
	NSArray *ret = [files objectsAtIndexes:is];
//	NSLog(@"FE in: %@", files);
//	NSLog(@"FE for \"%@\": %@", template, ret);
	return ret;
}

@implementation IIFileSource
-(id)initWithFile:(NSString*)file {return nil;}
-(NSArray*)filesWithExtension:(NSString*)extension atTopLevel:(BOOL)topLevel {return nil;}
-(NSString*)pathToFile:(NSString*)filename {return nil;}
-(NSData*)dataFromFile:(NSString*)path {return nil;}
-(BOOL) isValid {return NO;}
-(BOOL)containsFile:(NSString*)path ignoringExtension:(BOOL)ignoringExtension {return NO;}
-(NSString*)fileSourceName {return nil;}
@end

@interface IIFSFileSource : IIFileSource {
	NSString *baseName;
	NSArray *allSubpaths, *topLevelContents;
}
@end

@interface IIXADFileSource : IIFileSource {
	XADArchive *xad;
	XADError error;
	NSArray *archiveNames;
	NSMutableArray *temporaryFiles;
}
@end

@implementation IIFSFileSource
-(id) initWithFile:(NSString*)file
{
	if (self = [super init]) {
		baseName = [file retain];
        
        NSFileManager *manager = [NSFileManager defaultManager];

        allSubpaths = [[manager subpathsOfDirectoryAtPath:baseName error:nil] retain];
        topLevelContents = [[manager contentsOfDirectoryAtPath:baseName error:nil] retain];
	}
	
	return self;
}

-(void) dealloc
{
	[baseName release];
	[allSubpaths release];
	[topLevelContents release];
	[super dealloc];
}

-(BOOL) isValid
{
	struct stat st;
	
	return (stat([baseName UTF8String], &st) != -1 || errno != ENOENT) && ((st.st_mode & S_IFMT) == S_IFDIR);
}

-(NSArray*)filesWithExtension:(NSString*)extension atTopLevel:(BOOL)topLevel
{	
	return FilterExtensions(topLevel ? topLevelContents : allSubpaths, extension, NO, NO);
}

-(BOOL)containsFile:(NSString*)filename ignoringExtension:(BOOL)ignoringExtension
{
    if (ignoringExtension) {
        return [FilterExtensions(topLevelContents, filename, NO, YES) count] > 0;
    } else {
        NSFileManager *manager = [NSFileManager defaultManager];
        
        return [manager fileExistsAtPath:[baseName stringByAppendingPathComponent:filename]];
    }
}

-(NSString*)pathToFile:(NSString*)filename
{
	return [baseName stringByAppendingPathComponent:filename];
}

-(NSData*)dataFromFile:(NSString*)path
{
	return [NSData dataWithContentsOfMappedFile:[baseName stringByAppendingPathComponent:path]];
}

-(NSString*)fileSourceName
{
    return baseName;
}
@end

@implementation IIXADFileSource
-(id) initWithFile:(NSString*)file
{
	if (self = [super init]) {
		xad = [[XADArchive alloc] initWithFile:file delegate:self error:&error];
		archiveNames = [[xad allEntryNames] retain];
        temporaryFiles = [[NSArray alloc] init];
	}
	
	return self;
}

-(void) dealloc
{
	[xad release];
	[archiveNames release];
    [temporaryFiles release];
	[super dealloc];
}

-(BOOL) isValid
{
	return !error && ![xad isCorrupted];
}

-(NSArray*)filesWithExtension:(NSString*)extension atTopLevel:(BOOL)topLevel
{
	return FilterExtensions(archiveNames, extension, topLevel, NO);
}

-(BOOL)containsFile:(NSString*)filename ignoringExtension:(BOOL)ignoringExtension
{
    if (ignoringExtension) {
        return [FilterExtensions(archiveNames, filename, YES, YES) count] > 0;
    } else {
        return [archiveNames containsObject:filename];
    }
}

-(NSString*)pathToFile:(NSString*)filename
{
	NSString *tempPath = NSTemporaryDirectory();
    NSString *archiveName = [xad filename];
	NSString *archiveTempDir = [tempPath stringByAppendingPathComponent:archiveName];
	
	int idx = [archiveNames indexOfObject:filename];

    if (idx == INT_MAX) return nil;
    
	[xad extractEntry:idx to:archiveTempDir];
	
    IITemporaryFile *tempFile = [IITemporaryFile temporaryFileWithName:[[xad filename] stringByAppendingPathComponent:[xad nameOfEntry:idx]]];
	[temporaryFiles addObject:tempFile];
	
	return [tempFile path];
}

-(NSData*)dataFromFile:(NSString*)path
{
	int idx = [archiveNames indexOfObject:path];

	return (idx != INT_MAX) ? [xad contentsOfEntry:idx] : nil;
}

-(NSString*)fileSourceName
{
    return [xad filename];
}
@end

IIFileSource *GetFileSourceForPath(NSString *path)
{
	IIFileSource *fs = [[[IIFSFileSource alloc] initWithFile:path] autorelease];
	
	if (![fs isValid]) fs = [[[IIXADFileSource alloc] initWithFile:path] autorelease];
	if (![fs isValid]) return nil;
	
	return fs;
}