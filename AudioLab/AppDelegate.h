//
//  AppDelegate.h
//  AudioLab
//
//  Created by Jeff Gregorio on 9/5/14.
//  Copyright (c) 2014 ___FULLUSERNAME___. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AudioController.h"
#import "AnalysisViewController.h"
#import "EffectsViewController.h"
#import "SynthesisViewController.h"
#import "CreditsViewController.h"
#import "METButton.h"
#import "METDrawer.h"
#import "Constants.h"

typedef enum AudioWorksMode {
    kAudioWorksModeAnalysis = 0,
    kAudioWorksModeEffects,
    kAudioWorksModeSynthesis,
    kAudioWorksModeCredits
} AudioWorksMode;

typedef enum AudioWorksPlaybackMode {
    kAudioWorksPlaybackModePlay = 0,
    kAudioWorksPlaybackModePause,
    kAudioWorksPlaybackModeRecord
} AudioWorksPlaybackMode;

@interface AppDelegate : UIResponder <UIApplicationDelegate> {
    
    /* ViewControllers for each mode */
    AnalysisViewController *avc;
    EffectsViewController *evc;
    SynthesisViewController *svc;
    CreditsViewController *cvc;
    
    /* Navigation bar */
    AudioWorksMode currentMode;
    AudioWorksMode previousMode;
    METButton *analysisButton;
    METButton *effectsButton;
    METButton *synthesisButton;
    METButton *creditsButton;
    METButton *helpButton;
    int modeButtonsHeld;
    bool routingSynthToEffects;
    
    UIImage *creditsButtonImageIdle;
    UIImage *creditsButtonImageActive;
    UIImage *helpButtonImageIdle;
    UIImage *helpButtonImageActive;
    UIImageView *routingArrow;
    
    /* Level controls */
    METDrawer *levelsDrawer;
    METSlider *preGainSlider;
    float previousPreGain;
    
    METButton *playbackButton;
    UIImage *playbackButtonImagePlay;
    UIImage *playbackButtonImagePause;
    UIImage *playbackButtonImageRecord;
    AudioWorksPlaybackMode playbackMode;
}

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIView *navigationView;
@property (strong, atomic) AudioController *audioController;
@property (strong, atomic) METSlider *preGainSlider;
@property (strong, atomic) METDrawer *levelsDrawer;
@property (readonly) bool helpDisplayed;

- (void)playbackButtonPress:(id)sender;

@end

