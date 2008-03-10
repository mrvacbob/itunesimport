//
//  IIAssistantController.m
//  iTunesImport
//
//  Created by Alexander Strange on 1/25/08.
//  Copyright __MyCompanyName__ 2008. All rights reserved.
//

#import "IIAssistantController.h"
#import "IIAlbum.h"
#import "Utilities.h"
#import "iTunesApplication.h"

@implementation IIAssistantController
- (IBAction)advance:(id)sender
{
	[nextButton setEnabled:NO];
	[assistantTabView selectNextTabViewItem:self];
	
	int nextTab = [assistantTabView indexOfTabViewItem:[assistantTabView selectedTabViewItem]];
	
	switch (nextTab) {
		case 1:
			if (!albumTags) {albumTags = [album tags]; [self setAlbumFields];}
			[albumTrackTable setDataSource:albumTags];
			[nextButton setEnabled:YES];
			break;
		case 2:
            [self gatherAlbumTags];
			[imageChoiceView setDataSource:self];
            [self loadAlbumImages];
            [nextButton setEnabled:YES];
			break;
		case 3:
            [self importIntoiTunes];
	}
}

- (void)awakeFromNib
{
	parsingThread = nil;
	album = nil;
	albumTags = nil;
	[assistantWindow setTitle:@"iTunes Importer"];
	[albumTrackTable setColumnAutoresizingStyle:NSTableViewReverseSequentialColumnAutoresizingStyle];
    imageNameArray = [[NSMutableArray alloc] init];
    imageArray = [[NSMutableArray alloc] init];
}

#pragma mark -- Album Choice
- (IBAction)chooseAlbum:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setCanChooseDirectories:YES];
	[panel beginSheetForDirectory:nil file:nil modalForWindow:assistantWindow modalDelegate:self didEndSelector:@selector(chooseAlbumPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)chooseAlbumPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
	[chooseAlbumField setStringValue:[panel filename]]; 
	[self albumChosen:self];
}

- (void)validateAlbumOnThread
{
	if ([parsingThread isExecuting]) [parsingThread cancel];
	if (parsingThread) [parsingThread release];
	parsingThread = [[NSThread alloc] initWithTarget:self selector:@selector(validateAlbumThread) object:nil];
	
	[parsingThread start];
}

- (IBAction)albumChosen:(id)sender
{
	NSString *name = [chooseAlbumField stringValue];
	
	if ([name isValidFilename]) {
		[self validateAlbumOnThread];
	}
}

- (void)validateAlbumThread
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[progressIndicator performSelectorOnMainThread:@selector(startAnimation:) withObject:self waitUntilDone:NO];
	if (album) [album release];
	album = [GetAlbumForFileSource(GetFileSourceForPath([chooseAlbumField stringValue])) retain];
	NSString *desc = [album description];
    
	[albumTypeLabel performSelectorOnMainThread:@selector(setStringValue:) withObject:desc?desc:@"none?" waitUntilDone:NO];
	[nextButton setEnabled:desc ? YES : NO];
	[progressIndicator performSelectorOnMainThread:@selector(stopAnimation:) withObject:self waitUntilDone:NO];
	[pool release];
}

#pragma mark -- Tag Editing

- (void)setAlbumFields
{
#define set(tfield, field) if (albumTags->field) [tfield setStringValue:albumTags->field];
    
	set(albumArtistField, artist);
	set(albumTitleField, title);
	set(albumComposerField, composer);
	set(albumGenreField, genre);
	if (albumTags->year) [albumYearField setIntValue:albumTags->year];
}

- (void)gatherAlbumTags
{
#define get(tfield, field) if (albumTags->field) [albumTags->field release]; albumTags->field = [[tfield stringValue] retain];
    
    get(albumArtistField, artist);
	get(albumTitleField, title);
	get(albumComposerField, composer);
	get(albumGenreField, genre);
    albumTags->year = [albumYearField intValue];
    [album recanonicalizeTags];
}

#pragma mark -- Image Choice

- (void)loadAlbumImages
{
    imagesThread = [[NSThread alloc] initWithTarget:self selector:@selector(loadAlbumImagesThread) object:nil];
    
    [imagesThread start];
}

- (void)loadAlbumImagesThread
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [progressIndicator performSelectorOnMainThread:@selector(startAnimation:) withObject:self waitUntilDone:NO];
    IIFileSource *fs = [album fileSource];
    NSArray *imageNames = [fs filesWithExtension:@".jpg" atTopLevel:NO];
    
    for (NSString *imageName in imageNames) {
        NSData *imageData = [fs dataFromFile:imageName];
        
        [imageNameArray addObject:imageName];
        [imageArray addObject:[[[NSImage alloc] initWithData:imageData] autorelease]];
        [imageChoiceView performSelectorOnMainThread:@selector(reloadData) withObject:self waitUntilDone:NO];
    }
    
    [progressIndicator performSelectorOnMainThread:@selector(stopAnimation:) withObject:self waitUntilDone:NO];
	[pool release];
}

- (NSUInteger) numberOfItemsInImageBrowser:(IKImageBrowserView *) aBrowser
{
	return [imageArray count];
}

- (id) imageBrowser:(IKImageBrowserView *) aBrowser itemAtIndex:(NSUInteger)index
{
	return [imageArray objectAtIndex:index];
}

- (void) imageBrowserSelectionDidChange:(IKImageBrowserView *) aBrowser
{
    NSIndexSet *is = [aBrowser selectionIndexes];
    
    if ([is count] == 0) [curImageView setImage:nil];
    else [curImageView setImage:[imageArray objectAtIndex:[is firstIndex]]];
}

#pragma mark -- Import

- (void)importIntoiTunes
{
    iTunesImportThread = [[NSThread alloc] initWithTarget:self selector:@selector(iTunesImportThread) object:nil];
    
    [iTunesImportThread start];
}

- (void)iTunesImportThread
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    iTunesApplication *iTunes = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
    NSMutableArray *ittracks = [NSMutableArray array];
    [progressIndicator performSelectorOnMainThread:@selector(startAnimation:) withObject:self waitUntilDone:NO];
    [iTunes setDelegate:self];
    
    // BOOL reencode = [album shouldReencode];
    //iTunesUserPlaylist *dbgPlaylist = [[[[iTunes sources] objectAtIndex:0] userPlaylists] objectWithName:@"itt"];
    NSImage *artwork = [curImageView image];
    
    for (TrackTags *tr in albumTags->tracks) {
        @try {
            NSString *path = [album pathToTrackWithID:tr->tid];
            iTunesTrack *nt = [iTunes add:[NSArray arrayWithObject:[NSURL fileURLWithPath:path isDirectory:NO]] to:nil];
            [ittracks addObject:nt];
            
            nt.album = albumTags->title;
            if ([tr->artist length] && [albumTags->artist length]) {
                nt.albumArtist = albumTags->artist;
                nt.artist = tr->artist;
            } else nt.artist = [tr->artist length]?tr->artist:albumTags->artist;
            
            if ([tr->comment length]) nt.comment = tr->comment;
            
            nt.composer = [tr->composer length] ? tr->composer : albumTags->composer;
            nt.discCount = nt.discNumber = 1;
            nt.genre = [tr->genre length] ? tr->genre : albumTags->genre;
            nt.name = tr->title;
            nt.trackNumber = tr->num;
            nt.trackCount = [albumTags->tracks count];
            if (tr->year) nt.year = tr->year;
            
            if (artwork) {
                // iTunesArtwork *art = [[nt artworks] objectAtIndex:0];
                //  art.data = artwork;
            }
            sleep(3);
        } @catch (NSException *e) {
            NSLog(@"ScriptingBridge errored: %@", [e reason]);
            NSLog(@"Continuing with next track.");
        }
    }
    
    [progressIndicator performSelectorOnMainThread:@selector(stopAnimation:) withObject:self waitUntilDone:NO];
	[pool release];
}
@end
