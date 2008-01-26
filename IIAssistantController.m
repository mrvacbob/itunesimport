//
//  IIAssistantController.m
//  iTunesImport
//
//  Created by Alexander Strange on 1/25/08.
//  Copyright __MyCompanyName__ 2008. All rights reserved.
//

#import "IIAssistantController.h"
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
}

- (IBAction)albumChosen:(id)sender
{
	NSString *name = [chooseAlbumField stringValue];
	
	if (![name isValidFilename]) goto bad;
	
	[nextButton setEnabled:YES];
	return;
bad:
	[nextButton setEnabled:NO];
}
@end
