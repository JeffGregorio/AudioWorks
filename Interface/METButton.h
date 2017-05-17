//
//  METButton.h
//  CustomTabNavigationTest
//
//  Created by Jeff Gregorio on 6/30/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface METButton : UIButton {
    
    UIColor *_idleTextColor;
    UIColor *_heldTextColor;
    UIColor *_downTextColor;
    UIColor *_idleBackgroundColor;
    UIColor *_heldBackgroundColor;
    UIColor *_downBackgroundColor;
    
    bool _held;
    bool _active;
}

@property bool isHeld;
@property bool isActive;

- (id)initWithTitle:(NSString *)title origin:(CGPoint)origin;
- (id)initWithTitle:(NSString *)title origin:(CGPoint)origin color:(UIColor*)color;
//- (id)initWithImage:(NSString *)path origin:(CGPoint)origin;
- (void)setBackgroundColorForIdleState:(UIColor *)color;
- (void)setBackgroundColorForHeldState:(UIColor *)color;
- (void)setBackgroundColorForDownState:(UIColor *)color;
- (void)setImage:(UIImage *)image forState:(UIControlState)state;

- (void)toggleActive;
- (void)setActive:(bool)isActive;

@end
