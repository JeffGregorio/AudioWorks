//
//  DetailViewController.m
//  AudioWorks
//
//  Created by Jeff Gregorio on 6/26/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import "DetailViewController.h"

@implementation DetailViewController
@synthesize helpDisplayed;
@synthesize inputPaused;

- (void)toggleHelp {
    
}

- (void)toggleInput {
    
}

- (void)enableInput {
    
}

- (void)disableInput {
    
}

#pragma mark - Utility
/* Generate a linearly-spaced set of indices for sampling an incoming waveform */
- (void)CGlinspace:(CGFloat)minVal max:(CGFloat)maxVal numElements:(int)size array:(CGFloat *)array {
    
    CGFloat step = (maxVal-minVal)/(size-1);
    array[0] = minVal;
    int i;
    for (i = 1;i<size-1;i++) {
        array[i] = array[i-1]+step;
    }
    array[size-1] = maxVal;
}

- (void)linspace:(float)minVal max:(float)maxVal numElements:(int)size array:(float *)array {
    
    float step = (maxVal-minVal)/(size-1);
    array[0] = minVal;
    int i;
    for (i = 1;i<size-1;i++) {
        array[i] = array[i-1]+step;
    }
    array[size-1] = maxVal;
}

/* Flash animation in the given rectangle */
- (void)flashInFrame:(CGRect)flashFrame {
    
    UIView *flashView = [[UIView alloc] initWithFrame:flashFrame];
    [flashView setBackgroundColor:[UIColor blackColor]];
    [flashView setAlpha:0.5f];
    [[self view] addSubview:flashView];
    [UIView animateWithDuration:0.5f
                     animations:^{
                         [flashView setAlpha:0.0f];
                     }
                     completion:^(BOOL finished) {
                         [flashView removeFromSuperview];
                     }
     ];
}

@end
