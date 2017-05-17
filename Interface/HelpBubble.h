//
//  HelpBubble.h
//  DigitalSoundFX_v2
//
//  Created by Jeff Gregorio on 9/2/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>

#define kHelpBubbleLeadingTextSpace 15.0f
#define kHelpBubbleLineWidth 1.5f
#define kHelpBubbleBorderAlpha 0.8f
#define kHelpBubblePointerLength 15.0f
#define kHelpBubbleCornerRadius 8.0f

@class HelpLabel;

typedef enum PointerLocation {
    kHelpBubblePointerLocationNone,
    kHelpBubblePointerLocationTop,
    kHelpBubblePointerLocationBottom,
    kHelpBubblePointerLocationLeft,
    kHelpBubblePointerLocationRight
} PointerLocation;

@interface HelpBubble : UIView {
    
    NSString *_text;
    PointerLocation _pointerLoc;
    
    CGRect _bubbleFrame;    // Text frame excluding pointers
}

@property HelpLabel *label;     // Make UILabel accessible to set text alignment
@property CGPoint pointerOffset;

@property bool drawBackground;
@property (readonly) UIColor *color;
@property CGFloat opacity;
@property CGFloat leadingTextSpace;
@property CGFloat lineWidth;
@property CGFloat lineAlpha;
@property CGFloat pointerLength;
@property CGFloat cornerRadius;

- (id)initWithText:(NSString *)text origin:(CGPoint)origin;
- (id)initWithText:(NSString *)text origin:(CGPoint)origin width:(CGFloat)width;
- (id)initWithText:(NSString *)text origin:(CGPoint)origin width:(CGFloat)width alignment:(NSTextAlignment)alignment;

- (void)setFrameSizeForFontSize:(CGFloat)size;

- (void)setColor:(UIColor *)color;
- (void)setColor:(UIColor *)color alpha:(CGFloat)alpha;

- (void)setPointerLocation:(PointerLocation)loc;
- (void)setPointerLocation:(PointerLocation)loc offset:(CGPoint)offset;

@end

#pragma mark - HelpLabel
@interface HelpLabel : UILabel
@property (nonatomic, assign) UIEdgeInsets edgeInsets;
@end
