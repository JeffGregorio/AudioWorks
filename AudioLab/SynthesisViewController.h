//
//  SynthesisViewController.h
//  AudioWorks
//
//  Created by Jeff Gregorio on 6/24/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DetailViewController.h"
#import "AudioController.h"
#import "METScopeView.h"
#import "METSlider.h"
#import "HarmonicDotArray.h"
#import "FunctionDrawView.h"
#import "METButton.h"
#import "ParameterView.h"
#import "Constants.h"

#define kSynthesisPlotUpdateRate 0.002
#define kMaxPlotMax 2.0
#define kNumHarmonicEstimates 4

@interface SynthesisViewController : DetailViewController <METScopeViewDelegate, FunctionDrawViewDelegate, HarmonicDotArrayDelegate> {
    
    /* Fundamental frequency control */
    IBOutlet METSlider *fundamentalSlider;
    IBOutlet UILabel *fundamentalLabel;
    
    /* Harmonics */
    HarmonicDotArray *harmonicDots;
    
    /* Harmonic Presets */
    UISegmentedControl *presetSelector;
    NSInteger previouslySelectedPreset;
    CGFloat previousHarmonics[kNumHarmonics];
    CGFloat previousHarmonicEstimates[kNumHarmonics][kNumHarmonicEstimates];
    
    /* Parameter Information Views */
    ParameterView *harmonicInfoView;
    UILabel *freqValueLabel;
    UILabel *ampValueLabel;
    UIView *noiseInfoView;
    UILabel *noiseAmpValueLabel;
    
    /* Time/Frequency domain scopes */
    IBOutlet METScopeView *tdScopeView;
    IBOutlet METScopeView *fdScopeView;
    bool tdHold, fdHold;
    NSTimer *tdScopeClock;
    NSTimer *fdScopeClock;
    
    /* Waveform/Envelope Drawing */
    UISegmentedControl *drawSelector;
    UIButton *finishDrawingButton;
    FunctionDrawView *drawView;
    bool drawingEnvelope;
    bool drawingWaveform;
    float oldXMin, oldXMax;
    float oldXGridScale;
    bool usingWavetable;
    
    /* Plot x-axis values (time, frequencies) */
    float *plotTimes;
    float *plotFreqs;
    IBOutlet UILabel *timeAxisLabel;
    IBOutlet UILabel *freqAxisLabel;
    
    /* Tap recognizer for input enable control */
    UITapGestureRecognizer *tdTapRecognizer;
    bool inputPaused;
    
    /* Help */
    NSMutableArray *helpBubbles;
    NSMutableArray *helpBubblesDrawingWaveform;
    NSMutableArray *helpBubblesDrawingEnvelope;
    NSMutableArray *helpBubblesUsingWavetable;
    
}

@property (weak, atomic) AudioController *audioController;
@property (strong, atomic) ParameterView *harmonicInfoView;

- (IBAction)updateFundamental:(id)sender;
- (void)inputGainChanged;
- (void)toggleInput;

@end
