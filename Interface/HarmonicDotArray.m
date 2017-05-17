//
//  HarmonicDotArray.m
//  AudioWorks
//
//  Created by Jeff Gregorio on 7/7/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import "HarmonicDotArray.h"

#pragma mark - HarmonicDotArray
@implementation HarmonicDotArray

@synthesize parentScope;
@synthesize delegate;
@synthesize gainScalar;
@synthesize dotColor;
@synthesize edgeColor;
@synthesize lineColor;

- (id)initWithParentScope:(METScopeView *)parent {
    
    CGRect frame = parent.frame;
    frame.origin = CGPointMake(0.0f, 0.0f);
    self = [super initWithFrame:frame];
    if (self) {
        parentScope = parent;
        f0 = 440.0f;
        editable = false;
        activeDotIndex = -1;
        gainScalar = 1.0f;
        [self setBackgroundColor:[UIColor clearColor]];
        
        dotColor = [UIColor colorWithRed:0.95f green:0.95f blue:0.95f alpha:1.0];
        
        CGFloat edgeScalar = 0.5;
        CGFloat red = 0.0f, green = 0.0f, blue = 0.0f, alpha = 0.0f;
        [dotColor getRed:&red green:&green blue:&blue alpha:&alpha];
        edgeColor = [UIColor colorWithRed:edgeScalar * red
                                    green:edgeScalar * green
                                     blue:edgeScalar * blue
                                    alpha:alpha];
        

        lineColor = [UIColor colorWithRed:kAudioWorksBlue_R
                                    green:kAudioWorksBlue_G
                                     blue:kAudioWorksBlue_B
                                    alpha:1.0f];
        lineWidth = 1.2;
        lineAlpha = 0.8;
        
        gridDashLengths[0] = gridDashLengths[1] = self.frame.size.height / 30.0;
        
        harmonicDots = [[NSMutableArray alloc] init];
        noiseHandle = [[NoiseHandle alloc] initWithParent:self amplitude:0.0f];
        [self addSubview:noiseHandle];
    }
    return self;
}

- (void)setEditable:(bool)isEditable {
    editable = isEditable;
    for (int i = 0; i < [harmonicDots count]; i++)
        [[harmonicDots objectAtIndex:i] setEditable:editable];
}

- (void)setFundamentalFreq:(CGFloat)fundamental {
    f0 = fundamental;
    for (int i = 0; i < [harmonicDots count]; i++)
        [(HarmonicDot *)[harmonicDots objectAtIndex:i] setFrequency:f0 * (i+1)];
    
    [self setNeedsDisplay];
}

- (void)addHarmonicWithAmplitude_dB:(CGFloat)amp {
    [self addHarmonicWithAmplitude:powf(10.0f, amp / 20.0f)];
    [self setNeedsDisplay];
}

- (void)addHarmonicWithAmplitude:(CGFloat)amp {
    
    int harmonicNum = (int)[harmonicDots count] + 1;
    HarmonicDot *dot = [[HarmonicDot alloc] initWithParent:self loc:CGPointMake(f0 * harmonicNum, amp)];
    [harmonicDots addObject:dot];
    [self addSubview:dot];
    [self setNeedsDisplay];
}

/* Set a harmonic amplitude in decibels */
- (void)setAmplitude_dB:(CGFloat)amp forHarmonic:(int)n {
    [(HarmonicDot *)[harmonicDots objectAtIndex:n-1] setAmplitude:amp];
    [self setNeedsDisplay];
}

- (void)setAmplitude:(CGFloat)amp forHarmonic:(int)n {
    [self setAmplitude_dB:20.0f * log10f(amp + 0.0001f) forHarmonic:n];
    [self setNeedsDisplay];
}

- (void)setNoiseAmplitude_db:(CGFloat)amp {
    [noiseHandle setAmplitude:amp];
}

- (void)setNoiseAmplitude:(CGFloat)amp {
    [noiseHandle setAmplitude:20.0f * log10f(amp + 0.0001f)];
}

- (CGFloat)getAmplitudeForHarmonicNum:(int)n {
    
    if (n < 1 || n > [harmonicDots count]) {
        NSLog(@"%s: Invalid harmonic number %d", __PRETTY_FUNCTION__, n);
        return false;
    }
    
    return [[harmonicDots objectAtIndex:n-1] amplitude];
}

- (void)getAmplitudes:(CGFloat *)amps forNumHarmonics:(int)num {
    
    if (num < 1 || num > [harmonicDots count]) {
        NSLog(@"%s: Invalid number of harmonics %d", __PRETTY_FUNCTION__, num);
        return;
    }
    
    for (int i = 0; i < num; i++) {
        amps[i] = [[harmonicDots objectAtIndex:i] amplitude];
    }
}

- (void)plotBoundsChanged {
    HarmonicDot *dot;
    for (int i = 0; i < [harmonicDots count]; i++) {
        dot = [harmonicDots objectAtIndex:i];
        [dot setFrequency:dot.frequency];
    }
    [self setNeedsDisplay];
}

- (void)setGainScalar:(CGFloat)gain {
    gainScalar = gain;
    HarmonicDot *dot;
    for (int i = 0; i < [harmonicDots count]; i++) {
        dot = [harmonicDots objectAtIndex:i];
        [dot setAmplitude:dot.amplitude];
    }
    [noiseHandle setAmplitude:noiseHandle.amplitude];
    [self setNeedsDisplay];
}

- (CGRect)getActiveDotFrame {
    
    CGRect frame = CGRectMake(0.0f, 0.0f, 0.0f, 0.0f);
    if (activeDotIndex != -1 && activeDotIndex != [harmonicDots count]) {
        frame = [[harmonicDots objectAtIndex:activeDotIndex] frame];
    }
    return frame;
}

- (int)numHarmonics {
    return (int)[harmonicDots count];
}

#pragma mark - Drawing
- (void)drawRect:(CGRect)rect {
    
    CGPoint loc;
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetStrokeColorWithColor(context, lineColor.CGColor);
    CGContextSetAlpha(context, lineAlpha);
    CGContextSetLineWidth(context, lineWidth);
//    CGContextSetLineDash(context, M_PI, gridDashLengths, 2);
    
    for (int i = 0; i < [harmonicDots count]; i++) {
    
        HarmonicDot *dot = [harmonicDots objectAtIndex:i];
        loc = dot.frame.origin;
        loc.x += dot.frame.size.width / 2.0;
        loc.y += dot.frame.size.height / 2.0;
        
        CGContextMoveToPoint(context, loc.x, loc.y);
        CGContextAddLineToPoint(context, loc.x, self.frame.size.height);
        CGContextStrokePath(context);
    }
    
    loc = noiseHandle.frame.origin;
    loc.x += noiseHandle.frame.size.width / 2.0;
    loc.y += noiseHandle.frame.size.height / 2.0;
    CGContextMoveToPoint(context, loc.x, loc.y);
    CGContextAddLineToPoint(context, 0.0, loc.y);
    CGContextStrokePath(context);
}


#pragma mark - Touch Handling
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    previousTouchLocation = [[touches anyObject] locationInView:self];
    
    if (editable) {
        
        HarmonicDot *control;
        CGRect testFrame;
        
        /* See if we're within the bounds of any harmonic dots */
        for (int i = 0; i < [harmonicDots count]; i++) {
            
            control = [harmonicDots objectAtIndex:i];
            testFrame = control.frame;
            testFrame.size.width += kControlDotExtension;
            testFrame.size.height += kControlDotExtension;
            testFrame.origin.x -= kControlDotExtension/2.0;
            testFrame.origin.y -= kControlDotExtension/2.0;
            
            if (CGRectContainsPoint(testFrame, previousTouchLocation)) {
                activeDotIndex = i;
                [parentScope setPinchZoomEnabled:false];
                [parentScope setPanEnabled:false];
                if (delegate) [delegate touchDownOnHarmonic:i+1];
            }
        }
    }

    /* See if we're within the bounds of the noise handle */
    if (CGRectContainsPoint([noiseHandle frame], previousTouchLocation)) {
        NSLog(@"Noise Handle");
        activeDotIndex = (int)[harmonicDots count];
        [parentScope setPinchZoomEnabled:false];
        [parentScope setPanEnabled:false];
        if (delegate) [delegate touchDownOnNoiseSlider];
    }
    [self setNeedsDisplay];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    if (activeDotIndex == -1)
        return;
    
    CGPoint touchLoc = [[touches anyObject] locationInView:parentScope];
    CGPoint touchLocPlotScale = [parentScope pixelToPlotScale:touchLoc];
    
    /* Reposition any active harmonic dots and notify the delegate */
    if (activeDotIndex < [harmonicDots count]) {
        
        HarmonicDot *activeDot = [harmonicDots objectAtIndex:activeDotIndex];
        
        /* Set the amplitude only if it will be under 0 dB after scaling by the pre gain */
        CGFloat unscaledAmplitude = powf(10.0f, touchLocPlotScale.y / 20.0f) / gainScalar;
        
        if (unscaledAmplitude <= 1.0f) {
            [activeDot setAmplitude:20.0f * log10f(unscaledAmplitude + 0.00001f)];
            if (delegate) [delegate valueChangedForHarmonic:activeDotIndex+1 linearAmp:unscaledAmplitude];
        }
    }
    
    /* Reposition the noise handle if active and notify the delegate */
    else if (activeDotIndex == [harmonicDots count]) {
        
        /* Set the amplitude only if it will be under 0 dB after scaling by the pre gain */
        CGFloat unscaledAmplitude = powf(10.0f, touchLocPlotScale.y / 20.0f) / gainScalar;
        
        if (unscaledAmplitude <= 1.0f) {
            [noiseHandle setAmplitude:20.0f * log10f(unscaledAmplitude + 0.00001f)];
            if (delegate) [delegate noiseAmplitudeChanged:unscaledAmplitude];
        }
    }

    previousTouchLocation = touchLoc;
    [self setNeedsDisplay];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    
    [parentScope setPinchZoomEnabled:true];
    [parentScope setPanEnabled:true];
    
    if (delegate) [delegate harmonicDotArrayTouchEnded];
    [self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    
    activeDotIndex = -1;
    
    [parentScope setPinchZoomEnabled:true];
    [parentScope setPanEnabled:true];
    
    if (delegate) [delegate harmonicDotArrayTouchEnded];
    [self setNeedsDisplay];
}


@end


#pragma mark - HarmonicDot

CGFloat const kHarmonicDotRadiusEditable = 15.0f;
CGFloat const kHarmonicDotRadiusDisabled = 10.0f;
CGFloat const kHarmonicDotAlphaEditable = 1.0f;
CGFloat const kHarmonicDotAlphaDisabled = 0.8f;

@implementation HarmonicDot
@synthesize frequency, amplitude;

- (id)initWithParent:(HarmonicDotArray *)parent loc:(CGPoint)loc {
    
    CGRect frame = CGRectMake(0.0f, 0.0f,
                              2.0f * kHarmonicDotRadiusDisabled,
                              2.0f * kHarmonicDotRadiusDisabled);
    frame.origin.x -= frame.size.width  / 2.0f;       // Center
    frame.origin.y -= frame.size.height / 2.0f;
    
    self = [super initWithFrame:frame];
    if (self) {
        
        parentArray = parent;
        editable = false;
        frequency = loc.x;
        amplitude = 20.0f * log10f(loc.y + 0.0001f);
        
        [self setFrequency:frequency];
        [self setAmplitude:amplitude];
        
        [[self layer] setCornerRadius:self.frame.size.width / 2.0f];
        [[self layer] setBackgroundColor:[parent dotColor].CGColor];
        [[self layer] setBorderColor:[parent edgeColor].CGColor];
        [[self layer] setBorderWidth:1.0f];
        
        [self setAlpha:kHarmonicDotAlphaDisabled];
    }
    
    /* HarmonicDotArray handles all touch events */
    [self setUserInteractionEnabled:false];
    
    return self;
}

- (void)setEditable:(bool)isEditable {
    
    if (editable == isEditable)
        return;
    
    editable = isEditable;
    
    CGRect frame = [self frame];
    CGFloat delta = kHarmonicDotRadiusEditable - kHarmonicDotRadiusDisabled;
    if (editable) {
        frame.origin.x -= delta;
        frame.origin.y -= delta;
        frame.size.height = frame.size.width = 2.0f * kHarmonicDotRadiusEditable;
        [self setAlpha:kHarmonicDotAlphaEditable];
    }
    else {
        frame.origin.x += delta;
        frame.origin.y += delta;
        frame.size.height = frame.size.width = 2.0f * kHarmonicDotRadiusDisabled;
        [self setAlpha:kHarmonicDotAlphaDisabled];
    }
    [self setFrame:frame];
    [[self layer] setCornerRadius:self.frame.size.width/2.0f];
}

/* Set the frequency (x location) of the dot */
- (void)setFrequency:(CGFloat)freq {
    
    CGRect frame = self.frame;
    CGPoint loc = [[parentArray parentScope] plotScaleToPixel:CGPointMake(freq, 0.0f)];
    frame.origin.x = loc.x - frame.size.width / 2.0f;
    [self setFrame:frame];
    frequency = freq;
}

/* Set the amplitude (in dB) */
- (void)setAmplitude:(CGFloat)amp {
    
    amplitude = amp;                    // Save base amplitude in dB
    amp = powf(10.0f, amp / 20.0f);     // Linearize and scale by the preGain scalar before positioning the dot
    amp *= [parentArray gainScalar];
    
    CGRect frame = self.frame;
    CGPoint loc = [[parentArray parentScope] plotScaleToPixel:CGPointMake(0.0f, amp)];
    
    if (isnan(loc.x) || isnan(loc.y))
        return;
    
    frame.origin.y = loc.y - frame.size.height / 2.0f;
    [self setFrame:frame];
}

/* Set the linear amplitude */

/* Overridden to keep harmonic dots within plot bounds */
- (void)setFrame:(CGRect)frame {
    
//    CGPoint center;
//    center.y = frame.origin.y + frame.size.height / 2.0f;
//    center.y = center.y < 0.0f ? 0.0f : center.y;
//    center.y = center.y > [parentArray parentScope].frame.size.height ? [parentArray parentScope].frame.size.height : center.y;
//    frame.origin.y = center.y - frame.size.height / 2.0f;
    
    frame.origin.y = frame.origin.y < 0.0f ? 0.0f : frame.origin.y;
    frame.origin.y = frame.origin.y + frame.size.height > [parentArray parentScope].frame.size.height ? [parentArray parentScope].frame.size.height - frame.size.height : frame.origin.y;
    
    [super setFrame:frame];
}

@end

#pragma mark - NoiseHandle

@implementation NoiseHandle
@synthesize amplitude;

- (id)initWithParent:(HarmonicDotArray *)parent amplitude:(CGFloat)amp {
    
    CGRect frame = CGRectMake(0.0f, 0.0f, 4.0f * kHarmonicDotRadiusEditable, 2.0f * kHarmonicDotRadiusEditable);
    frame.origin.x = parent.frame.size.width - frame.size.width - 0.0f;
    self = [super initWithFrame:frame];
    if (self) {
        
        parentArray = parent;
        amplitude = 20.0f * log10f(amp + 0.0001f);
        [self setAmplitude:amplitude];
        
        [[self layer] setCornerRadius:kHarmonicDotRadiusEditable / 3.0f];
        [[self layer] setBackgroundColor:[parent dotColor].CGColor];
        [[self layer] setBorderColor:[parent edgeColor].CGColor];
        [[self layer] setBorderWidth:1.0f];
        
        [self setUserInteractionEnabled:false];
    }
    
    return self;
}

/* Set noise amplitude (in dB) */
- (void)setAmplitude:(CGFloat)amp {
    
    amplitude = amp;                    // Save base amplitude in dB
    amp = powf(10.0f, amp / 20.0f);     // Linearize and scale by the preGain scalar before positioning the dot
    amp *= [parentArray gainScalar];
    
    CGPoint loc = [[parentArray parentScope] plotScaleToPixel:CGPointMake(0.0f, amp)];
    
    if (isnan(loc.x) || isnan(loc.y))
        return;
    
    CGRect frame = self.frame;
    frame.origin.y = loc.y - frame.size.height;
//    frame.origin.y = loc.y - frame.size.height / 2.0f;
    [self setFrame:frame];
    
}

/* Overridden to keep harmonic dots within plot bounds */
- (void)setFrame:(CGRect)frame {

    frame.origin.y = frame.origin.y < 30.0f ? 30.0f : frame.origin.y;
    frame.origin.y = frame.origin.y + frame.size.height > [parentArray parentScope].frame.size.height ? [parentArray parentScope].frame.size.height - frame.size.height : frame.origin.y;
    
    [super setFrame:frame];
}

@end








