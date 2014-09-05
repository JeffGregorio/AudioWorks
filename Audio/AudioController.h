//
//  AudioController.h
//  DigitalSoundFX
//
//  Created by Jeff Gregorio on 5/11/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

/* ===== Scope/Bus use in I/O units (Adamson, Chris. "Learning Core Audio" Table 8.1) ===== */
/* ---------------------------------------------------------------------------------------- */
/* Scope        Bus         Semantics                                           Access      */
/* ---------------------------------------------------------------------------------------- */
/* Input        1 (in)      Input from hardware to I/O unit                     Read-only   */
/* Output       1 (in)      Output from I/O unit to program or other units      Read/write  */
/* Input        0 (out)     Input to I/O unit from program or other units       Read/write  */
/* Output       0 (out)     Output from I/O unit to hardware                    Read-only   */
/* ---------------------------------------------------------------------------------------- */

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVAudioSession.h>
#import <pthread.h>

#import "NVDSP.h"
#import "NVBandpassFilter.h"
#import "NVHighPassFilter.h"
#import "NVLowpassFilter.h"

#import "CircularBuffer.h"

#define kAudioSampleRate 44100.0
#define kAudioBufferSize 1024
#define kFFTSize kAudioBufferSize

#define kMaxDelayTime 2.0f
#define kModFreqRampDuration 0.1f

#pragma mark -
#pragma mark AudioController
@interface AudioController : NSObject {
    
@public
    
    /* Recording buffers */
    Float32 *inputBuffer;               // Pre-processing
    pthread_mutex_t inputBufferMutex;
    Float32 *outputBuffer;              // Post-processing
    pthread_mutex_t outputBufferMutex;
    
    /* Alternate recording buffers */
    
    Float32 *spectrumBuffer;                // Spectrum
    Float32 *outputSpectrumBuffer;
    pthread_mutex_t spectrumBufferMutex;
    int windowSize;
    FFTSetup fftSetup;
    float *inRealBuffer;
    float *outRealBuffer;
    float *window;
    float fftScale;
    COMPLEX_SPLIT splitBuffer;
    
    /* Ring Mod */
    float modFreq;          // Current modulation frequency
    float targetModFreq;    // Target value for parameter ramp
    float modFreqStep;      // Per-sample ramp value to reach target mod freq
    float modTheta;
    float modThetaInc;
    Float32 *modulationBuffer;                  // Modulation signal buffer
    pthread_mutex_t modulationBufferMutex;
    
    /* Filters */
    NVLowpassFilter *lpf;
    NVHighpassFilter *hpf;
    
    /* Distortion */
    Float32 clippingAmplitude;
    
    /* Delay */
    CircularBuffer *circularBuffer;         // Delay buffer
    pthread_mutex_t circularBufferMutex;
    Float32 tapGains[kMaxNumDelayTaps];
    
    bool inputWasEnabled, outputWasEnabled; // Pre-interruption flags
}

/* These are only of interest internally, but must be accessible publicly by the audio callback, which must be a non-member C method because Core Audio sucks */
@property (readonly) AudioUnit ioUnit;
@property (readonly) AudioBufferList *bufferList;

@property (readonly) AVAudioSession *audioSession;      /* Use to query sample rate, buffer
                                                         length (seconds), number of
                                                         input/output channels, etc. */

@property (readonly) double sampleRate;         // Audio sampling rate
@property (readonly) int bufferSizeFrames;      // Buffer length in samples
@property (readonly) Float32 inputGain;
@property Float32 outputGain;

@property (readonly) int recordingBufferLengthFrames;
@property (readonly) int fftSize;
@property (readonly) int nFFTFrames;

@property (readonly) bool inputEnabled;
@property bool outputEnabled;
@property bool distortionEnabled;
@property bool hpfEnabled;
@property bool lpfEnabled;
@property bool modulationEnabled;
@property bool delayEnabled;

/* Enable/disable audio input */
- (bool)setInputEnabled: (bool)enabled;
- (bool)setInputGain:(Float32)gain;

- (bool)setSampleRate:(double)sampleRate;
- (bool)setBufferSizeFrames:(int)bufferSizeFrames;

/* Append to and read most recent data from the internal buffers */
- (void)appendInputBuffer:(Float32 *)inBuffer withLength:(int)length;
- (void)appendOutputBuffer:(Float32 *)inBuffer withLength:(int)length;
- (void)getInputBuffer:(Float32 *)outBuffer withLength:(int)length;
- (void)getInputBuffer:(Float32 *)outBuffer from:(int)startIdx to:(int)endIdx;
- (void)getOutputBuffer:(Float32 *)outBuffer withLength:(int)length;
- (void)getOutputBuffer:(Float32 *)outBuffer from:(int)startIdx to:(int)endIdx;
- (void)getAverageSpectrum:(Float32 *)outBuffer from:(int)startIdx to:(int)endIdx;
- (void)getAverageOutputSpectrum:(Float32 *)outBuffer from:(int)startIdx to:(int)endIdx;
- (void)getModulationBuffer:(Float32 *)outBuffer withLength:(int)length;
- (void)computeFFTs;

/* Setters */
- (void)rescaleFilters:(float)minFreq max:(float)maxFreq;
- (void)setModFrequency:(float)freq;

@end
