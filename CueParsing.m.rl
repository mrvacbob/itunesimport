/*
 *  CueParsing.m.rl
 *  iTunesImport
 *
 *  Created by Alexander Strange on 2/3/08.
 *  Copyright 2008 __MyCompanyName__. All rights reserved.
 *
 */

#import "CueParsing.h"
#import "Utilities.h"

%%machine Cuesheet;
%%write data;

extern unsigned CountCuesheetTags(NSDictionary *cue)
{
	unsigned tags = 0;
	
	tags += [cue count];
	NSArray *tracks = [cue objectForKey:@"Tracks"];
	
	for (NSDictionary *track in tracks) {
		tags += [track count];
	}
	
	return tags;
}

NSDictionary *ParseCuesheet(NSString *cueSheet)
{
	NSMutableDictionary *cue = [NSMutableDictionary dictionary], *track = nil;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	cueSheet = STStandardizeStringNewlines(cueSheet);
	NSMutableArray *tracks = [NSMutableArray array];
	NSString *str;
	NSString *key, *val;
	size_t cuelen = [cueSheet length];
	unichar cuedata[cuelen];
	
	[cueSheet getCharacters:cuedata];
	
	const unichar *p = cuedata, *pe = cuedata + cuelen, *strbegin = p;
	int cs=0, num;

	[cue setObject:tracks forKey:@"Tracks"];
#define send() [NSString stringWithCharacters:strbegin length:p-strbegin]

	%%{
		alphtype unsigned short;
		
		action sstart {strbegin = p;}
		action savestr {str = send();}
		action setkey {key = [send() capitalizedString];}
		action setval {val = send();}
		action addval {
			val = send();
			[cue setObject:[val stringByReplacingOccurrencesOfString:@"\"" withString:@""] forKey:key];
		}
		action addtrackval {
			val = send();
			NSLog(@"track val: %@", val);
			[track setObject:[val stringByReplacingOccurrencesOfString:@"\"" withString:@""] forKey:key];
		}
		action setnum {str = send(); num = [str intValue];}
		action newtrack {
			if (track) [tracks addObject:track];
			track = [NSMutableDictionary dictionary];
			[track setObject:str forKey:@"Track"];
		}
		action addtrackindex {
			val = send();
			[track setObject:val forKey:[NSString stringWithFormat:@"Index %0.2d", num]];
		}
		
		nl = "\n";
		str = any*;
		wschar = space | 0xa0;
		ws = wschar+;
		nonws = any - wschar;
		bom = 0xfeff;
		num = ('-'? [0-9]+) >sstart %setnum;
		
		topkey = "GENRE" | "DATE" | "DISCID" | "COMMENT" | "PERFORMER" | "TITLE"  | "SONGWRITER" | "FILE";
		value = (("\"" [^\"]* "\"") | ((any - (wschar|"\""|nl))+));
		topsetting = topkey >sstart %setkey ws value >sstart %addval (ws? str)?;
		toplevel = (ws? "REM"? ws? topsetting :> nl)*;
		
		tracknum = ws? "TRACK" ws num ws "AUDIO" ws? nl;
		trackkey = "TITLE" | "PERFORMER" | "SONGWRITER" | "PREGAP" | "POSTGAP";
		tracksetting = (ws? ((trackkey >sstart %setkey ws value >sstart %addtrackval) | ("INDEX" >sstart %setkey ws num ws value >sstart %addtrackindex)) (ws? str)?) :> nl;
		track = tracknum %newtrack :> tracksetting*;
		tracks = track*;
		
		main := bom? toplevel tracks;
	}%%
	
	%%write init;
	%%write exec;
	%%write eof;

	[pool release];
	return cue;
}