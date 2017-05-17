//
//  METDrawer.h
//  CustomTabNavigationTest
//
//  Created by Jeff Gregorio on 7/2/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Constants.h"

@class METDrawerHandle;

@interface METDrawer : UIView {
    
    METDrawerHandle *handle;
    UIView *drawerView;
    
    CGPoint originOpen;
    CGPoint originClosed;
    
    UISwipeGestureRecognizer *swipeRecognizer;
}

@property (readonly) bool isOpen;
@property (readonly) bool swipeCloseEnabled;

- (void)open:(bool)animated;
- (void)close:(bool)animated;
- (void)setSwipeCloseEnabled:(bool)enabled;
- (CGRect)getHandleFrame;

@end
