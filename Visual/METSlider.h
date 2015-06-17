//
//  METSlider.h
//  ButtonSliderTest
//
//  Created by Jeff Gregorio on 9/25/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface METSlider : UIControl {
    
    /* Slider value */
    CGFloat _fillRatio;     // Unscaled value [0, 1]
    
    /* Slider size/position, assuming horizontal orientation */
    CGFloat _trackHeightScalar;
    CGFloat _tabRadiusScalar;
    CGFloat _trackWidth;
    CGFloat _trackHeight;
    CGFloat _trackTopEdge;
    CGFloat _trackBottomEdge;
    CGFloat _trackLeftEdge;
    CGFloat _trackRightEdge;
    CGFloat _trackCornerRadius;
    CGFloat _trackPadSpace;
    CGFloat _leftTouchLim;
    CGFloat _rightTouchLim;
    CGFloat _tabRadius;
    CGFloat _tabPosition;
    
    /* Colors */
    CGFloat _edgeRGBScalar;                 // RGB scalar to darken edge colors
    UIColor *_trackFillColor;
    UIColor *_trackFillEdgeColor;
    UIColor *_trackBackgroundColor;
    UIColor *_trackBackgroundEdgeColor;
    UIColor *_tabColor;
    UIColor *_tabEdgeColor;
}

@property (readonly) float value;
@property (readonly) float minValue;
@property (readonly) float maxValue;

/* Value */
- (BOOL)setValue:(float)value;
- (BOOL)setRange:(float)minVal max:(float)maxVal;

/* Dimensions */
- (BOOL)setTrackHeightScalar:(CGFloat)scale;
- (BOOL)setTabRadiusScalar:(CGFloat)scale;

/* Colors */
- (void)setTrackFillColor:(UIColor *)color;
- (void)setTrackBackgroundColor:(UIColor *)color;
- (void)setTabColor:(UIColor *)color;

@end
