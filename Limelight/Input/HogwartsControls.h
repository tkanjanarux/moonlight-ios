#import <UIKit/UIKit.h>
@class ControllerSupport;

// Experimental controller overlay for the default Hogwarts Legacy Xbox bindings.
@interface HogwartsControls : UIView
- (instancetype)initWithFrame:(CGRect)frame controllerSupport:(ControllerSupport *)support;
- (void)releaseAll;
@end
