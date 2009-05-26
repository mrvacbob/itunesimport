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

/*
 
 -(void)setupEncodingView
 {
 if(!encodingview)
 {
 NSNib *nib=[[[NSNib alloc] initWithNibNamed:@"EncodingView" bundle:nil] autorelease];
 [nib instantiateNibWithOwner:self topLevelObjects:nil];
 }
 
 NSImage *icon=[[NSWorkspace sharedWorkspace] iconForFile:archivename];
 [icon setSize:[encodingicon frame].size];
 [encodingicon setImage:icon];
 
 [encodingpopup buildEncodingListMatchingBytes:name_bytes];
 if(selected_encoding)
 {
 int index=[encodingpopup indexOfItemWithTag:selected_encoding];
 if(index>=0) [encodingpopup selectItemAtIndex:index];
 else [encodingpopup selectItemAtIndex:[encodingpopup indexOfItemWithTag:NSISOLatin1StringEncoding]];
 }
 
 [self selectEncoding:self];
 
 [self setDisplayedView:encodingview];
 }
 
 */
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
		if (!imageData) continue;
		NSImage *image = [[[NSImage alloc] initWithData:imageData] autorelease];
        if (!image) continue;
		
        [imageNameArray addObject:imageName];
        [imageArray addObject:image];
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
	iTunesLibraryPlaylist *library = [[[[iTunes sources] objectAtIndex:0] libraryPlaylists] objectAtIndex:0];
    NSMutableArray *ittracks = [NSMutableArray array];
    [progressIndicator performSelectorOnMainThread:@selector(startAnimation:) withObject:self waitUntilDone:NO];
    [iTunes setDelegate:self];
    
    BOOL reencode = [album shouldReencode], success;
    //iTunesUserPlaylist *dbgPlaylist = [[[[iTunes sources] objectAtIndex:0] userPlaylists] objectWithName:@"itt"];
    NSImage *artwork = [curImageView image];
    
#define settag(d, s) do {@try {success = true; nt.d = s;} @catch (NSException *e) {success = false; NSLog(@"ScriptingBridge failed setting %s for track %d", # d, tr->tid); sleep(2);}} while (!success);
	
    for (TrackTags *tr in albumTags->tracks) {
		NSLog(@"importing track %d \"%@\"",tr->tid,tr->title);
		NSString *path = [album pathToTrackWithID:tr->tid];
		iTunesTrack *nt = [iTunes add:[NSArray arrayWithObject:[NSURL fileURLWithPath:path isDirectory:NO]] to:nil];
		if (!nt) {
			NSLog(@"iTunes didn't want to add \"%@\"", path);
			continue;
		}
		[ittracks addObject:nt];
		
		settag(album, albumTags->title);
		if ([tr->artist length] && [albumTags->artist length]) {
			settag(albumArtist, albumTags->artist);
			settag(artist, tr->artist);
		} else settag(artist, [tr->artist length]?tr->artist:albumTags->artist);
		
		if ([tr->comment length]) settag(comment, tr->comment);
		
		settag(composer, [tr->composer length] ? tr->composer : albumTags->composer);
		settag(discCount, 1);
		settag(discNumber, 1);
		settag(genre, [tr->genre length] ? tr->genre : albumTags->genre);
		settag(name, tr->title);
		settag(trackNumber, tr->num);
		settag(trackCount, [albumTags->tracks count]);
		if (tr->year) settag(year, tr->year);
		
		if (artwork) {
			// iTunesArtwork *art = [[nt artworks] objectAtIndex:0];
			//  art.data = artwork;
		}
    }
    
	if (reencode) {
		@try {[iTunes convert:ittracks];} @catch (NSException *e) {NSLog(@"ScriptingBridge failed converting tracks. %@"); sleep(2);}
		for (iTunesTrack *tr in ittracks) {@try {[[library tracks] removeObject:tr];} @catch (NSException *e) {NSLog(@"ScriptingBridge failed removing original track"); sleep(2);}}
	}
	
    [progressIndicator performSelectorOnMainThread:@selector(stopAnimation:) withObject:self waitUntilDone:NO];
	[pool release];
}
@end
