//
//  HarmonicDotArray.h
//  AudioWorks
//
//  Created by Jeff Gregorio on 7/7/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "METScopeView.h"
#import "Constants.h"

@protocol HarmonicDotArrayDelegate
- (void)touchDownOnHarmonic:(int)num;
- (void)touchDownOnNoiseSlider;
- (void)valueChangedForHarmonic:(int)num linearAmp:(CGFloat)val;
- (void)noiseAmplitudeChanged:(CGFloat)linearAmp;
- (void)harmonicDotArrayTouchEnded;
@end

@class NoiseHandle;

#pragma mark - HarmonicDotArray
@interface HarmonicDotArray : UIControl {
    
    float f0;
    bool editable;
    
    NSMutableArray *harmonicDots;
    int activeDotIndex;
    NoiseHandle *noiseHandle;
    
    CGPoint previousTouchLocation;
    
    CGFloat lineWidth;
    CGFloat lineAlpha;
    CGFloat gridDashLengths[2];
}

@property METScopeView *parentScope;
@property id <HarmonicDotArrayDelegate> delegate;
@property (readonly) CGFloat gainScalar;
@property UIColor *dotColor;
@property UIColor *lineColor;
@property (readonly) UIColor *edgeColor;

- (id)initWithParentScope:(METScopeView *)parent;
- (void)setEditable:(bool)editable;
- (void)setFundamentalFreq:(CGFloat)f0;
- (void)addHarmonicWithAmplitude_dB:(CGFloat)amp;
- (void)addHarmonicWithAmplitude:(CGFloat)amp;
- (void)setAmplitude_dB:(CGFloat)amp forHarmonic:(int)n;
- (void)setAmplitude:(CGFloat)amp forHarmonic:(int)n;
- (void)setNoiseAmplitude_db:(CGFloat)amp;
- (void)setNoiseAmplitude:(CGFloat)amp;
- (CGFloat)getAmplitudeForHarmonicNum:(int)n;
- (void)getAmplitudes:(CGFloat *)amps forNumHarmonics:(int)num;
- (void)plotBoundsChanged;
- (void)setGainScalar:(CGFloat)gain;
- (CGRect)getActiveDotFrame;
- (int)numHarmonics;

@end

#pragma mark - HarmonicDot
@interface HarmonicDot : UIControl {
    
    bool editable;
    HarmonicDotArray *parentArray;
    
//    CGPoint previousTouchLoc;
}

@property (readonly) CGFloat frequency;
@property (readonly) CGFloat amplitude;

- (id)initWithParent:(HarmonicDotArray *)parent loc:(CGPoint)loc;
- (void)setEditable:(bool)editable;
- (void)setFrequency:(CGFloat)freq;
- (void)setAmplitude:(CGFloat)amp;

@end

#pragma mark - NoiseHandle
@interface NoiseHandle : UIControl {
    HarmonicDotArray *parentArray;
}

@property (readonly) CGFloat amplitude;

- (id)initWithParent:(HarmonicDotArray *)parent amplitude:(CGFloat)amp;
- (void)setAmplitude:(CGFloat)amp;

@end







