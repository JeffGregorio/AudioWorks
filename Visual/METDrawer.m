//
//  METDrawer.m
//  CustomTabNavigationTest
//
//  Created by Jeff Gregorio on 7/2/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import "METDrawer.h"

#pragma mark - METDrawerHandle
@interface METDrawerHandle : UIView {
    UIImageView *chevron;
    CGPoint previousTouchLocation;
}
@property METDrawer *parentDrawer;
- (id)initWithParentDrawer:(METDrawer *)parent;
- (id)initWithParentDrawer:(METDrawer *)parent size:(CGSize)size;
- (void)chevronOpenPosition;
- (void)chevronClosePosition;
@end

@implementation  METDrawerHandle
@synthesize parentDrawer;

- (id)initWithParentDrawer:(METDrawer *)parent {

    self = [[METDrawerHandle alloc] initWithParentDrawer:parent size:CGSizeMake(40.0f, parent.frame.size.height)];
    return self;
}

- (id)initWithParentDrawer:(METDrawer *)parent size:(CGSize)size {
    
    CGRect frame = parent.frame;
    frame.size.width = size.width;
    frame.size.height = size.height;
    frame.origin.x += parent.frame.size.width - frame.size.width;
    frame.origin.y = parent.frame.size.height / 2.0f - frame.size.height / 2.0f;
    self = [[METDrawerHandle alloc] initWithFrame:frame];
    
    chevron = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Chevron_small.png"]];
    [self addSubview:chevron];
    [chevron setContentMode:UIViewContentModeScaleAspectFill];
    
    CGRect imgFrame = self.frame;
    imgFrame.origin.x = 7.5f;
    imgFrame.origin.y = 0.0f;
    [chevron setFrame:imgFrame];
    
    parentDrawer = parent;
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    [self setBackgroundColor:[UIColor colorWithRed:kAudioWorksBlue_R
                                             green:kAudioWorksBlue_G
                                              blue:kAudioWorksBlue_B
                                             alpha:1.0f]];
    return self;
}


- (void)chevronOpenPosition {
    [chevron setTransform:CGAffineTransformMakeRotation(0.0f)];
    CGRect frame = chevron.frame;
    frame.origin.x = 7.5f;
    [chevron setFrame:frame];
}

- (void)chevronClosePosition {
    [chevron setTransform:CGAffineTransformMakeRotation(M_PI)];
    CGRect frame = chevron.frame;
    frame.origin.x = -2.0f;
    [chevron setFrame:frame];
}

#pragma mark - Touch Handlers
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    previousTouchLocation = [[touches anyObject] locationInView:[parentDrawer superview]];
    
    if ([parentDrawer isOpen])
        [parentDrawer close:true];
    else [parentDrawer open:true];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    CGPoint currentTouchLocation = [[touches anyObject] locationInView:[parentDrawer superview]];
    
    CGPoint motionVector = CGPointMake(0.0f, 0.0f);
    motionVector.x = currentTouchLocation.x - previousTouchLocation.x;
//    [parentDrawer applyMotionVector:motionVector];
    
    previousTouchLocation = currentTouchLocation;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    
}

@end

#pragma mark - METDrawer
@implementation METDrawer
@synthesize isOpen;
@synthesize swipeCloseEnabled;

- (id)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    [self setup];
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    
    self = [super initWithCoder:aDecoder];
    [self setup];
    return self;
}

- (void)setup {
    
    [self setBackgroundColor:[UIColor clearColor]];
    
    /* Handle */
    handle = [[METDrawerHandle alloc] initWithParentDrawer:self size:CGSizeMake(35.0f, 50.0f)];
    [[handle layer] setCornerRadius:5.0f];
    
    /* Drawer (visible) */
    CGRect frame = self.frame;
    frame.origin.x = 0.0f;
    frame.origin.y = 0.0f;
    frame.size.width -= 2.0f * handle.frame.size.width / 3.0f;
    drawerView = [[UIView alloc] initWithFrame:frame];
    [drawerView setBackgroundColor:[UIColor colorWithRed:0.95f green:0.95f blue:0.95f alpha:0.95f]];
    [[drawerView layer] setBorderWidth:0.8f];
    [[drawerView layer] setBorderColor:[UIColor lightGrayColor].CGColor];
    [[drawerView layer] setCornerRadius:10.0f];

    [self addSubview:drawerView];
    [self addSubview:handle];
    
    swipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(close:)];
    [swipeRecognizer setDirection:UISwipeGestureRecognizerDirectionLeft];
    [self addGestureRecognizer:swipeRecognizer];
    swipeCloseEnabled = true;
    
    isOpen = true;
    
    originOpen = self.frame.origin;
    originClosed = originOpen;
    originClosed.x -= drawerView.frame.size.width;
}

- (void)swipeClose:(id)sender {
    [self close:true];
}

- (void)open:(bool)animated {
    
    if (isOpen)
        return;
    
    CGRect frame = self.frame;
    frame.origin = originOpen;
    
    if (!animated)
        [self setFrame:frame];
    else {
        [UIView animateWithDuration:0.5f
                         animations:^{
                             [self setFrame:frame];
                         }
                         completion:^(BOOL finished) {
                             
                         }];
    }
    
    [handle chevronClosePosition];
    isOpen = true;
}

- (void)close:(bool)animated {
    
    if (!isOpen)
        return;
    
    CGRect frame = self.frame;
    frame.origin = originClosed;
    
    if (!animated)
        [self setFrame:frame];
    else {
        [UIView animateWithDuration:0.5f
                         animations:^{
                             [self setFrame:frame];
                         }
                         completion:^(BOOL finished) {
                             
                         }];
    }
    
    [handle chevronOpenPosition];
    isOpen = false;
}

- (void)setSwipeCloseEnabled:(bool)enabled {
    
    if (enabled == swipeCloseEnabled)
        return;
    
    swipeCloseEnabled = enabled;
    
    if (swipeCloseEnabled)
        [self addGestureRecognizer:swipeRecognizer];
    else
        [self removeGestureRecognizer:swipeRecognizer];
}

- (CGRect)getHandleFrame {
    return handle.frame;
}

@end
















