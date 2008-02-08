//
//  IIAssistantController.h
//  iTunesImport
//
//  Created by Alexander Strange on 1/25/08.
//  Copyright __MyCompanyName__ 2008. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IIAlbum.h"

@interface IIAssistantController : NSObject {
	IBOutlet NSWindow *assistantWindow;
	IBOutlet NSTabView *assistantTabView;
    IBOutlet NSButton *nextButton;

    IBOutlet NSTextField *chooseAlbumField;
	IBOutlet NSTextField *albumTypeLabel;
	
	IBOutlet NSProgressIndicator *parsingProgressIndicator;
	
	// --
	
	IBOutlet NSTextField *albumArtistField;
	IBOutlet NSTextField *albumTitleField;
	IBOutlet NSTextField *albumComposerField;

	NSThread *parsingThread;
	IIAlbum *album;
}
- (IBAction)advance:(id)sender;

- (IBAction)chooseAlbum:(id)sender;
- (void)chooseAlbumPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void*)contextInfo;
- (IBAction)albumChosen:(id)sender;
- (void)validateAlbum;
@end
