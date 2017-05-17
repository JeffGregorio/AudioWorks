//
//  METKeyboard.m
//  AudioWorks
//
//  Created by Jeff Gregorio on 7/14/16.
//  Copyright © 2016 Jeff Gregorio. All rights reserved.
//

#import "METKeyboard.h"

@implementation METKeyboard
@synthesize numKeys;
@synthesize activeNote;
@synthesize delegate;
@synthesize keys;
@synthesize minYPosition;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        lowNoteNum = 21;
        numKeys = 88;
        [self setup];
    }
    return self;
}

- (void)setup {
    
    keys = [[NSMutableArray alloc] init];
    activeKeys = [[NSMutableArray alloc] init];
    activeTouches = [[NSMutableArray alloc] init];
    [self setNumKeys:numKeys];
    
    /* Toolbar */
    CGRect frame = CGRectMake(0.0, 0.0, self.frame.size.width, self.frame.size.height / 7.0);
    toolbar = [[UIView alloc] initWithFrame:frame];
    [toolbar setBackgroundColor:[UIColor colorWithRed:0.25
                                                green:0.25
                                                 blue:0.45
                                                alpha:1.0]];
    [[toolbar layer] setBorderWidth:1.5];
    [[toolbar layer] setBorderColor:[UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0].CGColor];
    [self addSubview:toolbar];
    panningActive = false;
    
    UIImage *img;
    UIImageView *imgView;
    CGSize size = CGSizeMake(toolbar.frame.size.height/2.0, toolbar.frame.size.height);
    
    img = [UIImage imageNamed:@"Chevron_up.png"];
    frame = CGRectMake(0.0, 0.0, size.height, size.width);
    frame.origin.x += toolbar.frame.size.width/2.0 - frame.size.width/2.0;
    imgView = [[UIImageView alloc] initWithFrame:frame];
    imgView.contentMode = UIViewContentModeScaleToFill;
    [imgView setImage:img];
    [toolbar addSubview:imgView];
    
    img = [UIImage imageNamed:@"Chevron_down.png"];
    frame = CGRectMake(0.0, 0.0, size.height, size.width);
    frame.origin.x += toolbar.frame.size.width/2.0 - frame.size.width/2.0 - 1.5;
    frame.origin.y += toolbar.frame.size.height - frame.size.height;
    imgView = [[UIImageView alloc] initWithFrame:frame];
    imgView.contentMode = UIViewContentModeScaleToFill;
    [imgView setImage:img];
    [toolbar addSubview:imgView];
    
    img = [UIImage imageNamed:@"Chevron_right.png"];
    frame = CGRectMake(0.0, 0.0, size.width, size.height);
    frame.origin.x += toolbar.frame.size.width - frame.size.width;
    frame.origin.y += toolbar.frame.size.height/2.0 - frame.size.height/2.0 + 1.5;
    imgView = [[UIImageView alloc] initWithFrame:frame];
    imgView.contentMode = UIViewContentModeScaleToFill;
    [imgView setImage:img];
    [toolbar addSubview:imgView];
    img = [UIImage imageNamed:@"Chevron_right.png"];
    frame.origin.x -= frame.size.width;
    imgView = [[UIImageView alloc] initWithFrame:frame];
    imgView.contentMode = UIViewContentModeScaleToFill;
    [imgView setImage:img];
    [toolbar addSubview:imgView];
    
    img = [UIImage imageNamed:@"Chevron_left.png"];
    frame = CGRectMake(0.0, 0.0, size.width, size.height);
    frame.origin.y += toolbar.frame.size.height/2.0 - frame.size.height/2.0;
    imgView = [[UIImageView alloc] initWithFrame:frame];
    imgView.contentMode = UIViewContentModeScaleToFill;
    [imgView setImage:img];
    [toolbar addSubview:imgView];
    img = [UIImage imageNamed:@"Chevron_left.png"];
    frame.origin.x += frame.size.width;
    imgView = [[UIImageView alloc] initWithFrame:frame];
    imgView.contentMode = UIViewContentModeScaleToFill;
    [imgView setImage:img];
    [toolbar addSubview:imgView];
    
    /* Move keyboard to display F3 as lowest note */
    frame = [contentView frame];
    frame.origin.x = -1325.0;
    [contentView setFrame:frame];
    
    minYPosition = 0.0;
}

- (void)setNumKeys:(int)num {
    
    numKeys = num;
    
    for (int i = 0; i < [keys count]; i++) {
        [keys[i] removeFromSuperview];
    }
    [keys removeAllObjects];
    
    /* Create first key to get white key width */
    METKey *firstKey = [[METKey alloc] initWithParent:self noteNum:lowNoteNum];
    [keys addObject:firstKey];
    
    int i, n;
    numNaturals = 1;
    CGRect frame;
    naturalWidth = firstKey.frame.size.width;
    CGPoint origin = CGPointMake(naturalWidth, 0.0);
    for (i = 1, n = lowNoteNum+1; i < numKeys; i++, n++) {
        
        METKey *key = [[METKey alloc] initWithParent:self noteNum:n];
        frame = key.frame;
        
        switch (key.pitchClassNum) {
                
            case 1:     // C#/Db
                frame.origin.x = origin.x - 5.0 * frame.size.width / 8.0;
                break;
            case 6:     // F#/Gb
                frame.origin.x = origin.x - 3.0 * frame.size.width / 4.0;
                break;
            case 3:     // D#/Eb
                frame.origin.x = origin.x - 3.0 * frame.size.width / 8.0;
                break;
            case 10:    // A#/Bb
                frame.origin.x = origin.x - 1.0 * frame.size.width / 4.0;
                break;
            case 8:     // G#/Ab
                frame.origin.x = origin.x - 1.0 * frame.size.width / 2.0;
                break;
            default:    // Naturals
                frame.origin = origin;
                origin.x += naturalWidth;
                numNaturals++;
                break;
        }
        
        [key setFrame:frame];
        [keys addObject:key];
        [key setIndexInNoteArray:(int)[keys count]-1];
    }
    
    /* Size the content view appropriately and add keys */
    CGRect contentFrame = CGRectMake(0.0, 0.0, numNaturals * naturalWidth, self.frame.size.height);
    contentView = [[UIView alloc] initWithFrame:contentFrame];
    [contentView setBackgroundColor:[UIColor clearColor]];
    [self addSubview:contentView];
    
    for (int i = 0; i < [keys count]; i++) {
        [contentView addSubview:(METKey *)keys[i]];
        if (![keys[i] isAccidental])
            [contentView sendSubviewToBack:keys[i]];
    }
    
    activeKey = [METKey alloc];
}

- (METKey *)keyForTouchLoc:(CGPoint)loc {
    
    METKey *key;
    
    /* Find octave of this touch to search key bounds */
    int oct = -1;
    do {
        oct++;
        key = keys[MIN(oct*12, (int)[keys count]-1)];
    } while (oct < 8 && key.frame.origin.x < loc.x);
    oct--;
    
    /* Check for any key boundaries that contain the touch */
    int foundAccidental = -1;
    int foundNatural = -1;
    int nnotes = oct == 7 ? 4 : 12;
    for (int i = 0; i < nnotes; i++) {
        key = keys[oct*12 + i];
        if (CGRectContainsPoint(key.frame, loc)) {
            if (key.isAccidental)
                foundAccidental = oct*12 + i;
            else
                foundNatural = oct*12 + i;
        }
    }
    
    key = nil;
    
    /* If both an accidental and natural contain the touch, return the accidental */
    if (foundAccidental != -1)
        key = keys[foundAccidental];
    else if (foundNatural != -1)
        key = keys[foundNatural];
    
    return key;
}

/* Activate a note without sending a note on message to the delegate */
- (void)activateNote:(int)noteNum {
    
    if (noteNum < 21 || noteNum > 108)
        return;
    
    int i = 0;
    METKey *key = keys[i];
    while (i < [keys count]-1 && key.noteNum < noteNum)
        key = keys[i++];
    
    dispatch_async(dispatch_get_main_queue(),^ {
        [key activate:false];
    });
}

- (void)deactivateNote:(int)noteNum {
    
    if (noteNum < 21 || noteNum > 108)
        return;
    
    int i = 0;
    METKey *key = keys[i];
    while (i < [keys count]-1 && key.noteNum < noteNum)
        key = keys[i++];
    
    dispatch_async(dispatch_get_main_queue(),^ {
        [key deactivate:false];
    });
}

#pragma mark - Touch Handling
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    touch = [touches anyObject];
    CGPoint touchLoc = [touch locationInView:contentView];
    
    /* Toolbar touch */
    if (CGRectContainsPoint(toolbar.frame, [touch locationInView:self])) {
        previousPanTouchLoc = [touch locationInView:[self superview]];
        panningActive = true;
    }
    /* Key touch */
    else {
        [activeTouches addObject:touch];
        [activeKeys addObject:[self keyForTouchLoc:touchLoc]];
        [[activeKeys lastObject] activate:true];
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    touch = [touches anyObject];
    CGPoint touchLoc;
    
    if (panningActive) {
        touchLoc = [touch locationInView:[self superview]];
        [self handlePan:touchLoc];
    }
    else {
        
        /* Find the active touches index corresponding to this touch */
        NSInteger idx = [activeTouches indexOfObject:touch];
        
        /* Find the key corresponding to this touch location */
        touchLoc = [touch locationInView:contentView];
        METKey *testKey = [self keyForTouchLoc:touchLoc];
        
        if (idx != NSNotFound && testKey) {
        
            bool matched = false;
            for (int i = 0; i < [activeKeys count]; i++) {
                if ([testKey isEqual:activeKeys[i]])
                    matched = true;
            }
            
            /* If we didn't find a match, deactivate the key for this touch and activate a new key */
            if (!matched) {
                [activeKeys[idx] deactivate:true];
                [activeKeys removeObjectAtIndex:idx];
                
                [testKey activate:true];
                [activeKeys addObject:testKey];
            }
        }
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    touch = [touches anyObject];
    
    /* Find the active touches index corresponding to this touch */
    NSInteger idx = [activeTouches indexOfObject:touch];
    
    if (idx != NSNotFound) {
        [activeTouches removeObjectAtIndex:idx];
        [activeKeys[idx] deactivate:true];
        [activeKeys removeObjectAtIndex:idx];
    }
    
    if (panningActive)
        panningActive = false;
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

- (void)handlePan:(CGPoint)touchLoc {
    
    /* Compute change in location */
    CGFloat delx = touchLoc.x - previousPanTouchLoc.x;
    CGFloat dely = touchLoc.y - previousPanTouchLoc.y;
    
    CGRect frame;
    
    /* Vertical panning */
    if (fabs(dely) > fabs(delx)) {
        
        /* Move the keyboard frame */
        frame = [self frame];
        frame.origin.y += dely;
        
        /* Constrain to the parent view bounds */
        frame.origin.y = frame.origin.y < minYPosition ? minYPosition : frame.origin.y;
        frame.origin.y = frame.origin.y + frame.size.height > self.superview.frame.origin.y + self.superview.frame.size.height ? self.superview.frame.origin.y + self.superview.frame.size.height - frame.size.height: frame.origin.y;
        [self setFrame:frame];
    }
    
    /* Horizontal content view panning */
    else {
        
        /* Move the content view frame */
        frame = [contentView frame];
        frame.origin.x += delx;
        
        /* Constrain to parent view bounds */
        frame.origin.x = frame.origin.x > 0.0 ? 0.0 : frame.origin.x;
        frame.origin.x = frame.origin.x + frame.size.width < self.frame.size.width ? self.frame.size.width - frame.size.width : frame.origin.x;
        [contentView setFrame:frame];
    }
    
    previousPanTouchLoc = touchLoc;
}

@end

@implementation METKey
@synthesize parent;
@synthesize noteNum;
@synthesize pitchClassNum;
@synthesize isAccidental;
@synthesize isActive;
@synthesize indexInNoteArray;

- (id)initWithParent:(METKeyboard *)keyboard noteNum:(int)num {
    self = [super init];
    if (self) {
        parent = keyboard;
        noteNum = num;
        [self setup];
    }
    return self;
}

- (void)setup {
    
    CGFloat height = parent.frame.size.height;
    CGFloat width = parent.frame.size.width / 11.0; // Fit C to F in view
    borderWidth = 1.5;
    
    pitchClassNum = noteNum % 12;
    
    /* Accidental */
    if (pitchClassNum == 1 || pitchClassNum == 3 ||
        pitchClassNum == 6 || pitchClassNum == 8 || pitchClassNum == 10) {
        
        height *= 2.0 / 3.0;
        width *= 2.0 / 3.0;
        isAccidental = true;
        fillColor = [[UIColor blackColor] colorWithAlphaComponent:1.0];
        borderColor = [UIColor colorWithRed:0.45 green:0.45 blue:0.45 alpha:1.0].CGColor;
    }
    /* Natural */
    else {
        isAccidental = false;
        fillColor = [[UIColor whiteColor] colorWithAlphaComponent:1.0];
        borderColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0].CGColor;
    }
    
    [self setFrame:CGRectMake(0.0, 0.0, width, height)];
    [self setBackgroundColor:fillColor];
    [[self layer] setBorderWidth:borderWidth];
    [[self layer] setBorderColor:borderColor];
    [[self layer] setCornerRadius:8.0];
    
    /* Add a label if the note is a C */
    if (pitchClassNum == 0) {
        CGRect frame;
        frame.size.width = 40;
        frame.size.height = 20;
        frame.origin.x = 5.0;
        frame.origin.y = self.frame.size.height - frame.size.height - 5.0;
        UILabel *clabel = [[UILabel alloc] initWithFrame:frame];
        [clabel setTextColor:[UIColor colorWithCGColor:borderColor]];
        [clabel setText:[NSString stringWithFormat:@"C%d", noteNum / 12  - 1]];
        [self addSubview:clabel];
    }
}

- (void)activate:(bool)notifyDelegate {
    
    [self setBackgroundColor:[UIColor colorWithCGColor:borderColor]];
    
    if ([parent delegate] && notifyDelegate &&
        [[parent delegate] respondsToSelector:@selector(handleNoteOn:velocity:)])
        [[parent delegate] handleNoteOn:noteNum velocity:127];
    
    isActive = true;
}

- (void)deactivate:(bool)notifyDelegate {
    
    [self setBackgroundColor:fillColor];
    
    if ([parent delegate] && notifyDelegate &&
        [[parent delegate] respondsToSelector:@selector(handleNoteOff:)])
        [[parent delegate] handleNoteOff:noteNum];
    
    isActive = false;
}

@end
