/*
 *  CueParsing.m.h
 *  iTunesImport
 *
 *  Created by Alexander Strange on 2/3/08.
 *
 */

#import <Cocoa/Cocoa.h>

extern UInt32 ParseCuesheetTime(NSString *time);
extern void GetTrackStartLen(NSArray *tracks, UInt32 albumLen, int track, UInt32 *start, UInt32 *len);
extern NSDictionary *ParseCuesheet(NSString *cueSheet);
extern unsigned CountCuesheetTags(NSDictionary *cue);