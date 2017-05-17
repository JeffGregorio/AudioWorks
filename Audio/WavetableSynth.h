//
//  WavetableSynth.h
//  SoundSynth
//
//  Created by Jeff Gregorio on 7/14/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NVLowpassFilter.h"
#include <pthread.h>

#define kSynthFundamentalRampTime 0.1

@interface WavetableSynth : NSObject {
    
    int waveTableLength;
    int waveTableIdx;
    float *waveTable;
    float *waveTablePhases;
    
    NVLowpassFilter *lpf;       // Anti-aliaising filter
    
    double f_s;                 // Sampling rate
    
    float a_scale;              // Current amplitude scalar
    float target_a_scale;       // Target amplitude scalar
    float a_scale_step;         // Ramp value (per sample) to add to amplitude scalar
    
    float f_0;                  // Current fundamental freq
    float f_0_max;              // Maximum      fundamental freq
    float target_f_0;           // Target fundamental freq
    float f_0_step;             // Ramp value (per sample) to add to fundamental
    
    float a_n;                  // Noise amplitude
    float theta;                // Phase
    float thetaInc;             // Phase increment
    
    int envLength;              // Length in samples of the amplitude envelope
    int envIdx;                 // Current index in the envelope
    float *env;                 // Amplitude envelope
    
    pthread_mutex_t envMutex;
    pthread_mutex_t waveTableMutex;
}

@property (readonly) float f_0;
@property float f_0_max;
@property bool enabled;

- (id)initWithSampleRate:(double)fs maxFreq:(float)f0Max;
- (void)setWaveTable:(float *)table length:(int)len;
- (void)setWaveTableCG:(CGFloat *)table length:(int)len;
- (void)setFundamental:(float)f0;
- (void)setFundamental:(float)f0 ramp:(bool)doRamp;
- (void)setAmplitudeScalar:(float)amp;
- (void)setNoiseAmplitude:(float)amp;
- (void)setAmplitudeEnvelope:(float *)amp length:(int)len;
- (void)setAmplitudeEnvelopeCG:(CGFloat *)amp length:(int)len;
- (void)retriggerAmplitudeEnvelope;
- (void)resetAmplitudeEnvelope;
- (int)renderOutputBufferMono:(float *)buffer outNumberFrames:(int)nFrames;

@end
