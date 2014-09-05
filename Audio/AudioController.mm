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
    
    /* Allocate a buffer for processing samples and copy the ioData into it */
    Float32 *procBuffer = (Float32 *)calloc(inNumberFrames, sizeof(Float32));
    memcpy(procBuffer, (Float32 *)ioData->mBuffers[0].mData, sizeof(Float32) * inNumberFrames);
    
    /* Apply the input gain to the input buffer if it's not settable directly on the device */
//    if (![[controller audioSession] isInputGainSettable]) {
        for (int i = 0; i < inNumberFrames; i++)
            procBuffer[i] *= controller.inputGain;
//    }
    
    /* Set the pre-processing buffer with pre-gain applied */
    [controller appendInputBuffer:procBuffer withLength:inNumberFrames];
    
    /* ---------------- */
    /* == Modulation == */
    /* ---------------- */
    pthread_mutex_lock(&controller->modulationBufferMutex);
    for (int i = 0; i < inNumberFrames; i++) {
        
        /* Ramp the modulation frequency and recomputer the mod phase if needed */
        if ((controller->modFreq < controller->targetModFreq && controller->modFreqStep > 0) ||
            (controller->modFreq > controller->targetModFreq && controller->modFreqStep < 0) ) {
            controller->modFreq += controller->modFreqStep;
            controller->modThetaInc = 2.0 * M_PI * controller->modFreq / kAudioSampleRate;
        }
        
        controller->modulationBuffer[i] = sin(controller->modTheta);
        
        controller->modTheta += controller->modThetaInc;
        if (controller->modTheta > 2*M_PI)
            controller->modTheta -= 2*M_PI;
    }
    pthread_mutex_unlock(&controller->modulationBufferMutex);
    
    if (controller.modulationEnabled) {
        for (int i = 0; i < inNumberFrames; i++)
            procBuffer[i] *= controller->modulationBuffer[i];
    }
    
    /* ---------------- */
    /* == Distortion == */
    /* ---------------- */
    if (controller.distortionEnabled) {
        
        for (int i = 0; i < inNumberFrames; i++) {
            
            if (procBuffer[i] > controller->clippingAmplitude)
                procBuffer[i] = controller->clippingAmplitude;
            
            else if (procBuffer[i] < -controller->clippingAmplitude)
                procBuffer[i] = -controller->clippingAmplitude;
        }
    }
    
    /* ------------- */
    /* == Filters == */
    /* ------------- */
    
    if (controller.hpfEnabled)
        [controller->hpf filterContiguousData:procBuffer numFrames:inNumberFrames channel:0];
    
    if (controller.lpfEnabled)
        [controller->lpf filterContiguousData:procBuffer numFrames:inNumberFrames channel:0];
    
    /* ----------- */
    /* == Delay == */
    /* ----------- */
    
    /* Copy the processing buffer to the circular buffer */
    [controller->circularBuffer writeDataWithLength:inNumberFrames inData:procBuffer];
    
    if (controller.delayEnabled) {
        
        /* Allocate a buffer for the summed output of the filterbank */
        Float32 *outSamples = (Float32 *)calloc(inNumberFrames, sizeof(Float32));
        memcpy(outSamples, procBuffer, inNumberFrames * sizeof(Float32));
        
        /* Allocate a buffer for the outputs of individual filter bands */
        Float32 *delayTapOut = (Float32 *)calloc(inNumberFrames, sizeof(Float32));
        
        for (int i = 0; i < controller->circularBuffer.nTaps; i++) {
            
            /* Copy samples from the i^th delay tap */
            [controller->circularBuffer readFromDelayTap:i withLength:inNumberFrames outData:delayTapOut];
            
            /* Apply the tap gain */
            for (int j = 0; j < inNumberFrames; j++)
                outSamples[j] += controller->tapGains[i] * delayTapOut[j] / controller->circularBuffer.nTaps;
        }
        
        /* Overwrite the processing buffer with the delayed samples and free the unneeded buffers */
        memcpy(procBuffer, outSamples, inNumberFrames * sizeof(Float32));
        free(delayTapOut);
        free(outSamples);
    }
    
    /* Update the stored output buffer (for plotting) */
    [controller appendOutputBuffer:procBuffer withLength:inNumberFrames];
    
    /* Apply post-gain or mute */
    if (controller.outputEnabled) {
        for (int i = 0; i < inNumberFrames; i++)
            procBuffer[i] *= controller.outputGain;
    }
    else {
        for (int i = 0; i < inNumberFrames; i++)
            procBuffer[i] *= 0;
    }
    
    /* Copy the processing buffer into the left and right output channels */
    memcpy((Float32 *)ioData->mBuffers[0].mData, procBuffer, inNumberFrames * sizeof(Float32));
    memcpy((Float32 *)ioData->mBuffers[1].mData, procBuffer, inNumberFrames * sizeof(Float32));
    
    free(procBuffer);
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
@synthesize distortionEnabled;
@synthesize hpfEnabled;
@synthesize lpfEnabled;
@synthesize modulationEnabled;
@synthesize delayEnabled;

- (id)init {
    
    self = [super init];
    
    if (self) {
        
        /* Set flags */
        inputEnabled = inputWasEnabled = false;
        outputEnabled = outputWasEnabled = false;
        distortionEnabled = false;
        hpfEnabled = false;
        lpfEnabled = false;
        modulationEnabled = false;
        delayEnabled = false;
        
        /* Defaults */
        inputGain = 1.0f;
        outputGain = 1.0f;
        clippingAmplitude = 1.0f;
        
        /* Setup methods */
        [self setUpAudioSession];
        [self setUpIOUnit];
        [self allocateBuffersWithLength:kAudioBufferSize*110];
        [self setUpFilters];
        [self setUpRingModulator];
        [self setUpDelay];
        [self setInputEnabled:true];
        [self setOutputEnabled:true];
    }
    
    return self;
}

- (void)dealloc {
    
    if (inputBuffer)
        free(inputBuffer);
    if (outputBuffer)
        free(outputBuffer);
    if (spectrumBuffer)
        free(spectrumBuffer);
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
    
    bool success = true;
    NSError* error = nil;
    
    audioSession = [AVAudioSession sharedInstance];
    
    /* Set the category and mode of the audio session */
    success = [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    success = [audioSession setMode:AVAudioSessionModeMeasurement error:&error];
    
    /* Set sample rate, buffer duration, and number of IO channels */
    success = [audioSession setPreferredSampleRate:kAudioSampleRate error:&error];
    success = [audioSession setPreferredIOBufferDuration:kAudioBufferSize/kAudioSampleRate error:&error];
    success = [audioSession setPreferredOutputNumberOfChannels:2 error:&error];
    success = [audioSession setPreferredInputNumberOfChannels:1 error:&error];
    
    /* Activate the audio session */
    [audioSession setActive:true error:&error];
    
    /* Get the sample rate */
    sampleRate = audioSession.sampleRate;
    
    /* Size of a single audio buffer in samples */
    bufferSizeFrames = (int)roundf(audioSession.sampleRate * audioSession.IOBufferDuration);
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"inputAvailable = %s", audioSession.inputAvailable ? "true" : "false");
    NSLog(@"maximumInputNumberOfChannels = %d", audioSession.maximumInputNumberOfChannels);
    NSLog(@"maximumOutputNumberOfChannels = %d", audioSession.maximumOutputNumberOfChannels);
    NSLog(@"audioSession.outputNumberOfChannels = %d", audioSession.outputNumberOfChannels);
    NSLog(@"audioSession.inputNumberOfChannels  = %d", audioSession.inputNumberOfChannels);
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

- (void)allocateBuffersWithLength:(int)length {
    
    recordingBufferLengthFrames = length;
    
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

- (void)setUpFilters {
    
    hpf = [[NVHighpassFilter alloc] initWithSamplingRate:kAudioSampleRate];
    hpf.Q = 2.0;
    hpf.cornerFrequency = 20;
    
    lpf = [[NVLowpassFilter alloc] initWithSamplingRate:kAudioSampleRate];
    lpf.Q = 2.0;
    lpf.cornerFrequency = 20000;
}

- (void)setUpRingModulator {
    
    modFreq = targetModFreq = 440.0f;
    modFreqStep = 0.0f;
    modTheta = 0.0f;
    modThetaInc = 2.0 * M_PI * modFreq / kAudioSampleRate;
    
    if (!modulationBuffer)
        modulationBuffer = (Float32 *)malloc(kAudioBufferSize * sizeof(Float32));
    
    pthread_mutex_init(&modulationBufferMutex, NULL);
}

- (void)setUpDelay {

    circularBuffer = [[CircularBuffer alloc] initWithLength:(int)(kAudioSampleRate * kMaxDelayTime)];
    [circularBuffer addDelayTapForSampleDelay:(int)(kAudioSampleRate * 1.0)];
    tapGains[0] = 0.8;
    tapGains[1] = 0.5;
    tapGains[2] = 0.5;
    tapGains[3] = 0.5;
    tapGains[4] = 0.5;
}

#pragma mark - Interface Methods
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
    
//    bool success = false;
//    NSError* error = nil;
//    
//    /* Set the device's input gain if settable */
//    if ([audioSession isInputGainSettable]) {
//        success = [audioSession setInputGain:gain error:&error];
//        if (success) inputGain = gain;
//        else NSLog(@"%s failed", __PRETTY_FUNCTION__);
//    }
//    else
//        inputGain = gain;
//    
//    return success;
    
    inputGain = gain;
    return true;
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

/* Get n = length most recent audio samples from the recording buffer */
- (void)getInputBuffer:(Float32 *)outBuffer withLength:(int)length {
    
    if (length >= recordingBufferLengthFrames)
        NSLog(@"%s: Invalid buffer length", __PRETTY_FUNCTION__);
    
    pthread_mutex_lock(&inputBufferMutex);
    for (int i = 0; i < length; i++)
        outBuffer[i] = inputBuffer[recordingBufferLengthFrames - (length-i)];
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

- (void)rescaleFilters:(float)minFreq max:(float)maxFreq {
    
    hpf.cornerFrequency = minFreq;
    lpf.cornerFrequency = maxFreq;
}

- (void)setModFrequency:(float)freq {
    
    targetModFreq = freq;
    modFreqStep = (targetModFreq - modFreq) / (kModFreqRampDuration * kAudioSampleRate);
}

#pragma mark Utility Methods
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



















