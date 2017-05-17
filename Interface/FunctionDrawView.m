//
//  FunctionDrawView.m
//  SoundSynth
//
//  Created by Jeff Gregorio on 7/13/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import "FunctionDrawView.h"

@implementation FunctionDrawView

@synthesize delegate;
@synthesize length = _length;
@synthesize mirrorAcrossXAxis = _mirrorAcrossXAxis;
@synthesize resetOnTouchDown = _resetOnTouchDown;
@synthesize hasDrawnFunction = _hasDrawnFunction;

- (id)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
        
        _mirrorAcrossXAxis = false;
        _resetOnTouchDown = true;
        _hasDrawnFunction = false;
        
        [self allocateFunctionWithLength:self.frame.size.width];
        [self setBackgroundColor:[UIColor clearColor]];
    }
    return self;
}

- (void)allocateFunctionWithLength:(int)length {
    
    if (_pixelVals)
        free(_pixelVals);
    
    _length = length;
    _pixelVals = (CGFloat *)malloc(_length * sizeof(CGFloat));
    
    /* Populate the x coordinates of the array with a linear space on [0, view width] */
    [self linspace:0 max:self.frame.size.width numElements:length array:_pixelVals];
    
    /* Initialize y coordinates to half the view height */
    for (int i = 0; i < _length; i++) {
        _pixelVals[i] = self.frame.size.height / 2;
    }
    
    [self setNeedsDisplay];
}

- (void)getDrawingWithLength:(int)length pixelVals:(CGFloat *)outPixels {
 
    if (length == _length) {
        memcpy(outPixels, _pixelVals, _length * sizeof(CGFloat));
        return;
    }
    
    CGFloat *xQueries = (CGFloat *)malloc(length * sizeof(CGFloat));
    [self linspace:0 max:_length-1 numElements:length array:xQueries];
    
    /* Downsample the drawn waveform if we're requesting fewer samples than we have */
    if (length < _length) {
        for (int i = 0; i < length; i++)
            outPixels[i] = _pixelVals[(int)xQueries[i]];
    }
    
    /* Interpolate otherwise */
    else {
        
        outPixels[0] = _pixelVals[0];
        
        int j = 1;
        for (int i = 1; i < _length; i++) {
            
            while (xQueries[j] < i && j < length) {
                
                outPixels[j] = [self interpolatePoint:xQueries[j]
                                                   x0:(CGFloat)i-1
                                                   y0:_pixelVals[i-1]
                                                   x1:(CGFloat)i
                                                   y1:_pixelVals[i]];
                j++;
            }
            
        }
        outPixels[length-1] = _pixelVals[length-1];
    }
    
    free(xQueries);
    
    /* If we're mirroring across the x-axis, return the mirrored coordinates of anything greater than half the view height (i.e. return the cooresponding top-half coordinates of anything drawn in the bottom half) */
    if (_mirrorAcrossXAxis) {
        for (int i = 0; i < length; i++) {
            if (outPixels[i] > self.frame.size.height/2.0f) {
                outPixels[i] = [self yMirror:outPixels[i]];
            }
        }
    }
}

- (void)setDrawingWithLength:(int)length pixelVals:(CGFloat *)inPixels {
    
    if (length == _length) {
        memcpy(_pixelVals, inPixels, _length * sizeof(CGFloat));
        return;
    }
    
    CGFloat *xQueries = (CGFloat *)malloc(length * sizeof(CGFloat));
    [self linspace:0 max:length-1 numElements:length array:xQueries];
    
    /* Downsample the input waveform if its length is longer than the internal waveform */
    if (length > _length) {
        for (int i = 0; i < length; i++)
            _pixelVals[i] = inPixels[(int)xQueries[i]];
    }
    
    /* Interpolate otherwise */
    else {
        
        _pixelVals[0] = inPixels[0];
        
        int j = 1;
        for (int i = 1; i < _length; i++) {
            
            while (xQueries[j] < i && j < length) {
                
                _pixelVals[j] = [self interpolatePoint:xQueries[j]
                                                   x0:(CGFloat)i-1
                                                   y0:inPixels[i-1]
                                                   x1:(CGFloat)i
                                                   y1:inPixels[i]];
                j++;
            }
            
        }
        _pixelVals[length-1] = inPixels[length-1];
    }
    
    free(xQueries);
    [self setNeedsDisplay];
}

- (void)resetDrawing {
    [self allocateFunctionWithLength:_length];
    _hasDrawnFunction = false;
}

#pragma mark - Touch Methods
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    if (_resetOnTouchDown)
        [self resetDrawing];
    
    CGPoint loc = [[touches anyObject] locationInView:self];
    _previousSetIdx = (int)loc.x;
    _previousTouchLoc = loc;
    _pixelVals[_previousSetIdx] = loc.y;
    
    if ([delegate respondsToSelector:@selector(drawingBegan)])
        [delegate drawingBegan];
    
    _hasDrawnFunction = true;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    CGPoint loc = [[touches anyObject] locationInView:self];
    if (CGPointEqualToPoint(loc, _previousTouchLoc))
        return;
    
    int setIdx;         // Index in _pixelVals to set
    CGFloat setVal;
    
    if (loc.x < 0.0f)
        setIdx = 0;
    else if (loc.x > self.frame.size.width)
        setIdx = _length - 1;
    else
        setIdx = (int)loc.x;
    
    if (loc.y < 0.0f)
        setVal = 0.0;
    else if (loc.y > self.frame.size.height)
        setVal = self.frame.size.height;
    else
        setVal = loc.y;
    
    _pixelVals[setIdx] = setVal;
    
    /* Return if we didn't set any values */
    if (setIdx == _previousSetIdx)
        return;
    
    int startIdx = (setIdx > _previousSetIdx) ? _previousSetIdx : setIdx;
    int endIdx   = (setIdx < _previousSetIdx) ? _previousSetIdx : setIdx;
    
    /* Interpolate any points between the current and previous points set */
    [self interpolateInRange:startIdx
                         end:endIdx];
    
    _previousSetIdx = setIdx;
    _previousTouchLoc = loc;
    
    if ([delegate respondsToSelector:@selector(drawingChanged)])
        [delegate drawingChanged];
    
    [self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    
    if ([delegate respondsToSelector:@selector(drawingEnded)])
        [delegate drawingEnded];
}

- (void)interpolateInRange:(int)startIdx end:(int)endIdx {

    /* Linearly interpolate pixel y values between given indices */
    float step = (_pixelVals[endIdx] - _pixelVals[startIdx]) / (endIdx-startIdx);
    
    for (int i = startIdx+1; i < endIdx; i++) {
        _pixelVals[i] = _pixelVals[i-1] + step;
    }
}

#pragma mark - Render Methods
- (void)drawRect:(CGRect)rect {

    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, 5.0);
    
    CGPoint previous = CGPointMake(0.0, _pixelVals[0]);
    
    for (int i = 1; i < _length; i++) {
        
        CGContextMoveToPoint(context, previous.x, previous.y);
        CGContextAddLineToPoint(context, (CGFloat)i, _pixelVals[i]);
        CGContextStrokePath(context);
        
        previous.x = (CGFloat)i;
        previous.y = _pixelVals[i];
    }
    
    if (_mirrorAcrossXAxis) {
        
        previous = CGPointMake(0.0, [self yMirror:_pixelVals[0]]);
        for (int i = 1; i < _length; i++) {
            
            CGContextMoveToPoint(context, previous.x, previous.y);
            CGContextAddLineToPoint(context, (CGFloat)i, [self yMirror:_pixelVals[i]]);
            CGContextStrokePath(context);
            
            previous.x = (CGFloat)i;
            previous.y = _pixelVals[i];
        }
    }
}

#pragma mark - Utility

- (CGFloat)yMirror:(CGFloat)y {
    return y + 2.0f * ((self.frame.size.height / 2) - y);
}

- (CGFloat)interpolatePoint:(CGFloat)x x0:(CGFloat)x0 y0:(CGFloat)y0 x1:(CGFloat)x1 y1:(CGFloat)y1 {
    return y0 + ((x-x0)*(y1-y0)) / (x1-x0);
}

/* Generate a linearly-spaced set of indices for sampling an incoming waveform */
- (void)linspace:(CGFloat)minVal max:(CGFloat)maxVal numElements:(int)size array:(CGFloat *)array {
    
    CGFloat step = (maxVal - minVal) / (size - 1);
    array[0] = minVal;
    for (int i = 1; i < size-1; i++)
        array[i] = array[i-1] + step;
    
    array[size-1] = maxVal;
}

@end












