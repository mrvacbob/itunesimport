/*
 *  CueParsing.m.h
 *  iTunesImport
 *
 *  Created by Alexander Strange on 2/3/08.
 *
 */

#import <Cocoa/Cocoa.h>

extern NSDictionary *ParseCuesheet(NSString *cueSheet);
extern unsigned CountCuesheetTags(NSDictionary *cue);