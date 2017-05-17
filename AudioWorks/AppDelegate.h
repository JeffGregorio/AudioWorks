//
//  AppDelegate.h
//  AudioLab
//
//  Created by Jeff Gregorio on 9/5/14.
//  Copyright (c) 2014 ___FULLUSERNAME___. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AudioController.h"
#import "MIDIController.h"
#import "AnalysisViewController.h"
#import "EffectsViewController.h"
#import "SynthesisViewController.h"
#import "CreditsViewController.h"
#import "METButton.h"
#import "METDrawer.h"
#import "METKeyboard.h"
#import "Constants.h"
#import "HelpBubble.h"
//#include <math.h>

typedef enum AudioWorksMode {
    kAudioWorksModeAnalysis = 0,
    kAudioWorksModeEffects,
    kAudioWorksModeSynthesis,
    kAudioWorksModeCredits
} AudioWorksMode;

typedef enum AudioWorksAudioState {
    kAudioWorksAudioStatePlay = 0,
    kAudioWorksAudioStatePause,
    kAudioWorksAudioStateRecord
} AudioWorksAudioState;

@interface AppDelegate : UIResponder <UIApplicationDelegate, UIPickerViewDelegate,
MIDIHandler, METKeyboardDelegate> {
    
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
    UIImage *keyboardButtonImageIdle;
    UIImage *keyboardButtonImageActive;
    UIImageView *routingArrow;
    
    /* Level controls */
    METDrawer *levelsDrawer;
    METSlider *preGainSlider;
    float previousPreGain;
    
    METButton *recordStateButton;
    UIImage *recordStateButtonImagePlay;
    UIImage *recordStateButtonImagePause;
    UIImage *recordStateButtonImageRecord;
    AudioWorksAudioState audioState;
    
    METButton *playbackButton;  // Playback of recorded audio
    UIImage *playbackButtonImage;
    
    /* On-screen keyboard */
    METKeyboard *keyboard;
    METButton *keyboardButton;
    
    /* MIDI */
    /* Note: this is an awful way of doing MIDI parameter mapping */
    NSMutableArray *activeParamList;
    int ccModFreq;
    int ccModAmp;
    int ccDistHighThresh;
    int ccDistLowThresh;
    int ccLPFCutoff;
    int ccLPFResonance;
    int ccHPFCutoff;
    int ccHPFResonance;
    int ccDelayTime[kMaxNumDelayTaps];
    int ccDelayAmp[kMaxNumDelayTaps];
    
    HelpBubble *midiHelp;
}

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIView *navigationView;
@property (strong, atomic) AudioController *audioController;
@property (strong, atomic) MIDIController *midiController;
@property (strong, atomic) METSlider *preGainSlider;
@property (strong, atomic) METDrawer *levelsDrawer;
@property (readonly) bool helpDisplayed;
@property (strong, atomic) METButton *midiButton;
@property (strong, atomic) UIPickerView *midiParamPicker;

- (void)recordStateButtonPress:(id)sender;
- (void)playbackButtonPress:(id)sender;
- (void)queryAvailableMIDIParams;

@end

