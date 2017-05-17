//
//  METButton.m
//  CustomTabNavigationTest
//
//  Created by Jeff Gregorio on 6/30/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import "METButton.h"

@implementation METButton

@synthesize isHeld = _held;
@synthesize isActive = _active;

- (id)initWithTitle:(NSString *)title origin:(CGPoint)origin {
    
    self = [self initWithTitle:title origin:origin color:[UIColor blueColor]];
    return self;
}

- (id)initWithTitle:(NSString *)title origin:(CGPoint)origin color:(UIColor*)color {
    
    self = [super initWithFrame:CGRectMake(origin.x, origin.y, 1.0f, 1.0f)];
    
    _idleTextColor = _downBackgroundColor = color;
    _downTextColor = _idleBackgroundColor = [UIColor whiteColor];
    _heldTextColor = _idleTextColor;
    _heldBackgroundColor = [UIColor colorWithRed:0.9f green:0.9f blue:0.9f alpha:0.5f];
    
    
    [self setTitle:title forState:UIControlStateNormal];
    self.titleLabel.font = [UIFont systemFontOfSize:17.0f];

    [self setTitleShadowColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    [self setTitleColor:_idleTextColor forState:UIControlStateNormal];
    [[self layer] setBackgroundColor:[UIColor clearColor].CGColor];
    [[self layer] setCornerRadius:8.0f];
    [self sizeToFit];
    CGRect frame = self.frame;
    frame.size.width += 20.0f;
    [self setFrame:frame];
    
    _held = false;
    _active = false;
    
    return self;
}

//- (id)initWithImage:(NSString *)path origin:(CGPoint)origin {
//    
//    self = [super initWithFrame:<#(CGRect)#>]
//}

- (void)setBackgroundColorForIdleState:(UIColor *)color {
    _idleBackgroundColor = color;
    [[self layer] setBackgroundColor:_idleBackgroundColor.CGColor];
    [self setNeedsDisplay];
}

- (void)setBackgroundColorForHeldState:(UIColor *)color {
    _heldBackgroundColor = color;
    [self setNeedsDisplay];
}

- (void)setBackgroundColorForDownState:(UIColor *)color {
    _downBackgroundColor = color;
    [self setNeedsDisplay];
}

- (void)setImage:(UIImage *)image forState:(UIControlState)state {
    _idleBackgroundColor = [UIColor clearColor];
    _downBackgroundColor = [UIColor clearColor];
    [super setImage:image forState:state];
}


#pragma mark - Touch Handlers
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self sendActionsForControlEvents:UIControlEventTouchDown];
    [self setHeld:true];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
//    [super touchesMoved:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self sendActionsForControlEvents:UIControlEventTouchUpInside];
    [self setHeld:false];
}

#pragma mark - Interface Methods
- (void)toggleActive {
    [self setActive:!_active];
}

- (void)setActive:(bool)isActive {
    _active = isActive;
    if (_active) {
        [self setTitleColor:_downTextColor forState:UIControlStateNormal];
        [self setBackgroundColor:_downBackgroundColor];
        [[self layer] setBorderColor:_downBackgroundColor.CGColor];
    }
    else {
        [self setTitleColor:_idleTextColor forState:UIControlStateNormal];
        [self setBackgroundColor:_idleBackgroundColor];
        [[self layer] setBorderColor:_idleBackgroundColor.CGColor];
    }
}

#pragma mark - Misc.
- (void)setHeld:(bool)isHeld {
    
    if (_held == isHeld)
        return;
    
    _held = isHeld;
    
    CGRect frame = self.frame;
    
    if (_held) {
        frame.origin.x += 1.0f;
        frame.origin.y += 1.0f;
        [self setTitleColor:_heldTextColor forState:UIControlStateNormal];
        [self setBackgroundColor:_heldBackgroundColor];
        [[self layer] setBorderColor:_heldBackgroundColor.CGColor];
    }
    else {
        frame.origin.x -= 1.0f;
        frame.origin.y -= 1.0f;
        if (!_active) {
            [self setTitleColor:_idleTextColor forState:UIControlStateNormal];
            [self setBackgroundColor:_idleBackgroundColor];
            [[self layer] setBorderColor:_idleBackgroundColor.CGColor];
        }
    }
    
    [self setFrame:frame];
}

- (void)flash {
    [UIView animateWithDuration:0.1f
                     animations:^{
                         [self setAlpha:0.1f];
                     }
                     completion:^(BOOL finished) {
                         [self setAlpha:1.0f];
                     }
     ];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
