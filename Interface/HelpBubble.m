//
//  HelpBubble.m
//  DigitalSoundFX_v2
//
//  Created by Jeff Gregorio on 9/2/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import "HelpBubble.h"

@implementation HelpBubble

- (id)initWithText:(NSString *)text origin:(CGPoint)origin {
    
    /* Computer the size of the help bubble's frame based on the text */
    _text = text;
    CGSize textSize = [_text sizeWithAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:20.0f]}];
    
    return [self initWithText:text origin:origin width:textSize.width alignment:NSTextAlignmentLeft];
}

- (id)initWithText:(NSString *)text origin:(CGPoint)origin width:(CGFloat)width {
    return [self initWithText:text origin:origin width:width alignment:NSTextAlignmentLeft];
}

- (id)initWithText:(NSString *)text origin:(CGPoint)origin width:(CGFloat)width alignment:(NSTextAlignment)alignment {
    
    /* Computer the size of the help bubble's frame based on the text */
    _text = text;
    
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [UIFont systemFontOfSize:22.0f], NSFontAttributeName, nil];
    
    CGRect textFrame = [_text boundingRectWithSize:CGSizeMake(width, 1000)
                                           options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
                                        attributes:attributes context:nil];
    
    self = [super initWithFrame:CGRectMake(origin.x,
                                           origin.y,
                                           textFrame.size.width,
                                           textFrame.size.height)];
    
    if (self) {
        
        _leadingTextSpace = kHelpBubbleLeadingTextSpace;
        _lineWidth = kHelpBubbleLineWidth;
        _lineAlpha = kHelpBubbleBorderAlpha;
        _pointerLength = kHelpBubblePointerLength;
        _cornerRadius = kHelpBubbleCornerRadius;
        
        _bubbleFrame = self.frame;
        
        [self setBackgroundColor:[UIColor clearColor]];
        
        _drawBackground = true;
        _opacity = 0.75;
        _color = [[UIColor blackColor] colorWithAlphaComponent:_opacity];
        
        _label = [[HelpLabel alloc] initWithFrame:textFrame];
        [_label setEdgeInsets:UIEdgeInsetsMake(0, _leadingTextSpace,
                                              0, _leadingTextSpace)];
        [_label setTextAlignment:alignment];
        [_label setLineBreakMode:NSLineBreakByWordWrapping];
        [_label setTextColor:[UIColor whiteColor]];
        [_label setNumberOfLines:0];
        
        [_label setText:_text];
        [self addSubview:_label];
        
        _pointerLoc = kHelpBubblePointerLocationNone;
    }
    
    [self setUserInteractionEnabled:false];
    
    return self;
}

- (void)setFrameSizeForFontSize:(CGFloat)size {
    
    /* Set height scaling for specific font size */
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [UIFont systemFontOfSize:size], NSFontAttributeName, nil];
    
    CGRect textFrame = [_text boundingRectWithSize:CGSizeMake(self.frame.size.width, 1000)
                                           options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
                                        attributes:attributes context:nil];
    
    /* Shift the text frame up to compansate for the change in frame height */
    CGFloat heightDiff = textFrame.size.height - self.frame.size.height;
    CGRect labelFrame = _label.frame;
    labelFrame.size.height += heightDiff;
    [_label setFrame:labelFrame];
    
    textFrame.origin = self.frame.origin;
    [self setFrame:textFrame];
}

- (void)setColor:(UIColor *)color {
    _color = [color colorWithAlphaComponent:_opacity];
    [self setNeedsDisplay];
}

- (void)setColor:(UIColor *)color alpha:(CGFloat)alpha {
    _opacity = alpha;
    [self setColor:color];
}

- (void)setPointerLocation:(PointerLocation)loc {
    [self setPointerLocation:loc offset:CGPointMake(0.0f, 0.0f)];
}

- (void)setPointerLocation:(PointerLocation)loc offset:(CGPoint)offset {
    
    _pointerLoc = loc;
    
    CGRect frame = [self frame];
    CGRect labelFrame = [_label frame];
    
    switch (_pointerLoc) {
            
        case kHelpBubblePointerLocationBottom:
            frame.size.height += _pointerLength;
            break;
        case kHelpBubblePointerLocationTop:
            frame.size.height += _pointerLength;
            labelFrame.origin.y += _pointerLength;
            break;
        case kHelpBubblePointerLocationRight:
            frame.size.width += _pointerLength;
            break;
        case kHelpBubblePointerLocationLeft:
            frame.size.width += _pointerLength;
            frame.origin.x -= _pointerLength;
            labelFrame.origin.x += _pointerLength;
            break;
        default:
            break;
    }
    
    [_label setFrame:labelFrame];
    [self setFrame:frame];
    
    _pointerOffset = offset;
}

- (void)drawRect:(CGRect)rect {
    
    if (!_drawBackground)
        return;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, _lineWidth);
    CGContextSetStrokeColorWithColor(context, _color.CGColor);
    CGContextSetFillColorWithColor(context, _color.CGColor);
    
    CGFloat topEdge = _pointerLoc == kHelpBubblePointerLocationTop ? _pointerLength : 0.0f;
    CGFloat bottomEdge =  self.frame.size.height;
    bottomEdge -= _pointerLoc == kHelpBubblePointerLocationBottom ? _pointerLength : 0.0f;
    CGFloat leftEdge = _pointerLoc == kHelpBubblePointerLocationLeft ? _pointerLength : 0.0f;
    CGFloat rightEdge = self.frame.size.width;
    rightEdge -= _pointerLoc == kHelpBubblePointerLocationRight ? _pointerLength : 0.0f;
    
    /* Create the path and pass it to the drawing helpers to construct the borders */
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, nil, _cornerRadius + ((_pointerLoc == kHelpBubblePointerLocationLeft) ? _pointerLength : 0.0f), (_pointerLoc == kHelpBubblePointerLocationTop) ? _pointerLength : 0.0f);
    [self addTopEdgeAtY:topEdge withPointer:_pointerLoc == kHelpBubblePointerLocationTop path:path];
    [self addRightEdgeAtX:rightEdge withPointer:_pointerLoc == kHelpBubblePointerLocationRight path:path];
    [self addBottomEdgeAtY:bottomEdge withPointer:_pointerLoc == kHelpBubblePointerLocationBottom path:path];
    [self addLeftEdgeAtX:leftEdge withPointer:_pointerLoc == kHelpBubblePointerLocationLeft path:path];
    
    /* Draw */
    CGContextAddPath(context, path);
    CGContextFillPath(context);
    
    CGPathRelease(path);
}

-(void)addTopEdgeAtY:(CGFloat)y withPointer:(bool)drawPointer path:(CGMutablePathRef)path {

    CGPoint loc = CGPointMake(_cornerRadius, y);
    loc.x += _pointerLoc == kHelpBubblePointerLocationLeft ? _pointerLength : 0.0f;
    CGPathAddLineToPoint(path, nil, loc.x, loc.y);
    
    if (drawPointer) {
        
        CGPoint pointerApex = CGPointMake(_bubbleFrame.size.width / 2.0f, y - _pointerLength);
        pointerApex.x += _pointerOffset.x;
        
        /* Rising edge */
        loc.x += (pointerApex.x - _cornerRadius - (_pointerLength / 2.0f));
        CGPathAddLineToPoint(path, nil, loc.x, loc.y);
        
        /* Apex */
        loc = pointerApex;
        CGPathAddLineToPoint(path, nil, loc.x, loc.y);
        
        /* Falling edge */
        loc.x += (_pointerLength / 2.0f);
        loc.y = y;
        CGPathAddLineToPoint(path, nil, loc.x, loc.y);
    }
    
    loc.x = self.frame.size.width - _cornerRadius;
    loc.x -= _pointerLoc == kHelpBubblePointerLocationRight ? _pointerLength : 0.0f;
    CGPathAddLineToPoint(path, nil, loc.x, loc.y);
    
    loc.x += _cornerRadius;
    CGPathAddArcToPoint(path, nil, loc.x, loc.y, loc.x, loc.y + self.frame.size.height, _cornerRadius);
}

-(void)addBottomEdgeAtY:(CGFloat)y withPointer:(bool)drawPointer path:(CGMutablePathRef)path {

    CGPoint loc = CGPointMake(_bubbleFrame.size.width - _cornerRadius, y);
    loc.x += _pointerLoc == kHelpBubblePointerLocationLeft ? _pointerLength : 0.0f;
    CGPathAddLineToPoint(path, nil, loc.x, loc.y);
    
    if (drawPointer) {
        
        CGPoint pointerApex = CGPointMake(_bubbleFrame.size.width / 2.0f, y + _pointerLength);
        pointerApex.x += _pointerOffset.x;
        
        /* Falling edge (drawing from right to left) */
        loc.x -= (loc.x - (pointerApex.x - _cornerRadius + _pointerLength));
        CGPathAddLineToPoint(path, nil, loc.x, loc.y);
        
        /* Apex */
        loc = pointerApex;
        CGPathAddLineToPoint(path, nil, loc.x, loc.y);
        
        /* Rising edge (drawing from right to left) */
        loc.x -= (_pointerLength / 2.0f);
        loc.y = y;
        CGPathAddLineToPoint(path, nil, loc.x, loc.y);
    }
    
    loc.x = _cornerRadius;
    loc.x += _pointerLoc == kHelpBubblePointerLocationLeft ? _pointerLength : 0.0f;
    CGPathAddLineToPoint(path, nil, loc.x, loc.y);
    
    loc.x = _pointerLoc == kHelpBubblePointerLocationLeft ? _pointerLength : 0.0f;
    CGPathAddArcToPoint(path, nil, loc.x, loc.y, loc.x, loc.y - self.frame.size.height, _cornerRadius);
}

-(void)addLeftEdgeAtX:(CGFloat)x withPointer:(bool)drawPointer path:(CGMutablePathRef)path {

    CGPoint loc = CGPointMake(x, _bubbleFrame.size.height - _cornerRadius);
    loc.y += _pointerLoc == kHelpBubblePointerLocationTop ? _pointerLength : 0.0f;
    CGPathAddLineToPoint(path, nil, loc.x, loc.y);
    
    if (drawPointer) {
        
        //        CGPoint pointerApex = CGPointMake(_bubbleFrame.size.width / 2.0f, y - _pointerLength);
        CGPoint pointerApex = CGPointMake(x - _pointerLength, _bubbleFrame.size.height / 2.0f);
        pointerApex.y += _pointerOffset.y;
        
        /* Left-ward edge (drawing bottom to top) */
        loc.y -= (_bubbleFrame.size.height - (pointerApex.y + _cornerRadius + (_pointerLength / 2.0f)));
        CGPathAddLineToPoint(path, nil, loc.x, loc.y);
        
        /* Apex */
        loc = pointerApex;
        CGPathAddLineToPoint(path, nil, loc.x, loc.y);
        
        /* Right-ward edge (drawing bottom to top) */
        loc.y -= (_pointerLength / 2.0f);
        loc.x = x;
        CGPathAddLineToPoint(path, nil, loc.x, loc.y);
    }
    
    loc.y = _cornerRadius;
    loc.y += _pointerLoc == kHelpBubblePointerLocationTop ? _pointerLength : 0.0f;
    CGPathAddLineToPoint(path, nil, loc.x, loc.y);
    
    loc.y -= _cornerRadius;
    CGPathAddArcToPoint(path, nil, loc.x, loc.y, loc.x+self.frame.size.width, loc.y, _cornerRadius);
}

-(void)addRightEdgeAtX:(CGFloat)x withPointer:(bool)drawPointer path:(CGMutablePathRef)path {
    
    CGPoint loc = CGPointMake(x, _cornerRadius);
    loc.y += _pointerLoc == kHelpBubblePointerLocationTop ? _pointerLength : 0.0f;
    CGPathAddLineToPoint(path, nil, loc.x, loc.y);
    
    if (drawPointer) {
        
        CGPoint pointerApex = CGPointMake(x + _pointerLength, _bubbleFrame.size.height / 2.0f);
        pointerApex.y += _pointerOffset.y;
        
        /* Right-ward edge */
        loc.y += (pointerApex.y - _cornerRadius - (_pointerLength / 2.0f));
        CGPathAddLineToPoint(path, nil, loc.x, loc.y);
        
        /* Apex */
        loc = pointerApex;
        CGPathAddLineToPoint(path, nil, loc.x, loc.y);
        
        /* Left-ward edge */
        loc.y += (_pointerLength / 2.0f);
        loc.x = x;
        CGPathAddLineToPoint(path, nil, loc.x, loc.y);
    }
    
    loc.y = self.frame.size.height - _cornerRadius;
    loc.y -= _pointerLoc == kHelpBubblePointerLocationBottom ? _pointerLength : 0.0f;
    CGPathAddLineToPoint(path, nil, loc.x, loc.y);
    
    loc.y += _cornerRadius;
    CGPathAddArcToPoint(path, nil, loc.x, loc.y, loc.x-self.frame.size.width, loc.y-_cornerRadius, _cornerRadius);
}


@end

@implementation HelpLabel

- (id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        self.edgeInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    }
    return self;
}

- (void)drawTextInRect:(CGRect)rect {
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, self.edgeInsets)];
}

@end





















