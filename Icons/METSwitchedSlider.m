//
//  METSwitchedSlider.m
//  ButtonSliderTest
//
//  Created by Jeff Gregorio on 9/17/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import "METSwitchedSlider.h"

@implementation METSwitchedSlider

CGFloat const kDefaultSliderHeightScalar = 0.25f;
METSwitchType const kDefaultSwitchType = METSwitchTypeSocket;
METSwitchBehavior const kDefaultSwitchBehavior = METSwitchBehaviorDisableSlider;
CGFloat const kDefaultSliderDisabledAlphaScale = 0.5f;
CGFloat const kDefaultRectSwitchCornerRadius = 5.0f;
CGFloat const kDefaultEdgeRGBScalar = 0.5f;

@synthesize sliderValue = _sliderValue;
@synthesize switchType = _switchType;
@synthesize switchBehavior = _switchBehavior;
@synthesize switchState = _switchState;

- (id)initWithCoder:(NSCoder *)encoder {
    
    self = [super initWithCoder:encoder];
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
    
    [self setBackgroundColor:[UIColor clearColor]];
    
    _switchType = kDefaultSwitchType;
    _switchBehavior = kDefaultSwitchBehavior;
    _switchState = _previousSwitchState = METSwitchStateOn;
    _sliderDisabled = false;
    _sliderValue = 0.5f;
    _minValue = 0.0f;
    _maxValue = 1.0f;
    _sliderFillRatio = (_sliderValue - _minValue) / (_maxValue - _minValue);
    
    /* --------------------- */
    /* === Set up colors === */
    /* --------------------- */
    
    UIColor *lightOffWhite = [UIColor colorWithRed:0.95f green:0.95f blue:0.95f alpha:1.0];
    
    _edgeRGBScalar = kDefaultEdgeRGBScalar;
    _sliderDisabledAlphaScale = kDefaultSliderDisabledAlphaScale;
    [self setSwitchOnColor:[UIColor lightGrayColor]];
    [self setSwitchOffColor:lightOffWhite];
    [self setSliderFillColor:[[UIColor blueColor] colorWithAlphaComponent:0.6f]];
    [self setSliderBackgroundColor:lightOffWhite];
    [self setSliderTabColor:lightOffWhite];
    
    /* ------------------------- */
    /* === Set up dimensions === */
    /* ------------------------- */
    
    _switchWidth = self.frame.size.height;
    _rectSwitchCornerRadius = kDefaultRectSwitchCornerRadius;
    _sliderHeightScalar = kDefaultSliderHeightScalar;
    _sliderTabRadius = self.frame.size.height / 2.0f - 1.0f;
    _sliderLeadingSpace = 0.0f;
    
    [self computeObjectDimensions];
    [self computeTabLocation];
}

- (void)computeObjectDimensions {
    
    _sliderTopEdge = (self.frame.size.height * (1.0f - _sliderHeightScalar)) / 2.0f;
    _sliderBottomEdge = self.frame.size.height - _sliderTopEdge;
    
    _sliderPadSpace = fmaxf(_sliderTabRadius - _sliderCornerRadius, _sliderCornerRadius) + 1.0f;
    
    _sliderHeight = self.frame.size.height * _sliderHeightScalar;
    _sliderCornerRadius = _sliderHeight / 2.0f;
    
    _sliderLeftEdge = _switchWidth + _sliderPadSpace + _sliderLeadingSpace;
    _sliderRightEdge = self.frame.size.width - _sliderPadSpace;
    _sliderWidth = _sliderRightEdge - _sliderLeftEdge;
    
    _sliderLeftTouchLim = _sliderLeftEdge + _sliderCornerRadius;
    _sliderRightTouchLim = _sliderRightEdge - _sliderCornerRadius;
}

#pragma mark - Interface Methods
- (void)setSliderLeadingSpace:(CGFloat)space {
    _sliderLeadingSpace = space;
    [self computeObjectDimensions];
}

- (void)setSwitchWidth:(CGFloat)width {
    _switchWidth = width;
    [self computeObjectDimensions];
}

- (void)setSliderHeightScalar:(CGFloat)scale {
    _sliderHeightScalar = scale;
    [self computeObjectDimensions];
}

- (void)setSliderTabRadius:(CGFloat)radius {
    _sliderTabRadius = radius;
    [self computeObjectDimensions];
}

- (void)setSwitchOnColor:(UIColor *)color {

    _switchOnColor = color;
    
    CGFloat red = 0.0f, green = 0.0f, blue = 0.0f, alpha = 0.0f;
    [_switchOnColor getRed:&red green:&green blue:&blue alpha:&alpha];
    _switchOnEdgeColor = [UIColor colorWithRed:_edgeRGBScalar * red
                                         green:_edgeRGBScalar * green
                                          blue:_edgeRGBScalar * blue
                                         alpha:alpha];
}

- (void)setSwitchOffColor:(UIColor *)color {
    
    _switchOffColor = color;
    
    CGFloat red = 0.0f, green = 0.0f, blue = 0.0f, alpha = 0.0f;
    [_switchOffColor getRed:&red green:&green blue:&blue alpha:&alpha];
    _switchOffEdgeColor = [UIColor colorWithRed:_edgeRGBScalar * red
                                          green:_edgeRGBScalar * green
                                           blue:_edgeRGBScalar * blue
                                          alpha:alpha];
}

- (void)setSliderFillColor:(UIColor *)color {
    
    _sliderFillColor = color;
    
    CGFloat red = 0.0f, green = 0.0f, blue = 0.0f;
    [_sliderFillColor getRed:&red green:&green blue:&blue alpha:&_sliderFillEnabledAlpha];
    _sliderFillEdgeColor = [UIColor colorWithRed:_edgeRGBScalar * red
                                           green:_edgeRGBScalar * green
                                            blue:_edgeRGBScalar * blue
                                           alpha:_sliderFillEnabledAlpha];
    _sliderFillDisabledAlpha = _sliderDisabledAlphaScale * _sliderFillEnabledAlpha;
}

- (void)setSliderBackgroundColor:(UIColor *)color {
    
    _sliderBackgroundColor = color;
    
    CGFloat red = 0.0f, green = 0.0f, blue = 0.0f;
    [_sliderBackgroundColor getRed:&red green:&green blue:&blue alpha:&_sliderBackgroundEnabledAlpha];
    _sliderBackgroundEdgeColor = [UIColor colorWithRed:_edgeRGBScalar * red
                                                 green:_edgeRGBScalar * green
                                                  blue:_edgeRGBScalar * blue
                                                 alpha:_sliderBackgroundEnabledAlpha];
    _sliderBackgroundDisabledAlpha = _sliderDisabledAlphaScale * _sliderBackgroundEnabledAlpha;
}

- (void)setSliderTabColor:(UIColor *)color {
    
    _sliderTabColor = color;
    
    CGFloat red = 0.0f, green = 0.0f, blue = 0.0f;
    [_sliderTabColor getRed:&red green:&green blue:&blue alpha:&_sliderTabEnabledAlpha];
    _sliderTabEdgeColor = [UIColor colorWithRed:_edgeRGBScalar * red
                                          green:_edgeRGBScalar * green
                                           blue:_edgeRGBScalar * blue
                                          alpha:_sliderTabEnabledAlpha];
    _sliderTabDisabledAlpha = _sliderDisabledAlphaScale * _sliderTabEnabledAlpha;
}

#pragma mark - Slider Value/Tab Location Helpers
- (void)computeSliderFillRatioFromTouchLocation:(CGPoint)loc {
    
    if (_sliderDisabled)
        return;
    
    if (loc.x < _sliderLeftTouchLim && loc.x > _switchWidth) {
        _sliderFillRatio = 0.0f;
    }
    else if (loc.x  > _sliderRightTouchLim) {
        _sliderFillRatio = 1.0f;
    }
    else {
        /* Compute the portion of the slider that's filled */
        _sliderFillRatio = (loc.x - (_sliderLeftTouchLim)) /
                           (_sliderRightTouchLim - _sliderLeftTouchLim);
    }
}

- (void)scaleSliderValue {
    _sliderValue = _minValue + _sliderFillRatio * (_maxValue - _minValue);
    _sliderValue = _sliderValue < _minValue ? _minValue : _sliderValue;
    _sliderValue = _sliderValue > _maxValue ? _maxValue : _sliderValue;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)computeTabLocation {
    _tabPosition = _sliderLeftEdge + _sliderFillRatio * (_sliderRightEdge - _sliderLeftEdge);
    [self setNeedsDisplay];
}

#pragma mark - Touch Handlers
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    
    [super beginTrackingWithTouch:touch withEvent:event];
    CGPoint loc = [touch locationInView:self];
    
    if (loc.x < _switchWidth) {
        _previousSwitchState = _switchState;
        _switchState = METSwitchStateDown;
        [self setNeedsDisplay];
    }
    else {
        [self computeSliderFillRatioFromTouchLocation:loc];
        [self scaleSliderValue];
        [self computeTabLocation];
    }
    
    return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    
    [super beginTrackingWithTouch:touch withEvent:event];
    CGPoint loc = [touch locationInView:self];
    
    if (_switchState == METSwitchStateDown)
        return YES;
    
    [self computeSliderFillRatioFromTouchLocation:loc];
    [self scaleSliderValue];
    [self computeTabLocation];
    
    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    
    [super endTrackingWithTouch:touch withEvent:event];
    CGPoint loc = [touch locationInView:self];
    
    if (loc.x < _switchWidth && _switchState == METSwitchStateDown) {
        
        _switchState = _previousSwitchState == METSwitchStateOff ? METSwitchStateOn : METSwitchStateOff;
        [self sendActionsForControlEvents:UIControlEventValueChanged];
        [self setNeedsDisplay];
        
        if (_switchBehavior == METSwitchBehaviorSetSliderMin) {
            if (_switchState == METSwitchStateOn) {
                _sliderFillRatio = _previousSliderFillRatio;
                _sliderDisabled = false;
            }
            else {
                _previousSliderFillRatio = _sliderFillRatio;
                _sliderFillRatio = 0.0f;
                _sliderDisabled = true;
            }
            
            [self scaleSliderValue];
            [self computeTabLocation];
        }
        else if (_switchBehavior == METSwitchBehaviorDisableSlider) {
            if (_switchState == METSwitchStateOn)
                _sliderDisabled = false;
            else if (_switchState == METSwitchStateOff)
                _sliderDisabled = true;
        }
    }
    
    else {
        [self computeSliderFillRatioFromTouchLocation:loc];
        [self scaleSliderValue];
        [self computeTabLocation];
    }
}

#pragma mark - Drawing
- (void)drawRect:(CGRect)rect {
    
    CGFloat tabDrawLoc = _tabPosition;
    if (tabDrawLoc < _sliderLeftEdge + _sliderCornerRadius)
        tabDrawLoc = _sliderLeftEdge + _sliderCornerRadius;
    if (tabDrawLoc > _sliderRightEdge - _sliderCornerRadius)
        tabDrawLoc = _sliderRightEdge - _sliderCornerRadius;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGMutablePathRef path = CGPathCreateMutable();
    
    /* -------------------------- */
    /* === Draw slider filled === */
    /* -------------------------- */
    
    CGPathMoveToPoint(path, nil, _sliderLeftEdge + _sliderCornerRadius, _sliderTopEdge);
    CGPathAddLineToPoint(path, nil, tabDrawLoc, _sliderTopEdge);
    CGPathAddLineToPoint(path, nil, tabDrawLoc, _sliderBottomEdge);
    CGPathAddLineToPoint(path, nil, _sliderLeftEdge + _sliderCornerRadius, _sliderBottomEdge);
    CGPathAddArcToPoint(path, nil, _sliderLeftEdge, _sliderBottomEdge,
                        _sliderLeftEdge, self.frame.size.height / 2.0f,
                        _sliderCornerRadius);
    CGPathAddArcToPoint(path, nil, _sliderLeftEdge, _sliderTopEdge,
                        _sliderLeftEdge + _sliderCornerRadius, _sliderTopEdge,
                        _sliderCornerRadius);
    CGPathCloseSubpath(path);
    CGContextAddPath(context, path);
    
    CGContextSetStrokeColorWithColor(context, [_sliderFillEdgeColor colorWithAlphaComponent:_sliderDisabled ? _sliderFillDisabledAlpha : _sliderFillEnabledAlpha].CGColor);
    CGContextSetFillColorWithColor(context, [_sliderFillColor colorWithAlphaComponent:_sliderDisabled ? _sliderFillDisabledAlpha : _sliderFillEnabledAlpha].CGColor);
    CGContextDrawPath(context, kCGPathEOFillStroke);
    
    /* ------------------------------ */
    /* === Draw slider background === */
    /* ------------------------------ */
    
    CGMutablePathRef back = CGPathCreateMutable();
    CGPathMoveToPoint(back, nil, tabDrawLoc, _sliderTopEdge);
    CGPathAddArcToPoint(back, nil, _sliderRightEdge, _sliderTopEdge,
                        _sliderRightEdge, self.frame.size.height / 2.0f,
                        _sliderCornerRadius);
    CGPathAddArcToPoint(back, nil, _sliderRightEdge, _sliderBottomEdge,
                        _sliderRightEdge - _sliderCornerRadius, _sliderBottomEdge,
                        _sliderCornerRadius);
    CGPathAddLineToPoint(back, nil, tabDrawLoc, _sliderBottomEdge);
    CGPathCloseSubpath(back);
    CGContextAddPath(context, back);
    
    CGContextSetStrokeColorWithColor(context, [_sliderBackgroundEdgeColor colorWithAlphaComponent:_sliderDisabled ? _sliderBackgroundDisabledAlpha : _sliderBackgroundEnabledAlpha].CGColor);
    CGContextSetFillColorWithColor(context, [_sliderBackgroundColor colorWithAlphaComponent:_sliderDisabled ? _sliderBackgroundDisabledAlpha : _sliderBackgroundEnabledAlpha].CGColor);
    CGContextDrawPath(context, kCGPathEOFillStroke);
    
    /* ----------------------- */
    /* === Draw slider tab === */
    /* ----------------------- */
    
    CGMutablePathRef tab = CGPathCreateMutable();
    CGPathAddArc(tab, nil, tabDrawLoc, self.frame.size.height / 2.0f,
                 _sliderTabRadius, 0.0f, 2.0f*M_PI, true);
    CGPathCloseSubpath(tab);
    CGContextAddPath(context, tab);
    
    /* First, erase what's inside the circle so we can change the alpha without showing the background */
    CGContextSetBlendMode(context, kCGBlendModeClear);
    CGContextFillPath(context);
    
    /* Draw the slider tab */
    CGContextAddPath(context, tab);
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGContextSetStrokeColorWithColor(context, [_sliderTabEdgeColor colorWithAlphaComponent:_sliderDisabled ? _sliderTabDisabledAlpha : _sliderTabEnabledAlpha].CGColor);
    CGContextSetFillColorWithColor(context, [_sliderTabColor colorWithAlphaComponent:_sliderDisabled ? _sliderTabDisabledAlpha : _sliderTabEnabledAlpha].CGColor);
    CGContextDrawPath(context, kCGPathEOFillStroke);
    
    /* ------------------- */
    /* === Draw switch === */
    /* ------------------- */
    
    CGMutablePathRef switchPath = CGPathCreateMutable();
    
    switch (_switchType) {
        case METSwitchTypeRect:
            [self drawSwitchRect:switchPath];
            break;
        case METSwitchTypeCircle:
            [self drawSwitchCircle:switchPath];
            break;
        case METSwitchTypeSocket:
            [self drawSwitchSocket:switchPath];
            break;
        case METSwitchTypeNone:
        default:
            break;
    }
    
    CGContextAddPath(context, switchPath);
    
    UIColor *_switchBodyColor = _switchState == METSwitchStateOn ? _switchOnColor : _switchOffColor;
    UIColor *_switchEdgeColor = _switchState == METSwitchStateOn ? _switchOnEdgeColor : _switchOffEdgeColor;
    _switchBodyColor = _switchState == METSwitchStateDown ? _switchEdgeColor : _switchBodyColor;
    _switchEdgeColor = _switchState == METSwitchStateDown ? _switchBodyColor : _switchEdgeColor;
    
    CGContextSetStrokeColorWithColor(context, _switchEdgeColor.CGColor);
    CGContextSetFillColorWithColor(context, _switchBodyColor.CGColor);
    CGContextDrawPath(context, kCGPathEOFillStroke);
}

- (void)drawSwitchRect:(CGMutablePathRef)path {
    
    CGPathMoveToPoint(path, nil, _rectSwitchCornerRadius, 0.0f);
    CGPathAddArcToPoint(path, nil, _switchWidth, 0.0f, _switchWidth, self.frame.size.height, _rectSwitchCornerRadius);
    CGPathAddArcToPoint(path, nil, _switchWidth, self.frame.size.height, 0.0f, self.frame.size.height, _rectSwitchCornerRadius);
    CGPathAddArcToPoint(path, nil, 0.0f, self.frame.size.height, 0.0f, 0.0f, _rectSwitchCornerRadius);
    CGPathAddArcToPoint(path, nil, 0.0f, 0.0f, _rectSwitchCornerRadius, 0.0f, _rectSwitchCornerRadius);
    CGPathCloseSubpath(path);
}

- (void)drawSwitchCircle:(CGMutablePathRef)path  {
    
    CGPathAddArc(path, nil, _switchWidth / 2.0f, self.frame.size.height / 2.0f,
                 _switchWidth / 2.0f - 1.0f, 0.0f, 2.0f*M_PI, true);
    CGPathCloseSubpath(path);
}

- (void)drawSwitchSocket:(CGMutablePathRef)path  {
    
    CGPathMoveToPoint(path, nil, 1.0f, self.frame.size.height / 2.0f);
    CGPathAddArcToPoint(path, nil, 1.0f, 0.0f, _switchWidth, 0.0f, _sliderTabRadius);
    CGPathAddLineToPoint(path, nil, _sliderLeftTouchLim, 0.0f);
    CGPathAddArcToPoint(path, nil, _sliderLeftTouchLim - _sliderTabRadius, 0.0f,
                        _sliderLeftTouchLim - _sliderTabRadius, self.frame.size.height / 2.0f, _sliderTabRadius);
    CGPathAddArcToPoint(path, nil, _sliderLeftTouchLim - _sliderTabRadius, self.frame.size.height, _sliderLeftTouchLim, self.frame.size.height, _sliderTabRadius);
    CGPathAddLineToPoint(path, nil, _sliderTabRadius, self.frame.size.height);
    CGPathAddArcToPoint(path, nil, 1.0f, self.frame.size.height, 1.0f, self.frame.size.height / 2.0f, _sliderTabRadius);
    CGPathCloseSubpath(path);
}


@end

















