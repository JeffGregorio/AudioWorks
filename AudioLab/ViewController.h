//
//  ViewController.h
//  DigitalSoundFX
//
//  Created by Jeff Gregorio on 5/11/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "AudioController.h"
#import "METScopeView.h"
#import "FilterTapRegionView.h"
#import "PinchRegionView.h"
#import "HelpBubble.h"

#define kScopeUpdateRate 0.003

#define kDelayFeedbackScalar 0.15
#define kDelayMaxFeedback 0.8

#define kEffectEnabledAlpha 0.25f
#define kEffectDisabledAlpha 0.05f

@interface ViewController : UIViewController <METScopeViewDelegate> {
    
    /* Audio */
    AudioController *audioController;
    CGFloat previousPostGain;
    
    /* Time/Frequency domain scopes */
    IBOutlet METScopeView *tdScopeView;
    IBOutlet METScopeView *fdScopeView;
    bool tdHold, fdHold;
    NSTimer *tdScopeClock;
    NSTimer *fdScopeClock;
    
    /* Delay scope */
    METScopeView *delayView;
    UIPinchGestureRecognizer *delayPinchRecognizer;
    CGFloat delayPreviousPinchScale;
    UIPanGestureRecognizer *delayPanRecognizer;
    CGPoint delayPreviousPanLoc;
    bool delayOn;
    
    /* Waveform subview indices */
    int tdDryIdx, tdWetIdx, delayIdx;
    int fdDryIdx, fdWetIdx, modIdx;
    int tdClipIdxLow, tdClipIdxHigh;
    
    /* Plot x-axis values (time, frequencies) */
    float *plotTimes;
    float *plotFreqs;
    
    /* Delay control */
    UIView *delayRegionView;
    UITapGestureRecognizer *delayTapRecognizer;
    UIView *delayParameterView;
    UILabel *delayTimeValue;
    UILabel *delayAmountValue;
    
    /* Distortion cutoff control */
    PinchRegionView *distPinchRegionView;
    UITapGestureRecognizer *distCutoffTapRecognizer;
    UIPinchGestureRecognizer *distCutoffPinchRecognizer;
    CGFloat previousPinchScale;
    
    /* Modulation frequency control */
    UIView *modFreqPanRegionView;
    UITapGestureRecognizer *modFreqTapRecognizer;
    UIPanGestureRecognizer *modFreqPanRecognizer;
    CGPoint modFreqPreviousPanLoc;
    
    /* Filter control */
    FilterTapRegionView *hpfTapRegionView;
    FilterTapRegionView *lpfTapRegionView;
    UITapGestureRecognizer *hpfTapRecognizer;
    UITapGestureRecognizer *lpfTapRecognizer;
    
    /* Tap recognizer for input enable control */
    UITapGestureRecognizer *tdTapRecognizer;
    bool inputPaused;
    
    /* Gain controls */
    IBOutlet UISlider *preGainSlider;
    IBOutlet UISlider *postGainSlider;
    
    /* Switches */
    IBOutlet UISwitch *inputEnableSwitch;
    IBOutlet UISwitch *outputEnableSwitch;
    
    /* FX/Analysis mode */
    IBOutlet UIButton *effectsButton;
    bool analysisMode, delayWasActive, distWasActive, modWasActive, lpfWasActive, hpfWasActive;
    
    /* Help */
    bool helpDisplayed;
    IBOutlet UIButton *helpButton;
    
    /* Help bubble arrays for various modes */
    NSMutableArray *analysisModeHelp;
    NSMutableArray *analysisModeHelpInputEnabled;
    NSMutableArray *analysisModeHelpInputDisabled;
    NSMutableArray *effectsModeHelp;
    NSMutableArray *effectsModeHelpDelayEnabled;
    NSMutableArray *effectsModeHelpDelayDisabled;
    NSMutableArray *effectsModeHelpDistEnabled;
    NSMutableArray *effectsModeHelpDistDisabled;
    NSMutableArray *effectsModeHelpModEnabled;
    NSMutableArray *effectsModeHelpModDisabled;
    NSMutableArray *effectsModeHelpLPFEnabled;
    NSMutableArray *effectsModeHelpLPFDisabled;
    NSMutableArray *effectsModeHelpHPFEnabled;
    NSMutableArray *effectsModeHelpHPFDisabled;
}

@end

