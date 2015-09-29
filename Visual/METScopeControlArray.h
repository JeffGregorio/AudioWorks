//
//  METScopeControlArray.h
//  AudioWorks
//
//  Created by Jeff Gregorio on 7/18/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "METScopeView.h"

@class METControl;
@protocol METScopeControlArrayDelegate;

typedef enum METControlStyle {
    kMETControlStyleDot = 0,
    kMETControlStyleRect
} METControlStyle;

#pragma mark - METScopeControlArray
@interface METScopeControlArray : UIControl {
    
    NSMutableArray *controls;
    int activeControlIndex;
    bool activeControlConstrainsVertically;
    bool activeControlConstrainsHorizontally;
    
    CGFloat lineWidth;
    CGFloat lineAlpha;
    CGPoint plotOriginLocation;
}

@property (weak, atomic) METScopeView *parentScope;
@property id <METScopeControlArrayDelegate> delegate;
@property UIColor *lineColor;

- (id)initWithParentScope:(METScopeView *)parent;
- (void)setControlColor:(UIColor *)color;
- (int)addControlWithValues:(CGPoint)vals;
- (int)addControlWithStyle:(METControlStyle)style values:(CGPoint)vals;
- (METControl *)getControlAtIndex:(int)idx;
- (METControl *)getControlWithTag:(NSInteger)tag;
- (void)removeControlAtIndex:(int)idx;
- (void)removeControlWithTag:(NSInteger)tag;
- (int)numControls;

@end

#pragma mark - METControl Public Interface
@interface METControl : UIControl
@property (readonly) CGPoint location;
@property (readonly) CGPoint values;
@property (readonly) CGPoint minValues;
@property (readonly) CGPoint maxValues;
@property UIColor *lineColor;
@property CGFloat lineAlpha;
@property CGFloat lineWidth;
@property bool drawsVerticalLineToBottom;
@property bool drawsHorizontalLineToLeft;
@property bool drawsVerticalLineToAxis;
@property bool drawsHorizontalLineToAxis;
@property bool constrainVerticallyToParentView;
@property bool constrainHorizontallyToParentView;
- (void)setVerticalRange:(CGFloat)minVal max:(CGFloat)maxVal;
- (void)setHorizontalRange:(CGFloat)minVal max:(CGFloat)maxVal;
- (void)setStyle:(METControlStyle)style;
- (void)setFaceColor:(UIColor *)color;
- (void)setHidden:(BOOL)hidden;
@end

#pragma mark - METScopeControlOverlayDelegate
@protocol METScopeControlArrayDelegate <NSObject>
- (void)parameterDotTouchDown:(METControl *)sender;
- (void)parameterDotValuesChanged:(METControl *)sender;
- (void)parameterDotTouchUp:(METControl *)sender;
@end