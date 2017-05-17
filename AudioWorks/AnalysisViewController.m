//
//  AnalysisViewController.m
//  AudioWorks
//
//  Created by Jeff Gregorio on 6/24/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import "AnalysisViewController.h"
#import "AppDelegate.h"

@interface AnalysisViewController ()

@end

@implementation AnalysisViewController

@synthesize audioController;
@synthesize helpDisplayed;
@synthesize inputPaused;

- (void)viewDidLoad {
    
    NSLog(@"%@", self);
    
    [super viewDidLoad];
    
    UIColor *offWhite = [UIColor colorWithRed:kAudioWorksBackgroundColor_R
                                        green:kAudioWorksBackgroundColor_G
                                         blue:kAudioWorksBackgroundColor_B
                                        alpha:1.0f];
    [[self view] setBackgroundColor:offWhite];
    [timeAxisLabel setBackgroundColor:offWhite];
    [freqAxisLabel setBackgroundColor:offWhite];
    
    /* ----------- */
    /* == Audio == */
    /* ----------- */
    
    /* Get a reference to the AudioController from the AppDelegate */
    AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    audioController = [delegate audioController];
    
    /* Distortion */
    [audioController setDistortionEnabled:false];
    
    /* Filters */
    [audioController setLPFEnabled:false];
    [audioController setHPFEnabled:false];
    
    /* Modulation */
    [audioController setModulationEnabled:false];
    [audioController setModFrequency:440.0f];
    
    /* Delay */
    [audioController setDelayEnabled:false];
    
    /* ----------------------- */
    /* == Time Domain Scope == */
    /* ----------------------- */
    CGFloat minRange = (audioController.bufferSizeFrames+10) / audioController.sampleRate / 2.0f;
    CGFloat maxRange = (audioController.recordingBufferLengthFrames-10) / audioController.sampleRate;
    
    [tdScopeView setPlotResolution:512];
    [tdScopeView setMinPlotRange:CGPointMake(minRange + 0.00001f, 0.1f)];
    [tdScopeView setMaxPlotRange:CGPointMake(maxRange + 0.00001f, 2.0f)];
    [tdScopeView setHardXLim:-0.00001f max:maxRange];
    [tdScopeView setVisibleXLim:-0.00001f max:minRange * 2.0f];
    [tdScopeView setPlotUnitsPerXTick:0.005f];
    [tdScopeView setXGridAutoScale:true];
    [tdScopeView setYGridAutoScale:true];
    [tdScopeView setXLabelPosition:kMETScopeViewXLabelsOutsideBelow];
    [tdScopeView setYLabelPosition:kMETScopeViewYLabelsOutsideLeft];
    [tdScopeView setYLabelFormatString:@"%4.1f"];
    [tdScopeView setDelegate:self];
    
    /* Allocate subview for a single waveform */
    tdIdx = [tdScopeView addPlotWithColor:[UIColor blueColor] lineWidth:2.0f];
    
//    /* Tap gesture recognizer on time domain plot for pausing audio input */
//    tdTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTDTap:)];
//    [tdTapRecognizer setNumberOfTapsRequired:2];
//    [tdScopeView addGestureRecognizer:tdTapRecognizer];
    inputPaused = false;
    
    tdControlArray = [[METScopeControlArray alloc] initWithParentScope:tdScopeView];
    int c_idx = [tdControlArray addControlWithStyle:kMETControlStylePlayhead
                                 values:CGPointMake(0.0, 0.0)];
    playhead = [tdControlArray getControlAtIndex:c_idx];
    [playhead setConstrainVerticallyToParentView:true];
    [playhead setVerticalRange:1.2 max:1.2];
    [playhead setDrawsVerticalLineToBottom:true];
    [playhead setLineColor:[UIColor blueColor]];
    [playhead setTag:0];
    [playhead setHidden:true];
    [tdControlArray setDelegate:self];
    [tdScopeView addSubview:tdControlArray];
    
    /* ---------------------------- */
    /* == Frequency Domain Scope == */
    /* ---------------------------- */
    [fdScopeView setPlotResolution:fdScopeView.frame.size.width];
    [fdScopeView setUpFFTWithSize:kFFTSize];      // Set up FFT before setting FD mode
    [fdScopeView setDisplayMode:kMETScopeViewFrequencyDomainMode];
    [fdScopeView setHardXLim:0.0 max:10000];       // Set bounds after FD mode
    [fdScopeView setVisibleXLim:0.0 max:9300];
    [fdScopeView setPlotUnitsPerXTick:2000];
    [fdScopeView setXGridAutoScale:true];
    [fdScopeView setYGridAutoScale:true];
    [fdScopeView setXLabelPosition:kMETScopeViewXLabelsOutsideBelow];
    [fdScopeView setYLabelPosition:kMETScopeViewYLabelsOutsideLeft];
    [fdScopeView setAxisScale:kMETScopeViewAxesSemilogY];
    [fdScopeView setHardYLim:-80 max:0];
    [fdScopeView setPlotUnitsPerYTick:20];
    [fdScopeView setAxesOn:true];
    [fdScopeView setDelegate:self];
    
    /* Allocate subview for a single waveform */
    fdIdx = [fdScopeView addPlotWithColor:[UIColor blueColor] lineWidth:2.0f];
    
    /* Get the FFT frequencies for the FD scope */
    plotFreqs = (float *)malloc(fdScopeView.frame.size.width * sizeof(float));
    [self linspace:fdScopeView.minPlotMin.x
               max:fdScopeView.maxPlotMax.x
       numElements:fdScopeView.frame.size.width
             array:plotFreqs];
    
    /* ------------------ */
    /* === Help Setup === */
    /* ------------------ */
    
    helpDisplayed = false;
    helpBubbles = [[NSMutableArray alloc] init];
    
    /* TD Scope description */
    CGPoint origin;
    origin.x = tdScopeView.frame.origin.x + tdScopeView.frame.size.width - 200.0f;
    origin.y = tdScopeView.frame.origin.y + 50.0f;
    HelpBubble *bbl = [[HelpBubble alloc] initWithText:@"Audio signal in the time-domain"
                                                origin:origin
                                                 width:200.0f
                                             alignment:NSTextAlignmentRight];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    [bbl setDrawBackground:false];
    [[bbl label] setTextColor:[UIColor blackColor]];
    [[self view] addSubview:bbl];
    [helpBubbles addObject:bbl];
    [bbl setHidden:true];
    
    /* FD Scope desc. */
    origin.x = fdScopeView.frame.origin.x + fdScopeView.frame.size.width - 200.0f;
    origin.y = fdScopeView.frame.origin.y + 60.0f;
    bbl = [[HelpBubble alloc] initWithText:@"Audio signal in the frequency-domain (spectrum)"
                                    origin:origin
                                     width:200.0f
                                 alignment:NSTextAlignmentRight];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    [bbl setDrawBackground:false];
    [[bbl label] setTextColor:[UIColor blackColor]];
    [[self view] addSubview:bbl];
    [helpBubbles addObject:bbl];
    [bbl setHidden:true];
    
    /* Gesture interaction instructions for TD and FD plots */
    origin.x = tdScopeView.frame.origin.x + 150.0f;
    origin.y = tdScopeView.frame.origin.y + 50.0f;
    bbl = [[HelpBubble alloc] initWithText:@"Pinch plot with two fingers to zoom in time. Drag with one finger to shift forward or backward.\n\nThis plot shows up to 2.5 seconds of recorded audio. Use the playback button above to pause or resume recording."
                                    origin:origin
                                     width:300.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    [bbl setFrameSizeForFontSize:20.0f];
    [[self view] addSubview:bbl];
    [helpBubbles addObject:bbl];
    [bbl setHidden:true];
    
    origin.x = fdScopeView.frame.origin.x + 150.0f;
    origin.y = fdScopeView.frame.origin.y + 70.0f;
    bbl = [[HelpBubble alloc] initWithText:@"Pinch plot with two fingers to zoom in frequency. Drag with one finger to shift forward or backward.\n\nWhen input is enabled, this plot shows the real-time spectrum. When input is paused, this plot shows only the spectrum of the audio visible in the above plot."
                                    origin:origin
                                     width:300.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    [bbl setFrameSizeForFontSize:20.0f];
    [[self view] addSubview:bbl];
    [helpBubbles addObject:bbl];
    [bbl setHidden:true];
    
    origin.x = tdScopeView.frame.origin.x + 30.0f;
    origin.y = tdScopeView.frame.origin.y + tdScopeView.frame.size.height - 7.5f;
    bbl = [[HelpBubble alloc] initWithText:@"Tap to access level control"
                                    origin:origin
                                     width:250.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationLeft];
    [bbl setFrameSizeForFontSize:22.0f];
    [[self view] addSubview:bbl];
    [helpBubbles addObject:bbl];
    [bbl setHidden:true];
}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    
    /* Get a reference to the AudioController from the AppDelegate */
    AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    audioController = [delegate audioController];
    
    CGFloat minRange = (audioController.bufferSizeFrames+10) / audioController.sampleRate / 2.0f;
    CGFloat maxRange = (audioController.recordingBufferLengthFrames-10) / audioController.sampleRate;
    
    [tdScopeView setMinPlotRange:CGPointMake(minRange + 0.00001f, 0.1f)];
    [tdScopeView setMaxPlotRange:CGPointMake(maxRange + 0.00001f, 2.0f)];
    [tdScopeView setHardXLim:-0.00001f max:maxRange];
    [tdScopeView setVisibleXLim:-0.00001f max:minRange * 2.0f];
    
    /* Set the scope clocks */
    [self setTDUpdateRate:kAnalysisScopeUpdateRate];
    tdHold = false;
    [self setFDUpdateRate:kAnalysisScopeUpdateRate];
    fdHold = false;
    
    /* Display the help if the App Delegate's help button is active */
    if ([delegate helpDisplayed] != helpDisplayed)
        [self toggleHelp];
    
    [self enableInput];
    [audioController setSynthEnabled:false];
}

- (void)viewWillDisappear:(BOOL)animated {
    
    [super viewWillDisappear:animated];

    [tdScopeClock invalidate];
    [fdScopeClock invalidate];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setup {
    
}

#pragma mark - Help
- (void)toggleHelp {
    helpDisplayed = !helpDisplayed;
    [self updateHelp];
}

- (void)updateHelp {
    
    if (!helpDisplayed) {
        for (int i = 0; i < [helpBubbles count]; i++)
            [[helpBubbles objectAtIndex:i] setHidden:true];
    }
    else {
        for (int i = 0; i < [helpBubbles count]; i++)
            [[helpBubbles objectAtIndex:i] setHidden:false];
    }
}

#pragma mark - Plot Updates
- (void)setTDUpdateRate:(float)rate {
    
    if ([tdScopeClock isValid])
        [tdScopeClock invalidate];
    
    tdScopeClock = [NSTimer scheduledTimerWithTimeInterval:rate
                                                    target:self
                                                  selector:@selector(updateTDScope)
                                                  userInfo:nil
                                                   repeats:YES];
}

- (void)setFDUpdateRate:(float)rate {
    
    if ([fdScopeClock isValid])
        [fdScopeClock invalidate];
    
    fdScopeClock = [NSTimer scheduledTimerWithTimeInterval:rate
                                                    target:self
                                                  selector:@selector(updateFDScope)
                                                  userInfo:nil
                                                   repeats:YES];
}

- (void)updateTDScope {
    
    int startIdx = fmax(tdScopeView.visiblePlotMin.x, 0.0f) * audioController.sampleRate;
    int endIdx = fmin(tdScopeView.visiblePlotMax.x * audioController.sampleRate, audioController.recordingBufferLengthFrames);
    int visibleBufferLength = endIdx - startIdx;
    
    /* Update the plots */
    if (!tdHold && ![tdScopeView hasCurrentPinch] && ![tdScopeView hasCurrentPan]) {
        
        /* Get buffer of times for each sample */
        plotTimes = (float *)malloc(visibleBufferLength * sizeof(float));
        [self linspace:fmax(tdScopeView.visiblePlotMin.x, 0.0f)
                   max:tdScopeView.visiblePlotMax.x
           numElements:visibleBufferLength
                 array:plotTimes];
        
        /* Allocate wet/dry signal buffers */
        float *ybuffer = (float *)malloc(visibleBufferLength * sizeof(float));
        
        /* Get current visible samples from the audio controller */
        if (audioController.recordedPlayback) {
            [audioController getPlaybackBuffer:ybuffer from:startIdx to:endIdx];
        }
        else if (inputPaused) {
            [audioController getInputBuffer:ybuffer from:startIdx to:endIdx];
        }
        else {
            [audioController getInputBuffer:ybuffer withLength:visibleBufferLength];
        }
        
        [tdScopeView setPlotDataAtIndex:tdIdx
                             withLength:visibleBufferLength
                                  xData:plotTimes
                                  yData:ybuffer];
        free(plotTimes);
        free(ybuffer);
    }
}

- (void)updateFDScope {
    
    if (!fdHold && ![fdScopeView hasCurrentPinch] && ![fdScopeView hasCurrentPan]) {
        
//        NSLog(@"%s: paused = %s, pback = %s", __func__, inputPaused ? "true" : "false", audioController.recordedPlayback ? "true" : "false");
        
        /* If we've taken a snapshot, plot the averaged spectrum of the visible portion */
        if (inputPaused && !audioController.recordedPlayback) {
            
            int startIdx = fmax(tdScopeView.visiblePlotMin.x, 0.0) * audioController.sampleRate;
            int endIdx = fmin(tdScopeView.visiblePlotMax.x * audioController.sampleRate, audioController.recordingBufferLengthFrames);
            
            float *freqs = (float *)malloc(audioController.fftSize/2 * sizeof(float));
            [self linspace:0
                       max:audioController.sampleRate/2
               numElements:audioController.fftSize/2
                     array:freqs];
            
            /* Allocate wet/dry signal buffers */
            float *visibleSpec = (float *)malloc(audioController.fftSize/2 * sizeof(float));
            
            /* Get current visible samples from the audio controller */
            [audioController getAverageSpectrum:visibleSpec from:startIdx to:endIdx];
            
            [fdScopeView setCoordinatesInFDModeAtIndex:fdIdx
                                            withLength:audioController.fftSize/2
                                                 xData:freqs
                                                 yData:visibleSpec];
            
            free(freqs);
            free(visibleSpec);
        }
        
        /* Otherwise, plot the spectrum of the current audio buffer */
        else {
            /* Get buffer of times for each sample */
            plotTimes = (float *)malloc(audioController.bufferSizeFrames * sizeof(float));
            [self linspace:0.0 max:(audioController.bufferSizeFrames * audioController.sampleRate) numElements:audioController.bufferSizeFrames array:plotTimes];
            
            /* Allocate wet/dry signal buffers */
            float *yBuffer = (float *)malloc(audioController.bufferSizeFrames * sizeof(float));
            
            /* Get current visible samples from the audio controller */
            [audioController getInputBuffer:yBuffer withLength:audioController.bufferSizeFrames];
            
            [fdScopeView setPlotDataAtIndex:fdIdx
                                 withLength:audioController.bufferSizeFrames
                                      xData:plotTimes
                                      yData:yBuffer];
            free(plotTimes);
            free(yBuffer);
        }
    }
}

#pragma mark - Audio
- (void)toggleInput {
    
    if ([audioController inputEnabled]) [self disableInput];
    else [self enableInput];
    
    /* Flash animation on the time-domain plot */
    [self flashInFrame:tdScopeView.frame];
}

- (void)enableInput {
    
    inputPaused = false;
    [audioController setInputEnabled:true];
    
    /* Shift plot bounds back to the previous bounds */
    [tdScopeView setVisibleXLim:previousTMin max:previousTMax];
    
    /* Update the visible limits on the audioController for processing visible audio offline */
    [audioController setVisibleRangeInSeconds:fmaxf(0.0f, tdScopeView.visiblePlotMin.x) max:tdScopeView.visiblePlotMax.x];
    
    /* Zoom into the future when enabled */
    [tdScopeView setPinchZoomMode:kMETScopeViewPinchZoomHoldMin];
    
    [self hidePlayhead];
}

- (void)disableInput {
    
    /* Save previous plot bounds */
    previousTMin = [tdScopeView visiblePlotMin].x;
    previousTMax = [tdScopeView visiblePlotMax].x;
    
    inputPaused = true;
    [audioController setInputEnabled:false];
    
    [audioController computeFFTs];
    
    /* Keep the current plot range, but shift it to the end of the recording buffer */
    [tdScopeView setVisibleXLim:((audioController.recordingBufferLengthFrames-10) / audioController.sampleRate) - (tdScopeView.visiblePlotMax.x - tdScopeView.visiblePlotMin.x)
                            max:(audioController.recordingBufferLengthFrames-10) / audioController.sampleRate];
    
    /* Update the visible limits on the audioController for processing visible audio offline */
    [audioController setVisibleRangeInSeconds:fmaxf(0.0f, tdScopeView.visiblePlotMin.x) max:tdScopeView.visiblePlotMax.x];
    
    /* Zoom into the past when paused */
    [tdScopeView setPinchZoomMode:kMETScopeViewPinchZoomHoldMax];
    
    [self showPlayhead];
    [self updateTDScope];
}

- (void)toggleOutput {

//    if (audioController.outputEnabled) {
//        [audioController setOutputEnabled:false];
//        previousPostGain = [audioController outputGain];
//    }
//    else {
//        [audioController setOutputEnabled:true];
//    }
}

//#pragma mark - Gesture handling
//- (void)handleTDTap:(UITapGestureRecognizer *)sender {
//    [self toggleInput];
//}

- (CGFloat)getVisibleTMin {
    return [tdScopeView visiblePlotMin].x;
}

- (CGFloat)getVisibleTMax {
    return [tdScopeView visiblePlotMax].x;
}

#pragma mark - AudioPlaybackDelegate Methods
- (void)playbackPositionChanged:(CGFloat)time {
    dispatch_async(dispatch_get_main_queue(),^{
        [playhead setValues:CGPointMake(time, 1.0)];
        [tdControlArray setNeedsDisplay];
    });
}

- (void)playbackEnded {
    dispatch_async(dispatch_get_main_queue(),^{
        [playhead setValues:CGPointMake(tdScopeView.visiblePlotMin.x, 1.0)];
        [tdControlArray setNeedsDisplay];
    });
}

- (void)showPlayhead {
    [playhead setValues:CGPointMake(tdScopeView.visiblePlotMin.x, 1.0)];
    [playhead setHidden:false];
}

- (void)hidePlayhead {
    [playhead setHidden:true];
}

#pragma mark - METScopeViewDelegate Methods
- (void)pinchBegan:(METScopeView*)sender {
    
    /* Throttle time and spectrum plot updates based on the visible bounds of the time-domain plot (longer time-scales are more computationally intensive to plot, so throttle the plots more for longer scales) */
    float rate = 500 * (tdScopeView.visiblePlotMax.x - tdScopeView.visiblePlotMin.x) * [tdScopeClock timeInterval] + 30 * [tdScopeClock timeInterval];
    [self setTDUpdateRate:rate];
    [self setFDUpdateRate:rate/2];
    
    if (sender.displayMode == kMETScopeViewTimeDomainMode) {
        
        /* Update the visible limits on the audioController for processing visible audio offline */
        [audioController setVisibleRangeInSeconds:fmaxf(0.0f, tdScopeView.visiblePlotMin.x) max:tdScopeView.visiblePlotMax.x];
        
        [self tdScopeBoundsChanged];
    }
    
    else {
        
    }
}

- (void)pinchUpdate:(METScopeView*)sender {
    
    if (sender.displayMode == kMETScopeViewTimeDomainMode) {
        
        /* Update the visible limits on the audioController for processing visible audio offline */
        [audioController setVisibleRangeInSeconds:fmaxf(0.0f, tdScopeView.visiblePlotMin.x) max:tdScopeView.visiblePlotMax.x];
        
        [self tdScopeBoundsChanged];
    }
}

- (void)pinchEnded:(METScopeView*)sender {
    
    if (sender.displayMode == kMETScopeViewTimeDomainMode) {
        
        /* Update the visible limits on the audioController for processing visible audio offline */
        [audioController setVisibleRangeInSeconds:fmaxf(0.0f, tdScopeView.visiblePlotMin.x) max:tdScopeView.visiblePlotMax.x];
        
        [self tdScopeBoundsChanged];
    }
    
    /* Return time and spectrum plot updates to default rate */
    [self setTDUpdateRate:kAnalysisScopeUpdateRate];
    [self setFDUpdateRate:kAnalysisScopeUpdateRate];
}

- (void)panBegan:(METScopeView*)sender {
    
    /* Throttle time and spectrum plot updates based on the visible bounds of the time-domain plot (longer time-scales are more computationally intensive to plot, so throttle the plots more for longer scales) */
    float rate = 500 * (tdScopeView.visiblePlotMax.x - tdScopeView.visiblePlotMin.x) * [tdScopeClock timeInterval] + 30 * [tdScopeClock timeInterval];
    [self setTDUpdateRate:rate];
    [self setFDUpdateRate:rate/2];
    
    if (sender.displayMode == kMETScopeViewTimeDomainMode) {
        
        /* Update the visible limits on the audioController for processing visible audio offline */
        [audioController setVisibleRangeInSeconds:fmaxf(0.0f, tdScopeView.visiblePlotMin.x) max:tdScopeView.visiblePlotMax.x];
        
        [self tdScopeBoundsChanged];
    }
}

- (void)panUpdate:(METScopeView*)sender {
    
    if (sender.displayMode == kMETScopeViewTimeDomainMode) {
        
        /* Update the visible limits on the audioController for processing visible audio offline */
        [audioController setVisibleRangeInSeconds:fmaxf(0.0f, tdScopeView.visiblePlotMin.x) max:tdScopeView.visiblePlotMax.x];
        
        [self tdScopeBoundsChanged];
    }
}

- (void)panEnded:(METScopeView*)sender {
    
    if (sender.displayMode == kMETScopeViewTimeDomainMode) {
        
        /* Update the visible limits on the audioController for processing visible audio offline */
        [audioController setVisibleRangeInSeconds:fmaxf(0.0f, tdScopeView.visiblePlotMin.x) max:tdScopeView.visiblePlotMax.x];
        
        [self tdScopeBoundsChanged];
    }
    
    /* Return time and spectrum plot updates to default rate */
    [self setTDUpdateRate:kAnalysisScopeUpdateRate];
    [self setFDUpdateRate:kAnalysisScopeUpdateRate];
}

- (void)tdScopeBoundsChanged {
    dispatch_async(dispatch_get_main_queue(),^{
        [playhead setValues:CGPointMake(tdScopeView.visiblePlotMin.x, 1.0)];
        [tdControlArray setNeedsDisplay];
    });
//    [playhead setHorizontalRange:tdScopeView.visiblePlotMin.x
//                             max:tdScopeView.visiblePlotMax.x];
//    [playhead setValues:CGPointMake(tdScopeView.visiblePlotMin.x, 1.0)];
}

#pragma mark - METControlArrayDelegate Methods
- (void)parameterDotTouchDown:(METControl *)sender {
    
}

- (void)parameterDotValuesChanged:(METControl *)sender {
    
    NSLog(@"%s: sender.value = (%f, %f)", __func__, sender.values.x, sender.values.y);
    
}

- (void)parameterDotTouchUp:(METControl *)sender {
    
}



@end
