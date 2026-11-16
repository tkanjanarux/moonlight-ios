#import "HogwartsControls.h"
#import "ControllerSupport.h"
#include "Limelight.h"
#include <math.h>

@implementation HogwartsControls {
    ControllerSupport *_support;
    Controller *_controller;
    NSMutableArray<UIButton *> *_buttons;
    NSMutableSet<NSString *> *_held;
    NSMutableArray<NSNumber *> *_queue;
    UITouch *_moveTouch;
    UITouch *_cameraTouch;
    CGPoint _origin, _movePoint, _cameraPoint;
    short _lx, _ly, _rx, _ry;
    CGFloat _unit;
    CGSize _lastSize;
    BOOL _drawer, _sprint, _busy, _suspended;
    int _pulseFlags;
    unsigned char _pulseRT;
    NSUInteger _generation, _cameraGeneration;
}

- (instancetype)initWithFrame:(CGRect)frame controllerSupport:(ControllerSupport *)support {
    if ((self = [super initWithFrame:frame])) {
        _support = support;
        _controller = [support getOscController];
        _buttons = [NSMutableArray array];
        _held = [NSMutableSet set];
        _queue = [NSMutableArray array];
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        self.multipleTouchEnabled = YES;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        // x is distance from the left/right edge; y is distance from the bottom.
        // Dimensions are design millimetres calibrated for the unfolded Duo panel.
        NSArray *specs = @[
            @[@"cast", @"CAST", @"Basic Cast", @1,@18,@17,@11,@0],
            @[@"shield", @"P", @"Protego: hold for Stupefy", @1,@18,@30,@10,@0],
            @[@"dodge", @"B", @"Dodge", @1,@30,@16,@10,@0],
            @[@"spell1", @"1", @"Spell slot Y", @1,@7,@38,@9,@0],
            @[@"spell2", @"2", @"Spell slot B", @1,@19,@43,@9,@0],
            @[@"spell3", @"3", @"Spell slot A", @1,@31,@39,@9,@0],
            @[@"spell4", @"4", @"Spell slot X", @1,@37,@28,@9,@0],
            @[@"jump", @"A", @"Jump / menu confirm", @1,@7,@12,@9,@0],
            @[@"heal", @"+", @"Wiggenweld", @0,@8,@38,@9,@0],
            @[@"revelio", @"R", @"Revelio", @0,@21,@42,@9,@0],
            @[@"more", @"…", @"Extra controls", @0,@34,@38,@9,@0],
            @[@"sprint", @"RUN", @"Toggle sprint", @0,@34,@18,@9,@0],
            @[@"interact", @"X", @"Interact / menu action", @0,@8,@53,@9,@1],
            @[@"ancient", @"AM", @"Ancient Magic", @0,@21,@53,@9,@1],
            @[@"throw", @"RB", @"Ancient Magic Throw", @0,@34,@53,@9,@1],
            @[@"tools", @"LB", @"Hold tool wheel", @0,@8,@66,@9,@1],
            @[@"aim", @"LT", @"Hold aim", @0,@21,@66,@9,@1],
            @[@"lock", @"R3", @"Lock target", @0,@34,@66,@9,@1],
            @[@"set1", @"S↑", @"Spell set up", @1,@7,@57,@9,@1],
            @[@"set2", @"S→", @"Spell set right", @1,@20,@57,@9,@1],
            @[@"set3", @"S↓", @"Spell set down", @1,@33,@57,@9,@1],
            @[@"set4", @"S←", @"Spell set left", @1,@46,@57,@9,@1],
            @[@"up", @"↑", @"Menu up", @1,@7,@70,@9,@1],
            @[@"right", @"→", @"Menu right", @1,@20,@70,@9,@1],
            @[@"down", @"↓", @"Menu down", @1,@33,@70,@9,@1],
            @[@"left", @"←", @"Menu left", @1,@46,@70,@9,@1],
            @[@"map", @"MAP", @"Map / Field Guide", @0,@8,@79,@9,@1],
            @[@"menu", @"MENU", @"Pause menu", @0,@21,@79,@9,@1],
            @[@"exit", @"EXIT", @"Disconnect stream", @0,@34,@79,@9,@1],
        ];
        for (NSArray *spec in specs) {
            UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
            b.accessibilityIdentifier = spec[0];
            b.accessibilityLabel = spec[2];
            [b setTitle:spec[1] forState:UIControlStateNormal];
            b.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
            b.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.16];
            b.layer.borderColor = [UIColor.whiteColor colorWithAlphaComponent:0.65].CGColor;
            b.layer.borderWidth = 1;
            b.multipleTouchEnabled = NO;
            // Store immutable layout metadata on a separate accessibility-free layer.
            [b.layer setValue:spec forKey:@"hogwartsSpec"];
            [b addTarget:self action:@selector(buttonDown:) forControlEvents:UIControlEventTouchDown];
            [b addTarget:self action:@selector(buttonUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
            [_buttons addObject:b];
            [self addSubview:b];
        }
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(suspendInput:) name:UIApplicationWillResignActiveNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(resumeInput:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)suspendInput:(NSNotification *)note { [self releaseAll]; _suspended = YES; }
- (void)resumeInput:(NSNotification *)note { _suspended = NO; }
- (void)willMoveToSuperview:(UIView *)newSuperview {
    if (!newSuperview) [self releaseAll];
    [super willMoveToSuperview:newSuperview];
}
- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (!self.window) [self releaseAll];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    if (!CGSizeEqualToSize(_lastSize, self.bounds.size)) {
        [self releaseAll];
        _lastSize = self.bounds.size;
    }
    UIScreen *screen = self.window.screen ?: UIScreen.mainScreen;
    CGFloat screenWidth = MAX(screen.bounds.size.width, screen.bounds.size.height);
    _unit = MIN(6.1, MAX(4.0, screenWidth / 157.7163));
    // Fit on the cover display as well; unfolded Duo retains physical calibration.
    _unit = MIN(_unit, MIN(self.bounds.size.width / 110.0, self.bounds.size.height / 88.0));
    for (UIButton *b in _buttons) {
        NSArray *s = [b.layer valueForKey:@"hogwartsSpec"];
        CGFloat d = MAX(44, [s[6] doubleValue] * _unit);
        BOOL right = [s[3] boolValue];
        CGFloat inset = right ? self.safeAreaInsets.right : self.safeAreaInsets.left;
        CGFloat x = MAX(inset + d/2 + 2, [s[4] doubleValue] * _unit);
        if (right) x = self.bounds.size.width - x;
        CGFloat y = self.bounds.size.height - MAX(self.safeAreaInsets.bottom + d/2 + 2, [s[5] doubleValue] * _unit);
        b.frame = CGRectMake(x-d/2, y-d/2, d, d);
        b.layer.cornerRadius = d/2;
        b.hidden = [s[7] boolValue] && !_drawer;
    }
    [self setNeedsDisplay];
}

- (int)flagForAction:(NSString *)a {
    if ([a isEqual:@"shield"]) return Y_FLAG;
    if ([a isEqual:@"dodge"]) return B_FLAG;
    if ([a isEqual:@"jump"]) return A_FLAG;
    if ([a isEqual:@"interact"]) return X_FLAG;
    if ([a isEqual:@"heal"] || [a isEqual:@"down"]) return DOWN_FLAG;
    if ([a isEqual:@"revelio"] || [a isEqual:@"left"]) return LEFT_FLAG;
    if ([a isEqual:@"up"]) return UP_FLAG;
    if ([a isEqual:@"right"]) return RIGHT_FLAG;
    if ([a isEqual:@"throw"]) return RB_FLAG;
    if ([a isEqual:@"tools"]) return LB_FLAG;
    if ([a isEqual:@"ancient"]) return LB_FLAG | RB_FLAG;
    if ([a isEqual:@"lock"]) return RS_CLK_FLAG;
    if ([a isEqual:@"map"]) return BACK_FLAG;
    if ([a isEqual:@"menu"]) return PLAY_FLAG;
    return 0;
}
- (int)heldFlags {
    int flags = _sprint ? LS_CLK_FLAG : 0;
    for (NSString *a in _held) flags |= [self flagForAction:a];
    return flags;
}
- (void)sendState {
    [_support updateButtonFlags:_controller flags:[self heldFlags] | _pulseFlags];
    [_support updateLeftStick:_controller x:_lx y:_ly];
    [_support updateRightStick:_controller x:_rx y:_ry];
    [_support updateTriggers:_controller left:[_held containsObject:@"aim"] ? 255 : 0 right:_pulseRT];
    [_support updateFinished:_controller];
}
- (void)cancelPulse {
    ++_generation;
    [_queue removeAllObjects];
    _pulseFlags = 0;
    _pulseRT = 0;
    _busy = NO;
    [self sendState];
}
- (void)releaseAll {
    ++_cameraGeneration;
    _moveTouch = nil; _cameraTouch = nil;
    _lx = _ly = _rx = _ry = 0;
    _sprint = NO;
    [_held removeAllObjects];
    [self cancelPulse];
    for (UIButton *b in _buttons) b.alpha = 1;
    [self setNeedsDisplay];
}

// Serialize RT+face/dpad chords. RT is released before defensive buttons so
// Protego cannot accidentally become the spell assigned to Y.
- (void)runNextPulse {
    int conflict = A_FLAG | B_FLAG | X_FLAG | Y_FLAG | UP_FLAG | DOWN_FLAG | LEFT_FLAG | RIGHT_FLAG;
    if (_busy || !_queue.count || ([self heldFlags] & conflict) || _suspended) return;
    int flags = _queue.firstObject.intValue;
    [_queue removeObjectAtIndex:0];
    _busy = YES;
    NSUInteger generation = ++_generation;
    _pulseRT = 255;
    [self sendState];
    __weak HogwartsControls *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 40 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        HogwartsControls *s = weakSelf;
        if (!s || s->_generation != generation) return;
        s->_pulseFlags = flags;
        [s sendState];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 110 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        HogwartsControls *s = weakSelf;
        if (!s || s->_generation != generation) return;
        s->_pulseFlags = 0; s->_pulseRT = 0;
        [s sendState];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 150 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        HogwartsControls *s = weakSelf;
        if (!s || s->_generation != generation) return;
        s->_busy = NO;
        [s runNextPulse];
    });
}
- (void)buttonDown:(UIButton *)button {
    if (_suspended) return;
    NSString *a = button.accessibilityIdentifier;
    button.alpha = 0.55;
    if ([a isEqual:@"exit"]) {
        [self releaseAll];
        [_support requestStreamExit];
        return;
    }
    if ([a isEqual:@"more"]) {
        [self releaseAll];
        _drawer = !_drawer;
        [self setNeedsLayout];
        return;
    }
    if ([a isEqual:@"sprint"]) {
        _sprint = !_sprint;
        [self sendState];
        return;
    }
    if ([a isEqual:@"cast"] || [a hasPrefix:@"spell"] || [a hasPrefix:@"set"]) {
        int flags = 0;
        if ([a hasPrefix:@"spell"]) {
            const int spells[] = {Y_FLAG, B_FLAG, A_FLAG, X_FLAG};
            flags = spells[[a substringFromIndex:5].intValue-1];
        } else if ([a hasPrefix:@"set"]) {
            const int sets[] = {UP_FLAG, RIGHT_FLAG, DOWN_FLAG, LEFT_FLAG};
            flags = sets[[a substringFromIndex:3].intValue-1];
        }
        if (_queue.count < 3) [_queue addObject:@(flags)];
        [self runNextPulse];
        return;
    }
    [self cancelPulse];
    [_held addObject:a];
    [self sendState];
}
- (void)buttonUp:(UIButton *)button {
    button.alpha = 1;
    [_held removeObject:button.accessibilityIdentifier];
    [self sendState];
    [self runNextPulse];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (_suspended) return;
    for (UITouch *touch in touches) {
        if (touch.type != UITouchTypeDirect) continue;
        CGPoint p = [touch locationInView:self];
        if (p.x < self.bounds.size.width * .45 && !_moveTouch) {
            _moveTouch = touch;
            _origin = _movePoint = p;
        } else if (p.x >= self.bounds.size.width * .45 && !_cameraTouch) {
            _cameraTouch = touch;
            _cameraPoint = p;
        }
    }
    [self setNeedsDisplay];
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        CGPoint p = [touch locationInView:self];
        if (touch == _moveTouch) {
            CGFloat dx = p.x - _origin.x, dy = p.y - _origin.y;
            CGFloat radius = MAX(24, 6 * _unit), distance = hypot(dx, dy);
            CGFloat factor = distance > radius ? radius / distance : 1;
            _movePoint = CGPointMake(_origin.x + dx*factor, _origin.y + dy*factor);
            CGFloat magnitude = distance/radius;
            CGFloat output = magnitude < .12 ? 0 : MIN(1, (magnitude-.12)/.88);
            _lx = distance > 0 ? 32766 * dx/distance * output : 0;
            _ly = distance > 0 ? -32766 * dy/distance * output : 0;
        } else if (touch == _cameraTouch) {
            _rx = 32766 * MAX(-1, MIN(1, (p.x-_cameraPoint.x)/12));
            _ry = -32766 * MAX(-1, MIN(1, (p.y-_cameraPoint.y)/12));
            _cameraPoint = p;
            NSUInteger generation = ++_cameraGeneration;
            __weak HogwartsControls *weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 65*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                HogwartsControls *s = weakSelf;
                if (!s || generation != s->_cameraGeneration) return;
                s->_rx = s->_ry = 0;
                [s sendState];
            });
        }
    }
    [self sendState];
    [self setNeedsDisplay];
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *touch in touches) {
        if (touch == _moveTouch) { _moveTouch = nil; _lx = _ly = 0; _sprint = NO; }
        if (touch == _cameraTouch) { _cameraTouch = nil; _rx = _ry = 0; ++_cameraGeneration; }
    }
    [self sendState];
    [self setNeedsDisplay];
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self releaseAll]; }
- (void)drawRect:(CGRect)rect {
    if (!_moveTouch) return;
    CGFloat radius = 10*_unit;
    [[UIColor.whiteColor colorWithAlphaComponent:.45] setStroke];
    UIBezierPath *base = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(_origin.x-radius, _origin.y-radius, radius*2, radius*2)];
    base.lineWidth = 1;
    [base stroke];
    CGFloat knob = 4*_unit;
    [[UIColor.whiteColor colorWithAlphaComponent:.25] setFill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(_movePoint.x-knob, _movePoint.y-knob, knob*2, knob*2)] fill];
}
@end
