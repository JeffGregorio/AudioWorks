//
//  METScopeControlArray.m
//  AudioWorks
//
//  Created by Jeff Gregorio on 7/18/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import "METScopeControlArray.h"

#pragma mark - METControl Private Interface
@interface METControl() {
    
    METScopeControlArray *parentArray;
    CGPoint previousTouchLoc;

    CGSize dotSize;
    CGSize rectSize;
    CGFloat edgeScalar;
    
    CGPoint minLocation;
    CGPoint maxLocation;
}
@end

#pragma mark - METControl
@implementation METControl

@synthesize location, values, minValues, maxValues;
@synthesize lineColor, lineAlpha, lineWidth;
@synthesize drawsVerticalLineToBottom, drawsHorizontalLineToLeft;
@synthesize drawsVerticalLineToAxis, drawsHorizontalLineToAxis;
@synthesize constrainVerticallyToParentView, constrainHorizontallyToParentView;

const CGFloat kDotRadius = 15.0;

#pragma mark Private Methods
- (id)initWithParentArray:(METScopeControlArray *)parent {
    
    dotSize = CGSizeMake(2.0 * kDotRadius, 2.0 * kDotRadius);
    rectSize = CGSizeMake(4.0 * kDotRadius, 2.0 * kDotRadius);
    edgeScalar = 0.5f;
    location = CGPointMake(0.0f, 0.0f);
    
    CGRect frame = CGRectMake(location.x, location.y, dotSize.width, dotSize.height);
    self = [super initWithFrame:frame];
    if (self) {
        [[self layer] setCornerRadius:self.frame.size.width / 2.0f];
        [[self layer] setBorderWidth:1.0f];
        [self setUserInteractionEnabled:false];
        parentArray = parent;
        [self setFaceColor:[UIColor colorWithRed:0.95f green:0.95f blue:0.95f alpha:1.0f]];
        minValues = CGPointMake(-CGFLOAT_MAX, -CGFLOAT_MAX);
        maxValues = CGPointMake(CGFLOAT_MAX, CGFLOAT_MAX);
        [self setVerticalRange:minValues.y max:maxValues.y];
        [self setHorizontalRange:minValues.x max:maxValues.x];
        lineColor = [UIColor blackColor];
        lineAlpha = 0.75;
        lineWidth = 1.2;
        drawsVerticalLineToBottom = false;
        drawsHorizontalLineToLeft = false;
        drawsVerticalLineToAxis = false;
        drawsHorizontalLineToAxis = false;
        constrainVerticallyToParentView = false;
        constrainHorizontallyToParentView = false;
    }
    return self;
}

/* Set control values in METScopeView plot units */
- (void)setValues:(CGPoint)vals {
    
    /* Constrain to allowed range */
    vals.x = vals.x < minValues.x ? minValues.x : vals.x;
    vals.x = vals.x > maxValues.x ? maxValues.x : vals.x;
    vals.y = vals.y < minValues.y ? minValues.y : vals.y;
    vals.y = vals.y > maxValues.y ? maxValues.y : vals.y;
    values = vals;
    
    /* Convert to pixel values */
    location = [[parentArray parentScope] plotScaleToPixel_:values];
    
    CGRect frame = self.frame;
    frame.origin.x = location.x - frame.size.width / 2.0f;
    frame.origin.y = location.y - frame.size.height / 2.0f;
    [self setFrame:frame];
}

/* Set location of control in pixels. Note this may differ from displayed control frame location, which is constrained to the bounds of the METScopeView (i.e. touches dragged outside plot bounds can still alter the control "values" and "location", but [METControl setFrame:] constrains the control's apparent location). */
- (void)setLocation:(CGPoint)loc {

    /* Constrain to allowed range */
    loc.x = loc.x < minLocation.x ? minLocation.x : loc.x;
    loc.x = loc.x > maxLocation.x ? maxLocation.x : loc.x;
    loc.y = loc.y < minLocation.y ? minLocation.y : loc.y;
    loc.y = loc.y > maxLocation.y ? maxLocation.y : loc.y;
    location = loc;
    
    /* Convert to METScopeView plot units */
    values = [[parentArray parentScope] pixelToPlotScale:location];
    
    CGRect frame = self.frame;
    frame.origin.x = location.x - frame.size.width / 2.0f;
    frame.origin.y = location.y - frame.size.height / 2.0f;
    [self setFrame:frame];
}

/* Set the frame, constrained to display within the bounds of the METScopeView, independent of the actual "values" and "location" */
- (void)setFrame:(CGRect)frame {
    
    CGRect parentFrame = [[parentArray parentScope] frame];
    
    if (constrainVerticallyToParentView) {
        frame.origin.y = frame.origin.y < 0.0f ? 0.0f : frame.origin.y;
        frame.origin.y = frame.origin.y + frame.size.height > parentFrame.size.height ?
        parentFrame.size.height - frame.size.height : frame.origin.y;
    }
    if (constrainHorizontallyToParentView) {
        frame.origin.x = frame.origin.x < 0.0f ? 0.0f : frame.origin.x;
        frame.origin.x = frame.origin.x + frame.size.width > parentFrame.size.width ?
        parentFrame.size.width - frame.size.width : frame.origin.x;
    }
    [super setFrame:frame];
}

#pragma mark Public Methods
/* Set the allowed vertical range of the control in METScopeView plot units */
- (void)setVerticalRange:(CGFloat)minVal max:(CGFloat)maxVal {
    minValues.y = minVal;
    maxValues.y = maxVal;
    minLocation = [[parentArray parentScope] plotScaleToPixel_:minValues];   // Pixel range
    maxLocation = [[parentArray parentScope] plotScaleToPixel_:maxValues];
    CGFloat temp = minLocation.y;   // Swap due to inverted y-axis of pixel locations
    minLocation.y = maxLocation.y;
    maxLocation.y = temp;
}
/* Set the allowed horizontal range of the control in METScopeView plot units */
- (void)setHorizontalRange:(CGFloat)minVal max:(CGFloat)maxVal {
    minValues.x = minVal;
    maxValues.x = maxVal;
    minLocation = [[parentArray parentScope] plotScaleToPixel_:minValues];   // Pixel range
    maxLocation = [[parentArray parentScope] plotScaleToPixel_:maxValues];
    CGFloat temp = minLocation.y;   // Swap due to inverted y-axis of pixel locations
    minLocation.y = maxLocation.y;
    maxLocation.y = temp;
}

- (void)setStyle:(METControlStyle)style {
    
    CGRect frame = self.frame;
    CGFloat cornerRadius;
    CGFloat borderWidth;
    
    switch (style) {
        case kMETControlStyleDot:
            frame.size = dotSize;
            cornerRadius = dotSize.height / 2.0;
            borderWidth = 1.0;
            break;
            
        case kMETControlStyleRect:
            frame.size = rectSize;
            cornerRadius = rectSize.height / 6.0;
            borderWidth = 1.0;
            break;
            
        default:
            break;
    }
    
    [self setFrame:frame];
    [[self layer] setCornerRadius:cornerRadius];
    [[self layer] setBorderWidth:borderWidth];
}

- (void)setFaceColor:(UIColor *)color {
    
    /* Set face color */
    [[self layer] setBackgroundColor:color.CGColor];
    
    /* Color the borders a darker shade of the face color */
    CGFloat red = 0.0f, green = 0.0f, blue = 0.0f, alpha = 0.0f;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    [[self layer] setBorderColor:[UIColor colorWithRed:edgeScalar * red
                                                 green:edgeScalar * green
                                                  blue:edgeScalar * blue
                                                 alpha:alpha].CGColor];
    [parentArray setNeedsDisplay];
}

- (void)setHidden:(BOOL)hidden {
    [super setHidden:hidden];
    [parentArray setNeedsDisplay];
}
@end


#pragma mark - METScopeControlArray
@implementation METScopeControlArray

@synthesize parentScope;
@synthesize delegate;

- (id)initWithParentScope:(METScopeView *)parent {
    
    CGRect frame = parent.frame;
    frame.origin = CGPointMake(0.0f, 0.0f);
    self = [super initWithFrame:frame];
    if (self) {
        
        parentScope = parent;
        [self setBackgroundColor:[UIColor clearColor]];
        
        controls = [[NSMutableArray alloc] init];
        activeControlIndex = -1;
        plotOriginLocation = [parentScope plotScaleToPixel:CGPointMake(0.0, 0.0)];
    }
    return self;
}

- (void)setControlColor:(UIColor *)color {
    for (int i = 0; i < [controls count]; i++)
        [[controls objectAtIndex:i] setColor:color];
}

- (int)addControlWithValues:(CGPoint)vals {
    return [self addControlWithStyle:kMETControlStyleDot values:vals];
}

- (int)addControlWithStyle:(METControlStyle)style values:(CGPoint)vals {
    
    METControl *control = [[METControl alloc] initWithParentArray:self];
    [control setValues:vals];
    [control setStyle:style];
    [controls addObject:control];
    [self addSubview:control];
    return ((int)[controls count]-1);   // Return the index of this parameter
}

- (METControl *)getControlAtIndex:(int)idx {
    if ([controls count] == 0 || idx < 0 || idx >= [controls count]) {
        NSLog(@"%s : invalid index %d; [controls count] = %d", __PRETTY_FUNCTION__, idx, (int)[controls count]);
        return nil;
    }
    return [controls objectAtIndex:idx];
}

- (METControl *)getControlWithTag:(NSInteger)tag {
    
    METControl *retControl = nil;
    METControl *control;
    for (int i = 0; i < [controls count] && !retControl; i++) {
        control = [controls objectAtIndex:i];
        retControl = [control tag] == tag ? control : nil;
    }
    return control;
}

- (void)removeControlAtIndex:(int)idx {
    
    if ([controls count] == 0 || idx < 0 || idx >= [controls count]) {
        NSLog(@"%s : invalid index %d; [controls count] = %d", __PRETTY_FUNCTION__, idx, (int)[controls count]);
        return;
    }
    
    [[controls objectAtIndex:idx] removeFromSuperview];
    [controls removeObjectAtIndex:idx];
}

- (void)removeControlWithTag:(NSInteger)tag {
    
    int idx;
    METControl *control = [self getControlWithTag:tag];
    if (!control) {
        NSLog(@"%s : No control with tag %d", __PRETTY_FUNCTION__, (int)tag);
        return;
    }
    
    idx = (int)[controls indexOfObject:control];
    [[controls objectAtIndex:idx] removeFromSuperview];
    [controls removeObjectAtIndex:idx];
}

- (int)numControls {
    return (int)[controls count];
}

/* Should be called when METScopeView plot bounds change. Keeps controls at their proper locations in plot units */
- (void)setNeedsDisplay {
    METControl *control;
    for (int i = 0; i < [controls count]; i++) {
        control = [controls objectAtIndex:i];
        [control setValues:control.values];
        [control setVerticalRange:control.minValues.y max:control.maxValues.y];
        [control setHorizontalRange:control.minValues.x max:control.maxValues.x];
    }
    plotOriginLocation = [parentScope plotScaleToPixel:CGPointMake(0.0, 0.0)];
    [super setNeedsDisplay];
}

#pragma mark Drawing
- (void)drawRect:(CGRect)rect {
    
    METControl *control;
    
    CGPoint loc;
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    for (int i = 0; i < [controls count]; i++) {
        
        control = [controls objectAtIndex:i];
        CGContextSetStrokeColorWithColor(context, [control lineColor].CGColor);
        CGContextSetAlpha(context, [control lineAlpha]);
        CGContextSetLineWidth(context, [control lineWidth]);
        
        if ([control isHidden])
            continue;
        
        if ([control drawsVerticalLineToBottom]) {
            loc = control.frame.origin;
            loc.x += control.frame.size.width / 2.0;
            loc.y += control.frame.size.height / 2.0;
            CGContextMoveToPoint(context, loc.x, loc.y);
            CGContextAddLineToPoint(context, loc.x, self.frame.size.height);
            CGContextStrokePath(context);
        }
        if ([control drawsHorizontalLineToLeft]) {
            loc = control.frame.origin;
            loc.x += control.frame.size.width / 2.0;
            loc.y += control.frame.size.height / 2.0;
            CGContextMoveToPoint(context, loc.x, loc.y);
            CGContextAddLineToPoint(context, 0.0, loc.y);
            CGContextStrokePath(context);
        }
        if ([control drawsVerticalLineToAxis]) {
            loc = control.frame.origin;
            loc.x += control.frame.size.width / 2.0;
            loc.y += control.frame.size.height / 2.0;
            CGContextMoveToPoint(context, loc.x, loc.y);
            CGContextAddLineToPoint(context, loc.x, plotOriginLocation.y);
            CGContextStrokePath(context);
        }
        if ([control drawsHorizontalLineToAxis]) {
            loc = control.frame.origin;
            loc.x += control.frame.size.width / 2.0;
            loc.y += control.frame.size.height / 2.0;
            CGContextMoveToPoint(context, loc.x, loc.y);
            CGContextAddLineToPoint(context, plotOriginLocation.x, loc.y);
            CGContextStrokePath(context);
        }
    }
}

#pragma mark Touch Handling
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    CGPoint touch = [[touches anyObject] locationInView:parentScope];
    
    if ([self isEnabled]) {
        
        /* See if we're within the bounds of any harmonic dots */
        for (int i = 0; i < [controls count]; i++) {
            
            METControl *control = [controls objectAtIndex:i];
            if (CGRectContainsPoint(control.frame, touch)) {
                activeControlIndex = i;
                
                /* Touches should always constrain the dots to the view, regardless of user setting. Constrain all controls to the view until touch up. */
                activeControlConstrainsVertically = [control constrainVerticallyToParentView];
                activeControlConstrainsHorizontally = [control constrainHorizontallyToParentView];
                [control setConstrainHorizontallyToParentView:true];
                [control setConstrainVerticallyToParentView:true];

                if (delegate) [delegate parameterDotTouchDown:control];
                
                /* Gesture recognizers will cancel touchesMoved, so disable them until touch up */
                [parentScope setPinchZoomEnabled:false];
                [parentScope setPanEnabled:false];
            }
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    if (activeControlIndex == -1)
        return;
    
    CGPoint touch = [[touches anyObject] locationInView:parentScope];
    
    /* Reposition any active harmonic dots and notify the delegate */
    if (activeControlIndex < [controls count]) {
        METControl *control = [controls objectAtIndex:activeControlIndex];
        [control setLocation:touch];
        if (delegate) [delegate parameterDotValuesChanged:control];
    }
    [self setNeedsDisplay];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesCancelledOrEnded:(NSSet *)touches withEvent:(UIEvent *)event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesCancelledOrEnded:(NSSet *)touches withEvent:(UIEvent *)event];
}

- (void)touchesCancelledOrEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    
    if (activeControlIndex == -1)
        return;
    
    CGPoint touch = [[touches anyObject] locationInView:parentScope];
    METControl *activeControl = [controls objectAtIndex:activeControlIndex];
    [activeControl setLocation:touch];
    activeControlIndex = -1;
    
    [parentScope setPinchZoomEnabled:true];
    [parentScope setPanEnabled:true];
    
    /* Reset user constraint settings */
    [activeControl setConstrainHorizontallyToParentView:activeControlConstrainsHorizontally];
    [activeControl setConstrainVerticallyToParentView:activeControlConstrainsVertically];
    
    if (delegate)
        [delegate parameterDotTouchUp:activeControl];
    
    [self setNeedsDisplay];
}

@end
