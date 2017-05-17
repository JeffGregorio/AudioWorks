//
//  MIDIController.m
//  AudioWorks
//
//  Created by Jeff Gregorio on 7/8/16.
//  Copyright © 2016 Jeff Gregorio. All rights reserved.
//

#import "MIDIController.h"
#import "AppDelegate.h"


/* Core MIDI error handler */
void checkError(OSStatus error, const char* task) {
    
    if(error == noErr) return;
    
    char errorString[20];
    *(UInt32 *)(errorString + 1) = CFSwapInt32BigToHost(error);
    if(isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])) {
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    }
    else
        sprintf(errorString, "%d", (int)error);
    
    NSLog(@"Error: %s (%s)\n", task, errorString);
    exit(1);
}

/* Notification process for a change in the number of available MIDI devices */
void midiDevicesChanged(const MIDINotification *message, void *refCon) {
    MIDIController *midiController = (__bridge MIDIController*)refCon;
    [midiController openPorts];
}

/* Main MIDI input handler */
void midiInputCallback(const MIDIPacketList *list, void *procRef, void *srcRef) {
    
    MIDIController *midiController = (__bridge MIDIController*)procRef;
    
    UInt16 nBytes;
    const MIDIPacket *packet = &list->packet[0]; //gets first packet in list
    
    for (int i = 0; i < list->numPackets; i++) {
        
        nBytes = packet->length; //number of bytes in a packet
        
        int status = packet->data[0];
        int noteNum, vel;
        int contNum, val;
        int lsb, msb;
        float normVal;
        
        switch (status & 0xF0) {
                
            case 0x90:
                
                noteNum = packet->data[1];
                vel = packet->data[2];
                
                if ([midiController handler] != nil) {
                    if (vel != 0) {
                        if ([[midiController handler] respondsToSelector:@selector(handleNoteOn:velocity:)])
                            [[midiController handler] handleNoteOn:noteNum velocity:vel];
                    }
                    else {
                        if ([[midiController handler] respondsToSelector:@selector(handleNoteOff:)])
                            [[midiController handler] handleNoteOff:noteNum];
                    }
                }
                break;
                
            case 0xB0:
                
                contNum = packet->data[1];
                val = packet->data[2];
                
                if ([midiController handler] &&
                    [[midiController handler] respondsToSelector:@selector(handleCC:value:)])
                        [[midiController handler] handleCC:contNum value:val];
                break;
                
            case 0xC0:
                
                val = packet->data[1];
                if ([midiController handler] &&
                    [[midiController handler] respondsToSelector:@selector(handleProgramChange:)])
                    [[midiController handler] handleProgramChange:val];
                break;
                
            case 0xD0:
                
                val = packet->data[1];
                if ([midiController handler] &&
                    [[midiController handler] respondsToSelector:@selector(handleChannelAftertouch:)])
                    [[midiController handler] handleChannelAftertouch:val];
                break;
                
            case 0xE0:
                
                lsb = packet->data[1];
                msb = packet->data[2];
                if ([midiController handler] &&
                    [[midiController handler] respondsToSelector:@selector(handlePitchBend:)]) {
                
                    val = (msb << 7) + lsb;
                    normVal = (float)2 * val / (powf(2, 14));   // [0, 2]
                    normVal -= 1.0;                             // [-1, 1]
                    [[midiController handler] handlePitchBend:normVal];
                }
                break;
                
            default:
                break;
        }
        
        packet = MIDIPacketNext(packet);
    }
}

@implementation MIDIController
@synthesize handler;

- (id)init {
    
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (id)initWithHandler:(id<MIDIHandler>)pHandler {
    
    handler = pHandler;
    
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (void)dealloc {
    
    if (inputPort)
        checkError(MIDIPortDispose(inputPort), "Couldn't dispose MIDI input port");
    
    if (midiClient)
        checkError(MIDIClientDispose(midiClient), "Couldn't dispose MIDI client");
}

- (void)setup {
    
    checkError(MIDIClientCreate(CFSTR("MIDI Client"),
                                midiDevicesChanged,
                                (__bridge_retained void *)self,
                                &midiClient),
               "Couldn't create MIDI client");
   
    checkError(MIDIInputPortCreate(midiClient,
                                   CFSTR("Input"),
                                   midiInputCallback,
                                   (__bridge_retained void *)self,
                                   &inputPort),
               "MIDI input port error");
    
    [self openPorts];
}

- (void)openPorts {
    
    unsigned long sourceCount = MIDIGetNumberOfSources();
    
    for (int i = 0; i < sourceCount; ++i) {
        
        MIDIEndpointRef endPoint = MIDIGetSource(i);
        CFStringRef endpointName = NULL;
        
        checkError(MIDIObjectGetStringProperty(endPoint, kMIDIPropertyName, &endpointName),
                   "String property not found");
        
        NSLog(@"%s: MIDI Device %s", __PRETTY_FUNCTION__, CFStringGetCStringPtr(endpointName, kCFStringEncodingMacRoman));
        
        checkError(MIDIPortConnectSource(inputPort, endPoint, NULL), "MIDI not connected");
    }
    
    if (handler && [handler respondsToSelector:@selector(handleDeviceChange:)])
        [handler handleDeviceChange:(int)sourceCount];
}


@end


