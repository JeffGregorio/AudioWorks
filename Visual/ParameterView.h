//
//  ParameterView.h
//  AudioWorks
//
//  Created by Jeff Gregorio on 7/17/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ParameterView : UIView {
    
    CGRect boundingFrame;
    
    UILabel *freqValueLabel;
    UILabel *ampValueLabel;
    
}

- (id)initWithFrame:(CGRect)frame boundingFrame:(CGRect)bFrame;
- (void)setFreq:(float)val;
- (void)setAmp:(float)val;
- (void)setLeaderFrame:(CGRect)frame;

@end
