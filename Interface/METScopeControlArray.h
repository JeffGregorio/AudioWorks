//
//  METScopeControlArray.h
//  AudioWorks
//
//  Created by Jeff Gregorio on 7/18/15.
//  Copyright (c) 2015 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "METScopeView.h"

#define kControlDotExtension 30.0

@class METControl;
@protocol METScopeControlArrayDelegate;

typedef enum METControlStyle {
    kMETControlStyleDot = 0,
    kMETControlStyleRect,
    kMETControlStylePlayhead
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

- (void)setValues:(CGPoint)vals forControlWithTag:(NSInteger)tag;
- (void)setVerticalValue:(CGFloat)val forControlWithTag:(NSInteger)tag;
- (void)setHorizontalValue:(CGFloat)val forControlWithTag:(NSInteger)tag;

@end

#pragma mark - METControl Public Interface
@interface METControl : UIControl
@property (readonly) CGPoint location;
@property (getter=getValues) CGPoint values;
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
- (void)setValues:(CGPoint)vals;
- (CGPoint)getValues;
- (void)setVerticalRange:(CGFloat)minVal max:(CGFloat)maxVal;
- (void)setHorizontalRange:(CGFloat)minVal max:(CGFloat)maxVal;
- (void)setStyle:(METControlStyle)style;
- (void)setFaceColor:(UIColor *)color;
- (void)setHidden:(BOOL)hidden;
@end

#pragma mark - METScopeControlArrayDelegate
@protocol METScopeControlArrayDelegate <NSObject>
- (void)parameterDotTouchDown:(METControl *)sender;
- (void)parameterDotValuesChanged:(METControl *)sender;
- (void)parameterDotTouchUp:(METControl *)sender;
@end
