//
//  EffectsViewController.m
//  AudioWorks
//
//  Created by Jeff Gregorio on 6/24/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import "EffectsViewController.h"
#import "AppDelegate.h"

CGFloat const kInitialClippingAmplitudeHigh = 1.0;
CGFloat const kInitialClippingAmplitudeLow = -1.0;
CGFloat const kInitialModFreq = 2000.0;
CGFloat const kInitialModAmp = 0.75;
CGFloat const kFilterdBMagnitudeOffset = 0.0;

@interface EffectsViewController ()

@end

@implementation EffectsViewController

@synthesize audioController;
@synthesize helpDisplayed;

- (void)viewDidLoad {
    
    NSLog(@"%s: %@", __PRETTY_FUNCTION__, self);
    [super viewDidLoad];
    
    UIColor *offWhite = [UIColor colorWithRed:kAudioWorksBackgroundColor_R
                                        green:kAudioWorksBackgroundColor_G
                                         blue:kAudioWorksBackgroundColor_B
                                        alpha:1.0f];
    [[self view] setBackgroundColor:offWhite];
    [timeAxisLabel setBackgroundColor:offWhite];
    [freqAxisLabel setBackgroundColor:offWhite];
    
    /* Get a reference to the AudioController from the AppDelegate */
    AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    audioController = [delegate audioController];

    /* Scopes */
    [self setUpTDScope];
    [self setUpFDScope];
    
    /* Effect parameter controls */
    tdControlArray = [[METScopeControlArray alloc] initWithParentScope:tdScopeView];
    [self setUpDistortionControl];
    [self setUpDelayControl];
    
    fdControlArray = [[METScopeControlArray alloc] initWithParentScope:fdScopeView];
    [self setUpModulationControl];
    [self setUpFilterControl];
    [self setUpHelp];
    
    /* Update the scope views on timers by querying AudioController's wet/dry signal buffers */
    [self setTDUpdateRate:kEffectsScopeUpdateRate];
    [self setFDUpdateRate:kEffectsScopeUpdateRate];
}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    
    /* Get a reference to the AudioController from the AppDelegate */
    AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    audioController = [delegate audioController];
    
    /* Set the scope clocks */
    [self setTDUpdateRate:kEffectsScopeUpdateRate];
    tdHold = false;
    [self setFDUpdateRate:kEffectsScopeUpdateRate];
    fdHold = false;
    
    /* Display the help if the App Delegate's help button is active */
    if ([delegate helpDisplayed] != helpDisplayed)
        [self toggleHelp];
    
    /* Make sure we're not paused */
    if (![audioController inputEnabled])    [self enableInput];
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

- (void)dealloc {
    
    if (fdScopeTDXData) free(fdScopeTDXData);
    if (fdScopeTDYData) free(fdScopeTDYData);
    if (fdScopeFDXData) free(fdScopeFDXData);
    if (fdScopeFDYData) free(fdScopeFDYData);
    if (tdScopeXData) free(tdScopeXData);
    if (tdScopeYDataDry) free(tdScopeYDataDry);
    if (tdScopeYDataWet) free(tdScopeYDataWet);
    if (delayXBuffer) free(delayXBuffer);
    if (delayYBuffer) free(delayYBuffer);
    if (modulationXBuffer) free(modulationXBuffer);
    if (modulationYBuffer) free(modulationYBuffer);
}

#pragma mark - Setup
- (void)setUpTDScope {
    
    CGFloat minRange = (audioController.bufferSizeFrames+10) / audioController.sampleRate / 2.0f;
    CGFloat maxRange = ((audioController.recordingBufferLengthFrames-10) / audioController.sampleRate) - 0.5;
    
    [tdScopeView setPlotResolution:256];
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
    
    /* Allocate subviews for wet (pre-processing) and dry (post-processing) waveforms */
    tdDryIdx = [tdScopeView addPlotWithColor:[UIColor blueColor] lineWidth:2.0f];
    tdWetIdx = [tdScopeView addPlotWithColor:[UIColor  redColor] lineWidth:2.0f];
    
//    maxScale = 1.0;
//    startIdx = fmax(tdScopeView.visiblePlotMin.x, 0.0f) * audioController.sampleRate;
//    endIdx = (tdScopeView.visiblePlotMax.x  * maxScale) * audioController.sampleRate;
//    visibleBufferLength = endIdx - startIdx;
    [self tdScopeBoundsChanged];
}

- (void)setUpFDScope {
    
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
    [fdScopeView setHardYLim:-60 max:10];
    [fdScopeView setPlotUnitsPerYTick:20.0];
    [fdScopeView setAxesOn:true];
    [fdScopeView setDelegate:self];
    
    /* Allocate subviews for wet (pre-processing) and dry (post-processing) waveforms */
    fdDryIdx = [fdScopeView addPlotWithColor:[UIColor blueColor] lineWidth:2.0];
    fdWetIdx = [fdScopeView addPlotWithColor:[UIColor  redColor] lineWidth:2.0];
    
    /* Allocate constant-length buffers used copy data from the audioController to the FD Scope */
    fdScopeTDYData = (Float32 *)calloc([audioController bufferSizeFrames], sizeof(Float32));
    fdScopeTDXData = (Float32 *)calloc([audioController bufferSizeFrames], sizeof(Float32));
    [self linspace:0.0 max:([audioController bufferSizeFrames] * [audioController sampleRate])
       numElements:[audioController bufferSizeFrames] array:fdScopeTDXData];
    
    fdScopeFDYData = (Float32 *)calloc([audioController fftSize] / 2.0, sizeof(Float32));
    fdScopeFDXData = (Float32 *)calloc([audioController fftSize] / 2.0, sizeof(Float32));
    [self linspace:0.0 max:[audioController sampleRate] / 2.0 numElements:[audioController fftSize] / 2.0 array:fdScopeFDXData];
}

- (void)setUpDistortionControl {
    
    int idx;
    CGRect frame;
    METControl *control;
    UIColor *lineColor = [UIColor greenColor];
    
    /* High cutoff parameter */
    idx = [tdControlArray addControlWithStyle:kMETControlStyleRect
                                       values:CGPointMake([tdScopeView maxPlotMax].x, kInitialClippingAmplitudeHigh)];
    control = [tdControlArray getControlAtIndex:idx];
    [control setConstrainVerticallyToParentView:true];
    [control setConstrainHorizontallyToParentView:true];
    [control setVerticalRange:0.05 max:1.0];
    [control setHorizontalRange:[tdScopeView maxPlotMax].x max:[tdScopeView maxPlotMax].x];
    [control setDrawsHorizontalLineToLeft:true];
    [control setLineColor:lineColor];
    [control setTag:kDistCutoffHighTag];
    [control setHidden:true];
    
    /* Low cutoff parameter */
    idx = [tdControlArray addControlWithStyle:kMETControlStyleRect
                                       values:CGPointMake([tdScopeView maxPlotMax].x, kInitialClippingAmplitudeLow)];
    control = [tdControlArray getControlAtIndex:idx];
    [control setConstrainVerticallyToParentView:true];
    [control setConstrainHorizontallyToParentView:true];
    [control setVerticalRange:-1.0 max:-0.05];
    [control setHorizontalRange:[tdScopeView maxPlotMax].x max:[tdScopeView maxPlotMax].x];
    [control setDrawsHorizontalLineToLeft:true];
    [control setLineColor:lineColor];
    [control setTag:kDistCutoffLowTag];
    [control setHidden:true];
    
    /* Add the control array */
    [tdControlArray setNeedsDisplay];
    [tdScopeView addSubview:tdControlArray];
    [tdControlArray setDelegate:self];
    
    [audioController setClippingAmplitudeHigh:kInitialClippingAmplitudeHigh];
    [audioController setClippingAmplitudeLow:kInitialClippingAmplitudeLow];
    [audioController setDistortionEnabled:false];
    
    /* Create a subview over the right-most 15th of the time domain scope view for toggling distortion */
    frame.size.width = tdScopeView.frame.size.width / 7.1;
    frame.size.height = tdScopeView.frame.size.height;
    frame.origin.x = tdScopeView.frame.size.width - frame.size.width;
    frame.origin.y = 0;
    distortionTapRegionView = [[UIView alloc] initWithFrame:frame];
    [distortionTapRegionView setBackgroundColor:[[UIColor greenColor] colorWithAlphaComponent:0.05]];
    distCutoffTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleDistortion:)];
    [distCutoffTapRecognizer setNumberOfTapsRequired:1];
    [distortionTapRegionView addGestureRecognizer:distCutoffTapRecognizer];

    /* Add it to the control array */
    [tdControlArray addSubview:distortionTapRegionView];
}

- (void)setUpDelayControl {
    
    CGRect frame;
    CGPoint origin;
    
    /* Create a scope view for the delay signal. Hide it until we're editing a delay tap */
    delayScopeView = [[METScopeView alloc] initWithFrame:tdScopeView.frame];
    [delayScopeView setBackgroundColor:[UIColor clearColor]];
    [delayScopeView setPinchZoomEnabled:false];
    [delayScopeView setPanEnabled:false];
    [delayScopeView setPlotResolution:tdScopeView.plotResolution];
    [delayScopeView setHardXLim:-10.0 max:10.0];
    [delayScopeView setHardYLim:-10.0 max:10.0];
    [delayScopeView setAxesOn:false];
    [delayScopeView setGridOn:false];
    [delayScopeView setLabelsOn:false];
    [delayScopeView setMinPlotRange:CGPointMake(tdScopeView.minPlotRange.x, 0.1)];
    [delayScopeView setMaxPlotRange:CGPointMake(tdScopeView.maxPlotRange.x, 20.0)];
    [delayScopeView setAlpha:0.5];
    
    [[self view] addSubview:delayScopeView];
    [delayScopeView setUserInteractionEnabled:false];
    [delayScopeView setHidden:true];

    /* Allocate a subview for the delay signal */
    delayIdx = [delayScopeView addPlotWithResolution:200 color:[UIColor blackColor] lineWidth:2.0];
    
    /* Allocate buffers for copying plot data from the TD scope to the delay scope */
    delayXBuffer = (Float32 *)calloc(tdScopeView.plotResolution, sizeof(Float32));
    delayYBuffer = (Float32 *)calloc(tdScopeView.plotResolution, sizeof(Float32));
    
    /* Create a subview over the right-most 15th of the time domain scope view */
    frame.size.width = tdScopeView.frame.size.width / 7.1;
    frame.size.height = tdScopeView.frame.size.height;
    frame.origin.x = 0;
    frame.origin.y = 0;
    delayRegionView = [[UIView alloc] initWithFrame:frame];
    [delayRegionView setBackgroundColor:[UIColor blackColor]];
    [delayRegionView setAlpha:0.05];
    [tdControlArray addSubview:delayRegionView];
    
    /* Add a tap gesture recognizer to enable delay */
    delayTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleDelay:)];
    [delayTapRecognizer setNumberOfTapsRequired:1];
    [delayRegionView addGestureRecognizer:delayTapRecognizer];
    
    /* Add button for delay taps */
    origin = CGPointMake(delayRegionView.frame.origin.x + delayRegionView.frame.size.width / 2.0,
                         delayRegionView.frame.origin.y + 5.0 * delayRegionView.frame.size.height / 6.0);
    delayTapAddButton = [[METButton alloc] initWithTitle:@"+" origin:origin];
    frame = delayTapAddButton.frame;                // Center
    frame.origin.x -= frame.size.width / 2.0;
    frame.origin.y -= frame.size.height / 2.0;
    [delayTapAddButton setFrame:frame];
    [delayTapAddButton addTarget:self action:@selector(addDelayTap) forControlEvents:UIControlEventTouchUpInside];
    [delayTapAddButton setBackgroundColorForIdleState:[UIColor whiteColor]];
    [delayTapAddButton setBackgroundColorForHeldState:[UIColor lightGrayColor]];
    [delayTapAddButton setEnabled:false];
    [delayRegionView addSubview:delayTapAddButton];
    
    [audioController setDelayEnabled:false];
    editingDelayTap = false;
}

- (void)setUpModulationControl {
    
    int idx;
    METControl *control;
    
    modIdx = [fdScopeView addPlotWithColor:[UIColor greenColor] lineWidth:2.0];
    
    modulationYBuffer = (Float32 *)calloc([audioController bufferSizeFrames], sizeof(Float32));
    modulationXBuffer = (Float32 *)calloc([audioController bufferSizeFrames], sizeof(Float32));
    [self linspace:0.0 max:([audioController bufferSizeFrames] * [audioController sampleRate])
       numElements:[audioController bufferSizeFrames] array:modulationXBuffer];
    
    CGRect modRegionFrame;
    modRegionFrame.size.width = fdScopeView.frame.size.width;
    modRegionFrame.size.height = fdScopeView.frame.size.height / 4;
    modRegionFrame.origin.x = fdScopeView.frame.size.width - modRegionFrame.size.width;
    modRegionFrame.origin.y = fdScopeView.frame.size.height - modRegionFrame.size.height;
    modFreqPanRegionView = [[UIView alloc] initWithFrame:modRegionFrame];
    [modFreqPanRegionView setBackgroundColor:[UIColor greenColor]];
    [modFreqPanRegionView setAlpha:0.05];
    
    /* Add a tap gesture recognizer to enable modulation */
    modFreqTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleModulation:)];
    [modFreqTapRecognizer setNumberOfTapsRequired:1];
    [modFreqPanRegionView addGestureRecognizer:modFreqTapRecognizer];
    
    /* Modulation frequncy control dot */
    idx = [fdControlArray addControlWithStyle:kMETControlStyleDot
                                       values:CGPointMake(kInitialModFreq, kInitialModAmp)];
    control = [fdControlArray getControlAtIndex:idx];
    [control setConstrainVerticallyToParentView:true];
    [control setConstrainHorizontallyToParentView:false];
    [control setVerticalRange:-60.0f max:10.0f];
    [control setHorizontalRange:[fdScopeView minPlotMin].x max:[fdScopeView maxPlotMax].x];
    [control setDrawsVerticalLineToBottom:true];
    [control setLineColor:[UIColor greenColor]];
    [control setTag:kModulationParamsTag];
    
    /* Hide the control until the effect is activated */
    [[fdControlArray getControlWithTag:kModulationParamsTag] setHidden:true];
    
    /* Add the toggle region to the control array */
    [fdControlArray addSubview:modFreqPanRegionView];
    
    [audioController setModulationEnabled:false];
    [audioController setModFrequency:kInitialModFreq];
    [audioController setModAmp:kInitialModAmp];
}

- (void)setUpFilterControl {
    
    /* Allocate subview for the filter transfer functions */
    lpfIdx = [fdScopeView addPlotWithColor:[UIColor blackColor] lineWidth:2.0];
    hpfIdx = [fdScopeView addPlotWithColor:[UIColor blackColor] lineWidth:2.0];
    [fdScopeView setVisibilityAtIndex:lpfIdx visible:false];
    [fdScopeView setVisibilityAtIndex:hpfIdx visible:false];
    
    /* Create a subview over at the left side of the spectrum */
    CGRect hpfTapRegionFrame;
    hpfTapRegionFrame.size.width = fdScopeView.frame.size.width / 7.1;
    hpfTapRegionFrame.size.height = fdScopeView.frame.size.height - modFreqPanRegionView.frame.size.height;
    hpfTapRegionFrame.origin.x = 0;
    hpfTapRegionFrame.origin.y = 0;
    hpfTapRegionView = [[FilterTapRegionView alloc] initWithFrame:hpfTapRegionFrame];
    [hpfTapRegionView setBackgroundColor:[UIColor clearColor]];
    [hpfTapRegionView setFillColor:[UIColor blackColor]];
    [hpfTapRegionView setAlpha:0.05];
    
    /* Add a tap gesture recognizer to enable/disable the HPF */
    hpfTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleHPF:)];
    [hpfTapRecognizer setNumberOfTapsRequired:1];
    [hpfTapRegionView addGestureRecognizer:hpfTapRecognizer];
    
    /* Create a subview over at the right side of the spectrum */
    CGRect lpfTapRegionFrame;
    lpfTapRegionFrame.size.width = fdScopeView.frame.size.width / 7.1;
    lpfTapRegionFrame.size.height = fdScopeView.frame.size.height - modFreqPanRegionView.frame.size.height;
    lpfTapRegionFrame.origin.x = fdScopeView.frame.size.width - lpfTapRegionFrame.size.width;
    lpfTapRegionFrame.origin.y = 0;
    lpfTapRegionView = [[FilterTapRegionView alloc] initWithFrame:lpfTapRegionFrame];
    [lpfTapRegionView setBackgroundColor:[UIColor clearColor]];
    [lpfTapRegionView setFillColor:[UIColor blackColor]];
    [lpfTapRegionView setAlpha:0.05];
    
    /* Add a tap gesture recognizer to enable/disable the HPF */
    lpfTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleLPF:)];
    [lpfTapRecognizer setNumberOfTapsRequired:1];
    [lpfTapRegionView addGestureRecognizer:lpfTapRecognizer];
    
    /* Make a "knee" shaped fill region for the filter cutoff views */
    int nPoints = 100;
    float fillRegionX[nPoints];
    CGPoint fillRegion[nPoints];
    
    [self linspace:0.001f max:hpfTapRegionFrame.size.width numElements:nPoints-1 array:fillRegionX];
    for (int i = 0; i < nPoints-1; i++) {
        fillRegion[i].x = fillRegionX[i];
        fillRegion[i].y = 500.0f / fillRegionX[i] - fillRegionX[i] * 5.0f / hpfTapRegionFrame.size.width;
    }
    fillRegion[nPoints-1].x = hpfTapRegionFrame.origin.x;
    fillRegion[nPoints-1].y = hpfTapRegionFrame.origin.y;
    [hpfTapRegionView setFillRegion:fillRegion numPoints:nPoints];
    
    /* Reverse direction of y coordinates for the LPF */
    CGPoint temp;
    for (int i = 0, j = nPoints-1; i < nPoints/2; i++, j--) {
        temp.y = fillRegion[i].y;
        fillRegion[i].y = fillRegion[j].y;
        fillRegion[j].y = temp.y;
    }
    fillRegion[nPoints-1].x = lpfTapRegionFrame.size.width;
    fillRegion[nPoints-1].y = 0.0f;
    [lpfTapRegionView setFillRegion:fillRegion numPoints:nPoints];
    
    [audioController setLPFEnabled:false];
    [audioController setHPFEnabled:false];
    
    /* LPF control dot */
    int idx = [fdControlArray addControlWithStyle:kMETControlStyleDot
                                       values:CGPointMake(audioController->lpf.cornerFrequency,
                                                          0.0)];
    METControl *control = [fdControlArray getControlAtIndex:idx];
    [control setConstrainVerticallyToParentView:true];
    [control setConstrainHorizontallyToParentView:false];
    [control setVerticalRange:-8.0f max:15.0f];
    [control setHorizontalRange:30.0f max:[fdScopeView maxPlotMax].x];
    [control setDrawsVerticalLineToBottom:true];
    [control setLineColor:[UIColor blackColor]];
    [control setTag:kLPFParamsTag];
    
    /* HPF control dot */
    idx = [fdControlArray addControlWithStyle:kMETControlStyleDot
                                       values:CGPointMake(audioController->hpf.cornerFrequency,
                                                          0.0)];
    control = [fdControlArray getControlAtIndex:idx];
    [control setConstrainVerticallyToParentView:true];
    [control setConstrainHorizontallyToParentView:false];
    [control setVerticalRange:-5.0f max:15.0f];
    [control setHorizontalRange:30.0f max:[fdScopeView maxPlotMax].x];
    [control setDrawsVerticalLineToBottom:true];
    [control setLineColor:[UIColor blackColor]];
    [control setTag:kHPFParamsTag];
    
    /* Hide the controls until the effect is activated */
    [[fdControlArray getControlWithTag:kLPFParamsTag] setHidden:true];
    [[fdControlArray getControlWithTag:kHPFParamsTag] setHidden:true];
    
    /* Add the filter toggle regions to the control array */
    [fdControlArray addSubview:hpfTapRegionView];
    [fdControlArray addSubview:lpfTapRegionView];
    
    [fdControlArray setNeedsDisplay];
    [fdScopeView addSubview:fdControlArray];
    [fdControlArray setDelegate:self];
    [fdControlArray setHidden:false];
    
    /* Allocate buffers for storing the filter magnitude response */
    lpfMagnitudeResponse = (Float32 *)calloc([audioController fftSize] / 2.0, sizeof(Float32));
    hpfMagnitudeResponse = (Float32 *)calloc([audioController fftSize] / 2.0, sizeof(Float32));
    
    [self computeLPFMagnitudeResponse];
    [self computeHPFMagnitudeResponse];
}

- (void)setUpHelp {
    
    CGPoint origin;
    HelpBubble *bbl;
    UIColor *effectsModeHelpColor = [UIColor colorWithRed:20/255.0f green:60/255.0f blue:25/255.0f alpha:1.0f];
    
    helpDisplayed = false;
    helpBubblesDelayEnabled = [[NSMutableArray alloc] init];
    helpBubblesDelayDisabled = [[NSMutableArray alloc] init];
    helpBubblesDistEnabled = [[NSMutableArray alloc] init];
    helpBubblesDistDisabled = [[NSMutableArray alloc] init];
    helpBubblesModEnabled = [[NSMutableArray alloc] init];
    helpBubblesModDisabled = [[NSMutableArray alloc] init];
    helpBubblesLPFEnabled = [[NSMutableArray alloc] init];
    helpBubblesLPFDisabled = [[NSMutableArray alloc] init];
    helpBubblesHPFEnabled = [[NSMutableArray alloc] init];
    helpBubblesHPFDisabled = [[NSMutableArray alloc] init];
    
    /* Effects mode desc. */
    origin.x = tdScopeView.frame.origin.x + tdScopeView.frame.size.width / 2.3f;
    origin.y = tdScopeView.frame.origin.y + 50.0f;
    bbl = [[HelpBubble alloc] initWithText:@"When using effects, the blue signal is the input (clean) and the red signal is the output (effected)"
                                    origin:origin
                                     width:300.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationNone];
    [bbl setColor:effectsModeHelpColor];
    [bbl setFrameSizeForFontSize:21.0f];
    [[self view] addSubview:bbl];
    [helpBubblesDelayDisabled addObject:bbl];
    [bbl setHidden:true];
    
    /* Distortion desc. */
    origin.x = tdScopeView.frame.origin.x + tdScopeView.frame.size.width - 262.0f;
    origin.y = tdScopeView.frame.origin.y + tdScopeView.frame.size.height - 100.0f;
    bbl = [[HelpBubble alloc] initWithText:@"Tap to activate distortion..."
                                    origin:origin
                                     width:250.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationRight];
    [bbl setColor:effectsModeHelpColor];
    [[self view] addSubview:bbl];
    [helpBubblesDistDisabled addObject:bbl];
    [bbl setHidden:true];
    
    origin.x = tdScopeView.frame.origin.x + tdScopeView.frame.size.width - 340.0f;
    origin.y = tdScopeView.frame.origin.y + tdScopeView.frame.size.height - 113.0f;
    bbl = [[HelpBubble alloc] initWithText:@"Move the controls to adjust the hard-clipping thresholds"
                                    origin:origin
                                     width:250.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationRight];
    [bbl setColor:effectsModeHelpColor];
    [[self view] addSubview:bbl];
    [helpBubblesDistEnabled addObject:bbl];
    [bbl setHidden:true];
    
    /* Delay desc. */
    origin.x = tdScopeView.frame.origin.x + 115.0f;
    origin.y = tdScopeView.frame.origin.y + tdScopeView.frame.size.height - 100.0f;
    bbl = [[HelpBubble alloc] initWithText:@"Tap to activate \ndelay..."
                                    origin:origin
                                     width:250.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationLeft];
    [bbl setColor:effectsModeHelpColor];
    [[self view] addSubview:bbl];
    [helpBubblesDelayDisabled addObject:bbl];
    [bbl setHidden:true];
    
    origin.x = tdScopeView.frame.origin.x + 115.0f;
    origin.y = tdScopeView.frame.origin.y + 225.0f;
    bbl = [[HelpBubble alloc] initWithText:@"Tap add button to add a delay tap control. Move the control to adjust the delay time and amplitude. \n\nDrag the control down to zero to delete."
                                    origin:origin
                                     width:300.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationLeft offset:CGPointMake(0.0f, 59.0f)];
    [bbl setColor:effectsModeHelpColor];
    [bbl setFrameSizeForFontSize:21.0f];
    [[self view] addSubview:bbl];
    [helpBubblesDelayEnabled addObject:bbl];
    [bbl setHidden:true];
    
    /* Modulation desc. */
    origin.x = fdScopeView.frame.origin.x + fdScopeView.frame.size.width / 2.0f - 125.0f;
    origin.y = fdScopeView.frame.origin.y + fdScopeView.frame.size.height - 165.0f;
    bbl = [[HelpBubble alloc] initWithText:@"Tap to activate amplitude modulation..."
                                    origin:origin
                                     width:250.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationBottom];
    [bbl setColor:effectsModeHelpColor];
    [[self view] addSubview:bbl];
    [helpBubblesModDisabled addObject:bbl];
    [bbl setHidden:true];
    
    origin.x = fdScopeView.frame.origin.x + fdScopeView.frame.size.width / 2.0f - 122.0f;
    origin.y = fdScopeView.frame.origin.y + fdScopeView.frame.size.height - 191.0f;
    bbl = [[HelpBubble alloc] initWithText:@"Move the control to adjust the carrier wave\u2019s frequency and amplitude."
                                    origin:origin
                                     width:250.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationBottom offset:CGPointMake(1.0f, 0.0f)];
    [bbl setColor:effectsModeHelpColor];
    [[self view] addSubview:bbl];
    [helpBubblesModEnabled addObject:bbl];
    [bbl setHidden:true];
    
    /* Filter desc. */
    origin.x = fdScopeView.frame.origin.x + 20.0f;
    origin.y = fdScopeView.frame.origin.y + 20.0f;
    bbl = [[HelpBubble alloc] initWithText:@"Tap to activate high-pass filter..."
                                    origin:origin
                                     width:200.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationTop offset:CGPointMake(-73.0f, 0.0f)];
    [bbl setColor:effectsModeHelpColor];
    [[self view] addSubview:bbl];
    [helpBubblesHPFDisabled addObject:bbl];
    [bbl setHidden:true];
    
    bbl = [[HelpBubble alloc] initWithText:@"Move the control to adjust the filter\u2019s cutoff frequency and resonance."
                                    origin:origin
                                     width:200.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationTop offset:CGPointMake(-76.0f, 0.0f)];
    [bbl setColor:effectsModeHelpColor];
    [[self view] addSubview:bbl];
    [helpBubblesHPFEnabled addObject:bbl];
    [bbl setHidden:true];
    
    origin.x = fdScopeView.frame.origin.x + fdScopeView.frame.size.width - 205.0f;
    origin.y = fdScopeView.frame.origin.y + 20.0f;
    bbl = [[HelpBubble alloc] initWithText:@"Tap to activate low-pass filter..."
                                    origin:origin
                                     width:200.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationTop offset:CGPointMake(70.0f, 0.0f)];
    [bbl setColor:effectsModeHelpColor];
    [[self view] addSubview:bbl];
    [helpBubblesLPFDisabled addObject:bbl];
    [bbl setHidden:true];
    
    origin.x = fdScopeView.frame.origin.x + fdScopeView.frame.size.width - 216.0f;
    origin.y = fdScopeView.frame.origin.y + 20.0f;
    bbl = [[HelpBubble alloc] initWithText:@"Move the control to adjust the filter\u2019s cutoff frequency and resonance."
                                    origin:origin
                                     width:200.0f];
    [bbl setPointerLocation:kHelpBubblePointerLocationTop offset:CGPointMake(74.5f, 0.0f)];
    [bbl setColor:effectsModeHelpColor];
    [[self view] addSubview:bbl];
    [helpBubblesLPFEnabled addObject:bbl];
    [bbl setHidden:true];
}

#pragma mark - Help
- (void)toggleHelp {
    helpDisplayed = !helpDisplayed;
    [self updateHelp];
}

- (void)updateHelp {
    
    if (!helpDisplayed) {
        
        /* Set all help bubble arrays to hidden in case we've changed modes since help was displayed */
        for (int i = 0; i < [helpBubblesDelayEnabled count]; i++)
            [[helpBubblesDelayEnabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [helpBubblesDelayDisabled count]; i++)
            [[helpBubblesDelayDisabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [helpBubblesDistEnabled count]; i++)
            [[helpBubblesDistEnabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [helpBubblesDistDisabled count]; i++)
            [[helpBubblesDistDisabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [helpBubblesModEnabled count]; i++)
            [[helpBubblesModEnabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [helpBubblesModDisabled count]; i++)
            [[helpBubblesModDisabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [helpBubblesLPFEnabled count]; i++)
            [[helpBubblesLPFEnabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [helpBubblesLPFDisabled count]; i++)
            [[helpBubblesLPFDisabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [helpBubblesHPFEnabled count]; i++)
            [[helpBubblesHPFEnabled objectAtIndex:i] setHidden:true];
        for (int i = 0; i < [helpBubblesHPFDisabled count]; i++)
            [[helpBubblesHPFDisabled objectAtIndex:i] setHidden:true];
    }
    
    /* If help is enabled, check modes to display the relevant help info */
    else {
        
        /* Delay state-dependent */
        for (int i = 0; i < [helpBubblesDelayEnabled count]; i++)
            [[helpBubblesDelayEnabled objectAtIndex:i] setHidden:![audioController delayEnabled]];
        for (int i = 0; i < [helpBubblesDelayDisabled count]; i++)
            [[helpBubblesDelayDisabled objectAtIndex:i] setHidden:[audioController delayEnabled]];

        /* Distortion state-dependent */
        for (int i = 0; i < [helpBubblesDistEnabled count]; i++)
            [[helpBubblesDistEnabled objectAtIndex:i] setHidden:![audioController distortionEnabled]];
        for (int i = 0; i < [helpBubblesDistDisabled count]; i++)
            [[helpBubblesDistDisabled objectAtIndex:i] setHidden:[audioController distortionEnabled]];
        
        /* Modulation state-dependent */
        for (int i = 0; i < [helpBubblesModEnabled count]; i++)
            [[helpBubblesModEnabled objectAtIndex:i] setHidden:![audioController modulationEnabled]];
        for (int i = 0; i < [helpBubblesModDisabled count]; i++)
            [[helpBubblesModDisabled objectAtIndex:i] setHidden:[audioController modulationEnabled]];
        
        /* LPF state-dependent */
        for (int i = 0; i < [helpBubblesLPFEnabled count]; i++)
            [[helpBubblesLPFEnabled objectAtIndex:i] setHidden:![audioController lpfEnabled]];
        for (int i = 0; i < [helpBubblesLPFDisabled count]; i++)
            [[helpBubblesLPFDisabled objectAtIndex:i] setHidden:[audioController lpfEnabled]];
        
        /* HPF state-dependent */
        for (int i = 0; i < [helpBubblesHPFEnabled count]; i++)
            [[helpBubblesHPFEnabled objectAtIndex:i] setHidden:![audioController hpfEnabled]];
        for (int i = 0; i < [helpBubblesHPFDisabled count]; i++)
            [[helpBubblesHPFDisabled objectAtIndex:i] setHidden:[audioController hpfEnabled]];
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
    
//    /* If we're getting input from the Synth, we need to extend the time duration we're retrieving from the recording buffer to compensate for the phaze zero offset. Lower fundamental frequencies have larger offsets due to longer wavelengths. */    

    
    if (tdHold || [tdScopeView hasCurrentPinch] || [tdScopeView hasCurrentPan])
        return;
    
    /* Get current visible samples from the audio controller */
    if (![audioController inputEnabled]) {
        [audioController getInputBuffer:tdScopeYDataDry from:startIdx to:endIdx];
        [audioController getOutputBuffer:tdScopeYDataWet from:startIdx to:endIdx];
    }
    else {
        
        if (![audioController synthEnabled]) {
            [audioController getInputBuffer:tdScopeYDataDry withLength:visibleBufferLength];
            [audioController getOutputBuffer:tdScopeYDataWet withLength:visibleBufferLength];
        }
        else {
            [audioController getInputBuffer:tdScopeYDataDry withLength:visibleBufferLength offset:audioController.phaseZeroOffset];
            [audioController getOutputBuffer:tdScopeYDataWet withLength:visibleBufferLength offset:audioController.phaseZeroOffset];
        }
    }
    
    [tdScopeView setPlotDataAtIndex:tdDryIdx
                         withLength:visibleBufferLength
                              xData:tdScopeXData
                              yData:tdScopeYDataDry];
    
    [tdScopeView setPlotDataAtIndex:tdWetIdx
                         withLength:visibleBufferLength
                              xData:tdScopeXData
                              yData:tdScopeYDataWet];
    
    if (editingDelayTap && ![audioController inputEnabled]) {
        [delayScopeView setHidden:false];
        [self plotInputCopyForDelayTap];
    }
    else {
        [delayScopeView setHidden:true];
    }
}

- (void)updateFDScope {
    
    if (fdHold || [fdScopeView hasCurrentPinch] || [fdScopeView hasCurrentPan])
        return;
    
    /* If we've taken a snapshot, plot the averaged spectrum of the visible portion */
    if (![audioController inputEnabled]) {
        
        int sIdx = fmax(tdScopeView.visiblePlotMin.x, 0.0) * audioController.sampleRate;
        int eIdx = fmin(tdScopeView.visiblePlotMax.x * audioController.sampleRate, audioController.recordingBufferLengthFrames);
        
        /* Get spectrum of current visible samples from the audio controller and plot */
        [audioController getAverageSpectrum:fdScopeFDYData from:sIdx to:eIdx];
        [fdScopeView setCoordinatesInFDModeAtIndex:fdDryIdx
                                        withLength:audioController.fftSize/2
                                             xData:fdScopeFDXData
                                             yData:fdScopeFDYData];
        
        /* Also plot the averaged spectrum of the visible portion of the output buffer if in effects mode */
        if ([fdScopeView getVisibilityAtIndex:fdWetIdx]) {
            [audioController getAverageOutputSpectrum:fdScopeFDYData from:startIdx to:endIdx];
            [fdScopeView setCoordinatesInFDModeAtIndex:fdWetIdx
                                            withLength:audioController.fftSize/2
                                                 xData:fdScopeFDXData
                                                 yData:fdScopeFDYData];
        }
    }
    
    /* Otherwise, plot the wet and dry spectrum of the current audio buffer */
    else {
        /* Get current visible samples from the audio controller */
        [audioController getInputBuffer:fdScopeTDYData withLength:audioController.bufferSizeFrames];
        [fdScopeView setPlotDataAtIndex:fdDryIdx
                             withLength:audioController.bufferSizeFrames
                                  xData:fdScopeTDXData
                                  yData:fdScopeTDYData];
        
        [audioController getOutputBuffer:fdScopeTDYData withLength:audioController.bufferSizeFrames];
        [fdScopeView setPlotDataAtIndex:fdWetIdx
                             withLength:audioController.bufferSizeFrames
                                  xData:fdScopeTDXData
                                  yData:fdScopeTDYData];
    }
    
    if ([audioController modulationEnabled])
        [self plotModFreq];
}

- (void)plotModFreq {
    
    [audioController getModulationBuffer:modulationYBuffer withLength:[audioController bufferSizeFrames]];
    [fdScopeView setPlotDataAtIndex:modIdx
                         withLength:[audioController bufferSizeFrames]
                              xData:modulationXBuffer
                              yData:modulationYBuffer];
}

- (void)plotInputCopyForDelayTap {
    
    CGFloat newMin, newMax;
    
    /* Copy the TD Scope's current output buffer for the delay plot */
    [tdScopeView getPlotDataAtIndex:tdDryIdx withLength:tdScopeView.plotResolution xData:delayXBuffer yData:delayYBuffer];

    /* Plot */
    [delayScopeView setPlotDataAtIndex:delayIdx
                            withLength:tdScopeView.plotResolution
                                 xData:delayXBuffer
                                 yData:delayYBuffer];
    
    [delayScopeView setFillMode:[tdScopeView getFillModeAtIndex:tdDryIdx] atIndex:delayIdx];
    
    /* Set the bounds based on the delay parameters of the active dot */
    newMin = tdScopeView.visiblePlotMin.x - activeDelayTapControl.values.x;
    newMax = tdScopeView.visiblePlotMax.x - activeDelayTapControl.values.x;
    [delayScopeView setVisibleXLim:newMin max:newMax];
    
    newMin = tdScopeView.visiblePlotMin.y / activeDelayTapControl.values.y;
    newMax = tdScopeView.visiblePlotMax.y / activeDelayTapControl.values.y;
    [delayScopeView setVisibleYLim:newMin max:newMax];
}

#pragma mark - Audio
- (void)toggleInput {
    
    if ([audioController inputEnabled]) [self disableInput];
    else [self enableInput];
    
    /* Flash animation on the time-domain plot */
    [self flashInFrame:tdScopeView.frame];
    
    /* Update help if displayed */
    if (helpDisplayed)
        [self updateHelp];
}

- (void)enableInput {
    [audioController setInputEnabled:true];
}

- (void)disableInput {
    [audioController setInputEnabled:false];
    
    [audioController computeFFTs];
    
    /* Update the visible limits on the audioController for processing visible audio offline */
    [audioController setVisibleRangeInSeconds:fmaxf(0.0f, tdScopeView.visiblePlotMin.x) max:tdScopeView.visiblePlotMax.x];
}

#pragma mark - Effects
- (void)toggleDelay:(id)sender {
    
    /* Enable */
    if (![audioController delayEnabled]) {
        [audioController setDelayEnabled:true];
        [delayRegionView setAlpha:kEffectEnabledAlpha];
        
        for (int i = 0; i < [audioController getNumDelayTaps]; i++)
            [[tdControlArray getControlWithTag:kDelayParamsTag+i] setHidden:false];
        
        [delayTapAddButton setEnabled:true];
    }
    /* Disable */
    else {
        [audioController setDelayEnabled:false];
        [delayRegionView setAlpha:kEffectDisabledAlpha];
        
        for (int i = 0; i < [audioController getNumDelayTaps]; i++)
            [[tdControlArray getControlWithTag:kDelayParamsTag+i] setHidden:true];
        
        [delayTapAddButton setEnabled:false];
    }

    CGRect flashFrame = delayRegionView.frame;
    flashFrame.origin.x += tdScopeView.frame.origin.x;
    flashFrame.origin.y += tdScopeView.frame.origin.y;
    [self flashInFrame:flashFrame];
    
    if (helpDisplayed)
        [self updateHelp];
}

- (void)toggleDistortion:(UITapGestureRecognizer *)sender {

    /* Don't toggle distortion if tap was on the distortion controls */
    METControl *distControlHigh = [tdControlArray getControlWithTag:kDistCutoffHighTag];
    METControl *distControlLow = [tdControlArray getControlWithTag:kDistCutoffLowTag];
    CGPoint touch = [sender locationOfTouch:0 inView:tdControlArray];
    if (CGRectContainsPoint(distControlHigh.frame, touch) || CGRectContainsPoint(distControlLow.frame, touch))
        return;
    
    /* Disable */
    if (audioController.distortionEnabled) {
        
        [audioController setDistortionEnabled:false];
        [distortionTapRegionView setBackgroundColor:[[UIColor greenColor] colorWithAlphaComponent:kEffectDisabledAlpha]];

        /* Hide the distortion controls */
        [[tdControlArray getControlWithTag:kDistCutoffHighTag] setHidden:true];
        [[tdControlArray getControlWithTag:kDistCutoffLowTag] setHidden:true];
    }
    
    /* Enable */
    else {
        [audioController setDistortionEnabled:true];
        [distortionTapRegionView setBackgroundColor:[[UIColor greenColor] colorWithAlphaComponent:kEffectEnabledAlpha]];
        
        /* Unhide the distortion controls */
        [[tdControlArray getControlWithTag:kDistCutoffHighTag] setHidden:false];
        [tdControlArray bringSubviewToFront:[tdControlArray getControlWithTag:kDistCutoffHighTag]];
        [[tdControlArray getControlWithTag:kDistCutoffLowTag] setHidden:false];
        [tdControlArray bringSubviewToFront:[tdControlArray getControlWithTag:kDistCutoffLowTag]];
    }
    
    CGRect flashFrame = distortionTapRegionView.frame;
    flashFrame.origin.x += tdScopeView.frame.origin.x;
    flashFrame.origin.y += tdScopeView.frame.origin.y;
    [self flashInFrame:flashFrame];
    
    /* Update help if displayed */
    if (helpDisplayed)
        [self updateHelp];
}

- (void)toggleModulation:(UITapGestureRecognizer *)sender {
    
    /* Disable */
    if (audioController.modulationEnabled) {
        [audioController setModulationEnabled:false];
        [fdScopeView setVisibilityAtIndex:modIdx visible:false];
        [modFreqPanRegionView setAlpha:kEffectDisabledAlpha];
        
        /* Hide the modulation parameter control */
        [[fdControlArray getControlWithTag:kModulationParamsTag] setHidden:true];
        
//        /* Put the effects parameter views back on the FD scope */
//        [modFreqPanRegionView removeFromSuperview];
//        [lpfTapRegionView removeFromSuperview];
//        [hpfTapRegionView removeFromSuperview];
//        
//        [fdScopeView addSubview:modFreqPanRegionView];
//        [fdScopeView addSubview:lpfTapRegionView];
//        [fdScopeView addSubview:hpfTapRegionView];
//        
//        /* Hide the control */
//        [fdControlArray setHidden:true];
    }
    
    /* Enable */
    else {
        [audioController setModulationEnabled:true];
        [fdScopeView setVisibilityAtIndex:modIdx visible:true];
        [modFreqPanRegionView setAlpha:kEffectEnabledAlpha];
        
        /* Show the modulation parameter control */
        [[fdControlArray getControlWithTag:kModulationParamsTag] setHidden:false];
        
//        /* If the modulation frequency is beyond the plot bounds, put it in the center */
//        if (audioController->modFreq < fdScopeView.visiblePlotMin.x ||
//            audioController->modFreq > fdScopeView.visiblePlotMax.x)
//            [audioController setModFrequency:(fdScopeView.visiblePlotMax.x - fdScopeView.visiblePlotMin.x)];
//        
//        [fdControlArray setHidden:false];   // Show the parameter control overlay
//        
//        /* Move the effects parameter views from the scope to the ParameterDotArray view overlay */
//        [modFreqPanRegionView removeFromSuperview];
//        [lpfTapRegionView removeFromSuperview];
//        [hpfTapRegionView removeFromSuperview];
//        [fdControlArray addSubview:modFreqPanRegionView];
//        [fdControlArray addSubview:lpfTapRegionView];
//        [fdControlArray addSubview:hpfTapRegionView];
        
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

- (void)toggleHPF:(UITapGestureRecognizer *)sender {
    
    CGPoint touchLoc = [sender locationInView:hpfTapRegionView];
    
    float endAlpha;
    
    if (![hpfTapRegionView pointInFillRegion:touchLoc])
        return;
    
    if ([audioController hpfEnabled]) {
        
        /* Disable */
        [audioController setHPFEnabled:false];
        endAlpha = kEffectDisabledAlpha;
        
        /* Hide the control */
        [[fdControlArray getControlWithTag:kHPFParamsTag] setHidden:true];
        
        /* Hide the transfer function */
        [fdScopeView setVisibilityAtIndex:hpfIdx visible:false];

    }
    else {
        
        /* Enable */
        [audioController setHPFEnabled:true];
        endAlpha = kEffectEnabledAlpha;
        
        /* Show the control */
        [[fdControlArray getControlWithTag:kHPFParamsTag] setHidden:false];
        
        /* Show the transfer function */
        [fdScopeView setVisibilityAtIndex:hpfIdx visible:true];

    }
    
    [hpfTapRegionView setAlpha:1.0f];
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
        
        /* Disable */
        [audioController setLPFEnabled:false];
        endAlpha = kEffectDisabledAlpha;
        
        /* Hide the control */
        [[fdControlArray getControlWithTag:kLPFParamsTag] setHidden:true];
        
        /* Hide the transfer function */
        [fdScopeView setVisibilityAtIndex:lpfIdx visible:false];

    }
    else {
        
        /* Enable */
        [audioController setLPFEnabled:true];
        endAlpha = kEffectEnabledAlpha;
        
        /* Show the control */
        [[fdControlArray getControlWithTag:kLPFParamsTag] setHidden:false];
        
        /* Show the transfer function */
        [fdScopeView setVisibilityAtIndex:lpfIdx visible:true];
    }
    
    [lpfTapRegionView setAlpha:1.0f];
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

- (void)computeLPFMagnitudeResponse {
    
    float coeffs[5];
    [audioController->lpf getCoefficients:coeffs];
    
    float a1, a2, b0, b1, b2;
    b0 = coeffs[0];
    b1 = coeffs[1];
    b2 = coeffs[2];
    a1 = coeffs[3];
    a2 = coeffs[4];
    
    Float32 w, y;
    for (int i = 0; i < [audioController fftSize] / 2.0; i++) {
        
        /* Normalized DFT frequency */
        w = fdScopeFDXData[i] * 2.0 / [audioController sampleRate] * M_PI;
        
        y = b0*b0 + b1*b1 + b2*b2 + 2.0*(b0*b1 + b1*b2)*cosf(w) + 2.0*b0*b2*cos(2*w);
        y /= 1.0 + a1*a1 + a2*a2 + 2.0*(a1 + a1*a2)*cos(w) + 2*a2*cos(2*w);
        y = y < 0.0 ? 0.0 : y;
        y = y == INFINITY ? 0.0 : y;
        y = sqrtf(y);
        
        lpfMagnitudeResponse[i] = y;
    }
    
    [fdScopeView setCoordinatesInFDModeAtIndex:lpfIdx
                                    withLength:audioController.fftSize/2
                                         xData:fdScopeFDXData
                                         yData:lpfMagnitudeResponse];
}

- (void)computeHPFMagnitudeResponse {
    
    float coeffs[5];
    [audioController->hpf getCoefficients:coeffs];
    
    float a1, a2, b0, b1, b2;
    b0 = coeffs[0];
    b1 = coeffs[1];
    b2 = coeffs[2];
    a1 = coeffs[3];
    a2 = coeffs[4];
    
    Float32 w, y;
    for (int i = 0; i < [audioController fftSize] / 2.0; i++) {
        
        /* Normalized DFT frequency */
        w = fdScopeFDXData[i] * 2.0 / [audioController sampleRate] * M_PI;
        
        y = b0*b0 + b1*b1 + b2*b2 + 2.0*(b0*b1 + b1*b2)*cosf(w) + 2.0*b0*b2*cos(2*w);
        y /= 1.0 + a1*a1 + a2*a2 + 2.0*(a1 + a1*a2)*cos(w) + 2*a2*cos(2*w);
        y = y < 0.0 ? 0.0 : y;
        y = y == INFINITY ? 0.0 : y;
        y = sqrtf(y);
        
        hpfMagnitudeResponse[i] = y;
    }
    
    [fdScopeView setCoordinatesInFDModeAtIndex:hpfIdx
                                    withLength:audioController.fftSize/2
                                         xData:fdScopeFDXData
                                         yData:hpfMagnitudeResponse];
}

- (void)addDelayTap {
    
    if ([audioController getNumDelayTaps] == kMaxNumDelayTaps)
        return;
    
    /* Pause the input and reveal the delay scope view after adding a tap */
    if ([audioController inputEnabled])
        [(AppDelegate *)[[UIApplication sharedApplication] delegate] playbackButtonPress:self];
    
    int idx;
    CGPoint vals = CGPointMake(tdScopeView.visiblePlotMin.x + (tdScopeView.visiblePlotMax.x - tdScopeView.visiblePlotMin.x) / 3.0f, 0.5);
    
    idx = [tdControlArray addControlWithStyle:kMETControlStyleDot values:vals];
    activeDelayTapControl = [tdControlArray getControlAtIndex:idx];
    [activeDelayTapControl setDrawsVerticalLineToAxis:true];
    [activeDelayTapControl setConstrainVerticallyToParentView:true];
    [activeDelayTapControl setConstrainHorizontallyToParentView:false];
    [activeDelayTapControl setVerticalRange:-0.01 max:1.0];
    [activeDelayTapControl setHorizontalRange:[tdScopeView minPlotMin].x max:[tdScopeView maxPlotMax].x];
    [activeDelayTapControl setTag:kDelayParamsTag + [audioController getNumDelayTaps]];
    
    [audioController addDelayTapWithDelayTime:activeDelayTapControl.values.x gain:fmax(activeDelayTapControl.values.y, 0.0)];
    [tdControlArray setNeedsDisplay];
    
    [delayScopeView setHidden:false];
    [delayScopeView setVisibleXLim:tdScopeView.visiblePlotMin.x max:tdScopeView.visiblePlotMax.x];
    [delayScopeView setVisibleYLim:tdScopeView.visiblePlotMin.y max:tdScopeView.visiblePlotMax.y];
    
    [self plotInputCopyForDelayTap];
}

#pragma mark - METScopeViewDelegate Methods
- (void)pinchBegan:(METScopeView*)sender {
    
    /* Throttle time and spectrum plot updates based on the visible bounds of the time-domain plot (longer time-scales are more computationally intensive to plot, so throttle the plots more for longer scales) */
    float rate = 500 * (tdScopeView.visiblePlotMax.x - tdScopeView.visiblePlotMin.x) * [tdScopeClock timeInterval] + 30 * [tdScopeClock timeInterval];
    [self setTDUpdateRate:rate];
    [self setFDUpdateRate:rate/2];
    
    /* Perform any updates necessary when plot bounds change */
    if (sender.displayMode == kMETScopeViewTimeDomainMode)
        [self tdScopeBoundsChanged];
    else 
     [self fdScopeBoundsChanged];
}

- (void)pinchUpdate:(METScopeView*)sender {
    
    /* Perform any updates necessary when plot bounds change */
    if (sender.displayMode == kMETScopeViewTimeDomainMode)
        [self tdScopeBoundsChanged];
    else
        [self fdScopeBoundsChanged];
}

- (void)pinchEnded:(METScopeView*)sender {

    /* Perform any updates necessary when plot bounds change */
    if (sender.displayMode == kMETScopeViewTimeDomainMode)
        [self tdScopeBoundsChanged];
    else
        [self fdScopeBoundsChanged];
    
    /* Return time and spectrum plot updates to default rate */
    [self setTDUpdateRate:kEffectsScopeUpdateRate];
    [self setFDUpdateRate:kEffectsScopeUpdateRate];
}

- (void)panBegan:(METScopeView*)sender {
    
    /* Throttle time and spectrum plot updates based on the visible bounds of the time-domain plot (longer time-scales are more computationally intensive to plot, so throttle the plots more for longer scales) */
    float rate = 500 * (tdScopeView.visiblePlotMax.x - tdScopeView.visiblePlotMin.x) * [tdScopeClock timeInterval] + 30 * [tdScopeClock timeInterval];
    [self setTDUpdateRate:rate];
    [self setFDUpdateRate:rate/2];
    
    /* Perform any updates necessary when plot bounds change */
    if (sender.displayMode == kMETScopeViewTimeDomainMode)
        [self tdScopeBoundsChanged];
    else
        [self fdScopeBoundsChanged];
}

- (void)panUpdate:(METScopeView*)sender {
    
    /* Perform any updates necessary when plot bounds change */
    if (sender.displayMode == kMETScopeViewTimeDomainMode)
        [self tdScopeBoundsChanged];
    else
        [self fdScopeBoundsChanged];
}

- (void)panEnded:(METScopeView*)sender {
    
    /* Perform any updates necessary when plot bounds change */
    if (sender.displayMode == kMETScopeViewTimeDomainMode)
        [self tdScopeBoundsChanged];
    else
        [self fdScopeBoundsChanged];
    
    /* Return time and spectrum plot updates to default rate */
    [self setTDUpdateRate:kEffectsScopeUpdateRate];
    [self setFDUpdateRate:kEffectsScopeUpdateRate];
}

- (void)tdScopeBoundsChanged {
    
    /* Reallocate the time domain plot buffers for the new visible plot bounds */
    if (tdScopeXData) free(tdScopeXData);
    if (tdScopeYDataDry) free(tdScopeYDataDry);
    if (tdScopeYDataWet) free(tdScopeYDataWet);
    
    /* If we're getting input from the Synth, we need to extend the time duration we're retrieving from the recording buffer to compensate for the phaze zero offset. Lower fundamental frequencies have larger offsets due to longer wavelengths. */
    maxScale = 1.0;
    if ([audioController synthEnabled] && [audioController inputEnabled]) {
        
        float periodsInView = (tdScopeView.visiblePlotMax.x-tdScopeView.visiblePlotMin.x) * [audioController synthFundamental];
        maxScale = 1.1;
        
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
    }
    
    startIdx = fmax(tdScopeView.visiblePlotMin.x, 0.0f) * audioController.sampleRate;
    endIdx = (tdScopeView.visiblePlotMax.x  * maxScale) * audioController.sampleRate;
    visibleBufferLength = endIdx - startIdx;
    
    tdScopeYDataDry = (Float32 *)malloc(visibleBufferLength * sizeof(Float32));
    tdScopeYDataWet = (Float32 *)malloc(visibleBufferLength * sizeof(Float32));
    tdScopeXData = (Float32 *)malloc(visibleBufferLength * sizeof(Float32));
    [self linspace:fmax(tdScopeView.visiblePlotMin.x, 0.0f)
               max:tdScopeView.visiblePlotMax.x * maxScale
       numElements:visibleBufferLength
             array:tdScopeXData];
    
    /* Update the visible limits on the audioController for processing visible audio offline */
    [audioController setVisibleRangeInSeconds:fmaxf(0.0f, tdScopeView.visiblePlotMin.x) max:tdScopeView.visiblePlotMax.x];
    
    /* Update the control array */
    [tdControlArray setNeedsDisplay];
}

- (void)fdScopeBoundsChanged {
    
//    /* Set the LPF and HPF to roll off at the updated plot bounds */
//    [audioController rescaleFilters:fmax(fdScopeView.visiblePlotMin.x, 40.0) max:fdScopeView.visiblePlotMax.x];
    
    /* Update the control array */
    [fdControlArray setNeedsDisplay];
}

#pragma mark - METControlArrayDelegate Methods
- (void)parameterDotTouchDown:(METControl *)sender {
    
    if ([sender tag] >= kDelayParamsTag) {  // Only update delay parameters on touch up
        editingDelayTap = true;
        activeDelayTapControl = sender;
        
        if (![audioController inputEnabled]) {
            [tdScopeView setLineAlpha:0.3 atIndex:tdDryIdx];
            [tdScopeView setLineAlpha:0.3 atIndex:tdWetIdx];
        }
        return;
    }
    
    [self parameterUpdate:sender];  // Update the synth/effects parameters
}
- (void)parameterDotValuesChanged:(METControl *)sender {
    
//    if ([sender tag] >= kDelayParamsTag)    // Only update delay parameters on touch up
//        return;
    
    [self parameterUpdate:sender];  // Update the synth/effects parameters
}
- (void)parameterDotTouchUp:(METControl *)sender {
    
    [self parameterUpdate:sender];  // Update the synth/effects parameters

    if ([sender tag] >= kDelayParamsTag) {  // Check for delay tap gains < 0.0 to delete
        
        if (![audioController inputEnabled]) {
            [tdScopeView setLineAlpha:1.0 atIndex:tdDryIdx];
            [tdScopeView setLineAlpha:1.0 atIndex:tdWetIdx];
        }
        
        editingDelayTap = false;
        if (sender.values.y < 0.0) {
            activeDelayTapControl = nil;
            [tdControlArray removeControlWithTag:[sender tag]];
            [audioController removeDelayTap:(int)[sender tag] - kDelayParamsTag];
        }
    }
}
- (void)parameterUpdate:(METControl *)sender {
    
    int idx;
    CGPoint vals = sender.values;
    CGFloat q;
    
    switch ([sender tag]) {
            
        case kModulationParamsTag:
            [audioController setModFrequency:vals.x];
            [audioController setModAmp:powf(10.0f, vals.y / 20.0f)];
            break;
            
        case kDistCutoffHighTag:
            [audioController setClippingAmplitudeHigh:vals.y];
            break;
            
        case kDistCutoffLowTag:
            [audioController setClippingAmplitudeLow:vals.y];
            break;
            
        case kLPFParamsTag:
            
            /* Set the filter cutoff */
            [audioController setLPFCutoff:vals.x];
            
            /* Piecewise linear approximation of mapping from control value in dB to filter Q */
            q = vals.y;
            if (vals.y < 0.0) q = 0.4 + 0.075 * (vals.y + 8);
            else if (vals.y <= 4.0) q = 1.0 + vals.y / 8.0;
            else q = 1.5 + (vals.y - 4.0) / 4.0;
            audioController->lpf.Q = q;
            [self computeLPFMagnitudeResponse];
            break;
            
        case kHPFParamsTag:
            
            /* Set the filter cutoff */
            [audioController setHPFCutoff:vals.x];
            
            /* Piecewise linear approximation of mapping from control value in dB to filter Q */
            q = vals.y;
            if (vals.y < 0.0) q = 0.4 + 0.075 * (vals.y + 8);
            else if (vals.y <= 4.0) q = 1.0 + vals.y / 8.0;
            else q = 1.5 + (vals.y - 4.0) / 4.0;
            audioController->hpf.Q = q;
            
            [self computeHPFMagnitudeResponse];
            break;
            
        case kDelayParamsTag:
        case kDelayParamsTag+1:
        case kDelayParamsTag+2:
        case kDelayParamsTag+3:
        case kDelayParamsTag+4:
            
            idx = (int)[sender tag] - kDelayParamsTag;
            [audioController setDelayTap:idx time:vals.x amplitude:fmax(vals.y, 0.0)];
//            if (![audioController inputEnabled])
//                [audioController processRecordingInputBufferOffline];
            
            break;
            
        default:
            break;
    }
}
@end









