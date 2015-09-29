//
//  CircularBuffer.h
//  DigitalSoundFX
//
//  Created by Jeff Gregorio on 6/24/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kMaxNumDelayTaps 4
#define kDelayTimeRampTime 0.3f
#define kDelayTapGainRampTime 0.3f
#define kDelayProcBufferSize 64

@interface CircularBuffer : NSObject {
    
    Float32 sampleRate;
    Float32 *buffer;
    int bufferLength;
    int writeIdx;
    
    Float32 delayTimes[kMaxNumDelayTaps];
    Float32 targetDelayTimes[kMaxNumDelayTaps];
    Float32 delayTimeSteps[kMaxNumDelayTaps];
    
    Float32 tapGains[kMaxNumDelayTaps];
    Float32 targetTapGains[kMaxNumDelayTaps];
    Float32 tapGainSteps[kMaxNumDelayTaps];
    
    Float32 delayProcBuffer[kDelayProcBufferSize];
}

@property (readonly) int nTaps;

- (id)initWithLength:(int)length sampleRate:(Float32)sampleRate;
- (void)addDelayTapWithDelayTime:(Float32)time gain:(Float32)amp;
- (void)removeDelayTapAtIndex:(int)tapIdx;
- (void)setDelayTimeForTap:(int)tapIdx delayTime:(Float32)time;
- (void)setGainForTap:(int)tapIdx gain:(Float32)gain;
- (void)writeDataWithLength:(int)length inData:(Float32 *)data;
- (void)readFromDelayTap:(int)tapIdx withLength:(int)length outData:(Float32 *)data;
- (void)processInputBuffer:(Float32 *)ioBuffer length:(int)len;

@end
