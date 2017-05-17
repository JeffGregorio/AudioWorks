//
//  FunctionDrawView.h
//  SoundSynth
//
//  Created by Jeff Gregorio on 7/13/14.
//  Copyright (c) 2014 Jeff Gregorio. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol FunctionDrawViewDelegate;

@interface FunctionDrawView : UIView {
    
    int _length;                    // Length of drawing buffer
    CGFloat *_pixelVals;            // Drawing buffer
    int _previousSetIdx;
    CGPoint _previousTouchLoc;
}

@property (readonly) int length;
@property id <FunctionDrawViewDelegate> delegate;
@property bool mirrorAcrossXAxis;       // Reflect drawing across the x axis
@property bool resetOnTouchDown;        // Reset drawing in [touchesBegan:]
@property (readonly) bool hasDrawnFunction;

- (void)getDrawingWithLength:(int)length pixelVals:(CGFloat *)outPixels;
- (void)setDrawingWithLength:(int)length pixelVals:(CGFloat *)inPixels;
- (void)resetDrawing;

@end

#pragma mark - FunctionDrawViewDelegate
@protocol FunctionDrawViewDelegate <NSObject>
@optional
- (void)drawingEnded;
- (void)drawingBegan;
- (void)drawingChanged;
@end