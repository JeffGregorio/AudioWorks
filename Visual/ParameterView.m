//
//  ParameterView.m
//  AudioWorks
//
//  Created by Jeff Gregorio on 7/17/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import "ParameterView.h"

@implementation ParameterView

- (id)initWithFrame:(CGRect)frame boundingFrame:(CGRect)bFrame {
    
    CGRect fr;
    
    self = [super initWithFrame:frame];
    
    if (self) {
        
        boundingFrame = bFrame;
        
        [self setBackgroundColor:[[UIColor whiteColor] colorWithAlphaComponent:0.8f]];
        [[self layer] setBorderWidth:1.0f];
        [[self layer] setBorderColor:[[UIColor blueColor] colorWithAlphaComponent:0.1f].CGColor];
        
        /* Add the parameter labels */
        fr.origin.x = 5;
        fr.origin.y = 5;
        fr.size.width = 90;
        fr.size.height = 30;
        
        UILabel *freqParamLabel = [[UILabel alloc] initWithFrame:fr];
        [freqParamLabel setText:@"Frequency: "];
        [self addSubview:freqParamLabel];
        
        fr.origin.y += fr.size.height;
        UILabel *ampParamLabel = [[UILabel alloc] initWithFrame:fr];
        [ampParamLabel setText:@"Amplitude: "];
        [self addSubview:ampParamLabel];
        
        /* And their values */
        fr.origin.y -= fr.size.height;
        fr.origin.x += fr.size.width;
        freqValueLabel = [[UILabel alloc] initWithFrame:fr];
        [freqValueLabel setText:[NSString stringWithFormat:@"%5.1f Hz", 0.0f]];
        [freqValueLabel setTextAlignment:NSTextAlignmentRight];
        [self addSubview:freqValueLabel];
        
        fr.origin.y += fr.size.height;
        ampValueLabel = [[UILabel alloc] initWithFrame:fr];
        [ampValueLabel setText:[NSString stringWithFormat:@"%3.1f dB", 0.0f]];
        [ampValueLabel setTextAlignment:NSTextAlignmentRight];
        [self addSubview:ampValueLabel];
        
    }
    
    return self;
}

- (void)setFreq:(float)val {
    [freqValueLabel setText:[NSString stringWithFormat:@"%5.1f Hz", val]];
}

- (void)setAmp:(float)val {
    [ampValueLabel setText:[NSString stringWithFormat:@"%3.1f dB", val]];
}

- (void)setLeaderFrame:(CGRect)frame {
    
    CGRect infoViewFrame = self.frame;
    infoViewFrame.origin = frame.origin;
    infoViewFrame.origin.y += frame.size.height / 2.0f;
    infoViewFrame.origin.y -= infoViewFrame.size.height / 2.0f;
    infoViewFrame.origin.x -= 20.0f + infoViewFrame.size.width;
    
    /* Keep the info view frame in the bounding frame */
    if (infoViewFrame.origin.y < 0.0)
        infoViewFrame.origin.y = 0.0;
    if ((infoViewFrame.origin.y + infoViewFrame.size.height) > boundingFrame.size.height)
        infoViewFrame.origin.y = boundingFrame.size.height - infoViewFrame.size.height;
    if (infoViewFrame.origin.x < 0.0)
        infoViewFrame.origin.x = 0.0;
    if ((infoViewFrame.origin.x + infoViewFrame.size.width) > boundingFrame.size.width)
        infoViewFrame.origin.x = boundingFrame.size.width - infoViewFrame.size.width;
    
    [self setFrame:infoViewFrame];
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
}

@end
