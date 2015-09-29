//
//  METVerticalSliderArray.m
//  ButtonSliderTest
//
//  Created by Jeff Gregorio on 9/25/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import "METVerticalSliderArray.h"

@implementation METVerticalSliderArray

const int kDefaultNumSliders = 10;
const CGFloat kDefaultSliderWidth = 50.0f;

@synthesize delegate = _delegate;
@synthesize lastEditedSlider = _lastEditedSlider;

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
    
    [self setBackgroundColor:[UIColor clearColor]];
//    [[self layer] setBorderWidth:1.0f];
    
    _nSliders = kDefaultNumSliders;
    _sliderHeight = self.frame.size.height;
    _sliderWidth = kDefaultSliderWidth;
    
    _sliders = [[NSMutableArray alloc] init];
    _sliderLabels = [[NSMutableArray alloc] init];
    
    [self computeSpacing];
    [self createSliders];
//    [self setTrackWidthScalar:0.1f];
    [self setAllowsMultiSliderSwipe:YES];
}

- (void)computeSpacing {
    _sliderSpacing = (self.frame.size.width - _nSliders * _sliderWidth) / (float)(_nSliders - 1);
}

- (void)createSliders {
    
    /* Clear slider array and remove sliders from the superview */
    for (int i = 0; i < [_sliders count]; i++) {
        [[_sliders objectAtIndex:i] removeFromSuperview];
    }
    [_sliders removeAllObjects];
    
    /* (re-)create sliders */
    CGRect frame;
    METSlider *s;
    for (int i = 0; i < _nSliders; i++) {
        
        frame = CGRectMake(i * _sliderWidth - _sliderHeight / 2.0f + _sliderWidth / 2.0f
                           + i * _sliderSpacing,
                           _sliderHeight / 2.0f - _sliderWidth / 2.0f,
                           _sliderHeight,
                           _sliderWidth);
        
        s = [[METSlider alloc] initWithFrame:frame];
        [s setTag:i];
        [s addTarget:self action:@selector(updateSlider:) forControlEvents:UIControlEventValueChanged];
        s.transform = CGAffineTransformMakeRotation(3.0f * M_PI / 2.0f);
        s.userInteractionEnabled = NO;
        
        [_sliders addObject:s];
        [self addSubview:s];
    }
}

#pragma mark - Interface Methods
- (void)setNumSliders:(int)n {
    
    _nSliders = n;
    [self computeSpacing];
    [self createSliders];
}

- (void)setSliderWidth:(CGFloat)width {
    
    _sliderWidth = width;
    [self computeSpacing];
    [self createSliders];
}

- (BOOL)setTrackWidthScalar:(CGFloat)scale {
    
    BOOL rv = YES;
    METSlider *s;
    
    for (int i = 0; i < [_sliders count]; i++) {
        s = [_sliders objectAtIndex:i];
        
        if (![s setTrackHeightScalar:scale])
            rv = NO;
    }
    return rv;
}

- (BOOL)setTabRadiusScalar:(CGFloat)scale {
    
    BOOL rv = YES;
    METSlider *s;
    
    for (int i = 0; i < [_sliders count]; i++) {
        s = [_sliders objectAtIndex:i];
        
        if (![s setTabRadiusScalar:scale])
            rv = NO;
    }
    return rv;
}

- (void)setTrackFillColor:(UIColor *)color {
    
    METSlider *s;
    for (int i = 0; i < [_sliders count]; i++) {
        s = [_sliders objectAtIndex:i];
        [s setTrackFillColor:color];
    }
}

- (void)setTrackBackgroundColor:(UIColor *)color {
    
    METSlider *s;
    for (int i = 0; i < [_sliders count]; i++) {
        s = [_sliders objectAtIndex:i];
        [s setTrackBackgroundColor:color];
    }
}

- (void)setTabColor:(UIColor *)color {
    
    METSlider *s;
    for (int i = 0; i < [_sliders count]; i++) {
        s = [_sliders objectAtIndex:i];
        [s setTabColor:color];
    }
}

/* Allow a single swipe gesture across multiple sliders to set values */
- (void)setAllowsMultiSliderSwipe:(BOOL)allowed {
    
    _allowsMultiSliderSwipe = allowed;
    for (int i = 0; i < [_sliders count]; i++)
        [[_sliders objectAtIndex:i] setUserInteractionEnabled:!allowed];
}

/* Slider ranges */
- (BOOL)setRangeForAllSliders:(float)minVal max:(float)maxVal {
    
    BOOL rv = YES;
    METSlider *s;
    
    for (int i = 0; i < [_sliders count]; i++) {
        s = [_sliders objectAtIndex:i];
        
        if (![s setRange:minVal max:maxVal])
            rv = NO;
    }
    return rv;
}

- (BOOL)setRangeForSlider:(int)sliderIdx min:(float)minVal max:(float)maxVal {
    
    if (sliderIdx < 0 || sliderIdx > _nSliders) {
        NSLog(@"%s: invalid slider index %d", __PRETTY_FUNCTION__, sliderIdx);
        return NO;
    }
    
    return [[_sliders objectAtIndex:sliderIdx] setRange:minVal max:maxVal];
}

/* Slider values */
- (BOOL)setValueForAllSliders:(float)value {
    
    BOOL rv = YES;
    METSlider *s;
    
    for (int i = 0; i < [_sliders count]; i++) {
        s = [_sliders objectAtIndex:i];
        
        if (![s setValue:value])
            rv = NO;
    }
    return rv;
}

- (BOOL)setValuesForAllSlidersWithFloatArray:(float *)values {
    
    BOOL rv = YES;
    METSlider *s;
    
    for (int i = 0; i < [_sliders count]; i++) {
        s = [_sliders objectAtIndex:i];
        
        if (![s setValue:values[i]])
            rv = NO;
    }
    return rv;
}

- (BOOL)setValuesForAllSlidersWithNSArray:(NSArray *)values {
    
    BOOL rv = YES;
    METSlider *s;
    NSNumber *n;
    
    for (int i = 0; i < [values count] && i < [_sliders count]; i++) {
        s = [_sliders objectAtIndex:i];
        n = [values objectAtIndex:i];
        
        if (![s setValue:[n floatValue]])
            rv = NO;
    }
    return rv;
}

- (BOOL)setValueForSlider:(int)sliderIdx value:(float)value {
    
    if (sliderIdx < 0 || sliderIdx > _nSliders) {
        NSLog(@"%s: invalid slider index %d", __PRETTY_FUNCTION__, sliderIdx);
        return NO;
    }
    
    METSlider *s = [_sliders objectAtIndex:sliderIdx];
    return [s setValue:value];
}

#pragma mark - Touch Handlers
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    
    if (_allowsMultiSliderSwipe)
        [self handleTouchDistribution:touch withEvent:event];
    
    return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    
    if (_allowsMultiSliderSwipe)
        [self handleTouchDistribution:touch withEvent:event];
    
    return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    
    if (_allowsMultiSliderSwipe)
        [self handleTouchDistribution:touch withEvent:event];
}

- (void)handleTouchDistribution:(UITouch *)touch withEvent:(UIEvent *)event {
    
    CGPoint loc = [touch locationInView:self];
    
    for (int i = 0; i < [_sliders count]; i++) {
        
        METSlider *s = [_sliders objectAtIndex:i];
        if (CGRectContainsPoint(s.frame, loc)) {
            [s continueTrackingWithTouch:touch withEvent:event];
            _lastEditedSlider = i;
        }
    }
}

- (void)updateSlider:(METSlider *)sender {
    
    if (_delegate && [_delegate respondsToSelector:@selector(valueChangedForSlider:newValue:)])
        [_delegate valueChangedForSlider:[sender tag] newValue:[sender value]];
}

- (float)getValueForSlider:(int)sliderIdx {
    
    if (sliderIdx < 0 || sliderIdx > _nSliders) {
        NSLog(@"%s: invalid slider index %d", __PRETTY_FUNCTION__, sliderIdx);
        return false;
    }
    
    METSlider *s = [_sliders objectAtIndex:sliderIdx];
    return [s value];
}

- (void)getValuesForNumSliders:(float *)values num:(int)nSliders {
    
    if (nSliders < 0 || nSliders > _nSliders) {
        NSLog(@"%s: invalid number of sliders %d", __PRETTY_FUNCTION__, nSliders);
        return;
    }
    
    METSlider *s;
    for (int i = 0; i < nSliders; i++) {
        s = [_sliders objectAtIndex:i];
        values[i] = [s value];
    }
}

@end
