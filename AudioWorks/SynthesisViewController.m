//
//  SynthesisViewController.m
//  AudioWorks
//
//  Created by Jeff Gregorio on 6/24/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import "SynthesisViewController.h"
#import "AppDelegate.h"

@interface SynthesisViewController ()

@end

@implementation SynthesisViewController

@synthesize helpDisplayed;
@synthesize audioController;
@synthesize harmonicInfoView;
@synthesize midiNoteControlEnabled;

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
    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    audioController = [delegate audioController];
    
    /* Fundamental frequency control */
    [fundamentalSlider setRange:20.0f max:1000.0f];
    [fundamentalSlider setValue:440.0f];
    [fundamentalSlider setTabRadiusScalar:0.35f];
    usingWavetable = false;
    
    /* Fundamental frequency label */
    [fundamentalLabel setText:[NSString stringWithFormat:@"%5.1f", fundamentalSlider.value]];
    
    /* ----------------------------------------------------- */
    /* == Setup for time and frequency domain scope views == */
    /* ----------------------------------------------------- */
//    CGFloat minRange = (audioController.bufferSizeFrames+10) / audioController.sampleRate / 2.0f;
    CGFloat minRange = 1.0f / fundamentalSlider.maxValue;
    CGFloat maxRange = (audioController.recordingBufferLengthFrames-10) / audioController.sampleRate;
    maxRange *= 0.9f;
    
    [tdScopeView setPlotResolution:tdScopeView.frame.size.width];
    [tdScopeView setMinPlotRange:CGPointMake(minRange + 0.00001f, 0.1f)];
    [tdScopeView setMaxPlotRange:CGPointMake(maxRange + 0.00001f, 2.0f)];
    [tdScopeView setHardXLim:-0.00001f max:maxRange];
    [tdScopeView setXGridAutoScale:true];
    [tdScopeView setYGridAutoScale:true];
    [tdScopeView setVisibleXLim:-0.00001f max:audioController.bufferSizeFrames / audioController.sampleRate];
    [tdScopeView setXLabelPosition:kMETScopeViewXLabelsOutsideBelow];
    [tdScopeView setYLabelPosition:kMETScopeViewYLabelsOutsideLeft];
    [tdScopeView setDelegate:self];
    
    [tdScopeView addPlotWithColor:[UIColor blueColor] lineWidth:2.0];
    
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
    
    [fdScopeView addPlotWithColor:[UIColor blueColor] lineWidth:2.0];
    
    /* ---------------------- */
    /* == Drawing selector == */
    /* ---------------------- */
    
    CGRect frame;
    
    NSArray *options = @[@"Draw Waveform", @"Draw Envelope"];
    drawSelector = [[UISegmentedControl alloc] initWithItems:options];
    [drawSelector addTarget:self action:@selector(beginDrawing:) forControlEvents:UIControlEventValueChanged];
    frame = drawSelector.frame;
    frame.origin.x += tdScopeView.frame.size.width - frame.size.width - 2.0f;
    frame.origin.y += 4.0f;
    [drawSelector setFrame:frame];
    [tdScopeView addSubview:drawSelector];
    [[drawSelector layer] setBackgroundColor:[UIColor whiteColor].CGColor];
    
    /* --------------------- */
    /* == Draw View Setup == */
    /* --------------------- */
    
    frame = tdScopeView.frame;
    frame.size.width -= kWavetablePadLength;     // Don't go to edge of screen. Touches will be missed.
    drawView = [[FunctionDrawView alloc] initWithFrame:frame];
    drawingEnvelope = drawingWaveform = false;
    
    /* Done drawing button */
    frame.size.height = 40;
    frame.size.width = 100;
    frame.origin.x = tdScopeView.frame.size.width - frame.size.width - 6;
    frame.origin.y = 6;
    finishDrawingButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [finishDrawingButton setBackgroundColor:[UIColor whiteColor]];
    [[finishDrawingButton layer] setBorderWidth:1.0f];
    [[finishDrawingButton layer] setBorderColor:[[UIColor blueColor] colorWithAlphaComponent:0.1f].CGColor];
    [finishDrawingButton setFrame:frame];
    [finishDrawingButton setTitle:@"Done" forState:UIControlStateNormal];
    [finishDrawingButton addTarget:self action:@selector(endDrawing) forControlEvents:UIControlEventTouchUpInside];
    [drawView addSubview:finishDrawingButton];
    
    [[self view] addSubview:drawView];
    [drawView setHidden:true];
    
    /* ------------------------ */
    /* == Harmonic Dot Array == */
    /* ------------------------ */
    
//    UIColor *audioWorksBlue = [UIColor colorWithRed:kAudioWorksBlue_R
//                                              green:kAudioWorksBlue_G
//                                               blue:kAudioWorksBlue_B
//                                              alpha:1.0f];
    
    harmonicDots = [[HarmonicDotArray alloc] initWithParentScope:fdScopeView];
    [harmonicDots setFundamentalFreq:[fundamentalSlider value]];
    [harmonicDots setGainScalar:[delegate preGainSlider].value];
    
    /* Harmonic Dot Setup */
    for (int i = 1; i <= kNumHarmonics; i++) {
        [harmonicDots addHarmonicWithAmplitude:[audioController synthGetAmplitudeForHarmonic:i] * [audioController inputGain]];
    }
    
    [fdScopeView addSubview:harmonicDots];
    [harmonicDots setDelegate:self];
    [harmonicDots setEditable:true];
    
    /* In wavetable mode, harmonic dots are positioned based on amplitudes estimated from the FFT. Rather than a single estimate, the amplitude should be set based on a running average of the last N estimates */
    for (int i = 0; i < kNumHarmonics; i++) {
        for (int j = 0; j < kNumHarmonicEstimates; j++) {
            previousHarmonicEstimates[i][j] = 0.0;
        }
    }
    
    /* -------------------------------------- */
    /* == Harmonic/Noise Information Views == */
    /* -------------------------------------- */
    
    /* Create the harmonic parameter info view */
    frame.size.height = 70.0;
    frame.size.width = 200.0;
    frame.origin.y = 0.0;
    frame.origin.x = 0.0;
    harmonicInfoView = [[ParameterView alloc] initWithFrame:frame boundingFrame:fdScopeView.frame];
    
    /* Add the information view to the FD scope and hide until a parameter changes */
    [fdScopeView addSubview:harmonicInfoView];
    [harmonicInfoView setHidden:true];
    
    /* Noise info view */
    frame.size.height = 70.0;
    frame.size.width = 150.0;
    frame.origin.y = 0.0;
    frame.origin.x = 0.0;
    
    noiseInfoView = [[UIView alloc] initWithFrame:frame];
    [noiseInfoView setBackgroundColor:[[UIColor whiteColor] colorWithAlphaComponent:0.8f]];
    [[noiseInfoView layer] setBorderWidth:1.0f];
    [[noiseInfoView layer] setBorderColor:[[UIColor blueColor] colorWithAlphaComponent:0.1f].CGColor];
    [fdScopeView addSubview:noiseInfoView];
    
    /* Add the parameter label */
    frame.origin.x = 5;
    frame.origin.y = 5;
    frame.size.width = 135;
    frame.size.height = 30;
    
    UILabel *noiseAmpParamLabel = [[UILabel alloc] initWithFrame:frame];
    [noiseAmpParamLabel setText:@"Noise Amplitude: "];
    [noiseAmpParamLabel setTextAlignment:NSTextAlignmentRight];
    [noiseInfoView addSubview:noiseAmpParamLabel];
    
    /* And its value */
    frame.origin.y += frame.size.height;
    noiseAmpValueLabel = [[UILabel alloc] initWithFrame:frame];
    [noiseAmpValueLabel setText:[NSString stringWithFormat:@"%5.1f dB", 0.0f]];
    [noiseAmpValueLabel setTextAlignment:NSTextAlignmentRight];
    [noiseInfoView addSubview:noiseAmpValueLabel];
    
    [noiseInfoView setHidden:true];     // Hide until noise slider changes
    
    /* -------------------------------- */
    /* == Harmonic Amplitude Presets == */
    /* -------------------------------- */
    
    NSArray *presets = @[@"Sine", @"\"Square\"", @"\"Saw\"", @"Manual"];
    presetSelector = [[UISegmentedControl alloc] initWithItems:presets];
    [presetSelector addTarget:self action:@selector(setHarmonicPreset:) forControlEvents:UIControlEventValueChanged];
    frame = presetSelector.frame;
    frame.origin.x += fdScopeView.frame.size.width - frame.size.width - 2.0f;
    frame.origin.y += 4.0f;
    [presetSelector setFrame:frame];
    [presetSelector setSelectedSegmentIndex:0];
    previouslySelectedPreset = [presetSelector selectedSegmentIndex];
    [[presetSelector layer] setBackgroundColor:[UIColor whiteColor].CGColor];
    [fdScopeView addSubview:presetSelector];
    
    previousHarmonics[0] = -6.0;
    for (int i = 1; i < kNumHarmonics; i++)
        previousHarmonics[i] = -80.0;
    
    /* ------------------ */
    /* === Help Setup === */
    /* ------------------ */
    
    helpDisplayed = false;
    helpBubbles = [[NSMutableArray alloc] init];
    helpBubblesDrawingWaveform = [[NSMutableArray alloc] init];
    helpBubblesDrawingEnvelope = [[NSMutableArray alloc] init];
    helpBubblesUsingWavetable = [[NSMutableArray alloc] init];
    HelpBubble *bbl;
    
    /* Harmonic Preset Selector Description */
    CGPoint origin;
    origin.x = presetSelector.frame.origin.x + fdScopeView.frame.origin.x + 30.0f;
    origin.y = presetSelector.frame.origin.y + fdScopeView.frame.origin.y + 40.0f;
    bbl = [[HelpBubble alloc] initWithText:@"This additive synthesizer creates tones by adding harmonics (sine waves) together at specific amplitudes.\n\nSelect a harmonic preset or adjust harmonics manually."
                                    origin:origin
                                     width:presetSelector.frame.size.width - 40.0f
                                 alignment:NSTextAlignmentLeft];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    [[self view] addSubview:bbl];
    [helpBubbles addObject:bbl];
    [bbl setHidden:true];
    
    /* Synth to effects routing instructions */
    origin.x = fdScopeView.frame.origin.x + 75.0f;
    origin.y = [delegate navigationView].frame.size.height + 10.0f;
    bbl = [[HelpBubble alloc] initWithText:@"Press Synthesis and Effects simultaneously to apply effects to synthesized tones"
                                                origin:origin
                                                 width:250.0f
                                             alignment:NSTextAlignmentLeft];
    [bbl setPointerLocation:kHelpBubblePointerLocationTop];
    [[self view] addSubview:bbl];
    [helpBubbles addObject:bbl];
//    [helpBubblesUsingWavetable addObject:bbl];
    [bbl setHidden:true];
    
    /* Waveform/Envelope drawing instructions */
    origin.x = drawSelector.frame.origin.x + tdScopeView.frame.origin.x;
    origin.y = drawSelector.frame.origin.y + drawSelector.frame.size.height + tdScopeView.frame.origin.y + 5.0f;
    bbl = [[HelpBubble alloc] initWithText:@"Press to draw one period of a waveform or a 2-second amplitude envelope"
                                    origin:origin
                                     width:drawSelector.frame.size.width
                                 alignment:NSTextAlignmentLeft];
    [bbl setPointerLocation:kHelpBubblePointerLocationTop];
    [[self view] addSubview:bbl];
    [helpBubbles addObject:bbl];
//    [helpBubblesUsingWavetable addObject:bbl];
    [bbl setHidden:true];
    
    /* Waveform drawing instructions */
    origin = tdScopeView.frame.origin;
    bbl = [[HelpBubble alloc] initWithText:@"Draw one period of a waveform with one finger, then press \"Done\" to activate the wavetable synth. Press \"Done\" without drawing to cancel."
                                    origin:origin
                                     width:250.0f
                                 alignment:NSTextAlignmentLeft];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    frame = bbl.frame;
    frame.origin.y += tdScopeView.frame.size.height - frame.size.height - 20.0f;
    frame.origin.x += 20.0f;
    [bbl setFrame:frame];
    [[self view] addSubview:bbl];
    [helpBubblesDrawingWaveform addObject:bbl];
    [bbl setHidden:true];
    
    /* Envelope drawing instructions */
    origin = tdScopeView.frame.origin;
    bbl = [[HelpBubble alloc] initWithText:@"Draw an amplitude envelope with one finger, then press \"Done\" to apply it. Press \"Done\" without drawing to return to a constant amplitude."
                                    origin:origin
                                     width:250.0f
                                 alignment:NSTextAlignmentLeft];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    frame = bbl.frame;
    frame.origin.y += tdScopeView.frame.size.height - frame.size.height - 20.0f;
    frame.origin.x += 20.0f;
    [bbl setFrame:frame];
    [[self view] addSubview:bbl];
    [helpBubblesDrawingEnvelope addObject:bbl];
    [bbl setHidden:true];
    
    /* Wavetable synth harmonic estimates description */
    origin.x = presetSelector.frame.origin.x + fdScopeView.frame.origin.x + 30.0f;
    origin.y = presetSelector.frame.origin.y + fdScopeView.frame.origin.y + 40.0f;
    bbl = [[HelpBubble alloc] initWithText:@"The synth is now estimating the first 12 harmonic amplitudes for your waveform.\n\nAdjust any of the harmonics to return to additive synthesis using these amplitude estimates."
                                    origin:origin
                                     width:presetSelector.frame.size.width - 40.0f
                                 alignment:NSTextAlignmentLeft];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    [[self view] addSubview:bbl];
    [helpBubblesUsingWavetable addObject:bbl];
    [bbl setHidden:true];
    
    /* MIDI */
    midiNoteControlEnabled = false;
    midiDebugLabel = [[UILabel alloc] initWithFrame:CGRectMake(200, 200, 200, 200)];
    [tdScopeView addSubview:midiDebugLabel];
}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    
    /* Get a reference to the AudioController from the AppDelegate */
    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    audioController = [delegate audioController];
    
    [audioController setSynthEnabled:true];
    [audioController synthSetFundamental:fundamentalSlider.value];
    if (![audioController synthWavetableEnabled]) [audioController synthSetAdditiveEnabled];
    else [audioController synthSetWavetableEnabled];
    
    [audioController setInputGain:[delegate preGainSlider].value];
    [harmonicDots setGainScalar:[delegate preGainSlider].value];
    
    /* Set the scope clocks */
    [self setTDScopeUpdateRate:kSynthesisPlotUpdateRate];
    [self setFDScopeUpdateRate:kSynthesisPlotUpdateRate];
    tdHold = false;
    fdHold = false;
    
    /* Display the help if the App Delegate's help button is active */
    if ([delegate helpDisplayed] != helpDisplayed)
        [self toggleHelp];
    
    /* Make sure we're not paused */
    if (![audioController inputEnabled])
        [audioController setInputEnabled:true];
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

#pragma mark - Scope Updates
- (void)setTDScopeUpdateRate:(float)rate {
    
    if ([tdScopeClock isValid])
        [tdScopeClock invalidate];
    
    tdScopeClock = [NSTimer scheduledTimerWithTimeInterval:rate
                                                     target:self
                                                   selector:@selector(updateTDScope)
                                                   userInfo:nil
                                                    repeats:YES];
}

- (void)setFDScopeUpdateRate:(float)rate {
    
    if ([fdScopeClock isValid])
        [fdScopeClock invalidate];
    
    fdScopeClock = [NSTimer scheduledTimerWithTimeInterval:rate
                                                     target:self
                                                   selector:@selector(updateFDScope)
                                                   userInfo:nil
                                                    repeats:YES];
}

- (void)updateTDScope {
    
    if (tdHold)
        return;
    
    /* Extend the time duration we're retrieving from the recording buffer to compensate for the phaze zero offset. Lower fundamental frequencies have larger offsets due to longer wavelengths. */
    float periodsInView = (tdScopeView.visiblePlotMax.x-tdScopeView.visiblePlotMin.x) * [audioController synthFundamental];
    float maxScale = 1.1;
    
    if (periodsInView < 2.0)
        maxScale = 3.0;
    else if (periodsInView < 5.0)
        maxScale = 2.0;
    else if (periodsInView < 7.0)
        maxScale = 1.5;
    else if (periodsInView < 10.0)
        maxScale = 1.2;
    
    if ([audioController synthWavetableEnabled])
        maxScale *= 2.0;
    
    int startIdx = fmax(tdScopeView.visiblePlotMin.x, 0.0) * audioController.sampleRate;
    int endIdx = (tdScopeView.visiblePlotMax.x * maxScale) * audioController.sampleRate;
    int length = endIdx - startIdx;
    
    /* Update the plots if we're not pinching or panning */
    if (!tdScopeView.currentPan && !tdScopeView.currentPinch) {
        
        /* Get buffer of times for each sample */
        float *plotXVals = (float *)malloc(length * sizeof(float));
        [self linspace:fmax(tdScopeView.visiblePlotMin.x, 0.0)
                   max:tdScopeView.visiblePlotMax.x * maxScale
           numElements:length
                 array:plotXVals];
        
        /* Allocate signal buffers */
        float *plotYVals = (float *)malloc(length * sizeof(float));
        
        /* Get current visible samples from the audio controller */
        [audioController getInputBuffer:plotYVals withLength:length offset:audioController.phaseZeroOffset];
        
        [tdScopeView setPlotDataAtIndex:0
                             withLength:length
                                  xData:plotXVals
                                  yData:plotYVals];
        free(plotXVals);
        free(plotYVals);
    }
}

- (void)updateFDScope {
    
    if (fdHold)
        return;
    
    int length = audioController.bufferSizeFrames;
    
    /* Update the plots if we're not pinching or panning */
    if (!fdScopeView.currentPan && !fdScopeView.currentPinch) {
        
        /* Get buffer of times for each sample */
        float *plotXVals = (float *)malloc(length * sizeof(float));
        [self linspace:fmax(fdScopeView.visiblePlotMin.x, 0.0)
                   max:fdScopeView.visiblePlotMax.x
           numElements:length
                 array:plotXVals];
        
        /* Allocate signal buffers */
        float *plotYVals = (float *)malloc(length * sizeof(float));
        
        /* Get current visible samples from the audio controller */
        [audioController getInputBuffer:plotYVals withLength:length];
        
        [fdScopeView setPlotDataAtIndex:0
                             withLength:length
                                  xData:plotXVals
                                  yData:plotYVals];
        free(plotXVals);
        free(plotYVals);
    }
    
    if ([audioController synthWavetableEnabled])
        [self positionHarmonicDotsFromScopeFFT];
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
}

- (void)disableInput {
    inputPaused = true;
    [audioController setInputEnabled:false];
}

- (CGFloat)getVisibleTMin {
    return [tdScopeView visiblePlotMin].x;
}

- (CGFloat)getVisibleTMax {
    return [tdScopeView visiblePlotMax].x;
}


#pragma mark - Synth Parameter Updates
- (IBAction)updateFundamental:(id)sender {
    
    /* Update the synths' fundamentals */
    [audioController synthSetFundamental:fundamentalSlider.value];
    
    /* Update the label */
    [fundamentalLabel setText:[NSString stringWithFormat:@"%5.1f", fundamentalSlider.value]];
    
    /* Update the harmonic dots */
    [harmonicDots setFundamentalFreq:fundamentalSlider.value];
    
    if ([audioController synthWavetableEnabled])
        [self positionHarmonicDotsFromScopeFFT];
}

- (void)setFundamental:(float)f0 {
    
    [fundamentalSlider setValue:f0];
    [self updateFundamental:self];
}

- (void)touchDownOnHarmonic:(int)num {
    
    int harmonicNum = num;
    CGFloat dbAmp = [harmonicDots getAmplitudeForHarmonicNum:num];
    
    /* Update the harmonic info view's location/values and make it visible */
    [harmonicInfoView setLeaderFrame:[harmonicDots getActiveDotFrame]];
    [harmonicInfoView setFreq:fundamentalSlider.value * harmonicNum];
    [harmonicInfoView setAmp:dbAmp];
    [harmonicInfoView setHidden:false];
    
//    NSLog(@"%s : %@", __PRETTY_FUNCTION__, harmonicInfoView);
//    
//    NSLog(@"%s : num = %d, amp = %f", __PRETTY_FUNCTION__, harmonicNum, linearAmp);
//    NSLog(@"%s : org.x = %f, org.y = %f, size.w = %f, size.h = %f", __PRETTY_FUNCTION__, infoViewFrame.origin.x, infoViewFrame.origin.y, infoViewFrame.size.width, infoViewFrame.size.height);
}

- (void)touchDownOnNoiseSlider {
    
    CGFloat linearAmp = [audioController synthGetNoiseAmplitude];
    
    CGRect infoViewFrame = noiseInfoView.frame;
    infoViewFrame.origin.y = linearAmp;
    infoViewFrame.origin.x = 0.0;
    infoViewFrame.origin = [fdScopeView plotScaleToPixel:infoViewFrame.origin];
    infoViewFrame.origin.x = fdScopeView.frame.size.width - infoViewFrame.size.width - 60.0f;
    infoViewFrame.origin.y -= (infoViewFrame.size.height / 2.0f);
    
    /* Keep the info view frame in the FD scope */
    if (infoViewFrame.origin.y < 0.0)
        infoViewFrame.origin.y = 0.0;
    if ((infoViewFrame.origin.y + infoViewFrame.size.height) > fdScopeView.frame.size.height)
        infoViewFrame.origin.y = fdScopeView.frame.size.height - infoViewFrame.size.height;
    if (infoViewFrame.origin.x < 0.0)
        infoViewFrame.origin.x = 0.0;
    if ((infoViewFrame.origin.x + infoViewFrame.size.width) > fdScopeView.frame.size.width)
        infoViewFrame.origin.x = fdScopeView.frame.size.width - infoViewFrame.size.width;
    
    /* Update the noise info view's location/values and make it visible */
    [noiseAmpValueLabel setText:[NSString stringWithFormat:@"%3.1f dB", 20.0f * log10f(linearAmp + 0.0001f)]];
    [noiseInfoView setFrame:infoViewFrame];
    [noiseInfoView setHidden:false];
    
}

- (void)valueChangedForHarmonic:(int)num linearAmp:(CGFloat)val {
    
//    NSLog(@"%s : %@", __PRETTY_FUNCTION__, harmonicInfoView);

    int harmonicNum = num;
    CGFloat linearAmp = val;
    
    /* If we're updating a harmonic amplitude */
    if (harmonicNum <= kNumHarmonics) {
        
        /* Find the "Manual" item and select it if it is not already */
        if ([presetSelector selectedSegmentIndex] == UISegmentedControlNoSegment || ![[presetSelector titleForSegmentAtIndex:[presetSelector selectedSegmentIndex]] isEqualToString:@"Manual"]) {
            for (int i = 0; i < [presetSelector numberOfSegments]; i++) {
                if ([[presetSelector titleForSegmentAtIndex:i] isEqualToString:@"Manual"]) {
                    [presetSelector setSelectedSegmentIndex:i];
                    previouslySelectedPreset = i;
                }
            }
        }
        
        /* If we're in wavetable mode, save the current harmonic amplitude estimates and reset */
        if ([audioController synthWavetableEnabled]) {
            for (int i = 0; i < [harmonicDots numHarmonics]; i++) {
                previousHarmonics[i] = [harmonicDots getAmplitudeForHarmonicNum:i+1];
            }
            [self setHarmonicPreset:presetSelector];
        }
        
        /* Update the additive synth */
        linearAmp = linearAmp > 1.0f ? 1.0f : linearAmp;
        linearAmp = linearAmp < 0.0f ? 0.0f : linearAmp;
        [audioController synthSetAmplitude:linearAmp forHarmonic:harmonicNum-1];
        
        /* Update the harmonic info view's location/values */
        [harmonicInfoView setLeaderFrame:[harmonicDots getActiveDotFrame]];
        [harmonicInfoView setFreq:fundamentalSlider.value * harmonicNum];
        [harmonicInfoView setAmp:20.0 * log10f(linearAmp + 0.0001f)];
        
        /* Make sure we're in additive synth mode */
        if ([audioController synthWavetableEnabled]) {
            [audioController synthSetAdditiveEnabled];
            usingWavetable = false;
        }
    }
}

- (void)noiseAmplitudeChanged:(CGFloat)linearAmp {
    
    /* Update the synths */
    [audioController synthSetNoiseAmplitude:linearAmp];
    
    CGRect infoViewFrame = noiseInfoView.frame;
    infoViewFrame.origin.y = linearAmp;
    infoViewFrame.origin.x = 0.0;
    infoViewFrame.origin = [fdScopeView plotScaleToPixel:infoViewFrame.origin];
    infoViewFrame.origin.x = fdScopeView.frame.size.width - infoViewFrame.size.width - 60.0f;
    infoViewFrame.origin.y -= (infoViewFrame.size.height / 2.0f);
    
    /* Keep the info view frame in the FD scope */
    if (infoViewFrame.origin.y < 0.0)
        infoViewFrame.origin.y = 0.0;
    if ((infoViewFrame.origin.y + infoViewFrame.size.height) > fdScopeView.frame.size.height)
        infoViewFrame.origin.y = fdScopeView.frame.size.height - infoViewFrame.size.height;
    if (infoViewFrame.origin.x < 0.0)
        infoViewFrame.origin.x = 0.0;
    if ((infoViewFrame.origin.x + infoViewFrame.size.width) > fdScopeView.frame.size.width)
        infoViewFrame.origin.x = fdScopeView.frame.size.width - infoViewFrame.size.width;
    
    /* Update the noise info view's location/values and make it visible */
    [noiseAmpValueLabel setText:[NSString stringWithFormat:@"%3.1f dB", 20.0f * log10f(linearAmp + 0.0001f)]];
    [noiseInfoView setFrame:infoViewFrame];
    
//    if ([audioController synthWavetableEnabled]) [self positionHarmonicDotsFromScopeFFT];
}

- (void)harmonicDotArrayTouchEnded {
    
//    NSLog(@"%s : %@", __PRETTY_FUNCTION__, harmonicInfoView);
    [harmonicInfoView setHidden:true];
    [noiseInfoView setHidden:true];
}

- (void)inputGainChanged {
    [harmonicDots setGainScalar:[audioController inputGain]];
}

# pragma mark - MIDI Input Handling
- (void)setMidiNoteControlEnabled:(bool)enabled {
    midiNoteControlEnabled = enabled;
    if (midiNoteControlEnabled) {
        [audioController synthSetAmplitudeScalar:0.0f];
        [fundamentalSlider setEnabled:false];
    }
    else {
        [audioController synthSetAmplitudeScalar:1.0f];
        [fundamentalSlider setEnabled:true];
        [self updateFundamental:self];
    }
}

- (void)handleMIDINoteOff:(int)noteNum {
    noteVelocities[noteNum-1] = 0;
    [self updateNote];
}

- (void)handleMIDINoteOn:(int)noteNum velocity:(int)vel {
    noteVelocities[noteNum-1] = vel;
    [self updateNote];
}

- (void)handleProgramChange:(int)val {
    
    val = val % 4;
    dispatch_async(dispatch_get_main_queue(),^ {
        [presetSelector setSelectedSegmentIndex:val];
        [self setHarmonicPreset:presetSelector];
    });
}

- (void)handlePitchBend:(float)normVal {
    [audioController synthSetPitchBendVal:normVal];
}

- (void)updateNote {
    
    /* Find the lowest active note */
    int i = 0;
    while (i < 128 && noteVelocities[i] == 0) i++;
    
    /* If no notes are active, set amplitude to zero */
    if (i == 128) {
        [audioController synthSetAmplitudeScalar:0.0f];
        activeNoteIdx = -1;
        return;
    }
    
    /* Set the active note number and velocity */
    int noteNum = i+1;  // Array index to note number
    float f0 = 440.0 * powf(2.0, (noteNum-69)/12.0);
    int velocity = noteVelocities[i];
    [audioController synthSetFundamental:f0 ramp:false];
    [audioController synthSetAmplitudeScalar:(float)velocity/128.0f];
    [fundamentalLabel setText:[NSString stringWithFormat:@"%5.1f", f0]];
    
    if (activeNoteIdx == -1 || activeNoteIdx != i) {
        activeNoteIdx = i;
        [audioController synthRetriggerAmplitudeEnvelope];
    }
}

#pragma mark - Harmonic Presets
- (void)setHarmonicPreset:(UISegmentedControl *)sender  {
    
    NSString *selectedItem = [sender titleForSegmentAtIndex:[sender selectedSegmentIndex]];
    
    int nHarmonics = kNumHarmonics;
    
    /* If we're drawing a preset shape */
    if (![selectedItem isEqualToString:@"Manual"]) {
        
        /* Save the old harmonic amplitudes when exiting manual mode */
        if ([[sender titleForSegmentAtIndex:previouslySelectedPreset] isEqualToString:@"Manual"])
            [harmonicDots getAmplitudes:previousHarmonics forNumHarmonics:kNumHarmonics];
        
//        /* Use extra harmonics for non-sine presets */
//        if (![selectedItem isEqualToString:@"Sine"])
//            nHarmonics += 5;
    }
    
    float h[nHarmonics];
    [audioController synthSetNumHarmonics:nHarmonics];
    
    if ([selectedItem isEqualToString:@"Manual"]) {
        
        for (int i = 0; i < nHarmonics; i++)
            h[i] = previousHarmonics[i];
    }
    
    else if ([selectedItem isEqualToString:@"Sine"]) {
        h[0] = -6.0;
        for (int i = 1; i < nHarmonics; i++)
            h[i] = -80.0;
    }
    
    else if ([selectedItem isEqualToString:@"\"Saw\""]) {
        for (int i = 0; i < nHarmonics; i++) {
            h[i] = 0.3f / (float)(i+1);
            h[i] = 20.0f * log10f(h[i]);
        }
    }
    else if ([selectedItem isEqualToString:@"\"Square\""]) {
        for (int i = 0; i < nHarmonics; i++) {
            /* Odd index <--> even harmonic */
            if (i % 2 == 0) {
                h[i] = 0.5f / (float)(i+1);
                h[i] = 20.0f * log10f(h[i]);
            }
            else
                h[i] = -80.0;
        }
    }
    else
        return;
    
    /* Set the harmonic amplitudes */
    float linearAmp;
    for (int i = 0; i < nHarmonics; i++) {
        
        linearAmp = powf(10, h[i]/20.0);
        
        /* Update the harmonic dots */
        if (i < kNumHarmonics)
            [harmonicDots setAmplitude_dB:h[i] forHarmonic:i+1];
        
        [audioController synthSetAmplitude:linearAmp forHarmonic:i];
    }
    
    /* Make sure we're using the additive synth */
    if ([audioController synthWavetableEnabled]) {
        [audioController synthSetAdditiveEnabled];
        usingWavetable = false;
    }
    
    previouslySelectedPreset = [sender selectedSegmentIndex];
    [self updateHelp];
}

#pragma mark - Drawing
- (void)beginDrawing:(UISegmentedControl *)sender {
    
    NSString *selectedItem = [sender titleForSegmentAtIndex:[sender selectedSegmentIndex]];
    drawingWaveform = [selectedItem isEqualToString:@"Draw Waveform"];
    drawingEnvelope = [selectedItem isEqualToString:@"Draw Envelope"];
    
    if (!drawingEnvelope && !drawingWaveform)
        return;
    
    /* Deselect all presets if we're drawing a custom waveform */
    if (drawingWaveform && [presetSelector selectedSegmentIndex] != UISegmentedControlNoSegment) {
        previouslySelectedPreset = [presetSelector selectedSegmentIndex];
//        [presetSelector setSelectedSegmentIndex:UISegmentedControlNoSegment];
    }
    
    [drawView resetDrawing];
    
    /* If we're drawing an envelope, set the draw view to mirror across the x-axis */
    if (drawingEnvelope)
        [drawView setMirrorAcrossXAxis:true];
    else
        [drawView setMirrorAcrossXAxis:false];
    
    /* Save the old plot scaling parameters to reset them later */
    oldXMin = tdScopeView.visiblePlotMin.x;
    oldXMax = tdScopeView.visiblePlotMax.x;
    oldXGridScale = tdScopeView.tickUnits.x;
    
    /* Set the bounds on interval [0, xMax], where xMax is the length one period of the current f0 (to draw a waveform) or the length the recording buffer (to draw an amplitude envelope) */
    float newXMin = 0.0;
    float newXMax = oldXMax;
    if (drawingWaveform) newXMax = 1.0f / fundamentalSlider.value;
    else if (drawingEnvelope) newXMax = kMaxPlotMax;
    [tdScopeView setVisibleXLim:newXMin max:newXMax];
    
    /* Place the FunctionDrawView over the time domain scope */
    [tdScopeView setAlpha:0.5];
    [drawView setHidden:false];
    
    /* Remove the draw buttons from the plot while drawing; */
    [drawSelector setHidden:true];
    
    /* Disable the output enable switch and fundamental slider while drawing */
    [fundamentalSlider setEnabled:false];
    [presetSelector setEnabled:false];
    [harmonicDots setEnabled:false];
    [harmonicDots setAlpha:0.5];
    [fdScopeView setAlpha:0.5];
    
    if (drawingEnvelope)
        [self setTDScopeUpdateRate:kSynthesisPlotUpdateRate/4.0f];
    
    [self updateTDScope];
    tdHold = true;
    [self updateHelp];
}

- (void)endDrawing {
    
    /* --------------------- */
    /* == Drawn Waveform === */
    /* --------------------- */
    if (drawingWaveform) {
        drawingWaveform = false;
        
        /* If the drawView was modified... */
        if ([drawView hasDrawnFunction]) {
            
            if ([presetSelector selectedSegmentIndex] != UISegmentedControlNoSegment)
                previouslySelectedPreset = [presetSelector selectedSegmentIndex];
            
            /* If we're exiting manual harmonics mode, save the amplitudes */
            if ([[presetSelector titleForSegmentAtIndex:previouslySelectedPreset] isEqualToString:@"Manual"]) {
                [harmonicDots getAmplitudes:previousHarmonics forNumHarmonics:kNumHarmonics];
            }
            [presetSelector setSelectedSegmentIndex:UISegmentedControlNoSegment];
            
            /* Sample and send to the synth */
            [self sampleDrawnWaveform];
            [audioController synthSetWavetableEnabled];
            usingWavetable = true;
        }
    }
    
    /* --------------------- */
    /* == Drawn Envelope === */
    /* --------------------- */
    /* If we drew an amplitude envelope, sample and set it on the additive and wavetable synths */
    else if (drawingEnvelope) {
        drawingEnvelope = false;
        [self sampleDrawnEnvelope];
        [self setTDScopeUpdateRate:kSynthesisPlotUpdateRate];
    }
    
    /* Remove the function draw view */
    [drawView setHidden:true];
    
    /* Put the segmented control back */
    [tdScopeView setAlpha:1.0];
    [drawSelector setHidden:false];
    
    /* Set the time domain plot bounds to their original values before the tap */
    [tdScopeView setVisibleXLim:oldXMin max:oldXMax];
    [tdScopeView setPlotUnitsPerXTick:oldXGridScale];
    
    /* Re-enable disabled interface controls */
    [fundamentalSlider setEnabled:true];
    [presetSelector setEnabled:true];
    [harmonicDots setEnabled:true];
    [harmonicDots setAlpha:1];
    [fdScopeView setAlpha:1];
    
    /* Deselect both drawSelector buttons */
    [drawSelector setSelectedSegmentIndex:UISegmentedControlNoSegment];
    
    tdHold = false;
    [self updateHelp];
}

- (void)sampleDrawnEnvelope {
    
    if (![drawView hasDrawnFunction]) {
        [audioController synthResetAmplitudeEnvelope];
        return;
    }
    
    /* Get enough samples of the drawn envelope to cover the visible range of the plot */
    int envLength = (int)((tdScopeView.visiblePlotMax.x - tdScopeView.visiblePlotMin.x) * audioController.sampleRate);
    
    CGFloat *drawnEnvelope = (CGFloat *)calloc(envLength, sizeof(CGFloat));
    [drawView getDrawingWithLength:envLength pixelVals:drawnEnvelope];
    
    /* Convert to plot units */
    CGPoint p;
    for (int i = 0; i < envLength; i++) {
        p = [tdScopeView pixelToPlotScale:CGPointMake((CGFloat)i, drawnEnvelope[i])];
        drawnEnvelope[i] = p.y;
    }
    
    /* Set the envelope on the synths */
    [audioController synthSetAmplitudeEnvelope:drawnEnvelope length:envLength];
    free(drawnEnvelope);
}

- (void)sampleDrawnWaveform {
    
    /* Get a number of samples from the drawn waveform sufficient to represent the highest possible fundamental frequency */
    float upsampleFactor = fundamentalSlider.maxValue / fundamentalSlider.value;
    int wavetableLength = (int)(drawView.length * upsampleFactor * 3.0); // *3.0 is a hack
    
    /* Add a few extra samples to interpolate between starting and end points to smooth out discontinuities */
    wavetableLength += kWavetablePadLength;
    
    CGFloat *drawnWaveform = (CGFloat *)calloc(wavetableLength, sizeof(CGFloat));
    [drawView getDrawingWithLength:wavetableLength-kWavetablePadLength pixelVals:drawnWaveform];
    
    /* Convert pixel values to plot units */
    CGPoint p;
    for (int i = 0; i < wavetableLength-kWavetablePadLength; i++) {
        p = [tdScopeView pixelToPlotScale:CGPointMake((CGFloat)i, drawnWaveform[i])];
        drawnWaveform[i] = p.y;
    }
    
    int sampOffset = 2;
    
    /* Interpolate the extra samples ensuring continuity between the wave period's endpoints */
    CGFloat *wavetablePad = (CGFloat *)calloc(kWavetablePadLength+sampOffset, sizeof(CGFloat));
    [self CGlinspace:drawnWaveform[wavetableLength-kWavetablePadLength-sampOffset]
               max:drawnWaveform[0]
       numElements:kWavetablePadLength+sampOffset
             array:wavetablePad];
    
    for (int i = 0; i < kWavetablePadLength+sampOffset; i++) {
        drawnWaveform[wavetableLength-kWavetablePadLength-sampOffset+i] = wavetablePad[i];
    }
    
    [audioController synthSetWavetable:drawnWaveform length:wavetableLength];
    free(drawnWaveform);
    free(wavetablePad);
}

- (void)positionHarmonicDotsFromScopeFFT {
    
    /* Push old harmonic amplitude estimates back */
    for (int i = 0; i < kNumHarmonics; i++) {
        for (int j = 0; j < kNumHarmonicEstimates; j++)
            previousHarmonicEstimates[i][j] = previousHarmonicEstimates[i][j+1];
    }
    
    [audioController computeFFTs];
    
    /* Get the current amplitude estimates for each harmonic */
    CGFloat amp;
    CGFloat freq;
    for (int i = 1; i <= kNumHarmonics; i++) {
        freq = fundamentalSlider.value * i;
        amp = [audioController getFFTMagnitudeAtFrequency:freq];
        amp = 20.0f * log10f(amp + 0.0001f);
        amp = amp < -80.0f ? -80.0f : amp;
        amp = amp > 0.0f ? 0.0f : amp;
        previousHarmonicEstimates[i-1][kNumHarmonicEstimates-1] = amp;
    }
    
    /* Set the dot amplitudes based on the averaged position estimates */
    CGFloat meanAmp;
    for (int i = 0; i < kNumHarmonics; i++) {
        meanAmp = 0.0;
        for (int j = 0; j < kNumHarmonicEstimates; j++)
            meanAmp += previousHarmonicEstimates[i][j];
        meanAmp /= kNumHarmonicEstimates;
        [harmonicDots setAmplitude_dB:meanAmp forHarmonic:i+1];
    }
    
//    /* Position the noise slider based on estimated noise floor */
//    amp = [audioController getNoiseFloorMagnitude];
//    amp = amp < 0.0f ? 0.0f : amp;
//    amp = amp > 1.0f ? 1.0f : amp;
//    [harmonicDots setNoiseAmplitude:amp];
}


#pragma mark - METScopeviewDelegate methods
- (void)pinchBegan:(METScopeView *)sender {
    [harmonicDots plotBoundsChanged];
}

- (void)pinchEnded:(METScopeView *)sender {
    [harmonicDots plotBoundsChanged];
}

- (void)pinchUpdate:(METScopeView *)sender {
    [harmonicDots plotBoundsChanged];
}

- (void)panBegan:(METScopeView *)sender {
    [harmonicDots plotBoundsChanged];
}

- (void)panEnded:(METScopeView *)sender {
    [harmonicDots plotBoundsChanged];
}

- (void)panUpdate:(METScopeView *)sender {
    [harmonicDots plotBoundsChanged];
}

#pragma mark - Help
- (void)toggleHelp {
    helpDisplayed = !helpDisplayed;
    [self updateHelp];
}

- (void)updateHelp {
    
    for (int i = 0; i < [helpBubbles count]; i++)
        [[helpBubbles objectAtIndex:i] setHidden:true];
    for (int i = 0; i < [helpBubblesDrawingWaveform count]; i++)
        [[helpBubblesDrawingWaveform objectAtIndex:i] setHidden:true];
    for (int i = 0; i < [helpBubblesDrawingEnvelope count]; i++)
        [[helpBubblesDrawingEnvelope objectAtIndex:i] setHidden:true];
    for (int i = 0; i < [helpBubblesUsingWavetable count]; i++)
        [[helpBubblesUsingWavetable objectAtIndex:i] setHidden:true];

    if (helpDisplayed) {
        
        if (drawingWaveform) {
            for (int i = 0; i < [helpBubblesDrawingWaveform count]; i++)
                [[helpBubblesDrawingWaveform objectAtIndex:i] setHidden:false];
        }
        else if (drawingEnvelope) {
            for (int i = 0; i < [helpBubblesDrawingEnvelope count]; i++)
                [[helpBubblesDrawingEnvelope objectAtIndex:i] setHidden:false];
        }
        else if ([audioController synthWavetableEnabled]) {
            for (int i = 0; i < [helpBubblesUsingWavetable count]; i++)
                [[helpBubblesUsingWavetable objectAtIndex:i] setHidden:false];
        }
        else {
            for (int i = 0; i < [helpBubbles count]; i++)
                [[helpBubbles objectAtIndex:i] setHidden:false];
        }
    }
}

@end













