//
//  METVerticalSliderArray.h
//  ButtonSliderTest
//
//  Created by Jeff Gregorio on 9/25/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "METSlider.h"

@protocol METSliderArrayDelegate <NSObject>
- (void)valueChangedForSlider:(int)sliderIdx newValue:(float)value;
@end

@interface METVerticalSliderArray : UIControl {
    
    int _nSliders;
    NSMutableArray *_sliders;
    NSMutableArray *_sliderLabels;
    
    CGFloat _sliderHeight;
    CGFloat _sliderWidth;
    CGFloat _sliderSpacing;
    
    BOOL _allowsMultiSliderSwipe;
}

@property (weak) id <METSliderArrayDelegate> delegate;
@property (readonly) int lastEditedSlider;

/* Slider array formatting */
- (void)setNumSliders:(int)n;
- (void)setSliderWidth:(CGFloat)width;
- (BOOL)setTrackWidthScalar:(CGFloat)scale;
- (BOOL)setTabRadiusScalar:(CGFloat)scale;
- (void)setTrackFillColor:(UIColor *)color;
- (void)setTrackBackgroundColor:(UIColor *)color;
- (void)setTabColor:(UIColor *)color;

/* Allow a single swipe gesture across multiple sliders to set values */
- (void)setAllowsMultiSliderSwipe:(BOOL)allowed;

/* Slider ranges */
- (BOOL)setRangeForAllSliders:(float)minVal max:(float)maxVal;
- (BOOL)setRangeForSlider:(int)sliderIdx min:(float)minVal max:(float)maxVal;

/* Slider values */
- (BOOL)setValueForAllSliders:(float)value;
- (BOOL)setValuesForAllSlidersWithFloatArray:(float *)values;
- (BOOL)setValuesForAllSlidersWithNSArray:(NSArray *)values;
- (BOOL)setValueForSlider:(int)sliderIdx value:(float)value;

- (float)getValueForSlider:(int)sliderIdx;
- (void)getValuesForNumSliders:(float *)values num:(int)nSliders;

@end
