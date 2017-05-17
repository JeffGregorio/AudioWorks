//
//  WavetableSynth.m
//  SoundSynth
//
//  Created by Jeff Gregorio on 7/14/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import "WavetableSynth.h"

@implementation WavetableSynth

@synthesize f_0;
@synthesize f_0_max;
@synthesize enabled;

- (id)initWithSampleRate:(double)fs maxFreq:(float)f0Max {
    
    self = [super init];
    if (self) {
        waveTableLength = 0;
        f_s = fs;
        a_scale = 1.0f;
        f_0 = 440.0f;
        f_0_max = f0Max;
        target_f_0 = f_0;
        f_0_step = 0.0f;
        theta = 0.0f;
        thetaInc = 2.0f * M_PI * f_0 / f_s;
        envLength = 0;
        envIdx = 0;
        
        lpf = [[NVLowpassFilter alloc] initWithSamplingRate:f_s];
        lpf.Q = 2.0;
        lpf.cornerFrequency = 10000.0;
        
        pthread_mutex_init(&envMutex, NULL);
        pthread_mutex_init(&waveTableMutex, NULL);
    }
    return self;
}

- (void)setWaveTable:(float *)table length:(int)len {
    
    pthread_mutex_lock(&waveTableMutex);
    
    if (waveTable)
        free(waveTable);
    
    waveTableLength = len;
    waveTable = (float *)calloc(waveTableLength, sizeof(float));
    memcpy(waveTable, table, waveTableLength * sizeof(float));
    
    waveTablePhases = (float *)malloc(waveTableLength * sizeof(float));
    [self linspace:0 max:2*M_PI numElements:waveTableLength array:waveTablePhases];
    
    theta = 0;
    waveTableIdx = 0;
    
    pthread_mutex_unlock(&waveTableMutex);
}

- (void)setWaveTableCG:(CGFloat *)table length:(int)len {
    
    pthread_mutex_lock(&waveTableMutex);
    
    if (waveTable)
        free(waveTable);
    
    waveTableLength = len;
    waveTable = (float *)calloc(waveTableLength, sizeof(float));
    for (int i = 0; i < waveTableLength; i++)
        waveTable[i] = (float)table[i];
    
    waveTablePhases = (float *)malloc(waveTableLength * sizeof(float));
    [self linspace:0 max:2*M_PI numElements:waveTableLength array:waveTablePhases];
    
    theta = 0;
    waveTableIdx = 0;
    
    pthread_mutex_unlock(&waveTableMutex);
}

- (void)setFundamental:(float)f0 {
    
    target_f_0 = f0;
    f_0_step = (target_f_0 - f_0) / (kSynthFundamentalRampTime * f_s);
}

- (void)setFundamental:(float)f0 ramp:(bool)doRamp {
    if (doRamp)
        [self setFundamental:f0];
    else {
        f_0 = target_f_0 = f0;
        f_0_step = 0.0;
        thetaInc = 2.0f * M_PI * f_0 / f_s;
    }
}

- (void)setAmplitudeScalar:(float)amp {
    target_a_scale = amp;
    a_scale_step = (target_a_scale - a_scale) / (0.01 * f_s);
}

- (void)setNoiseAmplitude:(float)amp {
    a_n = amp;
}

- (void)setAmplitudeEnvelope:(float *)amp length:(int)len {
    
    pthread_mutex_lock(&envMutex);
    
    if (env)
        free(env);
    
    envLength = len;
    env = (float *)calloc(envLength, sizeof(float));
    memcpy(env, amp, envLength * sizeof(float));
    
    envIdx = 0;
    pthread_mutex_unlock(&envMutex);
}

- (void)setAmplitudeEnvelopeCG:(CGFloat *)amp length:(int)len {
    
    pthread_mutex_lock(&envMutex);
    
    if (env)
        free(env);
    
    envLength = len;
    env = (float *)calloc(envLength, sizeof(float));
    for (int i = 0; i < envLength; i++)
        env[i] = (float)amp[i];
    
    envIdx = 0;
    pthread_mutex_unlock(&envMutex);
}

- (void)retriggerAmplitudeEnvelope {
    envIdx = 0;
}

- (void)resetAmplitudeEnvelope {
    
    pthread_mutex_lock(&envMutex);
    
    if (env) {
        free(env);
        env = NULL;
    }
    
    envLength = 0;
    envIdx = 0;
    
    pthread_mutex_unlock(&envMutex);
}

/* Render a buffer of audio via wavetable synthesis. Return the index in the buffer of the first phase zero for waveform stabilization when plotting */
- (int)renderOutputBufferMono:(float *)buffer outNumberFrames:(int)nFrames {
    
    if (!waveTable)
        return -1;
    
    int phaseZeroIdx = -1;
    
//    int previousIdx;
    
    pthread_mutex_lock(&envMutex);
    pthread_mutex_lock(&waveTableMutex);
    
    for (int i = 0; i < nFrames; i++) {
    
        /* Ramp the fundamental if needed */
        if ((f_0_step > 0 && f_0 < target_f_0) || (f_0_step < 0 && f_0 > target_f_0)) {
            f_0 += f_0_step;
            thetaInc = 2.0f * M_PI * f_0 / f_s;
        }
        
        /* Ramp the amplitude scalar if needed */
        if ((a_scale_step > 0 && a_scale < target_a_scale) ||
            (a_scale_step < 0 && a_scale > target_a_scale)) {
            a_scale += a_scale_step;
        }
        
//        /* Find the wavetable phases surrounding the query phase */
//        while (theta > waveTablePhases[waveTableIdx]) {
//            waveTableIdx++;
//            if (waveTableIdx >= waveTableLength)
//                waveTableIdx = 0;
//        }
//        previousIdx = waveTableIdx != 0 ? waveTableIdx-1 : waveTableLength-1;
        
        /* Noise */
        buffer[i] = 8.0f * a_n * [self generateAWGN];
        
        buffer[i] += waveTable[(int)roundf((theta / (2*M_PI)) * waveTableLength)];

        if (env) {
            /* Envelope */
            buffer[i] *= env[envIdx];
            
            envIdx++;
            if (envIdx >= (envLength-1))
                envIdx = 0;
        }
        
        buffer[i] *= a_scale;
        
        /* Update phase */
        theta += thetaInc;
        if (theta >= 2 * M_PI) {
            theta -= 2 * M_PI;
            if (phaseZeroIdx < 0) {
                phaseZeroIdx = i;
            }
        }
    }
    
    pthread_mutex_unlock(&envMutex);
    pthread_mutex_unlock(&waveTableMutex);
    
    /* Anti-aliasing filter */
    [lpf filterContiguousData:buffer numFrames:nFrames channel:0];
    
    return phaseZeroIdx;
}

/* Generates additive white Gaussian Noise samples from the standard normal distribution (borrowed from http://www.embeddedrelated.com/showcode/311.php) */
- (float)generateAWGN {
    
    float temp1;
    float temp2 = 0.0;
    float result;
    int p;
    
    p = 1;
    
    while( p > 0 ) {
        
        temp2 = (rand() / ((float)RAND_MAX));   /*  rand() function generates an
                                                 integer between 0 and  RAND_MAX,
                                                 which is defined in stdlib.h.
                                                 */
        // temp2 is >= (RAND_MAX / 2)
        if (temp2 == 0)
            p = 1;
        
        // temp2 is < (RAND_MAX / 2)
        else
            p = -1;
    }
    
    temp1 = cos((2.0 * (float)M_PI ) * rand() / ((float)RAND_MAX));
    result = sqrt(-2.0 * log(temp2)) * temp1;
    
    return result;
}

/* Generate a linearly-spaced set of indices for sampling an incoming waveform */
- (void)linspace:(float)minVal max:(float)maxVal numElements:(int)size array:(float*)array {
    
    float step = (maxVal - minVal) / (size - 1);
    array[0] = minVal;
    for (int i = 1; i < size-1; i++)
        array[i] = array[i-1] + step;
    
    array[size-1] = maxVal;
}

/* Linear inerpolation */
- (float)interpolatePoint:(float)x x0:(float)x0 y0:(float)y0 x1:(float)x1 y1:(float)y1 {
    
    return y0 + ((x-x0)*(y1-y0)) / (x1-x0);
}


@end
