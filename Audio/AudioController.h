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

//#import "Audiobus.h"
#import "NVDSP.h"
#import "NVBandpassFilter.h"
#import "NVHighPassFilter.h"
#import "NVLowpassFilter.h"

#import "CircularBuffer.h"
#import "AdditiveSynth.h"
#import "WavetableSynth.h"

#import "Constants.h"

#define kAudioSampleRate 44100.0
#define kAudioBufferSize 1024
#define kFFTSize (kAudioBufferSize)

#define kMaxDelayTime 4.0f
#define kModFreqRampDuration 0.1f
#define kFilterCutoffRampDuration 0.1f

#define kRecordingBufferLengthSeconds 3.0
#define kWavetablePadLength 10

@protocol AudioControllerDelegate;

#pragma mark - AudioController
@interface AudioController : NSObject {
    
@public
    
    /* Recording buffers */
    Float32 *preInputGainBuffer;                // Pre-processing
    pthread_mutex_t preInputGainBufferMutex;
    Float32 *inputBuffer;                       // Pre-processing (pre-gain applied)
    pthread_mutex_t inputBufferMutex;
    Float32 *outputBuffer;                      // Post-processing
    pthread_mutex_t outputBufferMutex;
    
    /* Processing buffers */
    int procBufferLength;
    Float32 *procBuffer;
    Float32 *delayTapOut;

    Float32 *procBuffer1;
    Float32 *procBuffer2;
    
    /* Visible time-bounds for offline procesing */
    Float32 tMin, tMax;
    
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
    float modAmp;
    float modTheta;
    float modThetaInc;
    Float32 *modulationBuffer;                  // Modulation signal buffer
    pthread_mutex_t modulationBufferMutex;
    
    /* Filters */
    float lpfTargetCutoff;
    float lpfCutoffStep;
    float hpfTargetCutoff;
    float hpfCutoffStep;
    NVLowpassFilter *lpf;
    NVHighpassFilter *hpf;
    
    /* Distortion */
    Float32 clippingAmplitude;
    Float32 clippingAmplitudeLow;
    Float32 clippingAmplitudeHigh;
    
    /* Delay */
    CircularBuffer *circularBuffer;         // Delay buffer
    pthread_mutex_t circularBufferMutex;
    
    /* Synthesis */
    bool synthWavetableEnabled;
    bool synthAdditiveEnabled;
    Float32 synthFundamental;
    AdditiveSynth *aSynth;
    WavetableSynth *wSynth;
    int phaseZeroOffset;
    
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
@property (readonly) bool modulationEnabled;
@property (readonly) bool distortionEnabled;
@property (readonly) bool hpfEnabled;
@property (readonly) bool lpfEnabled;
@property (readonly) bool delayEnabled;
@property bool outputEnabled;

@property bool synthEnabled;
@property bool effectsEnabled;
@property (readonly) bool synthWavetableEnabled;
@property (readonly) bool synthAdditiveEnabled;
@property (readonly) Float32 synthFundamental;
@property (readonly) int phaseZeroOffset;

@property float modAmp;
@property (readonly) float modFreq;

/* Enable/disable audio input */
- (void)startAudioSession;
- (void)stopAudioSession;
- (bool)setInputEnabled:(bool)enabled;
- (bool)setInputGain:(Float32)gain;

- (bool)setSampleRate:(double)sampleRate;
- (bool)setBufferSizeFrames:(int)bufferSizeFrames;
- (void)setVisibleRangeInSeconds:(float)min max:(float)max;

/* Append to and read most recent data from the internal buffers */
- (void)appendPreInputGainBuffer:(Float32 *)inBuffer withLength:(int)length;
- (void)appendInputBuffer:(Float32 *)inBuffer withLength:(int)length;
- (void)appendOutputBuffer:(Float32 *)inBuffer withLength:(int)length;
- (void)getInputBuffer:(Float32 *)outBuffer withLength:(int)length;
- (void)getInputBuffer:(Float32 *)outBuffer withLength:(int)length offset:(int)offset;
- (void)getInputBuffer:(Float32 *)outBuffer from:(int)startIdx to:(int)endIdx;
- (void)getOutputBuffer:(Float32 *)outBuffer withLength:(int)length;
- (void)getOutputBuffer:(Float32 *)outBuffer withLength:(int)length offset:(int)offset;
- (void)getOutputBuffer:(Float32 *)outBuffer from:(int)startIdx to:(int)endIdx;
- (void)getAverageSpectrum:(Float32 *)outBuffer from:(int)startIdx to:(int)endIdx;
- (void)getAverageOutputSpectrum:(Float32 *)outBuffer from:(int)startIdx to:(int)endIdx;
- (void)getModulationBuffer:(Float32 *)outBuffer withLength:(int)length;
- (void)computeFFTs;
- (CGFloat)getFFTMagnitudeAtFrequency:(CGFloat)freq;
- (CGFloat)getNoiseFloorMagnitude;

/* FX Parameters */
- (void)setLPFCutoff:(CGFloat)fc;
- (void)setHPFCutoff:(CGFloat)fc;
- (void)setLPFEnabled:(bool)enabled;
- (void)setHPFEnabled:(bool)enabled;
- (void)setModFrequency:(float)freq;
- (void)setModulationEnabled:(bool)enabled;
- (void)setClippingAmplitude:(Float32)amp;
- (void)setClippingAmplitudeLow:(Float32)amp;
- (void)setClippingAmplitudeHigh:(Float32)amp;
- (void)setDistortionEnabled:(bool)enabled;
- (void)setDelayEnabled:(bool)enabled;
- (void)addDelayTapWithDelayTime:(Float32)time gain:(Float32)amp;
- (int)getNumDelayTaps;
- (void)setDelayTap:(int)tapIdx time:(CGFloat)time amplitude:(CGFloat)amp;
- (void)removeDelayTap:(int)tapIdx;

/* Synth Parameters */
- (void)synthSetFundamental:(float)f0;
- (void)synthSetNumHarmonics:(int)num;
- (void)synthSetAmplitude:(float)amp forHarmonic:(int)num;
- (void)synthSetNoiseAmplitude:(float)amp;
- (void)synthSetAdditiveEnabled;
- (void)synthSetWavetableEnabled;
- (void)synthSetWavetable:(CGFloat *)wavetable length:(int)length;
- (void)synthSetAmplitudeEnvelope:(CGFloat *)env length:(int)length;
- (void)synthResetAmplitudeEnvelope;
- (float)synthGetAmplitudeForHarmonic:(int)num;
- (float)synthGetNoiseAmplitude;

/* Effects processing DSP */
- (void)processRecordingInputBufferOffline;
- (void)processInputBuffer:(Float32 *)procBuffer length:(int)inNumberFrames;

/* Synthesis DSP */
- (void)renderOutputBufferMono:(Float32 *)buffer outNumberFrames:(int)outNumFrames;

@end
