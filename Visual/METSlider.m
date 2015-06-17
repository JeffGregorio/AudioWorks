//
//  METSlider.m
//  ButtonSliderTest
//
//  Created by Jeff Gregorio on 9/25/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import "METSlider.h"

@implementation METSlider

CGFloat const kDefaultTrackHeightScalar = 0.1f;
CGFloat const kDefaultTabRadiusScalar = 0.35f;
CGFloat const kDefaultEdgeRGBScalar = 0.5f;

@synthesize value = _value;
@synthesize minValue = _minValue;
@synthesize maxValue = _maxValue;

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self)
        [self defaultSetup];
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self)
        [self defaultSetup];
    return self;
}

- (void)defaultSetup {
    
//    [[self layer] setBorderWidth:1.0f];
    
    /* --------------------------- */
    /* === Set up slider value === */
    /* --------------------------- */
    
    _value = 0.5f;
    _minValue = 0.0f;
    _maxValue = 1.0f;
    _fillRatio = (_value - _minValue) / (_maxValue - _minValue);
    
    /* --------------------- */
    /* === Set up colors === */
    /* --------------------- */
    
    [self setBackgroundColor:[UIColor clearColor]];
    
    _edgeRGBScalar = kDefaultEdgeRGBScalar;
    [self setTrackFillColor:[[UIColor blueColor] colorWithAlphaComponent:0.6f]];
    
    UIColor *lightOffWhite = [UIColor colorWithRed:0.95f green:0.95f blue:0.95f alpha:1.0];
    [self setTrackBackgroundColor:lightOffWhite];
    [self setTabColor:lightOffWhite];
    
    /* ------------------------- */
    /* === Set up dimensions === */
    /* ------------------------- */
    
    _trackHeightScalar = kDefaultTrackHeightScalar;
    _tabRadiusScalar = kDefaultTabRadiusScalar;
    
    [self computeSliderDimensions];
    [self computeTabPosition];
}

- (void)computeSliderDimensions {
    
    _tabRadius = self.bounds.size.height * _tabRadiusScalar - 1.0f;
    
    _trackTopEdge = (self.bounds.size.height * (1.0f - _trackHeightScalar)) / 2.0f - 2.0f;
    _trackBottomEdge = self.bounds.size.height - _trackTopEdge - 2.0f;
    
    _trackPadSpace = fmaxf(_tabRadius, _trackCornerRadius) + 1.0f;
    
    _trackHeight = self.bounds.size.height * _trackHeightScalar;
    _trackCornerRadius = _trackHeight / 2.0f;
    
    _trackLeftEdge = _trackPadSpace;
    _trackRightEdge = self.bounds.size.width - _trackPadSpace;
    _trackWidth = _trackRightEdge - _trackLeftEdge;
    
    _leftTouchLim = _trackLeftEdge + _trackCornerRadius + _tabRadius;
    _rightTouchLim = _trackRightEdge - _trackCornerRadius - _tabRadius;
    
    [self setNeedsDisplay];
}

#pragma mark - Interface Methods
- (BOOL)setValue:(float)value {
    
    if (value < _minValue) value = _minValue;
    if (value > _maxValue) value = _maxValue;
    
    _value = value;
    _fillRatio = (_value - _minValue) / (_maxValue - _minValue);
    [self computeTabPosition];
    
    return NO;
}

- (BOOL)setRange:(float)minVal max:(float)maxVal {
    
    if (minVal >= maxVal) {
        NSLog(@"%s: Invalid range [%f, %f]. Range remaining [%f, %f]",
              __PRETTY_FUNCTION__, minVal, maxVal, _minValue, _maxValue);
        return NO;
    }
    
    _minValue = minVal;
    _maxValue = maxVal;
    _fillRatio = (_value - _minValue) / (_maxValue - _minValue);
    [self computeTabPosition];
    
    return YES;
}

- (BOOL)setTrackHeightScalar:(CGFloat)scale {
    
    if (scale < 0.0f) scale = 0.0f;
    if (scale > 1.0f) scale = 1.0f;
    
    _trackHeightScalar = scale;
    [self computeSliderDimensions];
    
    return YES;
}

- (BOOL)setTabRadiusScalar:(CGFloat)scale {
    
    if (scale < 0.0f) scale = 0.0f;
    if (scale > 1.0f) scale = 1.0f;
    
    _tabRadiusScalar = scale;
    [self computeSliderDimensions];
    
    return YES;
}

- (void)setTrackFillColor:(UIColor *)color {
    
    _trackFillColor = color;
    
    CGFloat red = 0.0f, green = 0.0f, blue = 0.0f, alpha = 0.0f;
    [_trackFillColor getRed:&red green:&green blue:&blue alpha:&alpha];
    _trackFillEdgeColor = [UIColor colorWithRed:_edgeRGBScalar * red
                                          green:_edgeRGBScalar * green
                                           blue:_edgeRGBScalar * blue
                                          alpha:alpha];
}

- (void)setTrackBackgroundColor:(UIColor *)color {
    
    _trackBackgroundColor = color;
    
    CGFloat red = 0.0f, green = 0.0f, blue = 0.0f, alpha = 0.0f;
    [_trackBackgroundColor getRed:&red green:&green blue:&blue alpha:&alpha];
    _trackBackgroundEdgeColor = [UIColor colorWithRed:_edgeRGBScalar * red
                                                green:_edgeRGBScalar * green
                                                 blue:_edgeRGBScalar * blue
                                                alpha:alpha];
}

- (void)setTabColor:(UIColor *)color {
    
    _tabColor = color;
    
    CGFloat red = 0.0f, green = 0.0f, blue = 0.0f, alpha = 0.0f;
    [_tabColor getRed:&red green:&green blue:&blue alpha:&alpha];
    _tabEdgeColor = [UIColor colorWithRed:_edgeRGBScalar * red
                                    green:_edgeRGBScalar * green
                                     blue:_edgeRGBScalar * blue
                                    alpha:alpha];
}

#pragma mark - Slider Value/Tab Location Helpers
- (void)computeSliderFillRatioFromTouchLocation:(CGPoint)loc {
    
    if (loc.x < _leftTouchLim) {
        _fillRatio = 0.0f;
    }
    else if (loc.x  > _rightTouchLim) {
        _fillRatio = 1.0f;
    }
    else {
        /* Compute the portion of the slider that's filled */
        _fillRatio = (loc.x - (_leftTouchLim)) /
        (_rightTouchLim - _leftTouchLim);
    }
}

- (void)scaleSliderValue {
    _value = _minValue + _fillRatio * (_maxValue - _minValue);
    _value = _value < _minValue ? _minValue : _value;
    _value = _value > _maxValue ? _maxValue : _value;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)computeTabPosition {
    _tabPosition = _trackLeftEdge + _fillRatio * (_trackRightEdge - _trackLeftEdge);
    [self setNeedsDisplay];
}

#pragma mark - Touch Handlers
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    
    [super beginTrackingWithTouch:touch withEvent:event];
    CGPoint loc = [touch locationInView:self];
    
    [self computeSliderFillRatioFromTouchLocation:loc];
    [self scaleSliderValue];
    [self computeTabPosition];
    
    return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    
    [super beginTrackingWithTouch:touch withEvent:event];
    CGPoint loc = [touch locationInView:self];
    
    [self computeSliderFillRatioFromTouchLocation:loc];
    [self scaleSliderValue];
    [self computeTabPosition];
    
    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    
    [super endTrackingWithTouch:touch withEvent:event];
    CGPoint loc = [touch locationInView:self];
    
    [self computeSliderFillRatioFromTouchLocation:loc];
    [self scaleSliderValue];
    [self computeTabPosition];
}

#pragma mark - Drawing Methods
- (void)drawRect:(CGRect)rect {
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    /* --------------------------------------- */
    /* === Draw slider track filled region === */
    /* --------------------------------------- */
    
    CGMutablePathRef filledPath = CGPathCreateMutable();
    [self drawTrackFilled:filledPath inRect:rect];
    CGContextAddPath(context, filledPath);
    
    CGContextSetStrokeColorWithColor(context, _trackFillEdgeColor.CGColor);
    CGContextSetFillColorWithColor(context, _trackFillColor.CGColor);
    CGContextDrawPath(context, kCGPathEOFillStroke);
    
    /* ------------------------------------ */
    /* === Draw slider track background === */
    /* ------------------------------------ */
    
    CGMutablePathRef backgroundPath = CGPathCreateMutable();
    [self drawTrackBackground:backgroundPath inRect:rect];
    CGContextAddPath(context, backgroundPath);
    
    CGContextSetStrokeColorWithColor(context, _trackBackgroundEdgeColor.CGColor);
    CGContextSetFillColorWithColor(context, _trackBackgroundColor.CGColor);
    CGContextDrawPath(context, kCGPathEOFillStroke);
    
    /* ----------------------- */
    /* === Draw slider tab === */
    /* ----------------------- */
    
    CGMutablePathRef tabPath = CGPathCreateMutable();
    [self drawTab:tabPath inRect:rect];
    CGContextAddPath(context, tabPath);
    
    /* Erase what's inside the circle so we can change the alpha without showing the background */
    CGContextSetBlendMode(context, kCGBlendModeClear);
    CGContextFillPath(context);
    
    /* Draw the slider tab */
    CGContextAddPath(context, tabPath);
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGContextSetStrokeColorWithColor(context, _tabEdgeColor.CGColor);
    CGContextSetFillColorWithColor(context, _tabColor.CGColor);
    CGContextDrawPath(context, kCGPathEOFillStroke);
}

- (void)drawTrackFilled:(CGMutablePathRef)path inRect:(CGRect)rect {
    
    CGPathMoveToPoint(path, nil, _trackLeftEdge + _trackCornerRadius, _trackTopEdge);
    CGPathAddLineToPoint(path, nil, _tabPosition, _trackTopEdge);
    CGPathAddLineToPoint(path, nil, _tabPosition, _trackBottomEdge);
    CGPathAddLineToPoint(path, nil, _trackLeftEdge + _trackCornerRadius, _trackBottomEdge);
    CGPathAddArcToPoint(path, nil, _trackLeftEdge, _trackBottomEdge,
                        _trackLeftEdge, rect.size.height / 2.0f,
                        _trackCornerRadius);
    CGPathAddArcToPoint(path, nil, _trackLeftEdge, _trackTopEdge,
                        _trackLeftEdge + _trackCornerRadius, _trackTopEdge,
                        _trackCornerRadius);
    CGPathCloseSubpath(path);
}

- (void)drawTrackBackground:(CGMutablePathRef)path inRect:(CGRect)rect {
    
    CGPathMoveToPoint(path, nil, _tabPosition, _trackTopEdge);
    CGPathAddArcToPoint(path, nil, _trackRightEdge, _trackTopEdge,
                        _trackRightEdge, rect.size.height / 2.0f,
                        _trackCornerRadius);
    CGPathAddArcToPoint(path, nil, _trackRightEdge, _trackBottomEdge,
                        _trackRightEdge - _trackCornerRadius, _trackBottomEdge,
                        _trackCornerRadius);
    CGPathAddLineToPoint(path, nil, _tabPosition, _trackBottomEdge);
    CGPathCloseSubpath(path);
}

- (void)drawTab:(CGMutablePathRef)path inRect:(CGRect)rect {
    
    CGPathAddArc(path, nil, _tabPosition, rect.size.height / 2.0f,
                 _tabRadius, 0.0f, 2.0f*M_PI, true);
    CGPathCloseSubpath(path);
}


@end
