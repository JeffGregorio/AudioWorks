//
//  EffectsViewController.h
//  AudioWorks
//
//  Created by Jeff Gregorio on 6/24/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DetailViewController.h"
#import "AudioController.h"
#import "METScopeView.h"
#import "FilterTapRegionView.h"
#import "METScopeControlArray.h"
#import "METButton.h"

#define kEffectsScopeUpdateRate 0.003

#define kDelayFeedbackScalar 1.0
#define kDelayMaxFeedback 0.8

#define kEffectEnabledAlpha 0.4f
#define kEffectDisabledAlpha 0.05f

enum {
    kPlayheadTag = 0,
    kModulationParamsTag,
    kDistCutoffHighTag,
    kDistCutoffLowTag,
    kLPFParamsTag,
    kHPFParamsTag,
    kDelayParamsTag,
};

@interface EffectsViewController : DetailViewController <METScopeViewDelegate, METScopeControlArrayDelegate, AudioPlaybackDelegate> {
    
    /* Time/Frequency domain scopes */
    IBOutlet METScopeView *tdScopeView;
    IBOutlet METScopeView *fdScopeView;
    IBOutlet UILabel *timeAxisLabel;
    IBOutlet UILabel *freqAxisLabel;
    NSTimer *tdScopeClock;
    NSTimer *fdScopeClock;
    bool tdHold, fdHold;
    
    METControl *playhead;
    
    bool inputPaused;
    float previousTMin;
    float previousTMax;
    
    /* Waveform subview indices */
    int tdDryIdx, tdWetIdx, delayIdx;
    int fdDryIdx, fdWetIdx, modIdx;
    int lpfIdx, hpfIdx;
    
    /* Constant-length scope data buffers */
    Float32 *fdScopeTDXData;
    Float32 *fdScopeTDYData;
    Float32 *fdScopeFDXData;
    Float32 *fdScopeFDYData;
    Float32 *lpfMagnitudeResponse;
    Float32 *hpfMagnitudeResponse;
    
    /* Scope data buffers with length based on visible plot bounds */
    Float32 maxScale;
    int startIdx, endIdx;
    int visibleBufferLength;
    Float32 *tdScopeXData;
    Float32 *tdScopeYDataDry;
    Float32 *tdScopeYDataWet;
    
    /* Delay scope */
    METScopeView *delayScopeView;
    METControl *activeDelayTapControl;
    bool editingDelayTap;
    Float32 *delayXBuffer;
    Float32 *delayYBuffer;
    
    /* Delay control */
    METScopeControlArray *tdControlArray;
    UIView *delayRegionView;
    UITapGestureRecognizer *delayTapRecognizer;
    METButton *delayTapAddButton;
//    int delayUpdateCounter;
    
    /* Distortion cutoff control */
    UIView *distortionTapRegionView;
    UITapGestureRecognizer *distCutoffTapRecognizer;
    
    /* Modulation frequency control */
    METScopeControlArray *fdControlArray;
    UIView *modFreqPanRegionView;
    UITapGestureRecognizer *modFreqTapRecognizer;
    Float32 *modulationXBuffer;
    Float32 *modulationYBuffer;
    
    /* Filter control */
    FilterTapRegionView *hpfTapRegionView;
    FilterTapRegionView *lpfTapRegionView;
    UITapGestureRecognizer *hpfTapRecognizer;
    UITapGestureRecognizer *lpfTapRecognizer;

    /* Help */
    UIBarButtonItem *helpButton;
    NSMutableArray *helpBubblesDelayEnabled;
    NSMutableArray *helpBubblesDelayDisabled;
    NSMutableArray *helpBubblesDistEnabled;
    NSMutableArray *helpBubblesDistDisabled;
    NSMutableArray *helpBubblesModEnabled;
    NSMutableArray *helpBubblesModDisabled;
    NSMutableArray *helpBubblesLPFEnabled;
    NSMutableArray *helpBubblesLPFDisabled;
    NSMutableArray *helpBubblesHPFEnabled;
    NSMutableArray *helpBubblesHPFDisabled;
}

@property (weak, atomic) AudioController *audioController;
@property (strong, readonly) METScopeView *tdScopeView;
@property (strong, readonly) METScopeView *fdScopeView;
@property (strong, readonly) METScopeControlArray *tdControlArray;
@property (strong, readonly) METScopeControlArray *fdControlArray;

- (void)getMIDIParams;
- (void)parameterUpdate:(METControl *)sender;

@end
