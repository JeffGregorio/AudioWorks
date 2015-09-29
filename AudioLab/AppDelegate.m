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
@synthesize navigationView;
@synthesize helpDisplayed;
@synthesize preGainSlider;
@synthesize levelsDrawer;

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
    playbackButton = [[METButton alloc] initWithTitle:@"?" origin:buttonOrigin color:audioWorksBlue];
    frame = playbackButton.frame;
    frame.size.width = frame.size.height;
    frame.size.height += 10.0f;
    [playbackButton setFrame:frame];
    playbackButtonImagePlay = [UIImage imageNamed:@"PlaybackButton_Play.png"];
    playbackButtonImagePause = [UIImage imageNamed:@"PlaybackButton_Pause.png"];
    playbackButtonImageRecord = [UIImage imageNamed:@"PlaybackButton_Record.png"];
    [playbackButton setImage:playbackButtonImagePause forState:UIControlStateNormal];
    playbackMode = kAudioWorksPlaybackModeRecord;
    [playbackButton addTarget:self action:@selector(playbackButtonPress:) forControlEvents:UIControlEventTouchUpInside];
    [navigationView addSubview:playbackButton];
    
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
        playbackMode = kAudioWorksPlaybackModeRecord;
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
                playbackMode = kAudioWorksPlaybackModeRecord;
                
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
                playbackMode = kAudioWorksPlaybackModeRecord;
                
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
                playbackMode = kAudioWorksPlaybackModePlay;
                
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
    [playbackButton setImage:playbackButtonImagePause forState:UIControlStateNormal];
    
    /* Modify the input gain control for synthesis mode */
    if ([sender tag] == kAudioWorksModeSynthesis || routingSynthToEffects) {
        previousPreGain = preGainSlider.value;
        [preGainSlider setRange:kPreGainMin max:1.0f];
        [preGainSlider setValue:0.75f];
    }
    else {
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
}

- (void)toggleHelp:(id)sender {
    
    DetailViewController *dvc = (DetailViewController *)self.window.rootViewController;
    [dvc toggleHelp];
    
    if (helpDisplayed) {
        [helpButton setImage:helpButtonImageIdle forState:UIControlStateNormal];
        helpDisplayed = false;
    }
    else {
        [helpButton setImage:helpButtonImageActive forState:UIControlStateNormal];
        helpDisplayed = true;
    }
}

- (void)playbackButtonPress:(id)sender {
    
    switch (currentMode) {
            
        case kAudioWorksModeAnalysis:
            
            [avc toggleInput];
            
            if (playbackMode == kAudioWorksPlaybackModeRecord) {
                playbackMode = kAudioWorksPlaybackModePause;
                [playbackButton setImage:playbackButtonImageRecord forState:UIControlStateNormal];
            }
            else if (playbackMode == kAudioWorksPlaybackModePause) {
                playbackMode = kAudioWorksPlaybackModeRecord;
                [playbackButton setImage:playbackButtonImagePause forState:UIControlStateNormal];
            }
            
            break;
            
        case kAudioWorksModeSynthesis:
            
            [svc toggleInput];
            
            if (playbackMode == kAudioWorksPlaybackModePlay) {
                playbackMode = kAudioWorksPlaybackModePause;
                [playbackButton setImage:playbackButtonImagePlay forState:UIControlStateNormal];
            }
            else if (playbackMode == kAudioWorksPlaybackModePause) {
                playbackMode = kAudioWorksPlaybackModePlay;
                [playbackButton setImage:playbackButtonImagePause forState:UIControlStateNormal];
            }
            
            break;
            
        case kAudioWorksModeEffects:
            
            [evc toggleInput];
            
            if (playbackMode == kAudioWorksPlaybackModeRecord) {
                playbackMode = kAudioWorksPlaybackModePause;
                [playbackButton setImage:playbackButtonImageRecord forState:UIControlStateNormal];
            }
            else if (playbackMode == kAudioWorksPlaybackModePause) {
                playbackMode = kAudioWorksPlaybackModeRecord;
                [playbackButton setImage:playbackButtonImagePause forState:UIControlStateNormal];
            }
            
            break;
            
        case kAudioWorksModeCredits:
            break;
        default:
            break;
    }
}

@end















