//
//  AdditiveSynth.h
//  SoundSynth
//
//  Created by Jeff Gregorio on 7/12/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <pthread.h>

#define kSynthFundamentalRampTime 0.1
#define kSynthEnvRetriggerRampTime 0.01

@interface AdditiveSynth : NSObject {
    
    double f_s;                 // Sampling rate
    int n_h;                    // Number of harmonics
    
    float a_scale;              // Current amplitude scalar
    float target_a_scale;       // Target amplitude scalar
    float a_scale_step;         // Ramp value (per sample) to add to amplitude scalar
    
    float f_0;                  // Current fundamental freq
    float target_f_0;           // Target fundamental freq
    float f_0_step;             // Ramp value (per sample) to add to fundamental
    
    float *a_h;                 // Harmonic amplitudes
    float a_n;                  // Noise amplitude
    float theta;                // Phase
    float thetaInc;             // Phase increment
    
    float *env;                 // Amplitude envelope
    int envLength;              // Length in samples of the amplitude envelope
    int envIdx;                 // Current index in the envelope
    float envAmp;               // Current amplitude envelope value
    float envAmpStep;           // Envelope retrigger ramp slope
    
    float *wavetable;
    int wavetableLength;
    
    pthread_mutex_t envMutex;
}

@property (readonly) float f_0;
@property (readonly) int n_h;
@property bool enabled;

- (id)initWithSampleRate:(double)fs numHarmonics:(int)n;
- (void)setNumHarmonics:(int)n;
- (void)setAmplitudeScalar:(float)amp;
- (void)setFundamental:(float)f0;
- (void)setFundamental:(float)f0 ramp:(bool)doRamp;
- (void)setAmplitude:(float)amp forHarmonic:(int)n;
- (float)getAmplitudeForHarmonic:(int)n;
- (float)getNoiseAmplitude;
- (void)setNoiseAmplitude:(float)amp;
- (void)setAmplitudeEnvelope:(float *)amp length:(int)len;
- (void)setAmplitudeEnvelopeCG:(CGFloat *)amp length:(int)len;
- (void)retriggerAmplitudeEnvelope;
- (void)resetAmplitudeEnvelope;
- (int)renderOutputBufferMono:(float *)buffer outNumberFrames:(int)nFrames;

- (float)wavetableLookup:(float)phase;
- (float)wavetableLookupInterp:(float)phase;

@end
