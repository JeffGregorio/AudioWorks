//
//  DetailViewController.h
//  AudioWorks
//
//  Created by Jeff Gregorio on 6/26/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HelpBubble.h"

@interface DetailViewController : UIViewController {
    
    
}

@property (readonly) bool helpDisplayed;

/* Override */
- (void)toggleHelp;

/* Utility */
- (void)CGlinspace:(CGFloat)minVal max:(CGFloat)maxVal numElements:(int)size array:(CGFloat *)array;
- (void)linspace:(float)minVal max:(float)maxVal numElements:(int)size array:(float*)array;
- (void)flashInFrame:(CGRect)flashFrame;

@end
