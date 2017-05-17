//
//  AppDelegate.m
//  AudioLab
//
//  Created by Jeff Gregorio on 9/5/14.
//  Copyright (c) 2014 ___FULLUSERNAME___. All rights reserved.
//

#import "AppDelegate.h"

float const kPreGainMin = 0.0f;
float const kPreGainMax = 4.0f;
float const kPostGainMin = 0.0f;
float const kPostGainMax = 4.0f;

@implementation AppDelegate

@synthesize audioController;
@synthesize midiController;
@synthesize navigationView;
@synthesize helpDisplayed;
@synthesize preGainSlider;
@synthesize levelsDrawer;
@synthesize midiButton;
@synthesize midiParamPicker;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    NSLog(@"%@", self);
    
    CGRect frame;
    UIColor *audioWorksBlue = [UIColor colorWithRed:kAudioWorksBlue_R
                                              green:kAudioWorksBlue_G
                                               blue:kAudioWorksBlue_B
                                              alpha:1.0f];
    /* ----------------------- */
    /* === ViewControllers === */
    /* ----------------------- */
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    avc = (AnalysisViewController *)[mainStoryboard instantiateViewControllerWithIdentifier:@"Analysis"];
    evc = (EffectsViewController *)[mainStoryboard instantiateViewControllerWithIdentifier:@"Effects"];
    svc = (SynthesisViewController *)[mainStoryboard instantiateViewControllerWithIdentifier:@"Synthesis"];
    cvc = (CreditsViewController *)[mainStoryboard instantiateViewControllerWithIdentifier:@"Credits"];
    
    self.window.rootViewController = avc;
    currentMode = previousMode = kAudioWorksModeAnalysis;
    
    
    UIView *view = self.window.rootViewController.view;
    
    /* ---------------------- */
    /* === Navigation Bar === */
    /* ---------------------- */
    navigationView = [[UIView alloc] initWithFrame:CGRectMake(-2.0f, -2.0f, view.frame.size.width + 4.0f, 67.0f)];
    [navigationView setBackgroundColor:[UIColor colorWithRed:0.99f green:0.99f  blue:0.99f  alpha:9.0f]];
    [[navigationView layer] setBorderWidth:2.0f];
    [[navigationView layer] setBorderColor:audioWorksBlue.CGColor];
    
    /* Mode Buttons */
    CGPoint buttonOrigin = CGPointMake(20.0f, 22.5f);
    CGFloat buttonSpacing = 20.0f;
    
    analysisButton = [[METButton alloc] initWithTitle:@"Analysis" origin:buttonOrigin color:audioWorksBlue];
    [analysisButton addTarget:self action:@selector(modeButtonDown:) forControlEvents:UIControlEventTouchDown];
    [analysisButton addTarget:self action:@selector(modeButtonUp:) forControlEvents:UIControlEventTouchUpInside];
    [analysisButton setTag:0];
    [analysisButton setActive:true];
    [navigationView addSubview:analysisButton];
    
    buttonOrigin.x += analysisButton.frame.size.width + buttonSpacing;
    synthesisButton = [[METButton alloc] initWithTitle:@"Synthesis" origin:buttonOrigin color:audioWorksBlue];
    [synthesisButton addTarget:self action:@selector(modeButtonDown:) forControlEvents:UIControlEventTouchDown];
    [synthesisButton addTarget:self action:@selector(modeButtonUp:) forControlEvents:UIControlEventTouchUpInside];
    [synthesisButton setTag:2];
    [navigationView addSubview:synthesisButton];
    
    buttonOrigin.x += synthesisButton.frame.size.width + buttonSpacing;
    effectsButton = [[METButton alloc] initWithTitle:@"Effects" origin:buttonOrigin color:audioWorksBlue];
    [effectsButton addTarget:self action:@selector(modeButtonDown:) forControlEvents:UIControlEventTouchDown];
    [effectsButton addTarget:self action:@selector(modeButtonUp:) forControlEvents:UIControlEventTouchUpInside];
    [effectsButton setTag:1];
    [navigationView addSubview:effectsButton];
    
    /* Credits button */
    buttonOrigin.x = navigationView.frame.size.width - 60.0f;
    buttonOrigin.y -= 3.0f;
    creditsButton = [[METButton alloc] initWithTitle:@"" origin:buttonOrigin color:audioWorksBlue];
    frame = creditsButton.frame;
    frame.size.width = frame.size.height;
    frame.size.height += 10.0f;
    [creditsButton setFrame:frame];
    creditsButtonImageIdle = [UIImage imageNamed:@"CreditsButton.png"];
    creditsButtonImageActive = [UIImage imageNamed:@"CreditsButton_down.png"];
    [creditsButton setImage:creditsButtonImageIdle forState:UIControlStateNormal];
    
    [creditsButton addTarget:self action:@selector(modeButtonDown:) forControlEvents:UIControlEventTouchDown];
    [creditsButton addTarget:self action:@selector(modeButtonUp:) forControlEvents:UIControlEventTouchUpInside];
    [creditsButton setTag:3];
    [navigationView addSubview:creditsButton];
    
    /* Help Button */
    buttonOrigin.x = navigationView.frame.size.width - 120.0f;
    helpButton = [[METButton alloc] initWithTitle:@"" origin:buttonOrigin color:audioWorksBlue];
    frame = helpButton.frame;
    frame.size.width = frame.size.height;
    frame.size.height += 10.0f;
    [helpButton setFrame:frame];
    helpButtonImageIdle = [UIImage imageNamed:@"HelpButton_small.png"];
    helpButtonImageActive = [UIImage imageNamed:@"HelpButton_down_small.png"];

    [helpButton setImage:helpButtonImageIdle forState:UIControlStateNormal];
    [helpButton addTarget:self action:@selector(toggleHelp:) forControlEvents:UIControlEventTouchUpInside];
    [navigationView addSubview:helpButton];
    helpDisplayed = false;
    
    routingSynthToEffects = false;
    routingArrow = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Arrow.png"]];
    frame = routingArrow.frame;
    frame.origin.x = synthesisButton.frame.origin.x + synthesisButton.frame.size.width - 2.0f;
    frame.origin.y = synthesisButton.frame.origin.y + synthesisButton.frame.size.height / 2.0f - frame.size.height / 2.0f;
    frame.size.width = effectsButton.frame.origin.x - frame.origin.x + 4.0f;
    [routingArrow setFrame:frame];
    
    /* Play/Pause/Record button */
    buttonOrigin.x = navigationView.frame.size.width - 180.0f;
    recordStateButton = [[METButton alloc] initWithTitle:@"?" origin:buttonOrigin color:audioWorksBlue];
    frame = recordStateButton.frame;
    frame.size.width = frame.size.height;
    frame.size.height += 10.0f;
    [recordStateButton setFrame:frame];
    recordStateButtonImagePlay = [UIImage imageNamed:@"recordStateButton_Play.png"];
    recordStateButtonImagePause = [UIImage imageNamed:@"recordStateButton_Pause.png"];
    recordStateButtonImageRecord = [UIImage imageNamed:@"recordStateButton_Record.png"];
    [recordStateButton setImage:recordStateButtonImagePause forState:UIControlStateNormal];
    audioState = kAudioWorksAudioStateRecord;
    [recordStateButton addTarget:self action:@selector(recordStateButtonPress:) forControlEvents:UIControlEventTouchUpInside];
    [navigationView addSubview:recordStateButton];
    
    /* Analysis/Effects mode playback button */
    buttonOrigin = recordStateButton.frame.origin;
    buttonOrigin.x -= recordStateButton.frame.size.width + buttonSpacing;
    playbackButton = [[METButton alloc] initWithTitle:@"" origin:buttonOrigin color:audioWorksBlue];
    frame = playbackButton.frame;
    frame.size.width = frame.size.height;
    frame.size.height += 10.0f;
    [playbackButton setFrame:frame];
    playbackButtonImage = [UIImage imageNamed:@"recordStateButton_Play.png"];
    [playbackButton setImage:playbackButtonImage forState:UIControlStateNormal];
    [playbackButton addTarget:self action:@selector(playbackButtonPress:) forControlEvents:UIControlEventTouchUpInside];
    
    /* Add the navigation view */
    [self.window.rootViewController.view addSubview:navigationView];
    modeButtonsHeld = 0;
    
    /* ---------------------- */
    /* === Level Controls === */
    /* ---------------------- */
    
    frame = self.window.rootViewController.view.frame;
    frame.size.height = 80.0f;
    frame.origin.y = self.window.rootViewController.view.frame.size.height / 2.0f - frame.size.height / 2.0f + 22.0f;
    levelsDrawer = [[METDrawer alloc] initWithFrame:frame];
    [self.window.rootViewController.view addSubview:levelsDrawer];
    [levelsDrawer close:false];
    [levelsDrawer setSwipeCloseEnabled:false];
    
    UILabel *preGainLabel = [[UILabel alloc] initWithFrame:CGRectMake(30.0f, 28.0f, 50.0f, 20.0f)];
    [preGainLabel setText:@"Level"];
    [levelsDrawer addSubview:preGainLabel];
    
    preGainSlider = [[METSlider alloc] initWithFrame:CGRectMake(preGainLabel.frame.origin.x + preGainLabel.frame.size.width + 10.0f, 10.0f, 630.0f, 60.0f)];
    [preGainSlider setTabRadiusScalar:0.3f];
    [preGainSlider setTrackFillColor:[[UIColor blueColor] colorWithAlphaComponent:0.8f]];
    [preGainSlider setRange:kPreGainMin max:kPreGainMax];
    [preGainSlider setValue:1.0f];
    [preGainSlider addTarget:self action:@selector(preGainChanged:) forControlEvents:UIControlEventValueChanged];
    [levelsDrawer addSubview:preGainSlider];
    previousPreGain = preGainSlider.value;

    /* ------------- */
    /* === Audio === */
    /* ------------- */
    audioController = [[AudioController alloc] init];
    [audioController setInputGain:preGainSlider.value];
    [audioController startAudioSession];
    [audioController setPlaybackDelegate:avc];
    
    /* -------------------------- */
    /* === On-screen Keyboard === */
    /* -------------------------- */
    buttonOrigin.x = navigationView.frame.size.width - 250.0f;
    keyboardButton = [[METButton alloc] initWithTitle:@"" origin:buttonOrigin color:audioWorksBlue];
    frame = keyboardButton.frame;
    frame.size.width = frame.size.height = recordStateButton.frame.size.height;
    [keyboardButton setFrame:frame];
    
    keyboardButtonImageIdle = [UIImage imageNamed:@"KeyboardButton.png"];
    keyboardButtonImageActive = [UIImage imageNamed:@"KeyboardButton_down.png"];
    [keyboardButton setImage:keyboardButtonImageIdle forState:UIControlStateNormal];
    [keyboardButton addTarget:self action:@selector(toggleKeyboard:) forControlEvents:UIControlEventTouchUpInside];
    
    CGFloat kbHeight = 280.0;
    CGRect kbFrame = CGRectMake(0.0, self.window.rootViewController.view.frame.size.height - kbHeight,
                                self.window.rootViewController.view.frame.size.width, kbHeight);
    keyboard = [[METKeyboard alloc] initWithFrame:kbFrame];
    [self.window.rootViewController.view addSubview:keyboard];
    [keyboard setHidden:true];
    [keyboard setDelegate:self];
    [keyboard setMinYPosition:navigationView.frame.size.height - 2];
    
    
    /* ------------ */
    /* === MIDI === */
    /* ------------ */
    buttonOrigin.x = navigationView.frame.size.width - 310.0f;
    midiButton = [[METButton alloc] initWithTitle:@"" origin:buttonOrigin color:audioWorksBlue];
    frame = midiButton.frame;
    frame.size.width = frame.size.height = recordStateButton.frame.size.height;
    frame.size.width -= 10.0;
    [midiButton setFrame:frame];
    
    [midiButton setImage:[UIImage imageNamed:@"MidiButton.png"] forState:UIControlStateNormal];
    [midiButton addTarget:self action:@selector(midiButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [navigationView addSubview:midiButton];
    [midiButton setHidden:true];
    
    CGRect pickerFrame = CGRectMake(0.0, navigationView.frame.size.height - 3.0, navigationView.frame.size.width, 200.0);
    midiParamPicker = [[UIPickerView alloc] initWithFrame:pickerFrame];
    [midiParamPicker setDelegate:self];
    [midiParamPicker setShowsSelectionIndicator:YES];
    [self.window.rootViewController.view addSubview:midiParamPicker];
    [[midiParamPicker layer] setBorderColor:[audioWorksBlue CGColor]];
    [[midiParamPicker layer] setBorderWidth:1.0];
    [midiParamPicker setBackgroundColor:[UIColor whiteColor]];
    [midiParamPicker setHidden:true];
    
    activeParamList = [[NSMutableArray alloc] init];
    ccModFreq = 0;
    ccModAmp = 0;
    ccDistHighThresh = 0;
    ccDistLowThresh = 0;
    ccLPFCutoff = 0;
    ccLPFResonance = 0;
    ccHPFCutoff = 0;
    ccHPFResonance = 0;
    for (int i = 0; i < kMaxNumDelayTaps; i++) {
        ccDelayTime[i] = 0;
        ccDelayAmp[i] = 0;
    }
    
    midiController = [[MIDIController alloc] initWithHandler:self];
    [midiController setHandler:self];
    
    /* MIDI mapping help */
    CGPoint origin;
    origin.x = 25.0f;
    origin.y = navigationView.frame.origin.y + navigationView.frame.size.height + 25.0;
    midiHelp = [[HelpBubble alloc] initWithText:@"Link a MIDI control or channel aftertouch by selecting an active effect's parameter and moving the control"
                                    origin:origin
                                     width:225.0
                                 alignment:NSTextAlignmentLeft];
    [midiHelp setPointerLocation:kHelpBubblePointerLocationNone];
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)preGainChanged:(id)sender {
    
    [audioController setInputGain:preGainSlider.value];
    
    if (currentMode == kAudioWorksModeSynthesis)
        [svc inputGainChanged];
}

- (void)modeButtonDown:(id)sender {
    modeButtonsHeld += 1;
}

- (void)modeButtonUp:(id)sender {
    
    modeButtonsHeld -= 1;
    
    /* Check audio input enabled/disabled status so we can match it in the next ViewController */
    DetailViewController *dvc = (DetailViewController *)self.window.rootViewController;
    bool inputWasPaused = dvc.inputPaused;
    CGFloat tmin = [dvc getVisibleTMin];
    CGFloat tmax = [dvc getVisibleTMax];
    
    /* Check if synth button is down and this press is effects or vice versa to activate synth -> FX routing */
    if (([synthesisButton isHeld] && [sender tag] == kAudioWorksModeEffects) || ([effectsButton isHeld] && [sender tag] == kAudioWorksModeSynthesis)) {
        
        [analysisButton setActive:false];
        [effectsButton setActive:true];
        [synthesisButton setActive:true];
        [creditsButton setImage:creditsButtonImageIdle forState:UIControlStateNormal];
    }
    
    else if (!routingSynthToEffects && [synthesisButton isActive] && [effectsButton isActive] && ([sender tag] == kAudioWorksModeEffects || [sender tag] == kAudioWorksModeSynthesis)) {
        
        self.window.rootViewController = evc;
        
        /* Activate both synth and effects modes in AudioController */
        routingSynthToEffects = true;
        [audioController setSynthEnabled:true];
        [audioController setEffectsEnabled:true];
        
        previousMode = currentMode;
        currentMode = kAudioWorksModeEffects;
        audioState = kAudioWorksAudioStateRecord;
    }
    else if (modeButtonsHeld == 0) {
        
        switch ([sender tag]) {
                
            case kAudioWorksModeAnalysis:
                
                [analysisButton setActive:true];
                [effectsButton setActive:false];
                [synthesisButton setActive:false];
                [creditsButton setImage:creditsButtonImageIdle forState:UIControlStateNormal];
                
                self.window.rootViewController = avc;
                [audioController setSynthEnabled:false];
                [audioController setEffectsEnabled:false];
                
                previousMode = currentMode;
                currentMode = kAudioWorksModeAnalysis;
                audioState = kAudioWorksAudioStateRecord;
                [audioController setPlaybackDelegate:avc];
                
                break;
                
            case kAudioWorksModeEffects:
                
                [analysisButton setActive:false];
                [effectsButton setActive:true];
                [synthesisButton setActive:false];
                [creditsButton setImage:creditsButtonImageIdle forState:UIControlStateNormal];
                
                self.window.rootViewController = evc;
                [audioController setSynthEnabled:false];
                [audioController setEffectsEnabled:true];
                
                previousMode = currentMode;
                currentMode = kAudioWorksModeEffects;
                audioState = kAudioWorksAudioStateRecord;
                [audioController setPlaybackDelegate:evc];
                
                break;
                
            case kAudioWorksModeSynthesis:
                
                [analysisButton setActive:false];
                [synthesisButton setActive:true];
                [effectsButton setActive:false];
                [creditsButton setImage:creditsButtonImageIdle forState:UIControlStateNormal];
                
                self.window.rootViewController = svc;
                [audioController setSynthEnabled:true];
                [audioController setEffectsEnabled:false];
                
                previousMode = currentMode;
                currentMode = kAudioWorksModeSynthesis;
                audioState = kAudioWorksAudioStatePlay;
                
                break;
                
            case kAudioWorksModeCredits:
                
                /* Return to previous mode if credits button is pressed while in credits mode */
                if (currentMode == kAudioWorksModeCredits) {
                
                    if (previousMode == kAudioWorksModeAnalysis) {
                        [analysisButton sendActionsForControlEvents:UIControlEventTouchDown];
                        [analysisButton sendActionsForControlEvents:UIControlEventTouchUpInside];
                    }
                    else if (previousMode == kAudioWorksModeSynthesis) {
                        [synthesisButton sendActionsForControlEvents:UIControlEventTouchDown];
                        [synthesisButton sendActionsForControlEvents:UIControlEventTouchUpInside];
                    }
                    else if (previousMode == kAudioWorksModeEffects) {
                        [effectsButton sendActionsForControlEvents:UIControlEventTouchDown];
                        [effectsButton sendActionsForControlEvents:UIControlEventTouchUpInside];
                    }
                }
                else {
                    [analysisButton setActive:false];
                    [effectsButton setActive:false];
                    [synthesisButton setActive:false];
                    [creditsButton setImage:creditsButtonImageActive forState:UIControlStateNormal];
                    
                    self.window.rootViewController = cvc;
                    [audioController setSynthEnabled:false];
                    [audioController setEffectsEnabled:false];
                    
                    previousMode = currentMode;
                    currentMode = kAudioWorksModeCredits;
                }
                
                break;
                
            default:
                break;
        }
        
        routingSynthToEffects = false;
    }
    
    [self.window.rootViewController.view addSubview:navigationView];
    [self.window.rootViewController.view addSubview:levelsDrawer];
    [self.window.rootViewController.view addSubview:midiParamPicker];
    [self.window.rootViewController.view addSubview:keyboard];
    [recordStateButton setImage:recordStateButtonImagePause forState:UIControlStateNormal];
    
    /* Modify the input gain control for synthesis mode */
    if (currentMode == kAudioWorksModeSynthesis || routingSynthToEffects) {
        previousPreGain = preGainSlider.value;
        [preGainSlider setRange:kPreGainMin max:1.0f];
        [preGainSlider setValue:0.75f];
        [navigationView addSubview:keyboardButton];
    }
    else {
        [keyboardButton removeFromSuperview];
        if (![keyboard isHidden])
            [self toggleKeyboard:keyboardButton];
        [preGainSlider setValue:previousPreGain];
        [preGainSlider setRange:kPreGainMin max:kPreGainMax];
    }
    
    [audioController setInputGain:preGainSlider.value];
    
    /* Hide the gain controls in Credits mode */
    if ([sender tag] == kAudioWorksModeCredits && previousMode != kAudioWorksModeCredits)
        [levelsDrawer setHidden:true];
    else
        [levelsDrawer setHidden:false];
    
    if (routingSynthToEffects)
        [navigationView addSubview:routingArrow];
    else
        [routingArrow removeFromSuperview];
    
    if (helpDisplayed && ![midiParamPicker isHidden]) {
        [self.window.rootViewController.view addSubview:midiHelp];
    }
    
//    if (inputWasPaused) {
//        dispatch_async(dispatch_get_main_queue(),^ {
//            DetailViewController *dvc = (DetailViewController *)self.window.rootViewController;
//            [dvc toggleInput];
//        });
//    }
}

- (void)toggleHelp:(id)sender {
    
    DetailViewController *dvc = (DetailViewController *)self.window.rootViewController;
    [dvc toggleHelp];
    
    if (helpDisplayed) {
        [helpButton setImage:helpButtonImageIdle forState:UIControlStateNormal];
        helpDisplayed = false;
        [midiHelp removeFromSuperview];
    }
    else {
        [helpButton setImage:helpButtonImageActive forState:UIControlStateNormal];
        helpDisplayed = true;
        if (![midiParamPicker isHidden])
            [[dvc view] addSubview:midiHelp];
    }
}

#pragma mark - Recording/Playback
- (void)recordStateButtonPress:(id)sender {
    
    DetailViewController *dvc;
    switch (currentMode) {
        case kAudioWorksModeAnalysis:
            dvc = avc;
            break;
        case kAudioWorksModeEffects:
            dvc = evc;
            break;
        case kAudioWorksModeSynthesis:
            dvc = svc;
            break;
        case kAudioWorksModeCredits:
            dvc = cvc;
        default:
            break;
    }
    
    /* Synthesis mode */
    if (currentMode == kAudioWorksModeSynthesis) {
        if (audioState == kAudioWorksAudioStatePlay) {  // Pause
            audioState = kAudioWorksAudioStatePause;
            [recordStateButton setImage:recordStateButtonImagePlay forState:UIControlStateNormal];
        }
        else {      // Resume
            audioState = kAudioWorksAudioStatePlay;
            [recordStateButton setImage:recordStateButtonImagePause forState:UIControlStateNormal];
        }
    }
    /* Analysis/Effects mode */
    else if (currentMode == kAudioWorksModeAnalysis || currentMode == kAudioWorksModeEffects) {
        if (audioState == kAudioWorksAudioStateRecord) {    // Pause
            audioState = kAudioWorksAudioStatePause;
            [recordStateButton setImage:recordStateButtonImageRecord forState:UIControlStateNormal];
            if (!audioController.synthEnabled)
                [navigationView addSubview:playbackButton];     // Add playback button
        }
        else {      // Resume
            audioState = kAudioWorksAudioStateRecord;
            [recordStateButton setImage:recordStateButtonImagePause forState:UIControlStateNormal];
            [playbackButton removeFromSuperview];       // Remove playback button
            
            // If we're exiting recorded playback, re-disable input so the ViewController's toggle method can re-enable it properly
            if (audioController.recordedPlayback) {
                [audioController setInputEnabled:false];
                audioController.recordedPlayback = false;
            }
        }
    }
    
    [dvc toggleInput];
}

- (void)playbackButtonPress:(id)sender {
    
    DetailViewController *dvc;
    
    switch (currentMode) {
        case kAudioWorksModeAnalysis:
            dvc = avc;
            break;
        case kAudioWorksModeEffects:
            dvc = evc;
            break;
        case kAudioWorksModeSynthesis:
        case kAudioWorksModeCredits:
        default:
            break;
    }
    
    if (dvc) {
        
        // Call standardized method on Analysis and Effects ViewControllers that adds playhead
        // - Add AudioControllerDelegate methods to Analysis and Effects ViewControllers that receive an updated playhead position and move the playhead
        
        [audioController setInputEnabled:true];     // Re-enable input (i.e. resume the callback function)
        [audioController startBufferPlayback:[dvc getVisibleTMin]];
        [dvc tdScopeBoundsChanged];
    }
}

#pragma mark - Keyboard
- (void)toggleKeyboard:(METButton *)sender {
    
    if (![keyboard isHidden]) {
        [keyboardButton setImage:keyboardButtonImageIdle forState:UIControlStateNormal];
        [keyboard setHidden:true];
        if ([midiButton isHidden] && [svc midiNoteControlEnabled])
            [svc setMidiNoteControlEnabled:false];
    }
    else {
        [keyboardButton setImage:keyboardButtonImageActive forState:UIControlStateNormal];
        [keyboard setHidden:false];
        [svc setMidiNoteControlEnabled:true];
    }
}

#pragma mark - MIDI
- (void)midiButtonPressed:(METButton *)sender {
    
    if ([midiParamPicker isHidden]) {
        [self queryAvailableMIDIParams];
        [midiParamPicker setHidden:false];
        [midiParamPicker reloadAllComponents];
        if (helpDisplayed) {
            DetailViewController *dvc = (DetailViewController *)self.window.rootViewController;
            [[dvc view] addSubview:midiHelp];
        }
    }
    else {
        [midiParamPicker setHidden:true];
        if (helpDisplayed)
            [midiHelp removeFromSuperview];
    }
}

- (void)queryAvailableMIDIParams {
    
    [activeParamList removeAllObjects];
    
    bool activeEffects = false;
    
    if ([audioController modulationEnabled]) {
        [activeParamList addObject:@"Modulation Freq"];
        [activeParamList addObject:@"Modulation Mix"];
        activeEffects = true;
    }
    if ([audioController distortionEnabled]) {
        [activeParamList addObject:@"Distortion High Thresh"];
        [activeParamList addObject:@"Distortion Low Thresh"];
        activeEffects = true;
    }
    if ([audioController lpfEnabled]) {
        [activeParamList addObject:@"LPF Cutoff Freq"];
        [activeParamList addObject:@"LPF Resonance"];
        activeEffects = true;
    }
    if ([audioController hpfEnabled]) {
        [activeParamList addObject:@"HPF Cutoff Freq"];
        [activeParamList addObject:@"HPF Resonance"];
        activeEffects = true;
    }
    if ([audioController delayEnabled]) {
        int nTaps = [audioController getNumDelayTaps];
        for (int i = 1; i <= nTaps; i++) {
            [activeParamList addObject:[NSString stringWithFormat:@"Delay Time %d", i]];
            [activeParamList addObject:[NSString stringWithFormat:@"Delay Amp %d", i]];
            activeEffects = true;
        }
    }
    
    if (!activeEffects)
        [activeParamList addObject:@"No Available Parameters"];
    
    [midiParamPicker reloadAllComponents];
}

#pragma mark - MIDIHandler
- (void)handleDeviceChange:(int)numDevices {
    
    if (numDevices > 1) {
        [midiButton setHidden:false];
        [svc setMidiNoteControlEnabled:true];
    }
    else {
        [midiButton setHidden:true];
        [midiParamPicker setHidden:true];
        
        if ([keyboard isHidden])
            [svc setMidiNoteControlEnabled:false];
    }
}

- (void)handleNoteOff:(int)noteNum {
    [keyboard deactivateNote:noteNum];
    [svc handleMIDINoteOff:noteNum];
}

- (void)handleNoteOn:(int)noteNum velocity:(int)vel {
    [keyboard activateNote:noteNum];
    [svc handleMIDINoteOn:noteNum velocity:vel];
}

- (void)handleCC:(int)ctrlNum value:(int)val {
    
    if (![midiParamPicker isHidden]) {
        NSInteger row = [midiParamPicker selectedRowInComponent:0];
        NSString *param = activeParamList[row];
        
        dispatch_async(dispatch_get_main_queue(),^ {
            
            UIView *selectedView;
            
            if ([param isEqualToString:@"Modulation Freq"]) {
                ccModFreq = ctrlNum;
                
                selectedView = [midiParamPicker viewForRow:row forComponent:0];
                [selectedView setBackgroundColor:[UIColor whiteColor]];
                [selectedView setBackgroundColor:[UIColor colorWithRed:kAudioWorksBlue_R
                                                                green:kAudioWorksBlue_G
                                                                  blue:kAudioWorksBlue_B
                                                                 alpha:1.0]];
            }
            if ([param isEqualToString:@"Modulation Mix"]) {
                ccModAmp = ctrlNum;
            }
            if ([param isEqualToString:@"Distortion High Thresh"]) {
                ccDistHighThresh = ctrlNum;
            }
            if ([param isEqualToString:@"Distortion Low Thresh"]) {
                ccDistLowThresh = ctrlNum;
            }
            if ([param isEqualToString:@"LPF Cutoff Freq"]) {
                ccLPFCutoff = ctrlNum;
            }
            if ([param isEqualToString:@"LPF Resonance"]) {
                ccLPFResonance = ctrlNum;
            }
            if ([param isEqualToString:@"HPF Cutoff Freq"]) {
                ccHPFCutoff = ctrlNum;
            }
            if ([param isEqualToString:@"HPF Resonance"]) {
                ccHPFResonance = ctrlNum;
            }
            if ([param hasPrefix:@"Delay Time"]) {
                NSString *sNum = [param substringFromIndex:[param length]-1];
                int num = [sNum intValue]-1;
                ccDelayTime[num] = ctrlNum;
            }
            if ([param hasPrefix:@"Delay Amp"]) {
                NSString *sNum = [param substringFromIndex:[param length]-1];
                int num = [sNum intValue]-1;
                ccDelayAmp[num] = ctrlNum;
            }
        });
    }
    
    float normVal = (float)(val / 128.0);
    CGPoint tdPlotMax = [[evc tdScopeView] visiblePlotMax];
    CGPoint tdPlotMin = [[evc tdScopeView] visiblePlotMin];
    CGPoint tdPlotRange = CGPointMake(tdPlotMax.x - tdPlotMin.x, tdPlotMax.y - tdPlotMin.y);
    CGPoint fdPlotMax = [[evc fdScopeView] visiblePlotMax];
    CGPoint fdPlotMin = [[evc fdScopeView] visiblePlotMin];
    CGPoint fdPlotRange = CGPointMake(fdPlotMax.x - fdPlotMin.x, fdPlotMax.y - fdPlotMin.y);
    
    if (ctrlNum == ccModFreq)
        [[evc fdControlArray] setHorizontalValue:fdPlotMin.x + normVal * fdPlotRange.x
                               forControlWithTag:kModulationParamsTag];
    if (ctrlNum == ccModAmp)
        [[evc fdControlArray] setVerticalValue:fdPlotMin.y + normVal * fdPlotRange.y
                             forControlWithTag:kModulationParamsTag];
    if (ctrlNum == ccDistHighThresh)
        [[evc tdControlArray] setVerticalValue:normVal
                             forControlWithTag:kDistCutoffHighTag];
    if (ctrlNum == ccDistLowThresh)
        [[evc tdControlArray] setVerticalValue:-(1.0 - normVal)
                             forControlWithTag:kDistCutoffLowTag];
    if (ctrlNum == ccLPFCutoff)
        [[evc fdControlArray] setHorizontalValue:fdPlotMin.x + normVal * fdPlotRange.x
                               forControlWithTag:kLPFParamsTag];
    if (ctrlNum == ccLPFResonance)
        [[evc fdControlArray] setVerticalValue:normVal * fdPlotMax.y
                             forControlWithTag:kLPFParamsTag];
    if (ctrlNum == ccHPFCutoff)
        [[evc fdControlArray] setHorizontalValue:fdPlotMin.x + normVal * fdPlotRange.x
                               forControlWithTag:kHPFParamsTag];
    if (ctrlNum == ccHPFResonance)
        [[evc fdControlArray] setVerticalValue:normVal * fdPlotMax.y
                             forControlWithTag:kLPFParamsTag];
    
    for (int i = 0; i < kMaxNumDelayTaps; i++) {
        if (ctrlNum == ccDelayTime[i]) {
            [[evc tdControlArray] setHorizontalValue:tdPlotMin.x + normVal * tdPlotRange.x
                                   forControlWithTag:kDelayParamsTag + i];
        }
        else if (ctrlNum == ccDelayAmp[i]) {
            [[evc tdControlArray] setVerticalValue:normVal
                                 forControlWithTag:kDelayParamsTag + i];
        }
    }
}

- (void)handleProgramChange:(int)val {
    [svc handleProgramChange:val];
}

- (void)handleChannelAftertouch:(int)val {
    // Fake CC message with ctrl number -1 so channel aftertouches can be mapped dynamically
    [self handleCC:-1 value:val];
}

- (void)handlePitchBend:(float)normVal {
    [svc handlePitchBend:normVal];
}

# pragma mark - UIPickerViewDelegate
//- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(nullable UIView *)view {
//    
//}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow: (NSInteger)row inComponent:(NSInteger)component {
    // Handle the selection
}

// tell the picker how many rows are available for a given component
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    
    NSUInteger numRows = [activeParamList count];
    return numRows;
}

// tell the picker how many components it will have
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

// tell the picker the title for a given component
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    
    NSString *title;
    
    if (component == 0)
        title = activeParamList[row];
    else
        title = @"-";
    
    return title;
}

// tell the picker the width of each row for a given component
- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component {
    int sectionWidth = 300;
    
    return sectionWidth;
}

@end















