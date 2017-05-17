//
//  METKeyboard.h
//  AudioWorks
//
//  Created by Jeff Gregorio on 7/14/16.
//  Copyright © 2016 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>
//#include "Defs.h"

@class METKey;

#pragma mark - METKeyboardDelegate
@protocol METKeyboardDelegate <NSObject>
@optional
- (void)handleNoteOff:(int)noteNum;
- (void)handleNoteOn:(int)noteNum velocity:(int)vel;
//- (void)handlePitchBend:(float)val;
@end

#pragma mark - METKeyboard
@interface METKeyboard : UIView {

    UIView *contentView;
    UIView *toolbar;
    
    int lowNoteNum;
    UITouch *touch;
    
    bool panningActive;
    CGPoint previousPanTouchLoc;    // Location in superview
    
    int numNaturals;
    CGFloat naturalWidth;
    
    METKey *activeKey;
    NSMutableArray *activeKeys;
    NSMutableArray *activeTouches;
}

@property (readonly) int numKeys;
@property int activeNote;
@property id<METKeyboardDelegate> delegate;
@property (readonly) NSMutableArray *keys;
@property CGFloat minYPosition;

- (id)initWithFrame:(CGRect)frame;
- (void)activateNote:(int)noteNum;
- (void)deactivateNote:(int)noteNum;

@end

#pragma mark - METKey
@interface METKey : UIView {
    UIColor *fillColor;
    CGColorRef borderColor;
    CGFloat borderWidth;
}

@property (readonly) METKeyboard *parent;
@property (readonly) int noteNum;
@property (readonly) int pitchClassNum;
@property (readonly) bool isAccidental;
@property (readonly) bool isActive;
@property int indexInNoteArray;


- (id)initWithParent:(METKeyboard *)keyboard noteNum:(int)num;
- (void)activate:(bool)notifyDelegate;
- (void)deactivate:(bool)notifyDelegate;

@end