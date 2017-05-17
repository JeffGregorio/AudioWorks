//
//  CircularBuffer.m
//  DigitalSoundFX
//
//  Created by Jeff Gregorio on 6/24/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import "CircularBuffer.h"

#define min(a, b) (((a) < (b)) ? (a) : (b))

@implementation CircularBuffer

@synthesize nTaps;

/* Allocate the buffer with a specified length */
- (id)initWithLength:(int)length sampleRate:(Float32)rate {
    
    self = [super init];
    if (self) {
    
        if (buffer)
            free(buffer);
        
        sampleRate = rate;
        bufferLength = length;
        buffer = (Float32 *)calloc(bufferLength, sizeof(Float32));
        writeIdx = 0;
        nTaps = 0;
        
        for (int i = 0; i < kMaxNumDelayTaps; i++) {
            delayTimes[i] = targetDelayTimes[i] = delayTimeSteps[i] = 0.0;
        }
    }
    
    return self;
}

- (void)addDelayTapWithDelayTime:(Float32)time gain:(Float32)amp {
    
    if (nTaps == kMaxNumDelayTaps) {
        NSLog(@"Warning: Maximum %d delay taps allowed", kMaxNumDelayTaps);
        return;
    }
    
    delayTimes[nTaps] = targetDelayTimes[nTaps] = time;
    delayTimeSteps[nTaps] = 0.0;
    
    tapGains[nTaps] = targetTapGains[nTaps] = amp;
    tapGainSteps[nTaps] = 0.0;
    
    nTaps++;
    
    NSLog(@"%s : time = %f, gain = %f, n = %d", __PRETTY_FUNCTION__, time, amp, nTaps);
}

- (void)removeDelayTapAtIndex:(int)tapIdx {
    
    if (tapIdx < 0 && tapIdx >= kMaxNumDelayTaps) {
        NSLog(@"Warning: Invalid tap index %d (nTaps = %d)", tapIdx, nTaps);
        return;
    }
    
    for (int i = tapIdx; i < nTaps; i++) {
        delayTimes[i] = delayTimes[i+1];
        targetDelayTimes[i] = targetDelayTimes[i+1];
        delayTimeSteps[i] = delayTimeSteps[i+1];
        tapGains[i] = tapGains[i+1];
        targetTapGains[i] = targetTapGains[i+1];
        tapGainSteps[i] = tapGainSteps[i+1];
    }
    nTaps--;
}

- (void)setDelayTimeForTap:(int)tapIdx delayTime:(Float32)time {
    
    if (tapIdx < 0 && tapIdx >= kMaxNumDelayTaps) {
        NSLog(@"Warning: Invalid tap index %d (nTaps = %d)", tapIdx, nTaps);
        return;
    }
    
    targetDelayTimes[tapIdx] = time;
    delayTimeSteps[tapIdx] = (targetDelayTimes[tapIdx] - delayTimes[tapIdx]) / (kDelayTimeRampTime * sampleRate);
}

- (Float32)getDelayTimeForTap:(int)tapIdx {
    
    Float32 time = -1.0;
    
    if (tapIdx < 0 && tapIdx >= kMaxNumDelayTaps) {
        NSLog(@"Warning: Invalid tap index %d (nTaps = %d)", tapIdx, nTaps);
        return time;
    }
    
    return delayTimes[tapIdx];
}

- (void)setGainForTap:(int)tapIdx gain:(Float32)gain {
    
    if (tapIdx < 0 && tapIdx >= kMaxNumDelayTaps) {
        NSLog(@"Warning: Invalid tap index %d (nTaps = %d)", tapIdx, nTaps);
        return;
    }
    
    targetTapGains[tapIdx] = gain;
    tapGainSteps[tapIdx] = (targetTapGains[tapIdx] - tapGains[tapIdx]) / (kDelayTapGainRampTime * sampleRate);
}

/* Write data to the circular buffer */
- (void)writeDataWithLength:(int)length inData:(Float32 *)data {
    
    /* Write the incoming samples */
    for (int i = 0; i < length; i++) {
        
        buffer[writeIdx] = data[i];
        
        writeIdx++;
        if (writeIdx >= bufferLength)
            writeIdx = 0;
    }
    
    /* Ramp the delay time/gain parameters if needed */
    for (int i = 0; i < nTaps; i++) {
        if ((delayTimeSteps[i] > 0.0 && delayTimes[i] < targetDelayTimes[i]) ||
            (delayTimeSteps[i] < 0.0 && delayTimes[i] > targetDelayTimes[i])) {
            delayTimes[i] += delayTimeSteps[i] * length;
        }
        if ((tapGainSteps[i] > 0.0 && tapGains[i] < targetTapGains[i]) ||
            (tapGainSteps[i] < 0.0 && tapGains[i] > targetTapGains[i])) {
            tapGains[i] += tapGainSteps[i] * length;
        }
    }
}

/* Read data starting from the delay tap index */
- (void)readFromDelayTap:(int)tapIdx withLength:(int)length outData:(Float32 *)data {
    
    if (tapIdx < 0 && tapIdx >= kMaxNumDelayTaps) {
        NSLog(@"Warning: Invalid tap index %d (nTaps = %d)", tapIdx, nTaps);
        return;
    }
    
    Float32 delayIdx = writeIdx - delayTimes[tapIdx] * sampleRate;
    if (delayIdx < 0) delayIdx += bufferLength;
    
    for (int i = 0; i < length; i++) {

//        data[i] = buffer[(int)delayIdx];
        data[i] = [self interpolateBuffer:delayIdx];
        
        delayIdx++;
        if (delayIdx >= bufferLength-1)
            delayIdx -= bufferLength;
    }
}

- (void)processInputBuffer:(Float32 *)ioBuffer length:(int)len {
    
    if (nTaps == 0)
        return;
    
    for (int i = 0; i < len; i += kDelayProcBufferSize) {
        
        /* Copy samples from I/O buffer into the internal processing buffer, and write those into the circular buffer */
        for (int j = 0; j < kDelayProcBufferSize; j++)
            delayProcBuffer[j] = ioBuffer[i+j];
        
        [self writeDataWithLength:kDelayProcBufferSize inData:delayProcBuffer];
        
        for (int tap = 0; tap < nTaps; tap++) {
            [self readFromDelayTap:tap withLength:kDelayProcBufferSize outData:delayProcBuffer];
            for (int j = 0; j < kDelayProcBufferSize; j++)
                ioBuffer[i+j] += delayProcBuffer[j] * tapGains[tap];
        }
    }
}

- (Float32)interpolateBuffer:(Float32)index {
    
    int x0 = (int)floorf(index);
    int x1 = x0+1;
    
    Float32 y0 = buffer[x0];
    Float32 y1 = buffer[x1];
    
    return y0 + (y1-y0)*((index - (Float32)x0));
}

@end















