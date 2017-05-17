//
//  MIDIController.h
//  AudioWorks
//
//  Created by Jeff Gregorio on 7/8/16.
//  Copyright © 2016 Jeff Gregorio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

@class AppDelegate;

#pragma mark - MIDIHandler
@protocol MIDIHandler <NSObject>
@optional
- (void)handleDeviceChange:(int)numDevices;
- (void)handleNoteOff:(int)noteNum;
- (void)handleNoteOn:(int)noteNum velocity:(int)vel;
- (void)handleCC:(int)synt value:(int)val;
- (void)handleProgramChange:(int)val;
- (void)handleChannelAftertouch:(int)val;
- (void)handlePitchBend:(float)normVal;
@end

#pragma mark - MIDIController
@interface MIDIController : NSObject {
    
    AppDelegate *appDelegate;

    MIDIClientRef midiClient;
    MIDIPortRef inputPort;
}

- (id)initWithHandler:(id<MIDIHandler>)pHandler;
- (void)openPorts;

@property id <MIDIHandler> handler;

@end