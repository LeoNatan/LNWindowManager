//
//  LNWindowManager.m
//  LNWindowManager
//
//  Created by Leo Natan on 4/4/13.
//
//

#import "LNWindowManager.h"
@import ObjectiveC;

//Helper subclasses
@interface _LNWindowPresentationHelperView : UIView @end
@implementation _LNWindowPresentationHelperView @end

@interface _LNWindowPresentationHelperViewController : UIViewController

@property (nonatomic, getter = isDismissingOrPresenting) BOOL dismissingOrPresenting;
@property (nonatomic, weak) UIWindow* window;

@end
@implementation _LNWindowPresentationHelperViewController
{
	NSUInteger _state;
}

- (void)loadView
{
	self.view = [_LNWindowPresentationHelperView new];
}

//Note: Not calling super implementation on purpose to supress iOS bug causing an "Unbalanced calls to begin/end appearance transitions" warning.

-(void)viewWillAppear:(BOOL)animated
{
	NSAssert(self.isDismissingOrPresenting, @"Window <%@, %p> dismissed incorrectly.\n\nStack trace:\n\n%@", self.window.class, self.window, [NSThread callStackSymbols]);
}

-(void)viewDidAppear:(BOOL)animated
{
}

- (void)viewWillDisappear:(BOOL)animated
{
}

- (void)viewDidDisappear:(BOOL)animated
{
}

@end

@interface _CPTemplateWindow : UIWindow @end
@implementation _CPTemplateWindow @end

@interface UIWindow (WindowPresentationPrivate)

-(void)setPresentingWindow:(UIWindow *)presentingWindow;

@end

@implementation UIWindow (WindowPresentation)

- (void)presentWindow:(UIWindow*)window animated:(BOOL)animated completion:(void (^)(void))completion
{
	[[LNWindowManager sharedWindowManager] presentWindow:window fromWindow:self animated:animated completion:completion];
}

- (void)dismissWindow:(UIWindow*)window animated:(BOOL)animated completion:(void (^)(void))completion
{
	[[LNWindowManager sharedWindowManager] dismissWindow:window fromWindow:self animated:animated completion:completion];
}

- (NSArray*)presentedWindows
{
	return [[LNWindowManager sharedWindowManager] presentedWindowsFromWindow:self];
}

- (UIWindow*)presentingWindow
{
	return objc_getAssociatedObject(self, "prop__presentingWindow");
}

- (void)setPresentingWindow:(UIWindow*)presentingWindow
{
	objc_setAssociatedObject(self, "prop__presentingWindow", presentingWindow, OBJC_ASSOCIATION_ASSIGN);
}

@end

static __strong LNWindowManager* __sharedWindowManagerInstance;

@implementation LNWindowManager
{
	NSMutableDictionary* _windowPresentationMapping;
	UIWindow* _topWindow;
	
	__strong UIViewController* test;
}

+(void)load
{
	[LNWindowManager sharedWindowManager];
}

+(LNWindowManager*)sharedWindowManager
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		__sharedWindowManagerInstance = [LNWindowManager new];
		__sharedWindowManagerInstance->_windowPresentationMapping = [NSMutableDictionary new];
		
		[[NSNotificationCenter defaultCenter] addObserver:__sharedWindowManagerInstance selector:@selector(_windowDidBecomeKeyNotification:) name:UIWindowDidBecomeKeyNotification object:nil];
#ifdef LN_WINDOW_MANAGER_DEBUG
		[[NSNotificationCenter defaultCenter] addObserver:__sharedWindowManagerInstance selector:@selector(_windowDidResignKeyNotification:) name:UIWindowDidResignKeyNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:__sharedWindowManagerInstance selector:@selector(_windowDidBecomeHiddenNotification:) name:UIWindowDidBecomeHiddenNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:__sharedWindowManagerInstance selector:@selector(_windowDidBecomeVisibleNotification:) name:UIWindowDidBecomeVisibleNotification object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:__sharedWindowManagerInstance selector:@selector(_keyboardWillShowNotification:) name:UIKeyboardWillShowNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:__sharedWindowManagerInstance selector:@selector(_keyboardWillHideNotification:) name:UIKeyboardWillHideNotification object:nil];
#endif
	});
	
	return __sharedWindowManagerInstance;
}

+ (UIColor*)defaultBarTintColor
{
	CGFloat red, green, blue, alpha;
	
	[[LNWindowManager defaultTintColor] getRed:&red green:&green blue:&blue alpha:&alpha];
	
	return [UIColor colorWithRed:0.05 green:green * 0.88f blue:blue * 1.0f alpha:alpha];
}

+ (UIColor*)defaultTintColor
{
	return [UIColor colorWithRed:34.0f / 255.0f green:131.0f / 255.0f blue:206.0f / 255.0f alpha:1.0f];
}

+ (UIWindow*)templateWindowForName:(NSString*)name
{
	Class class = [_CPTemplateWindow class];
	
	if(name != nil)
	{
		NSString* className = [NSString stringWithFormat:@"_CPTemplateWindow_%@", name];
		
		//See if our new class already exists.
		class = objc_getClass(className.UTF8String);
		
		if(class == nil)
		{
			//Create a new class, which is subclass of the view's class.
			class = objc_allocateClassPair([_CPTemplateWindow class], className.UTF8String, 0);
			
			//Register the new class in the objective C runtime.
			objc_registerClassPair(class);
		}
	}
	
	UIWindow* templateWindow = [[class alloc] initWithFrame:[UIScreen mainScreen].bounds];
	templateWindow.windowLevel = UIWindowLevelNormal;
	templateWindow.hidden = YES;
	[templateWindow setTintColor:[self defaultTintColor]];
	
	return templateWindow;
}

- (void)dismissKeyboard
{
#ifdef LN_WINDOW_MANAGER_DEBUG
	NSLog(@"Dismissing keyboards");
#endif
	
	//Use responder chain to resign first responder and dismiss the keyboard.
	[[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];
}

-(void)_windowDidBecomeKeyNotification:(NSNotification*)notification
{
#ifdef LN_WINDOW_MANAGER_DEBUG
	NSLog(@"Window <%@, %p> did become key", [notification.object class], notification.object);
#endif
	
	if(_topWindow == nil)
	{
        UIWindow* topWindow = notification.object;
        
        if(NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_6_1 && [topWindow.class.description rangeOfString:@"UIAlert"].location != NSNotFound)
        {
            return;
        }
        
		//Take first key window as top.
		_topWindow = topWindow;
	}
}

#ifdef LN_WINDOW_MANAGER_DEBUG
-(void)_windowDidResignKeyNotification:(NSNotification*)notification
{
	NSLog(@"Window <%@, %p> did resign key", [notification.object class], notification.object);
}

-(void)_windowDidBecomeVisibleNotification:(NSNotification*)notification
{
	NSLog(@"Window <%@, %p> did become visible", [notification.object class], notification.object);
}

-(void)_windowDidBecomeHiddenNotification:(NSNotification*)notification
{
	NSLog(@"Window <%@, %p> did become hidden", [notification.object class], notification.object);
}

-(void)_keyboardWillShowNotification:(NSNotification*)notification
{
	NSLog(@"Window <%@, %p> will show keyboard", [UIApplication sharedApplication].keyWindow, [UIApplication sharedApplication].keyWindow);
}

-(void)_keyboardWillHideNotification:(NSNotification*)notification
{
	NSLog(@"Window <%@, %p> will hide keyboard", [UIApplication sharedApplication].keyWindow, [UIApplication sharedApplication].keyWindow);
}
#endif

////

-(void)presentWindowFromKeyWindow:(UIWindow*)presentedWindow animated:(BOOL)animated completion:(void (^)(void))completion
{
	[self presentWindow:presentedWindow fromWindow:[UIApplication sharedApplication].keyWindow animated:animated completion:completion];
}

-(void)presentWindow:(UIWindow *)presentedWindow fromWindow:(UIWindow*)presentingWindow animated:(BOOL)animated completion:(void (^)(void))completion
{
    if(presentingWindow.isKeyWindow)
    {
        [self dismissKeyboard];
    }

	NSAssert(presentedWindow != presentingWindow, @"Presenting window cannot be equal to presented window: <%@, %p>", presentedWindow.class, presentedWindow);
	NSAssert(presentedWindow.presentingWindow == nil, @"Window <%@, %p> is already presented by window <%@, %p>.", presentedWindow.class, presentedWindow, presentedWindow.presentingWindow.class, presentedWindow.presentingWindow);
	
	NSValue* key = [NSValue valueWithNonretainedObject:presentingWindow];
	
	NSMutableArray* presentedWindows = _windowPresentationMapping[key];
	if(presentedWindows == nil)
	{
		presentedWindows = [NSMutableArray new];
	}
	
	[presentedWindows addObject:presentedWindow];
	
	CGRect frame = presentedWindow.frame;
	frame.origin.x = 0;
	frame.origin.y = 0;
	[presentedWindow setFrame:frame];
	
	_LNWindowPresentationHelperViewController* empty = [_LNWindowPresentationHelperViewController new];
	UIViewController* presentedRootVC = presentedWindow.rootViewController;
	presentedRootVC.view.transform = CGAffineTransformIdentity;
	
	presentedWindow.rootViewController = empty;
	
	if(presentingWindow.isKeyWindow)
	{
		[presentedWindow makeKeyWindow];
	}
	
	[empty setDismissingOrPresenting:YES];
	[empty setWindow:presentingWindow];
	
	presentedWindow.alpha = 1.0f;
	presentedWindow.hidden = NO;
	
//	[presentedWindow.rootViewController viewDidAppear:NO];
	
	_topWindow = presentedWindow;
	[presentedWindow setPresentingWindow:presentingWindow];
    
    presentingWindow.windowLevel = UIWindowLevelNormal;
    presentedWindow.windowLevel = UIWindowLevelNormal + 1;
	
#ifdef LN_WINDOW_MANAGER_DEBUG
	NSLog(@"Presenting window <%@, %p> from window <%@, %p>", presentedWindow.class, presentedWindow, presentingWindow.class, presentingWindow);
#endif
	
	[presentedRootVC.view setOpaque:NO];

	[empty presentViewController:presentedRootVC animated:animated completion:^
	 {
		 [(_LNWindowPresentationHelperViewController*)presentedWindow.rootViewController setDismissingOrPresenting:NO];
		 
		 if(NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1 && presentedRootVC.modalPresentationStyle == UIModalPresentationFullScreen)
		 {
			 [presentingWindow setHidden:YES];
		 }
		 
		 if(completion != nil)
		 {
			 completion();
		 }
	 }];
	
	_windowPresentationMapping[key] = presentedWindows;
}

- (void)dismissWindowFromKeyWindow:(UIWindow *)presentedWindow animated:(BOOL)animated completion:(void (^)(void))completion
{
	[self dismissWindow:presentedWindow fromWindow:[UIApplication sharedApplication].keyWindow animated:animated completion:completion];
}

- (void)dismissWindow:(UIWindow *)presentedWindow fromWindow:(UIWindow *)presentingWindow animated:(BOOL)animated completion:(void (^)(void))completion
{
	NSAssert(presentedWindow != presentingWindow, @"Dissmising window cannot be equal to presented window: <%@, %p>", presentedWindow.class, presentedWindow);
	NSAssert(presentedWindow.presentingWindow == presentingWindow, @"Window <%@, %p> has not been presented by window <%@, %p>", presentedWindow.class, presentedWindow, presentingWindow.class, presentingWindow);
    
	BOOL shouldMakeKey = NO;
	
	if(presentedWindow.isKeyWindow)
	{
		[self dismissKeyboard];
		
		shouldMakeKey = YES;
	}
	
	NSValue* key = [NSValue valueWithNonretainedObject:presentingWindow];
	
	NSMutableArray* presentedWindows = _windowPresentationMapping[key];
	if(presentedWindows == nil)
	{
		presentedWindows = [NSMutableArray new];
	}
	
	NSMutableArray* cleanup = [NSMutableArray new];
	
	_windowPresentationMapping[key] = presentedWindows;
	
	_topWindow = presentingWindow;
	
    // Dismiss child windows recuresively
	for (UIWindow* window in presentedWindow.presentedWindows) {
		[presentedWindow dismissWindow:window animated:NO completion:nil];
	}
	
	if([presentingWindow.rootViewController respondsToSelector:@selector(setDismissingOrPresenting:)])
	{
		[(_LNWindowPresentationHelperViewController*)presentingWindow.rootViewController setDismissingOrPresenting:YES];
	}
	
	[presentingWindow.rootViewController viewWillAppear:animated];
	
	[(_LNWindowPresentationHelperViewController*)presentedWindow.rootViewController setDismissingOrPresenting:YES];
	
#ifdef LN_WINDOW_MANAGER_DEBUG
	NSLog(@"Dismissing window <%@, %p> from window <%@, %p>", presentedWindow.class, presentedWindow, presentingWindow.class, presentingWindow);
#endif
	
	if(NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1 && presentedWindow.rootViewController.presentedViewController.modalPresentationStyle == UIModalPresentationFullScreen)
	{
		[presentingWindow setHidden:NO];
	}
	
	[presentedWindow.rootViewController dismissViewControllerAnimated:animated completion: ^
	 {
		 [presentingWindow.rootViewController viewDidAppear:animated];
         
         presentingWindow.windowLevel = UIWindowLevelNormal + 1;
		 
		 if([presentingWindow.rootViewController respondsToSelector:@selector(setDismissingOrPresenting:)])
		 {
			 [(_LNWindowPresentationHelperViewController*)presentingWindow.rootViewController setDismissingOrPresenting:NO];
		 }
		 
		 [presentedWindow setPresentingWindow:nil];
		 
		 if(completion != nil)
		 {
			 completion();
		 }
		 
		 [presentedWindow setRootViewController:nil];
		 
		 if(shouldMakeKey)
		 {
			 [presentingWindow makeKeyWindow];
		 }
		 
		 [presentedWindow setHidden:YES];
		 
		 [(_LNWindowPresentationHelperViewController*)presentedWindow.rootViewController setDismissingOrPresenting:NO];
		 [(_LNWindowPresentationHelperViewController*)presentedWindow.rootViewController setWindow:nil];
		 
		 [cleanup addObject:presentedWindow];
		 [presentedWindows removeObject:presentedWindow];
		 
		 //Perform cleanup late in the game to allow iOS7 UIWindow logic to complete gracefully.
		 dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			 [cleanup removeAllObjects];
		 });
	 }];
}

-(NSArray*)presentedWindowsFromKeyWindow
{
	return [self presentedWindowsFromWindow:[UIApplication sharedApplication].keyWindow];
}

-(NSArray*)presentedWindowsFromWindow:(UIWindow*)presentingWindow
{
	NSValue* key = [NSValue valueWithNonretainedObject:presentingWindow];
	
	NSMutableArray* presentedWindows = _windowPresentationMapping[key];
	
	return presentedWindows == nil ? @[] : presentedWindows;
}

-(UIWindow*)topWindow
{
	return _topWindow;
}

@end
