//
//  AnalysisViewController.h
//  AudioWorks
//
//  Created by Jeff Gregorio on 6/24/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DetailViewController.h"
#import "AudioController.h"
#import "METScopeView.h"
#import "METScopeControlArray.h"

#define kAnalysisScopeUpdateRate 0.003

@interface AnalysisViewController : DetailViewController < METScopeViewDelegate, METScopeControlArrayDelegate, AudioPlaybackDelegate> {
    
    /* Time/Frequency domain scopes */
    IBOutlet METScopeView *tdScopeView;
    IBOutlet METScopeView *fdScopeView;
    int tdIdx, fdIdx;
    bool tdHold, fdHold;
    NSTimer *tdScopeClock;
    NSTimer *fdScopeClock;
    
    /* Plot x-axis values (time, frequencies) */
    float *plotTimes;
    float *plotFreqs;
    IBOutlet UILabel *timeAxisLabel;
    IBOutlet UILabel *freqAxisLabel;
    
    /* Control array for time domain scope playhead */
    METScopeControlArray *tdControlArray;
    METControl *playhead;
    
    /* Tap recognizer for input enable control */
//    UITapGestureRecognizer *tdTapRecognizer;
    bool inputPaused;
    float previousTMin;
    float previousTMax;
    
    /* Help */
    NSMutableArray *helpBubbles;
}

@property (weak, atomic) AudioController *audioController;

- (CGFloat)toggleInput;
- (CGFloat)getVisibleTMin;
- (CGFloat)getVisibleTMax;

@end
