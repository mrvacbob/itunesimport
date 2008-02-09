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

@implementation IIAssistantController
- (IBAction)advance:(id)sender
{
	[nextButton setEnabled:NO];
	[assistantTabView selectNextTabViewItem:self];
	
	if ([assistantTabView indexOfTabViewItem:[assistantTabView selectedTabViewItem]] == 1) {
		if (!albumTags) {albumTags = [album tags]; [self setAlbumFields];}
	}
}

- (void)awakeFromNib
{
	parsingThread = nil;
	album = nil;
	albumTags = nil;
	[assistantWindow setTitle:@"iTunes Importer"];
	[albumTrackTable setColumnAutoresizingStyle:NSTableViewReverseSequentialColumnAutoresizingStyle];
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
	parsingThread = [[NSThread alloc] initWithTarget:self selector:@selector(validateAlbum) object:nil];
	
	[parsingThread start];
}

- (IBAction)albumChosen:(id)sender
{
	NSString *name = [chooseAlbumField stringValue];
	
	if ([name isValidFilename]) {
		[self validateAlbumOnThread];
	}
}

- (void)validateAlbum
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[parsingProgressIndicator performSelectorOnMainThread:@selector(startAnimation:) withObject:self waitUntilDone:NO];
	if (album) [album release];
	album = [GetAlbumForFileSource(GetFileSourceForPath([chooseAlbumField stringValue])) retain];
	NSString *desc = [album description];

	[albumTypeLabel performSelectorOnMainThread:@selector(setStringValue:) withObject:desc?desc:@"none?" waitUntilDone:NO];
	[nextButton setEnabled:desc ? YES : NO];
	[parsingProgressIndicator performSelectorOnMainThread:@selector(stopAnimation:) withObject:self waitUntilDone:NO];
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

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [album trackCount];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{	
	TrackTags *tt = [albumTags->tracks objectAtIndex:row];
	NSString *c = [tableColumn identifier];
	
	if ([c isEqualToString:@"Number"]) return [NSNumber numberWithUnsignedInt:tt->num];
	else if ([c isEqualToString:@"Title"]) return tt->title;
	else if ([c isEqualToString:@"Artist"]) return tt->artist;
	else if ([c isEqualToString:@"Composer"]) return tt->composer;
	else if ([c isEqualToString:@"Genre"]) return tt->genre;

	return nil;
}
@end
