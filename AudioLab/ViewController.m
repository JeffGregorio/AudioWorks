//
//  ViewController.m
//  DigitalSoundFX
//
//  Created by Jeff Gregorio on 5/11/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import "ViewController.h"

@implementation ViewController

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[self view] setBackgroundColor:[UIColor whiteColor]];
    
    /* ----------------- */
    /* == Audio Setup == */
    /* ----------------- */
    audioController = [[AudioController alloc] init];
    
    /* Distortion */
    [audioController setDistortionEnabled:false];
    
    /* Filters */
    [audioController setLpfEnabled:false];
    [audioController setHpfEnabled:false];
    [audioController rescaleFilters:fdScopeView.visiblePlotMin.x max:fdScopeView.visiblePlotMax.x];
    
    /* Modulation */
    [audioController setModulationEnabled:false];
    [audioController setModFrequency:440.0f];
    
    /* Delay */
    [audioController setDelayEnabled:false];
    
    /* Gains */
    [self updatePreGain:self];
    [self updatePostGain:self];
    
    /* ----------------------------------------------------- */
    /* == Setup for time and frequency domain scope views == */
    /* ----------------------------------------------------- */
    [tdScopeView setPlotResolution:256];
    [tdScopeView setHardXLim:-0.00001f
                         max:audioController.recordingBufferLengthFrames/audioController.sampleRate];
    [tdScopeView setVisibleXLim:-0.00001f
                            max:audioController.bufferSizeFrames/audioController.sampleRate];
    [tdScopeView setPlotUnitsPerXTick:0.005f];
    [tdScopeView setMinPlotRange:CGPointMake(audioController.bufferSizeFrames/audioController.sampleRate/2.0f, 0.1f)];
    [tdScopeView setMaxPlotRange:CGPointMake(audioController.recordingBufferLengthFrames/audioController.sampleRate, 2.0f)];
    [tdScopeView setXGridAutoScale:true];
    [tdScopeView setYGridAutoScale:true];
    [tdScopeView setXLabelPosition:kMETScopeViewXLabelsOutsideAbove];
    [tdScopeView setYLabelPosition:kMETScopeViewYLabelsOutsideLeft];
    [tdScopeView setDelegate:self];
    
    /* Allocate subviews for wet (pre-processing) and dry (post-processing) waveforms */
    tdDryIdx = [tdScopeView addPlotWithColor:[UIColor blueColor] lineWidth:2.0f];
    tdWetIdx = [tdScopeView addPlotWithColor:[UIColor  redColor] lineWidth:2.0f];
    
    /* Don't show the effected signal until we switch to effects mode */
    [tdScopeView setVisibilityAtIndex:tdWetIdx visible:false];
    
    /* Allocate subviews for the clipping amplitude */
    tdClipIdxLow = [tdScopeView addPlotWithResolution:10 color:[UIColor greenColor] lineWidth:2.0f];
    tdClipIdxHigh = [tdScopeView addPlotWithResolution:10 color:[UIColor greenColor] lineWidth:2.0f];
    
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
    
    /* Get the FFT frequencies for the FD scope */
    plotFreqs = (float *)malloc(fdScopeView.frame.size.width * sizeof(float));
    [self linspace:fdScopeView.minPlotMin.x
               max:fdScopeView.maxPlotMax.x
       numElements:fdScopeView.frame.size.width
             array:plotFreqs];
    
    /* Allocate subviews for wet (pre-processing) and dry (post-processing) waveforms */
    fdDryIdx = [fdScopeView addPlotWithColor:[UIColor blueColor] lineWidth:2.0];
    fdWetIdx = [fdScopeView addPlotWithColor:[UIColor  redColor] lineWidth:2.0];
    
    /* Don't show the effected signal until we switch to effects mode */
    [fdScopeView setVisibilityAtIndex:fdWetIdx visible:false];
    
    /* ------------------------------------ */
    /* === External gesture recognizers === */
    /* ------------------------------------ */
    
    tdTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTDTap:)];
    [tdTapRecognizer setNumberOfTapsRequired:2];
    [tdScopeView addGestureRecognizer:tdTapRecognizer];
    inputPaused = false;
    
    /* ----------------------------- */
    /* == Setup for delay control == */
    /* ----------------------------- */
    
    /* Create a subview over the right-most 15th of the time domain scope view */
    CGRect delayRegionFrame;
    delayRegionFrame.size.width = tdScopeView.frame.size.width / 7.1;
    delayRegionFrame.size.height = tdScopeView.frame.size.height;
    delayRegionFrame.origin.x = 0;
    delayRegionFrame.origin.y = 0;
    delayRegionView = [[UIView alloc] initWithFrame:delayRegionFrame];
    [delayRegionView setBackgroundColor:[UIColor blackColor]];
    [delayRegionView setAlpha:0.05];
    [tdScopeView addSubview:delayRegionView];
    
    /* Add a tap gesture recognizer to enable delay */
    delayTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDelayTap:)];
    [delayTapRecognizer setNumberOfTapsRequired:1];
    [delayRegionView addGestureRecognizer:delayTapRecognizer];
    
    [delayRegionView setHidden:true];   // Don't show until in effects mode
    
    /* Create a scope view for the delay signal. Don't add to main view yet */
    delayView = [[METScopeView alloc] initWithFrame:tdScopeView.frame];
    [delayView setBackgroundColor:[UIColor clearColor]];
    
    /* Disable internal METScopeView gesture recognizers and add our own so we can zoom vertically and set delay params */
    [delayView setPinchZoomEnabled:false];
    [delayView setPanEnabled:false];
    
    delayPinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handleDelayPinch:)];
    [delayView addGestureRecognizer:delayPinchRecognizer];
    delayPanRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDelayPan:)];
    [delayView addGestureRecognizer:delayPanRecognizer];
    
    /* Allocate a subview for the delay signal */
    delayIdx = [delayView addPlotWithResolution:200 color:[UIColor colorWithRed:0.5 green:0 blue:0 alpha:1] lineWidth:1.0];
    
    /* -------------------------------------------- */
    /* == Set up UIView to show delay parameters == */
    /* -------------------------------------------- */
    
    CGRect delayParameterFrame = CGRectMake(50, 50, 150, 100);
    delayParameterView = [[UIView alloc] initWithFrame:delayParameterFrame];
    [delayParameterView setBackgroundColor:[[UIColor whiteColor] colorWithAlphaComponent:0.8f]];
    [[delayParameterView layer] setBorderWidth:1.0f];
    [[delayParameterView layer] setBorderColor:[[UIColor blueColor] colorWithAlphaComponent:0.1f].CGColor];
    
    CGRect labelFrame = CGRectMake(10, 20, 65, 20);
    UILabel *timeParameter = [[UILabel alloc] initWithFrame:labelFrame];
    [timeParameter setText:@"  Time: "];
    [timeParameter setTextAlignment:NSTextAlignmentRight];
    [delayParameterView addSubview:timeParameter];
    
    CGRect valueFrame = labelFrame;
    valueFrame.origin.x += labelFrame.size.width + 20;
    delayTimeValue = [[UILabel alloc] initWithFrame:valueFrame];
    [delayTimeValue setText:[NSString stringWithFormat:@"%3.2f", 0.0]];
    [delayTimeValue setTextAlignment:NSTextAlignmentLeft];
    [delayParameterView addSubview:delayTimeValue];
    
    labelFrame.origin.y += labelFrame.size.height * 2;
    UILabel *amountParameter = [[UILabel alloc] initWithFrame:labelFrame];
    [amountParameter setText:@"Amount: "];
    [amountParameter setTextAlignment:NSTextAlignmentRight];
    [delayParameterView addSubview:amountParameter];
    
    valueFrame.origin.y += labelFrame.size.height * 2;
    delayAmountValue = [[UILabel alloc] initWithFrame:valueFrame];
    [delayAmountValue setText:[NSString stringWithFormat:@"%3.2f", 0.15/tdScopeView.visiblePlotMax.y]];
    [delayAmountValue setTextAlignment:NSTextAlignmentLeft];
    [delayParameterView addSubview:delayAmountValue];
    
    /* ------------------------------------------ */
    /* == Setup for clipping threshold control == */
    /* ------------------------------------------ */
    
    /* Create a subview over the right-most 15th of the time domain scope view */
    CGRect pinchRegionFrame;
    pinchRegionFrame.size.width = tdScopeView.frame.size.width / 7.1;
    pinchRegionFrame.size.height = tdScopeView.frame.size.height;
    pinchRegionFrame.origin.x = tdScopeView.frame.size.width - pinchRegionFrame.size.width;
    pinchRegionFrame.origin.y = 0;
    distPinchRegionView = [[PinchRegionView alloc] initWithFrame:pinchRegionFrame];
    [distPinchRegionView setBackgroundColor:[[UIColor greenColor] colorWithAlphaComponent:0.05]];
    [distPinchRegionView setLinesVisible:false];
    CGPoint pix = [tdScopeView plotScaleToPixel:CGPointMake(0.0, audioController->clippingAmplitude)];
    [distPinchRegionView setPixelHeightFromCenter:pix.y-distPinchRegionView.frame.size.height/2];
    [tdScopeView addSubview:distPinchRegionView];
    
    /* Add a tap gesture recognizer to enable clipping */
    distCutoffTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDistCutoffTap:)];
    [distCutoffTapRecognizer setNumberOfTapsRequired:1];
    [distPinchRegionView addGestureRecognizer:distCutoffTapRecognizer];
    
    /* Add a pinch recognizer and set the callback to update the clipping amplitude */
    distCutoffPinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handleDistCutoffPinch:)];
    [distPinchRegionView addGestureRecognizer:distCutoffPinchRecognizer];
    [distCutoffPinchRecognizer setEnabled:false];
    
    [distPinchRegionView setHidden:true];   // Don't show until in effects mode
    
    /* -------------------------------------------- */
    /* == Setup for modulation frequency control == */
    /* -------------------------------------------- */
    
    modIdx = [fdScopeView addPlotWithColor:[UIColor greenColor] lineWidth:2.0];
    
    CGRect modRegionFrame;
    modRegionFrame.size.width = fdScopeView.frame.size.width;
    modRegionFrame.size.height = fdScopeView.frame.size.height / 4;
    modRegionFrame.origin.x = fdScopeView.frame.size.width - modRegionFrame.size.width;
    modRegionFrame.origin.y = fdScopeView.frame.size.height - modRegionFrame.size.height;
    modFreqPanRegionView = [[UIView alloc] initWithFrame:modRegionFrame];
    [modFreqPanRegionView setBackgroundColor:[UIColor greenColor]];
    [modFreqPanRegionView setAlpha:0.05];
    [fdScopeView addSubview:modFreqPanRegionView];
    
    /* Add a tap gesture recognizer to enable modulation */
    modFreqTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleModFreqTap:)];
    [modFreqTapRecognizer setNumberOfTapsRequired:1];
    [modFreqPanRegionView addGestureRecognizer:modFreqTapRecognizer];
    
    /* Add a pan gesture recognizer for controlling the modulation frequency */
    modFreqPanRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleModFreqPan:)];
    [modFreqPanRegionView addGestureRecognizer:modFreqPanRecognizer];
    
    [modFreqPanRegionView setHidden:true];  // Don't show until in effects mode
    
    /* ------------------------------ */
    /* == Setup for filter control == */
    /* ------------------------------ */
    
    /* Create a subview over at the left side of the spectrum */
    CGRect hpfTapRegionFrame;
    hpfTapRegionFrame.size.width = fdScopeView.frame.size.width / 7.1;
    hpfTapRegionFrame.size.height = fdScopeView.frame.size.height - modRegionFrame.size.height;
    hpfTapRegionFrame.origin.x = 0;
    hpfTapRegionFrame.origin.y = 0;
    hpfTapRegionView = [[FilterTapRegionView alloc] initWithFrame:hpfTapRegionFrame];
    [hpfTapRegionView setBackgroundColor:[UIColor clearColor]];
    [hpfTapRegionView setFillColor:[UIColor blackColor]];
    [hpfTapRegionView setAlpha:0.05];
    [fdScopeView addSubview:hpfTapRegionView];
    
    /* Add a tap gesture recognizer to enable/disable the HPF */
    hpfTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleHPF:)];
    [hpfTapRecognizer setNumberOfTapsRequired:1];
    [hpfTapRegionView addGestureRecognizer:hpfTapRecognizer];
    
    /* Create a subview over at the right side of the spectrum */
    CGRect lpfTapRegionFrame;
    lpfTapRegionFrame.size.width = fdScopeView.frame.size.width / 7.1;
    lpfTapRegionFrame.size.height = fdScopeView.frame.size.height - modRegionFrame.size.height;
    lpfTapRegionFrame.origin.x = fdScopeView.frame.size.width - lpfTapRegionFrame.size.width;
    lpfTapRegionFrame.origin.y = 0;
    lpfTapRegionView = [[FilterTapRegionView alloc] initWithFrame:lpfTapRegionFrame];
    [lpfTapRegionView setBackgroundColor:[UIColor clearColor]];
    [lpfTapRegionView setFillColor:[UIColor blackColor]];
    [lpfTapRegionView setAlpha:0.05];
    [fdScopeView addSubview:lpfTapRegionView];
    
    /* Add a tap gesture recognizer to enable/disable the HPF */
    lpfTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleLPF:)];
    [lpfTapRecognizer setNumberOfTapsRequired:1];
    [lpfTapRegionView addGestureRecognizer:lpfTapRecognizer];
    
    /* Make a "knee" shaped fill region for the filter cutoff views */
    int nPoints = 100;
    float fillRegionX[nPoints];
    CGPoint fillRegion[nPoints];
    
    [self linspace:0 max:hpfTapRegionFrame.size.width numElements:nPoints-1 array:fillRegionX];
    for (int i = 0; i < nPoints-1; i++) {
        fillRegion[i].x = fillRegionX[i];
        fillRegion[i].y = 500.0f / fillRegionX[i] - fillRegionX[i] * 5.0f / hpfTapRegionFrame.size.width;
    }
    fillRegion[nPoints-1].x = hpfTapRegionFrame.origin.x;
    fillRegion[nPoints-1].y = hpfTapRegionFrame.origin.y;
    [hpfTapRegionView setFillRegion:fillRegion numPoints:nPoints];
    
    /* Reverse direction of y coordinates for the LPF */
    CGPoint temp;
    for (int i = 0, j = nPoints; i < nPoints/2; i++, j--) {
        temp.y = fillRegion[i].y;
        fillRegion[i].y = fillRegion[j].y;
        fillRegion[j].y = temp.y;
    }
    fillRegion[nPoints-1].x = hpfTapRegionFrame.size.width;
    fillRegion[nPoints-1].y = 0.0f;
    [lpfTapRegionView setFillRegion:fillRegion numPoints:nPoints];
    
    [hpfTapRegionView setHidden:true];  // Don't show until in effects mode
    [lpfTapRegionView setHidden:true];
    
    /* Update the scope views on timers by querying AudioController's wet/dry signal buffers */
    [self setTDUpdateRate:kScopeUpdateRate];
    [self setFDUpdateRate:kScopeUpdateRate];
    
    delayOn = false;
    
    [effectsButton.titleLabel setTextAlignment:NSTextAlignmentCenter];
    analysisMode = true;
    
    /* ------------------ */
    /* === Help Setup === */
    /* ------------------ */
    
    [helpButton.titleLabel setTextAlignment:NSTextAlignmentCenter];
    
    helpDisplayed = false;
    analysisModeHelp = [[NSMutableArray alloc] init];
    analysisModeHelpInputEnabled = [[NSMutableArray alloc] init];
    analysisModeHelpInputDisabled = [[NSMutableArray alloc] init];
    effectsModeHelp = [[NSMutableArray alloc] init];
    effectsModeHelpDelayEnabled = [[NSMutableArray alloc] init];
    effectsModeHelpDelayDisabled = [[NSMutableArray alloc] init];
    effectsModeHelpDistEnabled = [[NSMutableArray alloc] init];
    effectsModeHelpDistDisabled = [[NSMutableArray alloc] init];
    effectsModeHelpModEnabled = [[NSMutableArray alloc] init];
    effectsModeHelpModDisabled = [[NSMutableArray alloc] init];
    effectsModeHelpLPFEnabled = [[NSMutableArray alloc] init];
    effectsModeHelpLPFDisabled = [[NSMutableArray alloc] init];
    effectsModeHelpHPFEnabled = [[NSMutableArray alloc] init];
    effectsModeHelpHPFDisabled = [[NSMutableArray alloc] init];
    
    /* TD Scope description */
    HelpBubble *bbl = [[HelpBubble alloc] initWithText:@"Audio signal in the time-domain"
                                                origin:CGPointMake(tdScopeView.frame.origin.x + 50.0f, tdScopeView.frame.origin.y + 50.0f) width:200.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    [[self view] addSubview:bbl];
    [analysisModeHelp addObject:bbl];
    [bbl setHidden:true];
    
    /* FD Scope desc. */
    bbl = [[HelpBubble alloc] initWithText:@"Audio signal in the frequency-domain (spectrum)"
                                    origin:CGPointMake(fdScopeView.frame.origin.x + 50.0f, fdScopeView.frame.origin.y + 50.0f)
                                     width:200.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    [[self view] addSubview:bbl];
    [analysisModeHelp addObject:bbl];
    [bbl setHidden:true];
    
    /* Pinch and pan instructions */
    bbl = [[HelpBubble alloc] initWithText:@"Pinch plot with two fingers to zoom in time. Drag with one finger to shift forward or backward"
                                    origin:CGPointMake(tdScopeView.frame.origin.x + 50.0f, tdScopeView.frame.origin.y + 130.0f)
                                     width:200.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    [[self view] addSubview:bbl];
    [analysisModeHelp addObject:bbl];
    [bbl setHidden:true];
    
    bbl = [[HelpBubble alloc] initWithText:@"Pinch plot with two fingers to zoom in frequency. Drag with one finger to shift forward or backward"
                                    origin:CGPointMake(fdScopeView.frame.origin.x + 50.0f, fdScopeView.frame.origin.y + 150.0f)
                                     width:200.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    [[self view] addSubview:bbl];
    [analysisModeHelp addObject:bbl];
    [bbl setHidden:true];
    
    /* Double-tap to pause instructions */
    bbl = [[HelpBubble alloc] initWithText:@"Double-tap plot to pause input for analysis"
                                    origin:CGPointMake(tdScopeView.frame.origin.x + tdScopeView.frame.size.width/2.0f, tdScopeView.frame.origin.y + 50.0f)
                                     width:200.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    [[self view] addSubview:bbl];
    [analysisModeHelpInputEnabled addObject:bbl];
    [bbl setHidden:true];
    
    bbl = [[HelpBubble alloc] initWithText:@"Double-tap plot to resume audio input"
                                    origin:CGPointMake(tdScopeView.frame.origin.x + tdScopeView.frame.size.width/2.0f, tdScopeView.frame.origin.y + 50.0f)
                                     width:200.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    [[self view] addSubview:bbl];
    [analysisModeHelpInputDisabled addObject:bbl];
    [bbl setHidden:true];
    
    bbl = [[HelpBubble alloc] initWithText:@"When input is enabled, the frequency-domain plot shows the real-time spectrum"
                                    origin:CGPointMake(fdScopeView.frame.origin.x + fdScopeView.frame.size.width/2.0f, fdScopeView.frame.origin.y + 50.0f)
                                     width:200.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    [[self view] addSubview:bbl];
    [analysisModeHelpInputEnabled addObject:bbl];
    [bbl setHidden:true];
    
    bbl = [[HelpBubble alloc] initWithText:@"When input is paused, the frequency-domain plot shows the spectrum of the audio visible in time"
                                    origin:CGPointMake(fdScopeView.frame.origin.x + fdScopeView.frame.size.width/2.0f, fdScopeView.frame.origin.y + 50.0f)
                                     width:200.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    [[self view] addSubview:bbl];
    [analysisModeHelpInputDisabled addObject:bbl];
    [bbl setHidden:true];
    
    /* Input/output enable desc. */
    bbl = [[HelpBubble alloc] initWithText:@"Enable/Disable Input"
                                    origin:CGPointMake(inputEnableSwitch.frame.origin.x - 40.0f, inputEnableSwitch.frame.origin.y - 40.0f)
                                     width:250.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationBottom offset:CGPointMake(-45.0f, 0.0f)];
    [[self view] addSubview:bbl];
    [analysisModeHelp addObject:bbl];
    [bbl setHidden:true];
    
    bbl = [[HelpBubble alloc] initWithText:@"Enable/Disable Output"
                                    origin:CGPointMake(outputEnableSwitch.frame.origin.x - 40.0f, outputEnableSwitch.frame.origin.y + 30.0f)
                                     width:250.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationTop offset:CGPointMake(-55.0f, 0.0f)];
    [[self view] addSubview:bbl];
    [analysisModeHelp addObject:bbl];
    [bbl setHidden:true];
    
    /* Input gain control desc. */
    bbl = [[HelpBubble alloc] initWithText:@"Input gain control"
                                    origin:CGPointMake(preGainSlider.frame.origin.x + 170.0f, preGainSlider.frame.origin.y - 40.0f)
                                     width:250.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationBottom];
    [[self view] addSubview:bbl];
    [analysisModeHelp addObject:bbl];
    [bbl setHidden:true];
    
    /* Output gain control desc. */
    bbl = [[HelpBubble alloc] initWithText:@"Output gain control"
                                    origin:CGPointMake(postGainSlider.frame.origin.x + 160.0f, postGainSlider.frame.origin.y + 30.0f)
                                     width:250.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationTop];
    [[self view] addSubview:bbl];
    [analysisModeHelp addObject:bbl];
    [bbl setHidden:true];
    
    /* Effects mode desc. */
    bbl = [[HelpBubble alloc] initWithText:@"When using effects, the blue signal is the input (clean) and the red signal is the output (effected)"
                                                origin:CGPointMake(tdScopeView.frame.origin.x + 50.0f, tdScopeView.frame.origin.y + 50.0f) width:200.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    [[self view] addSubview:bbl];
    [effectsModeHelpDelayDisabled addObject:bbl];
    [bbl setHidden:true];
    
    /* Distortion desc. */
    bbl = [[HelpBubble alloc] initWithText:@"Tap to activate distortion"
                                    origin:CGPointMake(tdScopeView.frame.origin.x + tdScopeView.frame.size.width - 200.0f, tdScopeView.frame.origin.y + tdScopeView.frame.size.height - 100.0f)
                                     width:250.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationTop offset:CGPointMake(50.0f, 0.0f)];
    [[self view] addSubview:bbl];
    [effectsModeHelpDistDisabled addObject:bbl];
    [bbl setHidden:true];
    
    bbl = [[HelpBubble alloc] initWithText:@"Pinch to adjust hard-clipping threshold"
                                    origin:CGPointMake(tdScopeView.frame.origin.x + tdScopeView.frame.size.width - 240.0f, tdScopeView.frame.origin.y + tdScopeView.frame.size.height - 100.0f)
                                     width:250.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationTop offset:CGPointMake(60.0f, 0.0f)];
    [[self view] addSubview:bbl];
    [effectsModeHelpDistEnabled addObject:bbl];
    [bbl setHidden:true];
    
    /* Delay desc. */
    bbl = [[HelpBubble alloc] initWithText:@"Tap to set delay parameters"
                                    origin:CGPointMake(tdScopeView.frame.origin.x + 30.0f, tdScopeView.frame.origin.y + tdScopeView.frame.size.height - 100.0f)
                                     width:250.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationTop offset:CGPointMake(-50.0f, 0.0f)];
    [[self view] addSubview:bbl];
    [effectsModeHelpDelayDisabled addObject:bbl];
    [bbl setHidden:true];
    
    bbl = [[HelpBubble alloc] initWithText:@"Drag with one finger to set delay time. Pinch to set delay amount. Tap again to activate delay.\n\nA delay time \u2264 0 turns delay off."
                                    origin:CGPointMake(tdScopeView.frame.origin.x + 30.0f, tdScopeView.frame.origin.y + 200.0f)
                                     width:250.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    [[self view] addSubview:bbl];
    [effectsModeHelpDelayEnabled addObject:bbl];
    [bbl setHidden:true];
    
    /* Modulation desc. */
    bbl = [[HelpBubble alloc] initWithText:@"Tap to activate amplitude modulation"
                                    origin:CGPointMake(fdScopeView.frame.origin.x + 30.0f, fdScopeView.frame.origin.y + fdScopeView.frame.size.height - 80.0f)
                                     width:250.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationRight];
    [[self view] addSubview:bbl];
    [effectsModeHelpModDisabled addObject:bbl];
    [bbl setHidden:true];
    
    bbl = [[HelpBubble alloc] initWithText:@"Drag with one finger to set carrier frequency"
                                    origin:CGPointMake(fdScopeView.frame.origin.x + fdScopeView.frame.size.width/2.0f - 125.0f, fdScopeView.frame.origin.y + fdScopeView.frame.size.height - 140.0f)
                                     width:250.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationBottom];
    [[self view] addSubview:bbl];
    [effectsModeHelpModEnabled addObject:bbl];
    [bbl setHidden:true];
    
    /* Filter desc. */
    bbl = [[HelpBubble alloc] initWithText:@"Tap to activate high-pass filter"
                                    origin:CGPointMake(fdScopeView.frame.origin.x + 30.0f, fdScopeView.frame.origin.y + 50.0f) width:200.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationTop offset:CGPointMake(-60.0f, 0.0f)];
    [[self view] addSubview:bbl];
    [effectsModeHelpHPFDisabled addObject:bbl];
    [bbl setHidden:true];
    
    bbl = [[HelpBubble alloc] initWithText:@"Frequencies below the visible plot bounds are attenuated. Pinch or drag the spectrum plot to change the filter's cutoff frequency."
                                    origin:CGPointMake(fdScopeView.frame.origin.x + 30.0f, fdScopeView.frame.origin.y + 50.0f) width:200.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    [[self view] addSubview:bbl];
    [effectsModeHelpHPFEnabled addObject:bbl];
    [bbl setHidden:true];
    
    bbl = [[HelpBubble alloc] initWithText:@"Tap to activate low-pass filter"
                                    origin:CGPointMake(fdScopeView.frame.origin.x + fdScopeView.frame.size.width - 200.0f, fdScopeView.frame.origin.y + 50.0f) width:200.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationTop offset:CGPointMake(60.0f, 0.0f)];
    [[self view] addSubview:bbl];
    [effectsModeHelpLPFDisabled addObject:bbl];
    [bbl setHidden:true];
    
    bbl = [[HelpBubble alloc] initWithText:@"Frequencies above the visible plot bounds are attenuated. Pinch or drag the spectrum plot to change the filter's cutoff frequency."
                                    origin:CGPointMake(fdScopeView.frame.origin.x + fdScopeView.frame.size.width - 220.0f, fdScopeView.frame.origin.y + 50.0f) width:200.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    [[self view] addSubview:bbl];
    [effectsModeHelpLPFEnabled addObject:bbl];
    [bbl setHidden:true];
}

- (IBAction)changeMode:(UIButton*)sender {
    
    if (analysisMode) {
        
        analysisMode = false;
        
        [sender setTitle:@"Hide Effects" forState:UIControlStateNormal];
        
        if (delayWasActive)
            [audioController setDelayEnabled:true];
        if (distWasActive) {
            [audioController setDistortionEnabled:true];
            [tdScopeView setVisibilityAtIndex:tdClipIdxHigh visible:true];
            [tdScopeView setVisibilityAtIndex:tdClipIdxLow visible:true];
        }
        if (modWasActive) {
            [audioController setModulationEnabled:true];
            [fdScopeView setVisibilityAtIndex:modIdx visible:true];
        }
        if (lpfWasActive)
            [audioController setLpfEnabled:true];
        if (hpfWasActive)
            [audioController setHpfEnabled:true];
        
        [tdScopeView setVisibilityAtIndex:tdWetIdx visible:true];
        [fdScopeView setVisibilityAtIndex:fdWetIdx visible:true];
        
        [delayRegionView setHidden:false];
        [distPinchRegionView setHidden:false];
        [modFreqPanRegionView setHidden:false];
        [hpfTapRegionView setHidden:false];
        [lpfTapRegionView setHidden:false];
    }
    else {
        
        analysisMode = true;
        
        [sender setTitle:@"Show Effects" forState:UIControlStateNormal];
        
        delayWasActive = [audioController delayEnabled];
        distWasActive = [audioController distortionEnabled];
        modWasActive = [audioController modulationEnabled];
        lpfWasActive = [audioController lpfEnabled];
        hpfWasActive = [audioController hpfEnabled];
        
        if (delayWasActive)
            [audioController setDelayEnabled:false];
        if (distWasActive) {
            [audioController setDistortionEnabled:false];
            [tdScopeView setVisibilityAtIndex:tdClipIdxHigh visible:false];
            [tdScopeView setVisibilityAtIndex:tdClipIdxLow visible:false];
        }
        if (modWasActive) {
            [audioController setModulationEnabled:false];
            [fdScopeView setVisibilityAtIndex:modIdx visible:false];
        }
        if (lpfWasActive)
            [audioController setLpfEnabled:false];
        if (hpfWasActive)
            [audioController setHpfEnabled:false];
        
        [tdScopeView setVisibilityAtIndex:tdWetIdx visible:false];
        [fdScopeView setVisibilityAtIndex:fdWetIdx visible:false];
        
        [delayRegionView setHidden:true];
        [distPinchRegionView setHidden:true];
        [modFreqPanRegionView setHidden:true];
        [hpfTapRegionView setHidden:true];
        [lpfTapRegionView setHidden:true];
    }
    
    /* Update help if displayed */
    if (helpDisplayed)
        [self updateHelp];
}

- (IBAction)toggleHelp:(UIButton *)sender {
    
    [sender setTitle:helpDisplayed ? @"Show Help" : @"Hide Help" forState:UIControlStateNormal];
    helpDisplayed = !helpDisplayed;
    [self updateHelp];
}

/* Make sure the relevant help bubbles are displayed for the current mode and effect states. Also hides all help bubbles if helpDisplayed == false */
- (void)updateHelp {
    
    if (!helpDisplayed) {
        
        /* Set all help bubble arrays to hidden in case we've changed modes since help was displayed */
        for (int i = 0; i < [analysisModeHelp count]; i++)
            [[analysisModeHelp objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [analysisModeHelpInputEnabled count]; i++)
            [[analysisModeHelpInputEnabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [analysisModeHelpInputDisabled count]; i++)
            [[analysisModeHelpInputDisabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [effectsModeHelp count]; i++)
            [[effectsModeHelp objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [effectsModeHelpDelayEnabled count]; i++)
            [[effectsModeHelpDelayEnabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [effectsModeHelpDelayDisabled count]; i++)
            [[effectsModeHelpDelayDisabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [effectsModeHelpDistEnabled count]; i++)
            [[effectsModeHelpDistEnabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [effectsModeHelpDistDisabled count]; i++)
            [[effectsModeHelpDistDisabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [effectsModeHelpModEnabled count]; i++)
            [[effectsModeHelpModEnabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [effectsModeHelpModDisabled count]; i++)
            [[effectsModeHelpModDisabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [effectsModeHelpLPFEnabled count]; i++)
            [[effectsModeHelpLPFEnabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [effectsModeHelpLPFDisabled count]; i++)
            [[effectsModeHelpLPFDisabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [effectsModeHelpHPFEnabled count]; i++)
            [[effectsModeHelpHPFEnabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [effectsModeHelpHPFDisabled count]; i++)
            [[effectsModeHelpHPFDisabled objectAtIndex:i] setHidden:true];
    }
    
    /* If help is enabled, check modes to display the relevant help info */
    else {
    
        if (analysisMode) {
            
            for (int i = 0; i < [analysisModeHelp count]; i++)
                [[analysisModeHelp objectAtIndex:i] setHidden:false];
            
            /* Input state-dependent */
            if (inputPaused) {
                for (int i = 0; i < [analysisModeHelpInputEnabled count]; i++)
                    [[analysisModeHelpInputEnabled objectAtIndex:i] setHidden:true];
                for (int i = 0; i < [analysisModeHelpInputDisabled count]; i++)
                    [[analysisModeHelpInputDisabled objectAtIndex:i] setHidden:false];
            }
            else {
                for (int i = 0; i < [analysisModeHelpInputEnabled count]; i++)
                    [[analysisModeHelpInputEnabled objectAtIndex:i] setHidden:false];
                for (int i = 0; i < [analysisModeHelpInputDisabled count]; i++)
                    [[analysisModeHelpInputDisabled objectAtIndex:i] setHidden:true];
            }
            
            /* Hide all effects mode help */
            for (int i = 0; i < [effectsModeHelp count]; i++)
                [[effectsModeHelp objectAtIndex:i] setHidden:true];
            for (int i = 0; i < [effectsModeHelpDelayEnabled count]; i++)
                [[effectsModeHelpDelayEnabled objectAtIndex:i] setHidden:true];
            for (int i = 0; i < [effectsModeHelpDelayDisabled count]; i++)
                [[effectsModeHelpDelayDisabled objectAtIndex:i] setHidden:true];
            for (int i = 0; i < [effectsModeHelpDistEnabled count]; i++)
                [[effectsModeHelpDistEnabled objectAtIndex:i] setHidden:true];
            for (int i = 0; i < [effectsModeHelpDistDisabled count]; i++)
                [[effectsModeHelpDistDisabled objectAtIndex:i] setHidden:true];
            for (int i = 0; i < [effectsModeHelpModEnabled count]; i++)
                [[effectsModeHelpModEnabled objectAtIndex:i] setHidden:true];
            for (int i = 0; i < [effectsModeHelpModDisabled count]; i++)
                [[effectsModeHelpModDisabled objectAtIndex:i] setHidden:true];
            for (int i = 0; i < [effectsModeHelpLPFEnabled count]; i++)
                [[effectsModeHelpLPFEnabled objectAtIndex:i] setHidden:true];
            for (int i = 0; i < [effectsModeHelpLPFDisabled count]; i++)
                [[effectsModeHelpLPFDisabled objectAtIndex:i] setHidden:true];
            for (int i = 0; i < [effectsModeHelpHPFEnabled count]; i++)
                [[effectsModeHelpHPFEnabled objectAtIndex:i] setHidden:true];
            for (int i = 0; i < [effectsModeHelpHPFDisabled count]; i++)
                [[effectsModeHelpHPFDisabled objectAtIndex:i] setHidden:true];
        }
        
        else {
            
            for (int i = 0; i < [effectsModeHelp count]; i++)
                [[effectsModeHelp objectAtIndex:i] setHidden:false];
            
            /* Delay state-dependent */
            if (delayOn) {
                for (int i = 0; i < [effectsModeHelpDelayEnabled count]; i++)
                    [[effectsModeHelpDelayEnabled objectAtIndex:i] setHidden:false];
                for (int i = 0; i < [effectsModeHelpDelayDisabled count]; i++)
                    [[effectsModeHelpDelayDisabled objectAtIndex:i] setHidden:true];
            }
            else {
                for (int i = 0; i < [effectsModeHelpDelayEnabled count]; i++)
                    [[effectsModeHelpDelayEnabled objectAtIndex:i] setHidden:true];
                for (int i = 0; i < [effectsModeHelpDelayDisabled count]; i++)
                    [[effectsModeHelpDelayDisabled objectAtIndex:i] setHidden:false];
            }
            
            /* Distortion state-dependent */
            if ([audioController distortionEnabled]) {
                for (int i = 0; i < [effectsModeHelpDistEnabled count]; i++)
                    [[effectsModeHelpDistEnabled objectAtIndex:i] setHidden:false];
                for (int i = 0; i < [effectsModeHelpDistDisabled count]; i++)
                    [[effectsModeHelpDistDisabled objectAtIndex:i] setHidden:true];
            }
            else {
                for (int i = 0; i < [effectsModeHelpDistEnabled count]; i++)
                    [[effectsModeHelpDistEnabled objectAtIndex:i] setHidden:true];
                for (int i = 0; i < [effectsModeHelpDistDisabled count]; i++)
                    [[effectsModeHelpDistDisabled objectAtIndex:i] setHidden:false];
            }
            
            /* Modulation state-dependent */
            if ([audioController modulationEnabled]) {
                for (int i = 0; i < [effectsModeHelpModEnabled count]; i++)
                    [[effectsModeHelpModEnabled objectAtIndex:i] setHidden:false];
                for (int i = 0; i < [effectsModeHelpModDisabled count]; i++)
                    [[effectsModeHelpModDisabled objectAtIndex:i] setHidden:true];
            }
            else {
                for (int i = 0; i < [effectsModeHelpModEnabled count]; i++)
                    [[effectsModeHelpModEnabled objectAtIndex:i] setHidden:true];
                for (int i = 0; i < [effectsModeHelpModDisabled count]; i++)
                    [[effectsModeHelpModDisabled objectAtIndex:i] setHidden:false];
            }
            
            /* LPF state-dependent */
            if ([audioController lpfEnabled]) {
                for (int i = 0; i < [effectsModeHelpLPFEnabled count]; i++)
                    [[effectsModeHelpLPFEnabled objectAtIndex:i] setHidden:false];
                for (int i = 0; i < [effectsModeHelpLPFDisabled count]; i++)
                    [[effectsModeHelpLPFDisabled objectAtIndex:i] setHidden:true];
            }
            else {
                for (int i = 0; i < [effectsModeHelpLPFEnabled count]; i++)
                    [[effectsModeHelpLPFEnabled objectAtIndex:i] setHidden:true];
                for (int i = 0; i < [effectsModeHelpLPFDisabled count]; i++)
                    [[effectsModeHelpLPFDisabled objectAtIndex:i] setHidden:false];
            }
            
            /* HPF state-dependent */
            if ([audioController hpfEnabled]) {
                for (int i = 0; i < [effectsModeHelpHPFEnabled count]; i++)
                    [[effectsModeHelpHPFEnabled objectAtIndex:i] setHidden:false];
                for (int i = 0; i < [effectsModeHelpHPFDisabled count]; i++)
                    [[effectsModeHelpHPFDisabled objectAtIndex:i] setHidden:true];
            }
            else {
                for (int i = 0; i < [effectsModeHelpHPFEnabled count]; i++)
                    [[effectsModeHelpHPFEnabled objectAtIndex:i] setHidden:true];
                for (int i = 0; i < [effectsModeHelpHPFDisabled count]; i++)
                    [[effectsModeHelpHPFDisabled objectAtIndex:i] setHidden:false];
            }
            
            /* Hide all analysis mode help */
            for (int i = 0; i < [analysisModeHelp count]; i++)
                [[analysisModeHelp objectAtIndex:i] setHidden:true];
            for (int i = 0; i < [analysisModeHelpInputEnabled count]; i++)
                [[analysisModeHelpInputEnabled objectAtIndex:i] setHidden:true];
            for (int i = 0; i < [analysisModeHelpInputDisabled count]; i++)
                [[analysisModeHelpInputDisabled objectAtIndex:i] setHidden:true];
        }
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
        float *dryYBuffer = (float *)malloc(visibleBufferLength * sizeof(float));
        float *wetYBuffer = (float *)malloc(visibleBufferLength * sizeof(float));
        
        /* Get current visible samples from the audio controller */
        if (inputPaused) {
            [audioController getInputBuffer:dryYBuffer from:startIdx to:endIdx];
            [audioController getOutputBuffer:wetYBuffer from:startIdx to:endIdx];
        }
        else {
            [audioController getInputBuffer:dryYBuffer withLength:visibleBufferLength];
            [audioController getOutputBuffer:wetYBuffer withLength:visibleBufferLength];
        }
        
        [tdScopeView setPlotDataAtIndex:tdDryIdx
                             withLength:visibleBufferLength
                                  xData:plotTimes
                                  yData:dryYBuffer];
        
        [tdScopeView setPlotDataAtIndex:tdWetIdx
                             withLength:visibleBufferLength
                                  xData:plotTimes
                                  yData:wetYBuffer];
        free(plotTimes);
        free(dryYBuffer);
        free(wetYBuffer);
    }
}

- (void)updateFDScope {

    if (!fdHold && ![fdScopeView hasCurrentPinch] && ![fdScopeView hasCurrentPan]) {
        
        /* If we've taken a snapshot, plot the averaged spectrum of the visible portion */
        if (inputPaused) {
            
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
            
            [fdScopeView setCoordinatesInFDModeAtIndex:fdDryIdx
                                            withLength:audioController.fftSize/2
                                                 xData:freqs
                                                 yData:visibleSpec];
            
            /* Also plot the averaged spectrum of the visible portion of the output buffer if in effects mode */
            if ([fdScopeView getVisibilityAtIndex:fdWetIdx]) {
                
                [audioController getAverageOutputSpectrum:visibleSpec from:startIdx to:endIdx];
                
                [fdScopeView setCoordinatesInFDModeAtIndex:fdWetIdx
                                                withLength:audioController.fftSize/2
                                                     xData:freqs
                                                     yData:visibleSpec];
            }
                
            free(freqs);
            free(visibleSpec);
        }
        
        /* Otherwise, plot the spectrum of the current audio buffer */
        else {
            /* Get buffer of times for each sample */
            plotTimes = (float *)malloc(audioController.bufferSizeFrames * sizeof(float));
            [self linspace:0.0 max:(audioController.bufferSizeFrames * audioController.sampleRate) numElements:audioController.bufferSizeFrames array:plotTimes];
            
            /* Allocate wet/dry signal buffers */
            float *dryYBuffer = (float *)malloc(audioController.bufferSizeFrames * sizeof(float));
            float *wetYBuffer = (float *)malloc(audioController.bufferSizeFrames * sizeof(float));
            
            /* Get current visible samples from the audio controller */
            [audioController getInputBuffer:dryYBuffer withLength:audioController.bufferSizeFrames];
            [audioController getOutputBuffer:wetYBuffer withLength:audioController.bufferSizeFrames];
            
            [fdScopeView setPlotDataAtIndex:fdDryIdx
                                 withLength:audioController.bufferSizeFrames
                                      xData:plotTimes
                                      yData:dryYBuffer];
            
            [fdScopeView setPlotDataAtIndex:fdWetIdx
                                 withLength:audioController.bufferSizeFrames
                                      xData:plotTimes
                                      yData:wetYBuffer];
            free(plotTimes);
            free(dryYBuffer);
            free(wetYBuffer);
        }
    }
}

- (void)plotClippingThreshold {
    
    float xx[] = {tdScopeView.visiblePlotMin.x, tdScopeView.visiblePlotMax.x * 1.2};
    float yy[] = {audioController->clippingAmplitude, audioController->clippingAmplitude};
    
    /* Plot */
    [tdScopeView setPlotDataAtIndex:tdClipIdxHigh
                         withLength:2
                              xData:xx
                              yData:yy];
    
    /* Negative mirror */
    yy[0] = -audioController->clippingAmplitude;
    yy[1] = -audioController->clippingAmplitude;
    
    /* Plot */
    [tdScopeView setPlotDataAtIndex:tdClipIdxLow
                         withLength:2
                              xData:xx
                              yData:yy];
}

- (void)plotModFreq {
    
    /* Get buffer of times for each sample */
    plotTimes = (float *)malloc(kAudioBufferSize * sizeof(float));
    [self linspace:0.0 max:(kAudioBufferSize * kAudioSampleRate) numElements:kAudioBufferSize array:plotTimes];
    
    float *modYBuffer = (float *)malloc(kAudioBufferSize * sizeof(float));
    [audioController getModulationBuffer:modYBuffer withLength:kAudioBufferSize];
    
    [fdScopeView setPlotDataAtIndex:modIdx
                         withLength:kAudioBufferSize
                              xData:plotTimes
                              yData:modYBuffer];
    free(plotTimes);
    free(modYBuffer);
}

#pragma mark - Effects Controls
- (void)handleTDTap:(UITapGestureRecognizer *)sender {
    [self toggleInput:sender];
}

/* Tap on the delay strip to set delay parameters. Tap again to activate the effect (or deactivate if delayTime <= 0 */
- (void)handleDelayTap:(UITapGestureRecognizer *)sender {
    
    /* Note: delayOn is a flag indicating that everything is paused and we're modifying delay parameters. audioController.delayEnabled is the flag that indicates delay is being applied to the audio */
    if (delayOn) {
        
        delayOn = tdHold = fdHold = false;
        [tdScopeView setAlpha:1.0];
        
        /* Get the delay time as the difference between the bounds of the delay scope and the TD Scope */
        float delayTime = tdScopeView.visiblePlotMin.x - delayView.visiblePlotMin.x;
        [audioController->circularBuffer setSampleDelayForTap:0 sampleDelay:delayTime*audioController.sampleRate];
        
        /* Get the current feedback value as a function of the plot bounds */
        float feedback = fminf(kDelayFeedbackScalar / delayView.visiblePlotMax.y, kDelayMaxFeedback);
        
        audioController->tapGains[0] = feedback;
        
        /* Enable */
        if (delayTime > 0.0f) {
            [audioController setDelayEnabled:true];
            [delayRegionView setAlpha:kEffectEnabledAlpha];
        }
        else {
            [audioController setDelayEnabled:true];
            [delayRegionView setAlpha:kEffectDisabledAlpha];
        }
        
        /* Remove the tap gesture recognizer from the delayView (METScopeView) and add them to the delayRegionView (gray UIView strip) */
        [delayView removeGestureRecognizer:delayTapRecognizer];
        [delayRegionView addGestureRecognizer:delayTapRecognizer];
        
        /* Remove the delay scope from the main view */
        [delayView performSelectorOnMainThread:@selector(removeFromSuperview) withObject:nil waitUntilDone:false];
        
        /* Put the distortion pinch region back on the time-domain plot */
        [tdScopeView addSubview:distPinchRegionView];
        
        /* Remove the delay parameter view */
        [delayParameterView removeFromSuperview];
    }
    
    else {
        
        delayOn = tdHold = fdHold = true;
        [tdScopeView setAlpha:0.5];
        
        /* Copy settings from current time domain scope */
        [delayView setPlotResolution:tdScopeView.plotResolution];
        [delayView setHardXLim:-tdScopeView.maxPlotMax.x max:tdScopeView.maxPlotMax.x];
        [delayView setHardYLim:-10.0 max:10.0];
        [delayView setVisibleXLim:tdScopeView.visiblePlotMin.x max:tdScopeView.visiblePlotMax.x];
        [delayView setVisibleYLim:tdScopeView.visiblePlotMin.y max:tdScopeView.visiblePlotMax.y];
        [delayView setMinPlotRange:CGPointMake(tdScopeView.minPlotRange.x, 0.1)];
        [delayView setMaxPlotRange:CGPointMake(tdScopeView.maxPlotRange.x, 20.0)];
        [delayView setAxesOn:false];
        [delayView setGridOn:false];
        [delayView setLabelsOn:false];
        
        /* Copy the TD Scope's current output buffer for the delay plot */
        float *delayXBuffer = (float *)malloc(tdScopeView.plotResolution * sizeof(float));
        float *delayYBuffer = (float *)malloc(tdScopeView.plotResolution * sizeof(float));
        [tdScopeView getPlotDataAtIndex:tdWetIdx withLength:tdScopeView.plotResolution xData:delayXBuffer yData:delayYBuffer];
        
        /* Plot */
        [delayView setPlotDataAtIndex:delayIdx
                           withLength:tdScopeView.plotResolution
                                xData:delayXBuffer
                                yData:delayYBuffer];
        free(delayXBuffer);
        free(delayYBuffer);
        
        /* If the TD Scope is in fill mode, set it for the delay scope */
        [delayView setFillMode:[tdScopeView getFillModeAtIndex:tdWetIdx] atIndex:delayIdx];
        
        /* Add the delay scope to the main view */
        [[self view] addSubview:delayView];
        
        /* Remove the tap gesture recognizer from the delayRegionView (gray UIView strip) and add them to the delayView (METScopeView) */
        [delayRegionView removeGestureRecognizer:delayTapRecognizer];
        [delayView addGestureRecognizer:delayTapRecognizer];
        
        /* Add the delay parameter view */
        [delayView addSubview:delayParameterView];
        
        /* Make sure the distortion pinch region is on top so we can still use it */
        [delayView addSubview:distPinchRegionView];
        
        /* Get the delay time as the difference between the bounds of the delay scope and the TD Scope */
        float delayTime = tdScopeView.visiblePlotMin.x - delayView.visiblePlotMin.x;
        
        /* Set the label text */
        [delayTimeValue setText:[NSString stringWithFormat:@"%3.2f", delayTime]];
        
        /* Get the current feedback value as a function of the plot bounds */
        float feedback = fminf(kDelayFeedbackScalar / delayView.visiblePlotMax.y, kDelayMaxFeedback);
        
        /* Set the label text */
        [delayAmountValue setText:[NSString stringWithFormat:@"%3.2f", feedback]];
    }
    
    CGRect flashFrame = delayRegionView.frame;
    flashFrame.origin.x += tdScopeView.frame.origin.x;
    flashFrame.origin.y += tdScopeView.frame.origin.y;
    [self flashInFrame:flashFrame];
    
    /* Update help if displayed */
    if (helpDisplayed)
        [self updateHelp];
}

- (void)handleDelayPinch:(UIPinchGestureRecognizer *)sender {
    
    /* Pinch gesture began: save initial pinch scale */
    if (sender.state == UIGestureRecognizerStateBegan)
        delayPreviousPinchScale = sender.scale;
    
    /* Pinch gesture ended */
    else if (sender.state == UIGestureRecognizerStateEnded) {

    }
    
    /* Pinch gesture update: set delay feedback from pinch scale */
    else {

        /* Scale the time axis upper bound */
        CGFloat scaleChange;
        scaleChange = sender.scale - delayPreviousPinchScale;

        /* Get the current feedback value as a function of the plot bounds */
        float feedback = fminf(kDelayFeedbackScalar / delayView.visiblePlotMax.y, kDelayMaxFeedback);

        /* Set the label text */
        [delayAmountValue setText:[NSString stringWithFormat:@"%3.2f", feedback]];

        if (feedback < kDelayMaxFeedback || scaleChange < 0) {
            [delayView setVisibleYLim:(delayView.visiblePlotMin.y - scaleChange*delayView.visiblePlotMin.y) max:(delayView.visiblePlotMax.y - scaleChange*delayView.visiblePlotMax.y)];
        }
    
        delayPreviousPinchScale = sender.scale;
    }
}

- (void)handleDelayPan:(UIPinchGestureRecognizer *)sender {
    
    /* Location of current touch */
    CGPoint touchLoc = [sender locationInView:sender.view];

    /* Pan gesture began: save initial touch location */
    if (sender.state == UIGestureRecognizerStateBegan)
        delayPreviousPanLoc = touchLoc;
    

    /* Pan gesture ended */
    else if (sender.state == UIGestureRecognizerStateEnded && !delayOn) {

    }

    /* Pan gesture update: set the delay time from touch location */
    else {

        /* Get the relative change in location; convert to plot units (time) */
        CGPoint locChange;
        locChange.x = delayPreviousPanLoc.x - touchLoc.x;
        locChange.y = delayPreviousPanLoc.y - touchLoc.y;
        
        locChange.x *= delayView.unitsPerPixel.x;
        [delayView setVisibleXLim:(delayView.visiblePlotMin.x + locChange.x)
                              max:(delayView.visiblePlotMax.x + locChange.x)];

        /* Get the delay time as the difference between the bounds of the delay scope and the TD Scope */
        float delayTime = tdScopeView.visiblePlotMin.x - delayView.visiblePlotMin.x;

        /* Set the label text */
        [delayTimeValue setText:[NSString stringWithFormat:@"%3.2f", delayTime]];
        
        delayPreviousPanLoc = touchLoc;
    }
}

- (void)handleDistCutoffTap:(UITapGestureRecognizer *)sender {
    
    if (audioController.distortionEnabled) {
        [audioController setDistortionEnabled:false];
        [tdScopeView setVisibilityAtIndex:tdClipIdxLow visible:false];
        [tdScopeView setVisibilityAtIndex:tdClipIdxHigh visible:false];
        [distCutoffPinchRecognizer setEnabled:false];
        [distPinchRegionView setBackgroundColor:[[UIColor greenColor] colorWithAlphaComponent:kEffectDisabledAlpha]];
        [distPinchRegionView setLinesVisible:false];
    }
    
    else {
        [audioController setDistortionEnabled:true];
        [self plotClippingThreshold];
        [tdScopeView setVisibilityAtIndex:tdClipIdxLow visible:true];
        [tdScopeView setVisibilityAtIndex:tdClipIdxHigh visible:true];
        [distCutoffPinchRecognizer setEnabled:true];
        [distPinchRegionView setBackgroundColor:[[UIColor greenColor] colorWithAlphaComponent:kEffectEnabledAlpha]];
        [distPinchRegionView setLinesVisible:true];
    }
    
    CGRect flashFrame = distPinchRegionView.frame;
    flashFrame.origin.x += tdScopeView.frame.origin.x;
    flashFrame.origin.y += tdScopeView.frame.origin.y;
    [self flashInFrame:flashFrame];
    
    /* Update help if displayed */
    if (helpDisplayed)
        [self updateHelp];
}

- (void)handleDistCutoffPinch:(UIPinchGestureRecognizer *)sender {

    /* Reset the previous scale if the gesture began */
    if(sender.state == UIGestureRecognizerStateBegan)
        previousPinchScale = 1.0;
    
    /* Otherwise, increment or decrement by a constant depending on the direction of the pinch */
    else {
        
        float scaleChange = (sender.scale - previousPinchScale) / previousPinchScale;
        audioController->clippingAmplitude *= (1 + scaleChange);
        previousPinchScale = sender.scale;
    }
    
    /* Bound the clipping amplitude */
    if(audioController->clippingAmplitude >  1.0) audioController->clippingAmplitude =  1.0;
    if(audioController->clippingAmplitude < 0.05) audioController->clippingAmplitude = 0.05;
    
    /* Draw the clipping amplitude */
    [self plotClippingThreshold];
    
    /* Convert the clipping amplitude to pixels for the pinch region view */
    CGPoint pix = [tdScopeView plotScaleToPixel:CGPointMake(0.0, audioController->clippingAmplitude)];
    pix.y -= distPinchRegionView.frame.size.height/2.0;
    [distPinchRegionView setPixelHeightFromCenter:pix.y];
}

- (void)handleModFreqTap:(UITapGestureRecognizer *)sender {
    
    if (audioController.modulationEnabled) {
        [audioController setModulationEnabled:false];
        [fdScopeView setVisibilityAtIndex:modIdx visible:false];
        [modFreqPanRecognizer setEnabled:false];
        [modFreqPanRegionView setAlpha:kEffectDisabledAlpha];
    }
    
    else {
        [audioController setModulationEnabled:true];
        [fdScopeView setVisibilityAtIndex:modIdx visible:true];
        [modFreqPanRecognizer setEnabled:true];
        [modFreqPanRegionView setAlpha:kEffectEnabledAlpha];
        
        /* If the modulation frequency is beyond the plot bounds, put it in the center */
        if (audioController->modFreq < fdScopeView.visiblePlotMin.x ||
            audioController->modFreq > fdScopeView.visiblePlotMax.x)
            [audioController setModFrequency:(fdScopeView.visiblePlotMax.x - fdScopeView.visiblePlotMin.x)];
        
        [self plotModFreq];
    }
    
    CGRect flashFrame = modFreqPanRegionView.frame;
    flashFrame.origin.x += fdScopeView.frame.origin.x;
    flashFrame.origin.y += fdScopeView.frame.origin.y;
    [self flashInFrame:flashFrame];
    
    /* Update help if displayed */
    if (helpDisplayed)
        [self updateHelp];
}

- (void)handleModFreqPan:(UIPanGestureRecognizer *)sender {
    
    /* Location of current touch */
    CGPoint touchLoc = [sender locationInView:sender.view];
    
    if (sender.state == UIGestureRecognizerStateBegan) {
        
        /* Save initial touch location */
        modFreqPreviousPanLoc = touchLoc;
    }
    
    else if (sender.state == UIGestureRecognizerStateEnded) {
        
    }
    
    else {
        
        CGPoint locChange;
        locChange.x = modFreqPreviousPanLoc.x - touchLoc.x;
        locChange.y = modFreqPreviousPanLoc.y - touchLoc.y;
        
        locChange.x *= fdScopeView.unitsPerPixel.x;
        locChange.y *= fdScopeView.unitsPerPixel.y;
        
        float newModFreq = audioController->modFreq - locChange.x;
        
        if (newModFreq > fdScopeView.visiblePlotMin.x && newModFreq < fdScopeView.visiblePlotMax.x) {
            
            [audioController setModFrequency:newModFreq];
            
            [self plotModFreq];
        }
        
        modFreqPreviousPanLoc = touchLoc;
    }
}

- (void)toggleHPF:(UITapGestureRecognizer *)sender {
    
    CGPoint touchLoc = [sender locationInView:hpfTapRegionView];
    
    float endAlpha;
    
    if (![hpfTapRegionView pointInFillRegion:touchLoc])
        return;
    
    if ([audioController hpfEnabled]) {
        [audioController setHpfEnabled:false];
        endAlpha = kEffectDisabledAlpha;
    }
    else {
        [audioController setHpfEnabled:true];
        endAlpha = kEffectEnabledAlpha;
    }
    
    [hpfTapRegionView setAlpha:0.5f];
    [UIView animateWithDuration:0.5f
                     animations:^{
                         [hpfTapRegionView setAlpha:endAlpha];
                     }
                     completion:^(BOOL finished) {
                         [hpfTapRegionView setAlpha:endAlpha];
                     }
     ];
    
    /* Update help if displayed */
    if (helpDisplayed)
        [self updateHelp];
}

- (void)toggleLPF:(UITapGestureRecognizer *)sender {
    
    CGPoint touchLoc = [sender locationInView:lpfTapRegionView];
    
    float endAlpha;
    
    if (![lpfTapRegionView pointInFillRegion:touchLoc])
        return;
    
    if ([audioController lpfEnabled]) {
        [audioController setLpfEnabled:false];
        endAlpha = kEffectDisabledAlpha;
    }
    else {
        [audioController setLpfEnabled:true];
        endAlpha = kEffectEnabledAlpha;
    }
    
    [lpfTapRegionView setAlpha:0.5f];
    [UIView animateWithDuration:0.5f
                     animations:^{
                         [lpfTapRegionView setAlpha:endAlpha];
                     }
                     completion:^(BOOL finished) {
                         [lpfTapRegionView setAlpha:endAlpha];
                     }
     ];
    
    /* Update help if displayed */
    if (helpDisplayed)
        [self updateHelp];
}

- (IBAction)toggleInput:(id)sender {
    
    if ([audioController inputEnabled]) {       // Pause audio input
        
        inputPaused = true;
        [audioController setInputEnabled:false];
        [inputEnableSwitch setOn:false animated:true];
        
        [audioController computeFFTs];
        
        /* Keep the current plot range, but shift it to the end of the recording buffer */
        [tdScopeView setVisibleXLim:(audioController.recordingBufferLengthFrames / audioController.sampleRate) - (tdScopeView.visiblePlotMax.x - tdScopeView.visiblePlotMin.x)
                                max:audioController.recordingBufferLengthFrames / audioController.sampleRate];
        
        /* Zoom into the past when paused */
        [tdScopeView setPinchZoomMode:kMETScopeViewPinchZoomHoldMax];
        
        [self updateTDScope];
    }
    
    else {                                      // Resume audio input
        
        inputPaused = false;
        [audioController setInputEnabled:true];
        [inputEnableSwitch setOn:true animated:true];
        
        /* Shift plot bounds back to [0, audio buffer length] */
        [tdScopeView setVisibleXLim:-0.00001
                                max:audioController.bufferSizeFrames / audioController.sampleRate];
        
        /* Zoom into the past when paused */
        [tdScopeView setPinchZoomMode:kMETScopeViewPinchZoomHoldMin];
    }
    
    /* Flash animation on the time-domain plot */
    [self flashInFrame:tdScopeView.frame];
    
    /* Update help if displayed */
    if (helpDisplayed)
        [self updateHelp];
}

- (IBAction)toggleOutput:(id)sender {
    
    if (audioController.outputEnabled) {
        [audioController setOutputEnabled:false];
        previousPostGain = [audioController outputGain];
        postGainSlider.value = 0.0;
        [audioController setOutputGain:postGainSlider.value];
        [postGainSlider setEnabled:false];
        [postGainSlider setAlpha:0.5];
    }
    else {
        [audioController setOutputEnabled:true];
        postGainSlider.value = previousPostGain;
        [audioController setOutputGain:postGainSlider.value];
        [postGainSlider setEnabled:true];
        [postGainSlider setAlpha:1.0];
    }
}

- (IBAction)updatePreGain:(id)sender {
    [audioController setInputGain:preGainSlider.value];
}

- (IBAction)updatePostGain:(id)sender {
    [audioController setOutputGain:postGainSlider.value];
}

#pragma mark - METScopeViewDelegate Methods
- (void)pinchBegan:(METScopeView*)sender {
    
    /* Throttle time and spectrum plot updates based on the visible bounds of the time-domain plot (longer time-scales are more computationally intensive to plot, so throttle the plots more for longer scales) */
    float rate = 500 * (tdScopeView.visiblePlotMax.x - tdScopeView.visiblePlotMin.x) * [tdScopeClock timeInterval] + 30 * [tdScopeClock timeInterval];
    [self setTDUpdateRate:rate];
    [self setFDUpdateRate:rate/2];
    
    if (sender.displayMode == kMETScopeViewTimeDomainMode) {
        
    }
    
    else {
        
    }
}

- (void)pinchUpdate:(METScopeView*)sender {
    
    if (sender.displayMode == kMETScopeViewTimeDomainMode) {
        if (audioController.distortionEnabled)
            [self plotClippingThreshold];
    }
    else {
        /* Set the LPF and HPF to roll off at the updated plot bounds */
        [audioController rescaleFilters:fmax(fdScopeView.visiblePlotMin.x, 20.0) max:fdScopeView.visiblePlotMax.x];
    }
}

- (void)pinchEnded:(METScopeView*)sender {
    
    if (sender.displayMode == kMETScopeViewTimeDomainMode) {
        if (audioController.distortionEnabled)
            [self plotClippingThreshold];
    }
    else {
        /* Set the LPF and HPF to roll off at the updated plot bounds */
        [audioController rescaleFilters:fmax(fdScopeView.visiblePlotMin.x, 20.0) max:fdScopeView.visiblePlotMax.x];
    }
    
    /* Return time and spectrum plot updates to default rate */
    [self setTDUpdateRate:kScopeUpdateRate];
    [self setFDUpdateRate:kScopeUpdateRate];
}

- (void)panBegan:(METScopeView*)sender {
    
    /* Throttle time and spectrum plot updates based on the visible bounds of the time-domain plot (longer time-scales are more computationally intensive to plot, so throttle the plots more for longer scales) */
    float rate = 500 * (tdScopeView.visiblePlotMax.x - tdScopeView.visiblePlotMin.x) * [tdScopeClock timeInterval] + 30 * [tdScopeClock timeInterval];
    [self setTDUpdateRate:rate];
    [self setFDUpdateRate:rate/2];
    
    if (sender.displayMode == kMETScopeViewTimeDomainMode) {
        
    }
    
    else {
        
    }
}

- (void)panUpdate:(METScopeView*)sender {
    if (sender.displayMode == kMETScopeViewTimeDomainMode) {
        if (audioController.distortionEnabled)
            [self plotClippingThreshold];
    }
    else {
        /* Set the LPF and HPF to roll off at the updated plot bounds */
        [audioController rescaleFilters:fmax(fdScopeView.visiblePlotMin.x, 20.0) max:fdScopeView.visiblePlotMax.x];
    }
}

- (void)panEnded:(METScopeView*)sender {
    
    if (sender.displayMode == kMETScopeViewTimeDomainMode) {
        if (audioController.distortionEnabled)
            [self plotClippingThreshold];
    }
    else {
        /* Set the LPF and HPF to roll off at the updated plot bounds */
        [audioController rescaleFilters:fmax(fdScopeView.visiblePlotMin.x, 20.0) max:fdScopeView.visiblePlotMax.x];
    }
    
    /* Return time and spectrum plot updates to default rate */
    [self setTDUpdateRate:kScopeUpdateRate];
    [self setFDUpdateRate:kScopeUpdateRate];
}

#pragma mark - Utility
/* Generate a linearly-spaced set of indices for sampling an incoming waveform */
- (void)linspace:(float)minVal max:(float)maxVal numElements:(int)size array:(float*)array {
    
    float step = (maxVal-minVal)/(size-1);
    array[0] = minVal;
    int i;
    for (i = 1;i<size-1;i++) {
        array[i] = array[i-1]+step;
    }
    array[size-1] = maxVal;
}

/* Flash animation in the given rectangle */
- (void)flashInFrame:(CGRect)flashFrame {
    
    UIView *flashView = [[UIView alloc] initWithFrame:flashFrame];
    [flashView setBackgroundColor:[UIColor blackColor]];
    [flashView setAlpha:0.5f];
    [[self view] addSubview:flashView];
    [UIView animateWithDuration:0.5f
                     animations:^{
                         [flashView setAlpha:0.0f];
                     }
                     completion:^(BOOL finished) {
                         [flashView removeFromSuperview];
                     }
     ];
}

@end















