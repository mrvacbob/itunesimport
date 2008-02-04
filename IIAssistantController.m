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

- (IBAction)albumChosen:(id)sender
{
	NSString *name = [chooseAlbumField stringValue];
	
	if ([name isValidFilename]) {
		[self validateAlbum:name];
	}
}

- (void)validateAlbum:(in NSString*)name
{
	[parsingProgressIndicator performSelectorOnMainThread:@selector(startAnimation:) withObject:self waitUntilDone:NO];
	IIAlbum *album = GetAlbumForFileSource(GetFileSourceForPath(name));
	NSString *desc = [album description];

	[albumTypeLabel setStringValue:desc ? desc : @"none?"];
	[parsingProgressIndicator performSelectorOnMainThread:@selector(stopAnimation:) withObject:self waitUntilDone:NO];
}
@end
