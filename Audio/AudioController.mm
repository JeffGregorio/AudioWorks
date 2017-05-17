//
//  AudioController.m
//  DigitalSoundFX
//
//  Created by Jeff Gregorio on 5/11/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import "AudioController.h"

/* Main render callback method */
static OSStatus processingCallback(void *inRefCon, // Reference to the calling object
                                 AudioUnitRenderActionFlags *ioActionFlags,
                                 const AudioTimeStamp 		*inTimeStamp,
                                 UInt32 					inBusNumber,
                                 UInt32 					inNumberFrames,
                                 AudioBufferList 			*ioData)
{
    OSStatus status;
    
	/* Cast void to AudioController input object */
	AudioController *controller = (__bridge AudioController *)inRefCon;
    
    /* Copy samples from input bus into the ioData (buffer to output) */
    status = AudioUnitRender(controller.ioUnit,
                             ioActionFlags,
                             inTimeStamp,
                             1, // Input bus
                             inNumberFrames,
                             ioData);
    if (status != noErr)
        printf("Error rendering from remote IO unit\n");
    
    /* Playback a recorded buffer */
    if (controller.recordedPlayback) {
        // If we have more than an audio buffer left
        if (controller.read_ptr + inNumberFrames < controller.recordingBufferLengthFrames) {
            memcpy(controller->procBuffer,
                   controller->playbackBuffer+controller.read_ptr,
                   sizeof(Float32) * inNumberFrames);
            controller.read_ptr += inNumberFrames;
            
            if ([controller playbackDelegate])
                [[controller playbackDelegate] playbackPositionChanged:controller.read_ptr / controller.sampleRate];
        }
        // Last partial audio buffer
        else {
            int i;
            for (i = 0; controller.read_ptr < controller.recordingBufferLengthFrames; i++, controller.read_ptr++)
                controller->procBuffer[i] = controller->playbackBuffer[controller.read_ptr];
            // Pad end with zeros
            while (i < inNumberFrames) {
                controller->procBuffer[i] = 0.0;
                i++;
            }
            
            if ([controller playbackDelegate])
                [[controller playbackDelegate] playbackEnded];
        }
    }
    /* Get input from the mic or from the synth */
    else {
        if (![controller synthEnabled])
            memcpy(controller->procBuffer, (Float32 *)ioData->mBuffers[0].mData, sizeof(Float32) * inNumberFrames);
        else
            [controller renderOutputBufferMono:controller->procBuffer outNumberFrames:inNumberFrames];
    }
    
    /* Apply the input gain to the input buffer */
    for (int i = 0; i < inNumberFrames; i++)
        controller->procBuffer[i] *= controller.inputGain;
    
    /* Append to audio playback buffer if not currently playing back */
    if (![controller recordedPlayback])
        [controller appendPlaybackBuffer:controller->procBuffer withLength:inNumberFrames];
    
    /* Set the pre-processing buffer with pre-gain applied */
    [controller appendInputBuffer:controller->procBuffer withLength:inNumberFrames];
    
    /* FX processing method */
    if ([controller effectsEnabled])
        [controller processInputBuffer:controller->procBuffer length:inNumberFrames];
    
    /* Update the playback wet buffer (for plotting) */
    if (controller.recordedPlayback) {
        int j = 0;
        for (int i = controller.read_ptr - inNumberFrames; i < controller.read_ptr; j++, i++) {
            controller->playbackWetBuffer[i] = controller->procBuffer[j];
        }
    }
    
    /* Update the stored output buffer (for plotting) */
    [controller appendOutputBuffer:controller->procBuffer withLength:inNumberFrames];
    
    /* Apply post-gain or mute */
    if (controller.outputEnabled) {
        for (int i = 0; i < inNumberFrames; i++)
            controller->procBuffer[i] *= controller.outputGain;
    }
    else {
        for (int i = 0; i < inNumberFrames; i++)
            controller->procBuffer[i] *= 0;
    }
    
    /* Copy the processing buffer into the left and right output channels */
    memcpy((Float32 *)ioData->mBuffers[0].mData, controller->procBuffer, inNumberFrames * sizeof(Float32));
    memcpy((Float32 *)ioData->mBuffers[1].mData, controller->procBuffer, inNumberFrames * sizeof(Float32));

    return status;
}

/* Interrupt handler to stop/start audio for incoming notifications/alarms/calls */
void interruptListener(void *inUserData, UInt32 inInterruptionState) {
    
    AudioController *controller = (__bridge AudioController *)inUserData;
    
    if (inInterruptionState == kAudioSessionBeginInterruption) {
        
        if (controller.inputEnabled) {
            [controller setInputEnabled:false];
            controller->inputWasEnabled = true;
        }
        
        if (controller.outputEnabled) {
            [controller setOutputEnabled:false];
            controller->outputWasEnabled = true;
        }
    }
    else if (inInterruptionState == kAudioSessionEndInterruption) {

        if (controller->inputWasEnabled)
            [controller setInputEnabled:true];
        if (controller->outputWasEnabled)
            [controller setOutputEnabled:true];
    }
}

#pragma mark - AudioController
@implementation AudioController

@synthesize playbackDelegate;

@synthesize ioUnit;
@synthesize bufferList;
@synthesize audioSession;

@synthesize sampleRate;
@synthesize bufferSizeFrames;
@synthesize inputGain;
@synthesize outputGain;

@synthesize recordingBufferLengthFrames;
@synthesize fftSize;
@synthesize nFFTFrames;

@synthesize inputEnabled;
@synthesize outputEnabled;
@synthesize recordedPlayback;
@synthesize read_ptr;

@synthesize effectsEnabled;
@synthesize distortionEnabled;
@synthesize hpfEnabled;
@synthesize lpfEnabled;
@synthesize modulationEnabled;
@synthesize delayEnabled;
@synthesize synthEnabled;
@synthesize phaseZeroOffset;
@synthesize synthFundamental;

@synthesize synthAdditiveEnabled;
@synthesize synthWavetableEnabled;

@synthesize modAmp;
@synthesize modFreq;

- (id)init {
    
    self = [super init];
    
    if (self) {
        
        /* Set flags */
        inputEnabled = inputWasEnabled = recordedPlayback = false;
        outputEnabled = outputWasEnabled = false;
        effectsEnabled = true;
        distortionEnabled = false;
        hpfEnabled = false;
        lpfEnabled = false;
        modulationEnabled = false;
        delayEnabled = false;
        
        /* Defaults */
        inputGain = 1.0f;
        outputGain = 1.0f;
        clippingAmplitude = 1.0f;
        clippingAmplitudeHigh = 1.0f;
        clippingAmplitudeLow = -1.0f;
    }
    
    return self;
}

- (void)dealloc {
    
    if (playbackBuffer)
        free(playbackBuffer);
    if (playbackWetBuffer)
        free(playbackWetBuffer);
    if (preInputGainBuffer)
        free(preInputGainBuffer);
    if (inputBuffer)
        free(inputBuffer);
    if (outputBuffer)
        free(outputBuffer);
    if (procBuffer)
        free(procBuffer);
    if (delayTapOut)
        free(delayTapOut);
    if (spectrumBuffer)
        free(spectrumBuffer);
    if (outputSpectrumBuffer)
        free(outputSpectrumBuffer);
    if (inRealBuffer)
        free(inRealBuffer);
    if (outRealBuffer)
        free(outRealBuffer);
    if (window)
        free(window);
    
    
    pthread_mutex_destroy(&inputBufferMutex);
    pthread_mutex_destroy(&outputBufferMutex);
    pthread_mutex_destroy(&spectrumBufferMutex);
}

/* Set up fancy new AVAudioSession API that replaces the old Core Audio AudioSession API */
- (void)setUpAudioSession {
    
    NSError* error = nil;
    
    audioSession = [AVAudioSession sharedInstance];
    
    /* Set the category and mode of the audio session */
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    [audioSession setMode:AVAudioSessionModeMeasurement error:&error];
    
    /* Set sample rate, buffer duration, and number of IO channels */
    [audioSession setPreferredSampleRate:kAudioSampleRate error:&error];
    [audioSession setPreferredIOBufferDuration:kAudioBufferSize/kAudioSampleRate error:&error];
    [audioSession setPreferredOutputNumberOfChannels:2 error:&error];
    [audioSession setPreferredInputNumberOfChannels:1 error:&error];
    
    /* Activate the audio session */
    [audioSession setActive:true error:&error];
    
    /* Get the sample rate */
    sampleRate = audioSession.sampleRate;
    
    /* Size of a single audio buffer in samples */
    bufferSizeFrames = (int)roundf(audioSession.sampleRate * audioSession.IOBufferDuration);
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"inputAvailable = %s", audioSession.inputAvailable ? "true" : "false");
    NSLog(@"maximumInputNumberOfChannels = %ld", (long)audioSession.maximumInputNumberOfChannels);
    NSLog(@"maximumOutputNumberOfChannels = %ld", (long)audioSession.maximumOutputNumberOfChannels);
    NSLog(@"audioSession.outputNumberOfChannels = %ld", (long)audioSession.outputNumberOfChannels);
    NSLog(@"audioSession.inputNumberOfChannels  = %ld", (long)audioSession.inputNumberOfChannels);
    NSLog(@"audioSession.sampleRate             = %f", audioSession.sampleRate);
    NSLog(@"audioSession.IOBufferDuration       = %f", audioSession.IOBufferDuration);
    NSLog(@"bufferSizeFrames                    = %d", (unsigned int)bufferSizeFrames);
}

/* Instantiate and set callback on the RemoteIO audio unit */
- (void)setUpIOUnit {
    
    OSStatus status;
    AudioUnitScope inputBus  = 1;
    AudioUnitScope outputBus = 0;
    UInt32 enableFlag = 1;
    
    /* --------------------------------- */
    /* == Instantiate a RemoteIO unit == */
    /* --------------------------------- */
    
    /* Create description of the Remote IO unit */
    AudioComponentDescription inputcd   = {0};
    inputcd.componentType               = kAudioUnitType_Output;
    inputcd.componentSubType            = kAudioUnitSubType_RemoteIO;
    inputcd.componentManufacturer       = kAudioUnitManufacturer_Apple;
    inputcd.componentFlags              = 0;
    inputcd.componentFlagsMask          = 0;
    
    /* Find the audio component from the description */
    AudioComponent comp = AudioComponentFindNext(NULL, &inputcd);
    if (comp == NULL) {
        NSLog(@"%s: Error getting RemoteIO unit", __PRETTY_FUNCTION__);
        return;
    }
    
    /* Create an instance of the remote IO unit from the audio componenet */
    status = AudioComponentInstanceNew(comp, &ioUnit);
    if (status != noErr) {
        [self printErrorMessage:@"AudioComponentInstanceNew[_inputUnit] failed" withStatus:status];
    }
    
    /* ------------------------- */
    /* == Enable input/output == */
    /* ------------------------- */
    
    status = AudioUnitSetProperty(ioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  inputBus,
                                  &enableFlag,
                                  sizeof(enableFlag));
    if (status != noErr) {
        [self printErrorMessage:@"Enable/disable input failed" withStatus:status];
    }
    
    status = AudioUnitSetProperty(ioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  outputBus,
                                  &enableFlag,
                                  sizeof(enableFlag));
    if (status != noErr) {
        [self printErrorMessage:@"Enable/disable input failed" withStatus:status];
    }
    
    /* ----------------------------------- */
    /* == Allocate audio stream buffers == */
    /* ----------------------------------- */
    
    /* Get the ASBD for the remote IO unit */
    UInt32 asbdSize = sizeof(AudioStreamBasicDescription);
    AudioStreamBasicDescription asbd = {0};
    AudioUnitGetProperty(ioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output,
                         inputBus,
                         &asbd,
                         &asbdSize);
    NSLog(@"ASBD for output scope, input bus:");
    [self printASBD:asbd];
    
    /* Allocate the audio buffer list */
    UInt32 propSize = offsetof(AudioBufferList, mBuffers[0]) + (sizeof(AudioBuffer) * asbd.mChannelsPerFrame);
    
    bufferList = (AudioBufferList *)malloc(propSize);
    bufferList->mNumberBuffers = asbd.mChannelsPerFrame;
    
    for (UInt32 i = 0; i < bufferList->mNumberBuffers; i++) {
        bufferList->mBuffers[i].mNumberChannels = 1;
        bufferList->mBuffers[i].mDataByteSize = bufferSizeFrames * sizeof(Float32);
        bufferList->mBuffers[i].mData = malloc(bufferSizeFrames * sizeof(Float32));
    }
    
    /* ---------------------- */
    /* == Set I/O callback == */
    /* ---------------------- */
    
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = processingCallback;
    callbackStruct.inputProcRefCon = (__bridge void*) self;
    
    status = AudioUnitSetProperty(ioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Input,
                                  outputBus,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    if (status != noErr) {
        [self printErrorMessage:@"AudioUnitSetProperty[kAudioUnitProperty_SetRenderCallback] failed" withStatus:status];
    }
    
    /* ---------------- */
    /* == Initialize == */
    /* ---------------- */
    
    status = AudioUnitInitialize(ioUnit);
    if (status != noErr) {
        [self printErrorMessage:@"AudioUnitInitialize[_inputUnit] failed" withStatus:status];
    }
}

- (void)allocateRecordingBuffersWithLength:(int)length {
    
    recordingBufferLengthFrames = length;
    tMin = 0.0f;
    tMax = (float)length / sampleRate;
    
    /* Recorded audio playback */
    if (playbackBuffer)
        free(playbackBuffer);
    playbackBuffer = (Float32 *)calloc(length, sizeof(Float32));
    
    if (playbackWetBuffer)
        free(playbackWetBuffer);
    playbackWetBuffer = (Float32 *)calloc(length, sizeof(Float32));
    
    /* Time-domain (pre-processing, pre-input gain) */
    if (preInputGainBuffer)
        free(preInputGainBuffer);
    
    preInputGainBuffer = (Float32 *)calloc(length, sizeof(Float32));
    pthread_mutex_init(&preInputGainBufferMutex, NULL);
    
    /* Time-domain (pre-processing) */
    if (inputBuffer)
        free(inputBuffer);
    
    inputBuffer  = (Float32 *)calloc(length, sizeof(Float32));
    pthread_mutex_init(&inputBufferMutex, NULL);
    
    /* Time-domain (post-processing) */
    if (outputBuffer)
        free(outputBuffer);
    
    outputBuffer = (Float32 *)calloc(length, sizeof(Float32));
    pthread_mutex_init(&outputBufferMutex, NULL);
    
    /* Frequency domain */
    if (spectrumBuffer)
        free(spectrumBuffer);
    
    fftSize = kFFTSize;
    fftScale = 2.0f / (float)(fftSize/2);
    nFFTFrames = ceil(recordingBufferLengthFrames / kFFTSize);
    
    spectrumBuffer = (Float32 *)calloc(nFFTFrames * fftSize/2, sizeof(Float32));
    outputSpectrumBuffer = (Float32 *)calloc(nFFTFrames * fftSize/2, sizeof(Float32));
    pthread_mutex_init(&spectrumBufferMutex, NULL);
    
    inRealBuffer = (float *)malloc(fftSize * sizeof(float));
    outRealBuffer = (float *)malloc(fftSize * sizeof(float));
    splitBuffer.realp = (float *)malloc(fftSize/2 * sizeof(float));
    splitBuffer.imagp = (float *)malloc(fftSize/2 * sizeof(float));
    
    fftSetup = vDSP_create_fftsetup(log2f(fftSize), FFT_RADIX2);
    
    windowSize = kFFTSize;
    window = (float *)calloc(windowSize, sizeof(float));
    vDSP_hann_window(window, windowSize, vDSP_HANN_NORM);
}

- (void)allocateProcessingBuffersWithLength:(int)length {
    
    procBufferLength = length;
    
    if (procBuffer) free(procBuffer);
    if (delayTapOut) free(delayTapOut);
    
    if (procBuffer1) free(procBuffer1);
    if (procBuffer2) free(procBuffer2);
    
    procBuffer = (Float32 *)calloc(procBufferLength, sizeof(Float32));
    delayTapOut = (Float32 *)calloc(procBufferLength, sizeof(Float32));
    
    procBuffer1 = (Float32 *)calloc(procBufferLength, sizeof(Float32));
    procBuffer2 = (Float32 *)calloc(procBufferLength, sizeof(Float32));
}

- (void)setUpFilters {
    
    hpf = [[NVHighpassFilter alloc] initWithSamplingRate:sampleRate];
    hpf.Q = 1.0;
    hpf.cornerFrequency = 1000.0;
    hpfTargetCutoff = hpf.cornerFrequency;
    hpfCutoffStep = 0.0;
    
    lpf = [[NVLowpassFilter alloc] initWithSamplingRate:sampleRate];
    lpf.Q = 1.0;
    lpf.cornerFrequency = 4000.0;
    lpfTargetCutoff = lpf.cornerFrequency;
    lpfCutoffStep = 0.0f;
}

- (void)setUpRingModulator {
    
    modFreq = targetModFreq = 440.0f;
    modFreqStep = 0.0f;
    modTheta = 0.0f;
    modThetaInc = 2.0 * M_PI * modFreq / sampleRate;
    
    if (!modulationBuffer)
        modulationBuffer = (Float32 *)malloc(bufferSizeFrames * sizeof(Float32));
    
    pthread_mutex_init(&modulationBufferMutex, NULL);
}

- (void)setUpDelay {

    circularBuffer = [[CircularBuffer alloc] initWithLength:(int)(sampleRate * kMaxDelayTime) sampleRate:sampleRate];

//    for (int i = 0; i < kMaxNumDelayTaps; i++) {
//        [circularBuffer addDelayTapWithDelayTime:0.0 gain:0.0];
////        tapGains[0] = targetTapGains[0] = tapGainSteps[0] = 0.0;
//    }
}

- (void)setUpSynthesis {
    
    /* Synthesis Setup */
    aSynth = [[AdditiveSynth alloc] initWithSampleRate:sampleRate numHarmonics:kNumHarmonics];
    synthEnabled = false;
    
    [aSynth setFundamental:440.0f];
    
    [aSynth setAmplitude:powf(10.0f, -6.0/20.0f) forHarmonic:0];
    for (int i = 1; i < kNumHarmonics; i++)
        [aSynth setAmplitude:0.0f forHarmonic:i];
    
    wSynth = [[WavetableSynth alloc] initWithSampleRate:sampleRate maxFreq:1000.0f];
    [wSynth setFundamental:440.0f];
}

#pragma mark - Interface Methods
/* Set up and start the audio session */
- (void)startAudioSession {
    
    [self setUpAudioSession];
    [self setUpIOUnit];
    [self allocateRecordingBuffersWithLength:(int)kRecordingBufferLengthSeconds * sampleRate];
    [self allocateProcessingBuffersWithLength:bufferSizeFrames];
    [self setUpFilters];
    [self setUpRingModulator];
    [self setUpDelay];
    [self setUpSynthesis];
    [self setInputEnabled:true];
    [self setOutputEnabled:true];
}

/* Cancel audio callback and tear down the audio session */
- (void)stopAudioSession {
    
    AudioOutputUnitStop(ioUnit);
    AudioUnitUninitialize(ioUnit);
    AudioComponentInstanceDispose(ioUnit);
}

/* Start/stop audio input */
- (bool)setInputEnabled:(bool)enabled {
    
    OSStatus status;
    
    if (enabled) {
        status = AudioOutputUnitStart(ioUnit);
        if (status != noErr) {
            [self printErrorMessage:@"AudioOutputUnitStart[_inputUnit] failed" withStatus:status];
        }
        else inputEnabled = true;
    }
    else {
        status = AudioOutputUnitStop(ioUnit);
        if (status != noErr) {
            [self printErrorMessage:@"AudioOutputUnitStop[_inputUnit] failed" withStatus:status];
        }
        else inputEnabled = false;
    }
    
    return status == noErr;
}

- (bool)setInputGain:(Float32)gain {
    
    inputGain = gain;
    
    if (!inputEnabled)
        [self processRecordingInputBufferOffline];
    
    return true;
}

#pragma mark ########## Active ############
- (void)startBufferPlayback:(Float32)t0 {
    recordedPlayback = true;
    read_ptr = recordingBufferLengthFrames - (kRecordingBufferLengthSeconds - t0) * sampleRate;
    read_ptr = read_ptr >= 0 ? read_ptr : 0;
}

- (bool)setSampleRate:(double)fs {
    
    bool success = false;
    NSError* error = nil;
    
    /* Set the preferred sample rate */
    success = [audioSession setPreferredSampleRate:fs error:&error];
    
    /* Get the actual sample rate */
    sampleRate = audioSession.sampleRate;
    
    return success;
}

- (bool)setBufferSizeFrames:(int)nFrames {
    
    bool success = false;
    NSError* error = nil;
    
    success = [audioSession setPreferredIOBufferDuration:nFrames/sampleRate error:&error];
    
    /* Get the actual buffer size */
    bufferSizeFrames = (int)roundf(audioSession.sampleRate * audioSession.IOBufferDuration);
    
    return success;
}

- (void)setVisibleRangeInSeconds:(float)min max:(float)max {
    tMin = min;
    tMax = max;
}

- (void)appendPlaybackBuffer:(Float32 *)inBuffer withLength:(int)length {
    
    /* Shift old values back */
    for (int i = 0; i < recordingBufferLengthFrames - length; i++)
        playbackBuffer[i] = playbackBuffer[i + length];
    
    /* Append new values to the front */
    for (int i = 0; i < length; i++)
        playbackBuffer[recordingBufferLengthFrames - (length-i)] = inBuffer[i];
}

/* We need to store audio input before applying pre-gain so we can do offline processing when input is paused */
- (void)appendPreInputGainBuffer:(Float32 *)inBuffer withLength:(int)length {
    
    pthread_mutex_lock(&preInputGainBufferMutex);
    
    /* Shift old values back */
    for (int i = 0; i < recordingBufferLengthFrames - length; i++)
        preInputGainBuffer[i] = preInputGainBuffer[i + length];
    
    /* Append new values to the front */
    for (int i = 0; i < length; i++)
        preInputGainBuffer[recordingBufferLengthFrames - (length-i)] = inBuffer[i];
    
    pthread_mutex_unlock(&preInputGainBufferMutex);
}

/* Internal pre/post processing buffer setters/getters */
- (void)appendInputBuffer:(Float32 *)inBuffer withLength:(int)length {
    
    pthread_mutex_lock(&inputBufferMutex);
    
    /* Shift old values back */
    for (int i = 0; i < recordingBufferLengthFrames - length; i++)
        inputBuffer[i] = inputBuffer[i + length];
    
    /* Append new values to the front */
    for (int i = 0; i < length; i++)
        inputBuffer[recordingBufferLengthFrames - (length-i)] = inBuffer[i];
    
    pthread_mutex_unlock(&inputBufferMutex);
    
//    /* In analysis mode, we want to be able to plot the averaged spectrum of the visible portion of the time domain input signal. Taking the FFT of each input buffer causes a visible lag between the input/output buffers when plotting both. Only take the FFT when we're in analysis mode (plotting input only). Also may need to lock the recording buffer to a multiple of the audio buffer size or FFT size */
//    
//    /* Take the FFT and add it to the spectrum buffer */
//    pthread_mutex_lock(&spectrumBufferMutex);
//    
//    float *fftBuffer = (float *)malloc(fftSize/2 * sizeof(float));
//    [self computeMagnitudeFFT:inBuffer inBufferLength:length outMagnitude:fftBuffer window:true];
//    
//    int specBufferLength = fftSize/2 * nFFTFrames;
//    
//    /* Shift the old values back */
//    for (int i = 0; i < specBufferLength - fftSize/2; i++)
//        spectrumBuffer[i] = spectrumBuffer[i + fftSize/2];
//    
//    /* Append the new values to the front */
//    for (int i = 0; i < fftSize/2; i++)
//        spectrumBuffer[specBufferLength - (fftSize/2-i)] = fftBuffer[i];
//    
//    free(fftBuffer);
//    
//    pthread_mutex_unlock(&spectrumBufferMutex);
}

- (void)computeFFTs {
    
    float *tdBuffer = (float *)calloc(bufferSizeFrames, sizeof(float));
    float *fdBuffer = (float *)calloc(fftSize/2, sizeof(float));
    
    pthread_mutex_lock(&spectrumBufferMutex);
    
    for (int t = 0; t < nFFTFrames; t++) {

        for (int i = 0; i < bufferSizeFrames; i++)
            tdBuffer[i] = inputBuffer[t*bufferSizeFrames+i];
        
        [self computeMagnitudeFFT:tdBuffer inBufferLength:bufferSizeFrames outMagnitude:fdBuffer window:true];
        
        for (int i = 0; i < fftSize/2; i++)
            spectrumBuffer[t*fftSize/2+i] = fdBuffer[i];
        
        for (int i = 0; i < bufferSizeFrames; i++)
            tdBuffer[i] = outputBuffer[t*bufferSizeFrames+i];
        
        [self computeMagnitudeFFT:tdBuffer inBufferLength:bufferSizeFrames outMagnitude:fdBuffer window:true];
        
        for (int i = 0; i < fftSize/2; i++)
            outputSpectrumBuffer[t*fftSize/2+i] = fdBuffer[i];
    }
    
    free(tdBuffer);
    free(fdBuffer);
    
    pthread_mutex_unlock(&spectrumBufferMutex);
}

- (CGFloat)getFFTMagnitudeAtFrequency:(CGFloat)freq {
    
    CGFloat step = (sampleRate / 2.0f) / (fftSize /2.0f - 1);
    CGFloat fidx = freq / step;
    int idx = floor(fidx);
    
    int width = 16;
    int low = idx - width/2;
    low = low < 0 ? 0 : low;
    int high = idx + width/2;
    high = high >= nFFTFrames * fftSize/2 ? nFFTFrames * fftSize/2 : high;
    
    return (CGFloat)[self getMax:spectrumBuffer from:low to:high];
}

- (Float32)getMax:(Float32 *)values from:(int)min to:(int)max {
    
    Float32 maxVal = values[min];
    for (int i = min+1; i <= max; i++)
        maxVal = (values[i] > maxVal) ? values[i] : maxVal;
    return maxVal;
}

- (CGFloat)getNoiseFloorMagnitude {
    
    CGFloat mag = 0.0;
    
    CGFloat freq = synthFundamental / 2.0f;
    CGFloat step = (sampleRate / 2.0f) / (fftSize /2.0f - 1);
    int idx;
    
    int n = 20;
    for (int i = 1; i <= n; i++) {
        idx = roundf(freq/step);
        mag += spectrumBuffer[idx-1] + spectrumBuffer[idx] + spectrumBuffer[idx+1];
    }
    mag /= 3*n;
    
    return mag;
}

- (void)appendOutputBuffer:(Float32 *)inBuffer withLength:(int)length {
    
    pthread_mutex_lock(&outputBufferMutex);
    
    /* Shift old values back */
    for (int i = 0; i < recordingBufferLengthFrames - length; i++)
        outputBuffer[i] = outputBuffer[i + length];
    
    /* Append new values to the front */
    for (int i = 0; i < length; i++)
        outputBuffer[recordingBufferLengthFrames - (length-i)] = inBuffer[i];
    
    pthread_mutex_unlock(&outputBufferMutex);
}

- (void)getPlaybackBuffer:(Float32 *)outBuffer from:(int)startIdx to:(int)endIdx {
    
    if (startIdx < 0 || endIdx >= recordingBufferLengthFrames || endIdx < startIdx)
        NSLog(@"%s: Invalid buffer indices", __PRETTY_FUNCTION__);
    
    int length = endIdx - startIdx;
    
    for (int i = 0, j = startIdx; i < length; i++, j++)
        outBuffer[i] = playbackBuffer[j];
}

- (void)getPlaybackWetBuffer:(Float32 *)outBuffer from:(int)startIdx to:(int)endIdx {
    
    if (startIdx < 0 || endIdx >= recordingBufferLengthFrames || endIdx < startIdx)
        NSLog(@"%s: Invalid buffer indices", __PRETTY_FUNCTION__);
    
    int length = endIdx - startIdx;
    
    for (int i = 0, j = startIdx; i < length; i++, j++)
        outBuffer[i] = playbackWetBuffer[j];
}

/* Get n = length most recent audio samples from the recording buffer */
- (void)getInputBuffer:(Float32 *)outBuffer withLength:(int)length {
    
    if (length >= recordingBufferLengthFrames)
        NSLog(@"%s: Invalid buffer length", __PRETTY_FUNCTION__);
    
    pthread_mutex_lock(&inputBufferMutex);
    for (int i = 0; i < length; i++)
        outBuffer[i] = inputBuffer[recordingBufferLengthFrames - (length-i)];
    pthread_mutex_unlock(&inputBufferMutex);
    
}

- (void)getInputBuffer:(Float32 *)outBuffer withLength:(int)length offset:(int)offset {
    pthread_mutex_lock(&inputBufferMutex);
    for (int i = 0; i < length; i++)
        outBuffer[i] = inputBuffer[recordingBufferLengthFrames - (length-i) + offset];
    pthread_mutex_unlock(&inputBufferMutex);
}

/* Get recorded audio samples in a specified range */
- (void)getInputBuffer:(Float32 *)outBuffer from:(int)startIdx to:(int)endIdx {
    
    if (startIdx < 0 || endIdx >= recordingBufferLengthFrames || endIdx < startIdx)
        NSLog(@"%s: Invalid buffer indices", __PRETTY_FUNCTION__);
    
    int length = endIdx - startIdx;
    
    pthread_mutex_lock(&inputBufferMutex);
    for (int i = 0, j = startIdx; i < length; i++, j++)
        outBuffer[i] = inputBuffer[j];
    pthread_mutex_unlock(&inputBufferMutex);
}

- (void)getOutputBuffer:(Float32 *)outBuffer withLength:(int)length {
    
    if (length >= recordingBufferLengthFrames)
        NSLog(@"%s: Invalid buffer length", __PRETTY_FUNCTION__);
    
    pthread_mutex_lock(&outputBufferMutex);
    for (int i = 0; i < length; i++)
        outBuffer[i] = outputBuffer[recordingBufferLengthFrames - (length-i)];
    pthread_mutex_unlock(&outputBufferMutex);
}

- (void)getOutputBuffer:(Float32 *)outBuffer withLength:(int)length offset:(int)offset {
    pthread_mutex_lock(&outputBufferMutex);
    for (int i = 0; i < length; i++)
        outBuffer[i] = outputBuffer[recordingBufferLengthFrames - (length-i) + offset];
    pthread_mutex_unlock(&outputBufferMutex);
}

- (void)getOutputBuffer:(Float32 *)outBuffer from:(int)startIdx to:(int)endIdx {
    
    if (startIdx < 0 || endIdx >= recordingBufferLengthFrames || endIdx < startIdx)
        NSLog(@"%s: Invalid buffer indices", __PRETTY_FUNCTION__);
    
    int length = endIdx - startIdx;
    
    pthread_mutex_lock(&outputBufferMutex);
    for (int i = 0, j = startIdx; i < length; i++, j++)
        outBuffer[i] = outputBuffer[j];
    pthread_mutex_unlock(&outputBufferMutex);
}

- (void)getAverageSpectrum:(Float32 *)outBuffer from:(int)startIdx to:(int)endIdx {
    
    if (startIdx < 0 || endIdx >= recordingBufferLengthFrames || endIdx < startIdx)
        NSLog(@"%s: Invalid buffer indices", __PRETTY_FUNCTION__);
    
    int startFFTFrame = floor(startIdx / fftSize);
    int endFFTFrame = floor(endIdx / fftSize);
    int nFrames = endFFTFrame - startFFTFrame;
    
    pthread_mutex_lock(&spectrumBufferMutex);
    for (int i = 0; i < fftSize/2; i++) {
        
        outBuffer[i] = 0.0f;
        for (int j = startFFTFrame; j <= endFFTFrame; j++)
            outBuffer[i] += spectrumBuffer[i + j*fftSize/2] / nFrames;
    }
    pthread_mutex_unlock(&spectrumBufferMutex);
}

- (void)getAverageOutputSpectrum:(Float32 *)outBuffer from:(int)startIdx to:(int)endIdx {
    
    if (startIdx < 0 || endIdx >= recordingBufferLengthFrames || endIdx < startIdx)
        NSLog(@"%s: Invalid buffer indices", __PRETTY_FUNCTION__);
    
    int startFFTFrame = floor(startIdx / fftSize);
    int endFFTFrame = floor(endIdx / fftSize);
    int nFrames = endFFTFrame - startFFTFrame;
    
    pthread_mutex_lock(&spectrumBufferMutex);
    for (int i = 0; i < fftSize/2; i++) {
        
        outBuffer[i] = 0.0f;
        for (int j = startFFTFrame; j <= endFFTFrame; j++)
            outBuffer[i] += outputSpectrumBuffer[i + j*fftSize/2] / nFrames;
    }
    pthread_mutex_unlock(&spectrumBufferMutex);
}

- (void)getModulationBuffer:(Float32 *)outBuffer withLength:(int)length {
    
    if (length > bufferSizeFrames)
        length = bufferSizeFrames;
    
    pthread_mutex_lock(&modulationBufferMutex);
    for (int i = 0; i < length; i++)
        outBuffer[i] = modulationBuffer[i];
    pthread_mutex_unlock(&modulationBufferMutex);
}

#pragma mark - Effects Parameters
- (void)setLPFCutoff:(CGFloat)fc {
    lpfTargetCutoff = fc;
    lpfCutoffStep = (lpfTargetCutoff - lpf.cornerFrequency) / (kFilterCutoffRampDuration * sampleRate / bufferSizeFrames);
    
    if (!inputEnabled)
        [self processRecordingInputBufferOffline];
}

- (void)setHPFCutoff:(CGFloat)fc {
    hpfTargetCutoff = fc;
    hpfCutoffStep = (hpfTargetCutoff - hpf.cornerFrequency) / (kFilterCutoffRampDuration * sampleRate / bufferSizeFrames);
    
    if (!inputEnabled)
        [self processRecordingInputBufferOffline];
}

- (void)setLPFEnabled:(bool)enabled {
    
    lpfEnabled = enabled;
    
    if (!inputEnabled)
        [self processRecordingInputBufferOffline];
}

- (void)setHPFEnabled:(bool)enabled {
    
    hpfEnabled = enabled;
    
    if (!inputEnabled)
        [self processRecordingInputBufferOffline];
}

- (void)setModFrequency:(float)freq {
    
    targetModFreq = freq;
    modFreqStep = (targetModFreq - modFreq) / (kModFreqRampDuration * sampleRate);
    
    if (!inputEnabled)
        [self processRecordingInputBufferOffline];
}

- (void)setModAmp:(float)amp {
    
    targetModAmp = amp > 1.0 ? 1.0 : amp;
    modAmpStep = (targetModAmp - modAmp) / (kModAmpRampDuration * sampleRate);
    
    if (!inputEnabled)
        [self processRecordingInputBufferOffline];
}

- (void)setModulationEnabled:(bool)enabled {
    
    modulationEnabled = enabled;
    
    if (!inputEnabled)
        [self processRecordingInputBufferOffline];
}

- (void)setClippingAmplitude:(Float32)amp {
    
    clippingAmplitude = amp;
    if (clippingAmplitude > 1.0f)   clippingAmplitude = 1.0f;
    if (clippingAmplitude < 0.05f)  clippingAmplitude = 0.05f;
    
    if (!inputEnabled)
        [self processRecordingInputBufferOffline];
}

- (void)setClippingAmplitudeLow:(Float32)amp {
    
    clippingAmplitudeLow = amp;
    if (clippingAmplitudeLow < -1.0f)   clippingAmplitudeLow = -1.0f;
    if (clippingAmplitudeLow > -0.05f)  clippingAmplitudeLow = -0.05f;
    
    if (!inputEnabled)
        [self processRecordingInputBufferOffline];
}
- (void)setClippingAmplitudeHigh:(Float32)amp {
    
    clippingAmplitudeHigh = amp;
    if (clippingAmplitudeHigh > 1.0f)   clippingAmplitudeHigh = 1.0f;
    if (clippingAmplitudeHigh < 0.05f)  clippingAmplitudeHigh = 0.05f;
    
    if (!inputEnabled)
        [self processRecordingInputBufferOffline];
}

- (void)setDistortionEnabled:(bool)enabled {
    
    distortionEnabled = enabled;
    
    if (!inputEnabled)
        [self processRecordingInputBufferOffline];
}

- (void)setDelayEnabled:(bool)enabled {
    
    delayEnabled = enabled;
    
    if (!inputEnabled)
        [self processRecordingInputBufferOffline];
}

- (void)addDelayTapWithDelayTime:(Float32)time gain:(Float32)amp {
    [circularBuffer addDelayTapWithDelayTime:time gain:amp];
}

- (int)getNumDelayTaps {
    return [circularBuffer nTaps];
}

- (void)setDelayTap:(int)tapIdx time:(CGFloat)time amplitude:(CGFloat)amp {
    
    if (tapIdx < 0 || tapIdx >= kMaxNumDelayTaps) {
        NSLog(@"Invalid delay tap index %d", tapIdx);
        return;
    }
    
    [circularBuffer setDelayTimeForTap:tapIdx delayTime:time];
    [circularBuffer setGainForTap:tapIdx gain:amp];
    
//    if (!inputEnabled)
//        [self processRecordingInputBufferOffline];
}

- (CGFloat)getDelayTimeForTap:(int)tapIdx {
    
    Float32 time = -1.0;
    
    if (tapIdx < 0 || tapIdx >= kMaxNumDelayTaps) {
        NSLog(@"Invalid delay tap index %d", tapIdx);
        return time;
    }
    return [circularBuffer getDelayTimeForTap:tapIdx];
}

- (void)removeDelayTap:(int)tapIdx {
    [circularBuffer removeDelayTapAtIndex:tapIdx];
}

#pragma mark - Effects DSP
/* Apply input gain and effects to the audio in the recording buffers between tMin and tMax when real-time audio input is paused */
- (void)processRecordingInputBufferOffline {
    
    int i = roundf(tMin * sampleRate);  // Sample index of the visible plot min
    i -= fmodf(i, bufferSizeFrames);    // Nearest starting buffer inde
    
    while (i < tMax * sampleRate - 1) {
        
        for (int j = 0; j < bufferSizeFrames; j++)
            procBuffer[j] = inputBuffer[i+j];
//            procBuffer[j] = inputBuffer[i+j] = preInputGainBuffer[i+j] * inputGain;
            
        [self processInputBuffer:procBuffer length:bufferSizeFrames];
        
        for (int j = 0; j < bufferSizeFrames; j++)
            outputBuffer[i+j] = procBuffer[j];
        
        i += bufferSizeFrames;
    }
    
    [self computeFFTs];
}

- (void)processInputBuffer:(Float32 *)buffer length:(int)inNumberFrames {
    
    /* ---------------- */
    /* == Modulation == */
    /* ---------------- */
    
    pthread_mutex_lock(&modulationBufferMutex);
    for (int i = 0; i < inNumberFrames; i++) {
        
        /* Ramp the modulation frequency and recomputer the mod phase if needed */
        if ((modFreq < targetModFreq && modFreqStep > 0) ||
            (modFreq > targetModFreq && modFreqStep < 0) ) {
            modFreq += modFreqStep;
            modThetaInc = 2.0 * M_PI * modFreq / kAudioSampleRate;
        }
        /* Ramp the modulation amplitude if needed */
        if ((modAmp < targetModAmp && modAmpStep > 0) ||
            (modAmp > targetModAmp && modAmpStep < 0) ) {
            modAmp += modAmpStep;
        }
        
        modulationBuffer[i] = [aSynth wavetableLookup:modTheta];
//        modulationBuffer[i] = modAmp * [aSynth wavetableLookup:modTheta];
        
        modTheta += modThetaInc;
        if (modTheta > 2*M_PI)
            modTheta -= 2*M_PI;
    }
    pthread_mutex_unlock(&modulationBufferMutex);

    if (modulationEnabled) {
        for (int i = 0; i < inNumberFrames; i++) {
//            buffer[i] *= modulationBuffer[i];
            buffer[i] = (1.0-modAmp) * buffer[i] + modAmp * buffer[i] * modulationBuffer[i];
        }
    }
    
    /* ---------------- */
    /* == Distortion == */
    /* ---------------- */
    
    if (distortionEnabled) {
        
        for (int i = 0; i < inNumberFrames; i++) {
            
            if (buffer[i] > clippingAmplitudeHigh)
                buffer[i] = clippingAmplitudeHigh;
            
            else if (buffer[i] < clippingAmplitudeLow)
                buffer[i] = clippingAmplitudeLow;
        }
    }
    
    /* ------------- */
    /* == Filters == */
    /* ------------- */
    
    /* Ramp the filter cutoff frequencies if needed */
    if (hpf.cornerFrequency < hpfTargetCutoff && hpfCutoffStep > 0) {
        if (hpf.cornerFrequency + hpfCutoffStep < hpfTargetCutoff)
            [hpf setCornerFrequency:hpf.cornerFrequency + hpfCutoffStep];
        else {
            [hpf setCornerFrequency:hpfTargetCutoff];
            hpfCutoffStep = 0.0;
        }
    }
    if (hpf.cornerFrequency > hpfTargetCutoff && hpfCutoffStep < 0) {
        if (hpf.cornerFrequency + hpfCutoffStep > hpfTargetCutoff)
            [hpf setCornerFrequency:hpf.cornerFrequency + hpfCutoffStep];
        else {
            [hpf setCornerFrequency:hpfTargetCutoff];
            hpfCutoffStep = 0.0;
        }
    }
    if (lpf.cornerFrequency < lpfTargetCutoff && lpfCutoffStep > 0) {
        if (lpf.cornerFrequency + lpfCutoffStep < lpfTargetCutoff)
            [lpf setCornerFrequency:lpf.cornerFrequency + lpfCutoffStep];
        else {
            [lpf setCornerFrequency:lpfTargetCutoff];
            lpfCutoffStep = 0.0;
        }
    }
    if (lpf.cornerFrequency > lpfTargetCutoff && lpfCutoffStep < 0) {
        if (lpf.cornerFrequency + lpfCutoffStep > lpfTargetCutoff)
            [lpf setCornerFrequency:lpf.cornerFrequency + lpfCutoffStep];
        else {
            [lpf setCornerFrequency:lpfTargetCutoff];
            lpfCutoffStep = 0.0;
        }
    }
    
    if (hpfEnabled) {
        /* Apply filter */
        [hpf filterContiguousData:buffer numFrames:inNumberFrames channel:0];
    }
    
    if (lpfEnabled) {
        /* Apply filter */
        [lpf filterContiguousData:buffer numFrames:inNumberFrames channel:0];
    }
    
    /* ----------- */
    /* == Delay == */
    /* ----------- */
    
    if (delayEnabled) {
        [circularBuffer processInputBuffer:buffer length:inNumberFrames];
    }
}


#pragma mark - Synth Parameter Updates
- (void)synthSetAmplitudeScalar:(float)amp {
    [aSynth setAmplitudeScalar:amp];
    [wSynth setAmplitudeScalar:amp];
}

- (void)synthSetWavetableEnabled {
    synthWavetableEnabled = true;
    synthAdditiveEnabled = false;
}

- (void)synthSetWavetable:(CGFloat *)wavetable length:(int)length {
    [wSynth setWaveTableCG:wavetable length:length];
}

- (void)synthSetAdditiveEnabled {
    synthWavetableEnabled = false;
    synthAdditiveEnabled = true;
}

- (void)synthSetFundamental:(float)f0 {
    synthFundamental = f0;
    [aSynth setFundamental:f0];
    [wSynth setFundamental:f0];
}

- (void)synthSetFundamental:(float)f0 ramp:(bool)doRamp {
    if (doRamp)
        [self synthSetFundamental:f0];
    else {
        synthFundamental = f0;
        [aSynth setFundamental:f0 ramp:false];
        [wSynth setFundamental:f0 ramp:false];
    }
}

- (void)synthSetPitchBendVal:(float)normVal {   // [-1, 1]
    normVal *= kPitchBendNumSemitones;          // [-2, 2] (semitones)
    normVal = powf(2.0, normVal/12.0);          // [2^(-1/6), 2^(1/6)]  (pitch multipler)
    [aSynth setFundamental:synthFundamental * normVal];
    [wSynth setFundamental:synthFundamental * normVal];
}

- (void)synthSetNoiseAmplitude:(float)amp {
    [aSynth setNoiseAmplitude:amp];
    [wSynth setNoiseAmplitude:amp];
}

- (void)synthSetNumHarmonics:(int)num {
    [aSynth setNumHarmonics:num];
}

- (void)synthSetAmplitude:(float)amp forHarmonic:(int)num {
    
    if (!synthAdditiveEnabled)
        [self synthSetAdditiveEnabled];
    
    [aSynth setAmplitude:amp forHarmonic:num];
}

- (void)synthSetAmplitudeEnvelope:(CGFloat *)env length:(int)length {
    [aSynth setAmplitudeEnvelopeCG:env length:length];
    [wSynth setAmplitudeEnvelopeCG:env length:length];
}

- (void)synthRetriggerAmplitudeEnvelope {
    [aSynth retriggerAmplitudeEnvelope];
    [wSynth retriggerAmplitudeEnvelope];
}

- (void)synthResetAmplitudeEnvelope {
    [aSynth resetAmplitudeEnvelope];
    [wSynth resetAmplitudeEnvelope];
}

- (float)synthGetAmplitudeForHarmonic:(int)num {
    return [aSynth getAmplitudeForHarmonic:num-1];
}

- (float)synthGetNoiseAmplitude {
    return [aSynth getNoiseAmplitude];
}

#pragma mark - Synthesis DSP
- (void)renderOutputBufferMono:(Float32 *)buffer outNumberFrames:(int)outNumFrames {
    if (synthWavetableEnabled)
        phaseZeroOffset = [wSynth renderOutputBufferMono:buffer outNumberFrames:outNumFrames];
    else if (synthAdditiveEnabled)
        phaseZeroOffset = [aSynth renderOutputBufferMono:buffer outNumberFrames:outNumFrames];
}

#pragma mark - Utility Methods
/* Compute the single-sided magnitude spectrum using Accelerate's vDSP methods */
- (void)computeMagnitudeFFT:(float *)inBuffer inBufferLength:(int)len outMagnitude:(float *)magnitude window:(bool)doWindow {
    
    /* Recomputer the window if it's not the length of the input signal and we're windowing */
    if (doWindow && len != windowSize) {
        windowSize = len;
        free(window);
        window = (float *)malloc(windowSize * sizeof(float));
        vDSP_hann_window(window, windowSize, vDSP_HANN_NORM);
    }
    
    /* If the input signal is shorter than the fft size, zero-pad */
    if (len < fftSize) {
        
        /* Window and zero-pad */
        if (doWindow) {
            
            /* Window the input signal */
            float *windowed = (float *)malloc(len * sizeof(float));
            vDSP_vmul(inBuffer, 1, window, 1, windowed, 1, len);
            
            /* Copy */
            for (int i = 0; i < len; i++)
                inRealBuffer[i] = windowed[i];
            
            /* Zero-pad */
            for (int i = len; i < fftSize; i++)
                inRealBuffer[i] = 0.0f;
            
            free(windowed);
        }
        
        /* Just copy and zero-pad */
        else {
            for (int i = 0; i < len; i++)
                inRealBuffer[i] = inBuffer[i];
            
            for (int i = len; i < fftSize; i++)
                inRealBuffer[i] = 0.0f;
        }
    }
    
    /* No zero-padding */
    else {
        
        /* Multiply by Hann window */
        if (doWindow)
            vDSP_vmul(inBuffer, 1, window, 1, inRealBuffer, 1, len);
        
        /* Otherwise just copy into the real input buffer */
        else
            cblas_scopy(fftSize, inBuffer, 1, inRealBuffer, 1);
    }
    
    /* Transform the real input data into the even-odd split required by vDSP_fft_zrip() explained in: https://developer.apple.com/library/ios/documentation/Performance/Conceptual/vDSP_Programming_Guide/UsingFourierTransforms/UsingFourierTransforms.html */
    vDSP_ctoz((COMPLEX *)inRealBuffer, 2, &splitBuffer, 1, fftSize/2);
    
    /* Computer the FFT */
    vDSP_fft_zrip(fftSetup, &splitBuffer, 1, log2f(fftSize), FFT_FORWARD);
    
    splitBuffer.imagp[0] = 0.0;     // ?? Shitty did this
    
    /* Convert the split complex data splitBuffer to an interleaved complex coordinate pairs */
    vDSP_ztoc(&splitBuffer, 1, (COMPLEX *)inRealBuffer, 2, fftSize/2);
    
    /* Convert the interleaved complex vector to interleaved polar coordinate pairs (magnitude, phase) */
    vDSP_polar(inRealBuffer, 2, outRealBuffer, 2, fftSize/2);
    
    /* Copy the even indices (magnitudes) */
    cblas_scopy(fftSize/2, outRealBuffer, 2, magnitude, 1);
    
    /* Normalize the magnitude */
    for (int i = 0; i < fftSize/2; i++)
        magnitude[i] *= fftScale;
    
    //    /* Copy the odd indices (phases) */
    //    cblas_scopy(fftSize/2, outRealBuffer+1, 2, phase, 1);
}

- (void)printErrorMessage:(NSString *)errorString withStatus:(OSStatus)result {
    
    char errorDetail[20];
    
    /* Check if the error is a 4-character code */
    *(UInt32 *)(errorDetail + 1) = CFSwapInt32HostToBig(result);
    if (isprint(errorDetail[1]) && isprint(errorDetail[2]) && isprint(errorDetail[3]) && isprint(errorDetail[4])) {
        
        errorDetail[0] = errorDetail[5] = '\'';
        errorDetail[6] = '\0';
    }
    else /* Format is an integer */
        sprintf(errorDetail, "%d", (int)result);
    
    fprintf(stderr, "Error: %s (%s)\n", [errorString cStringUsingEncoding:NSASCIIStringEncoding], errorDetail);
}

- (void)printASBD:(AudioStreamBasicDescription)asbd {
    
    char formatIDString[5];
    UInt32 formatID = CFSwapInt32HostToBig(asbd.mFormatID);
    bcopy(&formatID, formatIDString, 4);
    formatIDString[4] = '\0';
    
    NSLog (@"  Sample Rate:         %10.0f",  asbd.mSampleRate);
    NSLog (@"  Format ID:           %10s",    formatIDString);
    NSLog (@"  Format Flags:        %10X",    (unsigned int)asbd.mFormatFlags);
    NSLog (@"  Bytes per Packet:    %10d",    (unsigned int)asbd.mBytesPerPacket);
    NSLog (@"  Frames per Packet:   %10d",    (unsigned int)asbd.mFramesPerPacket);
    NSLog (@"  Bytes per Frame:     %10d",    (unsigned int)asbd.mBytesPerFrame);
    NSLog (@"  Channels per Frame:  %10d",    (unsigned int)asbd.mChannelsPerFrame);
    NSLog (@"  Bits per Channel:    %10d",    (unsigned int)asbd.mBitsPerChannel);
}

@end



















