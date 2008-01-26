//
//  IIAssistantController.h
//  iTunesImport
//
//  Created by Alexander Strange on 1/25/08.
//  Copyright __MyCompanyName__ 2008. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface IIAssistantController : NSObject {
	IBOutlet NSWindow *assistantWindow;
	IBOutlet NSTabView *assistantTabView;
    IBOutlet NSButton *nextButton;

    IBOutlet NSTextField *chooseAlbumField;
	IBOutlet NSTextField *albumTypeLabel;
}
- (IBAction)advance:(id)sender;

- (IBAction)chooseAlbum:(id)sender;
- (void)chooseAlbumPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void*)contextInfo;
- (IBAction)albumChosen:(id)sender;
@end
