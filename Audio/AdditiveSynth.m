//
//  AdditiveSynth.m
//  SoundSynth
//
//  Created by Jeff Gregorio on 7/12/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import "AdditiveSynth.h"

@implementation AdditiveSynth

@synthesize f_0;
@synthesize n_h;
@synthesize enabled;

- (id)initWithSampleRate:(double)fs numHarmonics:(int)n {
    
    self = [super init];
    if (self) {
        f_s = fs;
        n_h = n;
        a_scale = 1.0f;
        f_0 = 440.0f;
        target_f_0 = f_0;
        f_0_step = 0.0f;
        a_h = (float *)calloc(n_h, sizeof(float));
        a_n = 0.0f;
        theta = 0.0f;
        thetaInc = 2.0f * M_PI * f_0 / f_s;
        envLength = 0;
        envIdx = 0;
        pthread_mutex_init(&envMutex, NULL);
        
        [self setUpWavetableWithLength:4096];
    }
    return self;
}

- (void)setUpWavetableWithLength:(int)length {
    
    wavetableLength = length;
    wavetable = (float *)malloc((wavetableLength + 1) * sizeof(float));
    for (int i = 0; i < wavetableLength; i++)
        wavetable[i] = sinf(((double)i/(double)wavetableLength) * M_PI * 2.0);
    wavetable[length] = wavetable[0];
}

- (float)wavetableLookup:(float)phase {
    
    int idx;
    if (phase >= 0)
        idx = (int)((float)wavetableLength * phase / (2*M_PI)) % wavetableLength;
    else
        idx = (int)((float)wavetableLength * phase / (2*M_PI)) % wavetableLength + wavetableLength;
    
    return wavetable[idx];
}
- (float)wavetableLookupInterp:(float)phase {
    
    float y0, y1, y;
    float x = (float)wavetableLength * phase / (2*M_PI);
    int x0 = (int)x;
    float f = x - x0;
    
    if (x0 >= 0) {
        x0 = x0 % wavetableLength;
        y0 = wavetable[x0];
        y1 = wavetable[x0+1];
        y = y0 + f * (y1-y0);
    }
    else {
        x0 = x0 % wavetableLength + wavetableLength;
        y0 = wavetable[x0];
        y1 = wavetable[x0-1];
        y = y0 - f * (y1-y0);
    }
    
    return y;
}

- (void)setNumHarmonics:(int)n {
    
    n_h = n;
    
    if (a_h)
        free(a_h);
    
    a_h = (float *)calloc(n_h, sizeof(float));
}

- (void)setAmplitudeScalar:(float)amp {
    target_a_scale = amp;
    a_scale_step = (target_a_scale - a_scale) / (0.01 * f_s);
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

- (void)setAmplitude:(float)amp forHarmonic:(int)n {
    
    if (n >= n_h) {
        NSLog(@"%s: Invalid harmonic number %d. Synth has %d harmonics", __PRETTY_FUNCTION__, n, n_h);
        return;
    }
    
    a_h[n] = amp;
}

- (float)getAmplitudeForHarmonic:(int)n {
    return a_h[n];
}

- (float)getNoiseAmplitude {
    return a_n;
}

- (void)setNoiseAmplitude:(float)amp {
    a_n = amp;
}

- (void)setAmplitudeEnvelope:(float *)amp length:(int)len {
    
    pthread_mutex_lock(&envMutex);
    
    if (env)
        free(env);
    
    envLength = len;
    env = (float *)malloc(envLength * sizeof(float));
    memcpy(env, amp, envLength * sizeof(float));
    
    envIdx = 0;
    envAmp = 0;
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
    envAmp = 0;
    pthread_mutex_unlock(&envMutex);
}

- (void)retriggerAmplitudeEnvelope {
    if (!env)
        return;
    if (envIdx < 0)
        return;
    envAmpStep = (env[0] - env[envIdx]) / (kSynthEnvRetriggerRampTime * f_s);
    envIdx = -1;
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

/* Render a buffer of audio via additive synthesis. Return the index in the buffer of the first phase zero for waveform stabilization when plotting */
- (int)renderOutputBufferMono:(float *)buffer outNumberFrames:(int)nFrames {
    
    int phaseZeroIdx = -1;
    
    pthread_mutex_lock(&envMutex);
    
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
        
        /* Noise */
//        buffer[i] = 8.0f * a_n * [self generateAWGN];
        buffer[i] = a_n * 20.0f * (((rand()-RAND_MAX/2.0f) / (float)RAND_MAX));
        
        /* Harmonics */
        for (int n = 0; n < n_h; n++) {
            
            /* Synthesize any harmonics under 20kHz */
            if (f_0 * (n+1) < 20000.0)
                buffer[i] += a_h[n] * [self wavetableLookup:(n+1) * theta];
        }
        
        if (env) {
            
            if (envIdx < 0) {
                if ((envAmpStep > 0 && envAmp < env[0]) || (envAmpStep < 0 && envAmp > env[0])) {
                    envAmp += envAmpStep;
                }
                else envIdx = 0;
            }
            else {
                envAmp = env[envIdx];
                envIdx++;
                if (envIdx >= (envLength-1))
                    envIdx = -1;
            }
            
            /* Envelope */
            buffer[i] *= envAmp;
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

@end















