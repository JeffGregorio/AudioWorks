//
//  METSwitchedSlider.h
//  ButtonSliderTest
//
//  Created by Jeff Gregorio on 9/17/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum METSliderTabType {
    METSliderTabTypeCircle = 0,
    METSliderTabTypeRect            // TODO
} METSliderTabType;

typedef enum METSwitchType {
    METSwitchTypeNone = 0,          // TODO
    METSwitchTypeRect,
    METSwitchTypeCircle,
    METSwitchTypeSocket
} METSwitchType;

typedef enum METSwitchBehavior {
    METSwitchBehaviorNone = 0,
    METSwitchBehaviorSetSliderMin,
    METSwitchBehaviorDisableSlider
} METSwitchBehavior;

typedef enum METSwitchState {
    METSwitchStateOff = 0,
    METSwitchStateOn,
    METSwitchStateDown
} METSwitchState;

@interface METSwitchedSlider : UIControl {

    /* Switch state */
    bool _sliderDisabled;
    METSwitchState _previousSwitchState;
    
    /* Switch size/position */
    CGFloat _switchWidth;
    CGFloat _rectSwitchCornerRadius;
    
    /* Slider value */
    CGFloat _sliderFillRatio;
    CGFloat _previousSliderFillRatio;
    CGFloat _tabPosition;
    CGFloat _minValue;
    CGFloat _maxValue;
    
    /* Slider size/position */
    CGFloat _sliderWidth;
    CGFloat _sliderHeight;
    CGFloat _sliderTopEdge;
    CGFloat _sliderBottomEdge;
    CGFloat _sliderLeftEdge;
    CGFloat _sliderRightEdge;
    CGFloat _sliderCornerRadius;
    CGFloat _sliderTabRadius;
    CGFloat _sliderHeightScalar;
    CGFloat _sliderPadSpace;
    CGFloat _sliderLeftTouchLim;
    CGFloat _sliderRightTouchLim;
    CGFloat _sliderLeadingSpace;
    
    /* Colors */
    CGFloat _edgeRGBScalar;
    UIColor *_switchOnEdgeColor;
    UIColor *_switchOffEdgeColor;
    UIColor *_sliderFillEdgeColor;
    UIColor *_sliderBackgroundEdgeColor;
    UIColor *_sliderTabEdgeColor;
    
    UIColor *_switchOnColor;
    UIColor *_switchOffColor;
    UIColor *_sliderFillColor;
    UIColor *_sliderBackgroundColor;
    UIColor *_sliderTabColor;
    
    /* Opacity for disabled slider components */
    CGFloat _sliderDisabledAlphaScale;
    CGFloat _sliderFillEnabledAlpha;
    CGFloat _sliderFillDisabledAlpha;
    CGFloat _sliderBackgroundEnabledAlpha;
    CGFloat _sliderBackgroundDisabledAlpha;
    CGFloat _sliderTabEnabledAlpha;
    CGFloat _sliderTabDisabledAlpha;
}

@property (readonly) float sliderValue;
@property (readonly) METSwitchState switchState;

/* Changes in switchState and sliderValue both send to the "ValueChanged" outlet, so query these flags to find out which value changed triggered the event */
@property (readonly) bool sliderValueChanged;
@property (readonly) bool switchStateChanged;

@property METSwitchType switchType;
@property METSwitchBehavior switchBehavior;

- (void)setSliderValue:(float)sliderValue;
- (void)setSliderRange:(float)minVal max:(float)maxVal;
- (void)setSwitchState:(METSwitchState)state;

- (void)setSliderLeadingSpace:(CGFloat)space;
- (void)setSwitchWidth:(CGFloat)width;
- (void)setSliderHeightScalar:(CGFloat)scale;
- (void)setSliderTabRadius:(CGFloat)radius;

- (void)setSwitchOnColor:(UIColor *)color;
- (void)setSwitchOffColor:(UIColor *)color;
- (void)setSliderFillColor:(UIColor *)color;
- (void)setSliderBackgroundColor:(UIColor *)color;
- (void)setSliderTabColor:(UIColor *)color;

/* TODO: Enabled/Disable setting value by tapping outside of slider tab */

@end
