//
//  SDPullNavigationBar.m
//  ios-shared

//
//  Created by Brandon Sneed on 08/06/2013.
//  Copyright 2013-2014 SetDirection. All rights reserved.
//

#import "SDPullNavigationBar.h"

#import "SDPullNavigationBarBackground.h"
#import "SDPullNavigationBarTabButton.h"
#import "SDPullNavigationManager.h"
#import "UIDevice+machine.h"
#import "UIColor+SDExtensions.h"

static const CGFloat kDefaultMenuWidth = 320.0f;

@interface SDPullNavigationMenuContainer : UIView   // This custom class used for debugging purposes.
@end

#pragma mark - SDPullNavigationBar

@interface SDPullNavigationBar()<UIGestureRecognizerDelegate>

@property (nonatomic, strong) SDPullNavigationBarBackground* pullBackgroundView;
@property (nonatomic, strong) SDPullNavigationBarTabButton* tabButton;
@property (nonatomic, strong) SDPullNavigationMenuContainer* menuContainer;
@property (nonatomic, strong) UIImageView* menuBackgroundEffectsView;
@property (nonatomic, strong) UIImageView* menuBottomAdornmentView;
@property (nonatomic, assign) BOOL animating;
@property (nonatomic, assign) BOOL tabOpen;
@property (nonatomic, assign) CGFloat menuWidth;

@end

@implementation SDPullNavigationBar

+ (void)setupDefaults
{
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:NO];

    [[UIBarButtonItem appearance] setBackButtonTitlePositionAdjustment:UIOffsetMake(-9999, -9999) forBarMetrics:UIBarMetricsDefault];

    SDPullNavigationBar* pullBarAppearance = [SDPullNavigationBar appearance];
    if ([UIDevice bcdSystemVersion] >= 0x070000)
    {
        pullBarAppearance.barTintColor = [UIColor colorWith8BitRed:29 green:106 blue:166 alpha:1.0f];
        pullBarAppearance.titleTextAttributes = @{ UITextAttributeTextColor : [UIColor whiteColor] };
        pullBarAppearance.tintColor = [UIColor whiteColor];
    }
    else
    {
        pullBarAppearance.tintColor = [UIColor colorWith8BitRed:23 green:108 blue:172 alpha:1.0];
    }
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self != nil)
    {
        [self commonInit];
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)commonInit
{
    self.translucent = NO;

    // I tagged all of the view to be able to find them quickly when I am viewing the hierarchy in Spark Inspector or Reveal.
    {
        _pullBackgroundView = [[SDPullNavigationBarBackground alloc] init];
        _pullBackgroundView.autoresizesSubviews = YES;
        _pullBackgroundView.userInteractionEnabled = NO;
        _pullBackgroundView.opaque = NO;
        _pullBackgroundView.backgroundColor = [UIColor clearColor];
        _pullBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _pullBackgroundView.delegate = (id<SDPullNavigationBarOverlayProtocol>)self;
        _pullBackgroundView.frame = self.bounds;
        _pullBackgroundView.tag = 1;
    }

    {
        _tabButton = [[SDPullNavigationBarTabButton alloc] initWithNavigationBar:self];
        _tabButton.tag = 2;
    }

    [self insertSubview:_pullBackgroundView atIndex:1];
    [self addSubview:_tabButton];

    {
        _menuContainer = [[SDPullNavigationMenuContainer alloc] initWithFrame:self.superview.bounds];
        _menuContainer.clipsToBounds = YES;
        _menuContainer.backgroundColor = [UIColor clearColor];
        _menuContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _menuContainer.translatesAutoresizingMaskIntoConstraints = YES;
        _menuContainer.opaque = NO;

        _menuContainer.layer.shadowColor = [UIColor blackColor].CGColor;
        _menuContainer.layer.shadowOffset = CGSizeMake(0, -3.0);
        _menuContainer.layer.shadowRadius = 3.0f;
        _menuContainer.layer.shadowOpacity = 1.0;
        _menuContainer.tag = 3;
    }

    {
        _menuBackgroundEffectsView = [[UIImageView alloc] initWithFrame:_menuContainer.bounds];
        _menuBackgroundEffectsView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _menuBackgroundEffectsView.clipsToBounds = YES;
        _menuBackgroundEffectsView.backgroundColor = [@"#00000033" uicolor];
        _menuBackgroundEffectsView.opaque = NO;
        _menuBackgroundEffectsView.tag = 4;
        [_menuContainer addSubview:_menuBackgroundEffectsView];
    }

    {
        UIStoryboard* menuStoryBoard = [UIStoryboard storyboardWithName:[SDPullNavigationManager sharedInstance].globalMenuStoryboardId bundle:nil];
        _menuController = [menuStoryBoard instantiateInitialViewController];
        _menuController.view.clipsToBounds = YES;
        _menuController.view.opaque = YES;
        _menuController.view.tag = 5;
        _menuController.view.translatesAutoresizingMaskIntoConstraints = YES;
        _menuController.pullNavigationBarDelegate = self;
        [_menuContainer addSubview:_menuController.view];
        UITapGestureRecognizer* dismissTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissTapAction:)];
        dismissTapGesture.delegate = self;
        [_menuContainer addGestureRecognizer:dismissTapGesture];
    }

    UIImage* menuAdornmentImage = [SDPullNavigationManager sharedInstance].menuAdornmentImage;
    if(menuAdornmentImage)
    {
        _menuBottomAdornmentView = [[UIImageView alloc] initWithFrame:(CGRect){CGPointZero, { _menuController.view.bounds.size.width, menuAdornmentImage.size.height }}];
        _menuBottomAdornmentView.clipsToBounds = YES;
        _menuBottomAdornmentView.backgroundColor = [UIColor clearColor];
        _menuBottomAdornmentView.opaque = YES;
        _menuBottomAdornmentView.image = menuAdornmentImage;
        _menuBottomAdornmentView.tag = 6;
        [_menuContainer addSubview:_menuBottomAdornmentView];
    }

    _menuWidth = kDefaultMenuWidth;
    if([_menuController respondsToSelector:@selector(pullNavigationMenuWidth)])
        _menuWidth = _menuController.pullNavigationMenuWidth;

    // Setup the starting point for the first opening animation.

    CGRect menuFrame = _menuController.view.frame;
    menuFrame.size.height = MIN(_menuController.pullNavigationMenuHeight, self.availableHeight);
    _menuController.view.frame = menuFrame;
    _menuBottomAdornmentView.frame = (CGRect){{menuFrame.origin.x, menuFrame.origin.y + menuFrame.size.height}, _menuBottomAdornmentView.frame.size};

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(statusBarWillChangeRotationNotification:)
                                                 name:UIApplicationWillChangeStatusBarOrientationNotification
                                               object:nil];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    NSInteger index = 0;
    if(self.subviews.count > 0)
        index = 1;

    CGFloat tabOffset = 8.0f;

    CGPoint navBarCenter = self.center;
    CGRect tabFrame = self.tabButton.frame;
    tabFrame.origin.x = (navBarCenter.x - (tabFrame.size.width * 0.5f));
    tabFrame.origin.y = self.bounds.size.height - (tabFrame.size.height - tabOffset);
    self.tabButton.frame = CGRectIntegral(tabFrame);

    [self insertSubview:self.pullBackgroundView atIndex:index];
    [self addSubview:self.tabButton];

    self.menuContainer.frame = self.superview.frame;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    self.pullBackgroundView.frame = self.bounds;
}

- (void)drawOverlayRect:(CGRect)rect
{
    // default implementation does nothing.
}

- (void)tapAction:(id)sender
{
    [self togglePullMenuWithCompletionBlock:nil];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer*)gestureRecognizer shouldReceiveTouch:(UITouch*)touch
{
    return ![touch.view isDescendantOfView:self.menuController.view];
}

- (void)dismissTapAction:(UITapGestureRecognizer*)sender
{
    if(self.tabOpen)
        [self dismissPullMenuWithCompletionBlock:nil];
}

#pragma mark - Helpers

+ (UINavigationController*)navControllerWithViewController:(UIViewController*)viewController
{
    UINavigationController *navController = [[UINavigationController alloc] initWithNavigationBarClass:[self class] toolbarClass:nil];
    [navController setViewControllers:@[viewController]];
    navController.delegate = [SDPullNavigationManager sharedInstance];
    return navController;
}

- (void)statusBarWillChangeRotationNotification:(NSNotification*)notification
{
    [self dismissPullMenuWithoutAnimation];
}

- (void)togglePullMenuWithCompletionBlock:(void (^)(void))completion
{
    if(!self.animating)
    {
        self.animating = YES;

        if([UIDevice iPad] && !self.tabOpen)
        {
            self.menuController.view.frame = (CGRect){{ self.frame.size.width * 0.5f - 160.0f, 64.0f }, { self.menuWidth, 0.0f } };
            self.menuBottomAdornmentView.frame = (CGRect){ { self.menuController.view.frame.origin.x, self.menuController.view.frame.origin.y + self.menuController.view.frame.size.height },
                                                           { self.menuController.view.frame.size.width, [SDPullNavigationManager sharedInstance].menuAdornmentImage.size.height } };
        }

        [self.superview insertSubview:self.menuContainer belowSubview:self];
        self.menuContainer.hidden = NO;

        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^
        {
            self.tabButton.tuckedTab = !self.tabOpen;
            if(!self.tabOpen)
                [self.tabButton setNeedsDisplay];

            CGFloat height = self.tabOpen ? 0.0f : MIN(self.menuController.pullNavigationMenuHeight, self.availableHeight);
            CGFloat width = [UIDevice iPad] ? self.menuWidth : self.menuController.view.frame.size.width;

            self.menuController.view.frame = (CGRect){ { self.frame.size.width * 0.5f - self.menuController.view.bounds.size.width * 0.5f, self.frame.size.height + 20.0f }, { width, height } };
            self.menuBottomAdornmentView.frame = (CGRect){{self.menuController.view.frame.origin.x, self.menuController.view.frame.origin.y + self.menuController.view.frame.size.height }, self.menuBottomAdornmentView.frame.size };

            self.tabOpen = !self.tabOpen;
         }
         completion:^(BOOL finished)
         {
             if(self.tabOpen == NO)
                 [self.tabButton setNeedsDisplay];
             self.animating = NO;
             self.menuContainer.hidden = !self.tabOpen;
             self.menuBottomAdornmentView.hidden = !self.tabOpen;

             if(self.tabOpen == NO)
                 [self.menuContainer removeFromSuperview];

             if(completion)
                 completion();
         }];
    }
    else
    {
        // Don't forget that if we did not need to dismiss the menu, then we should still call the completion block.
        if(completion)
            completion();
    }
}

- (void)dismissPullMenuWithoutAnimation
{
    self.menuContainer.hidden = YES;

    self.tabButton.tuckedTab = YES;
    CGFloat width = [UIDevice iPad] ? self.menuWidth : self.menuController.view.frame.size.width;

    self.menuController.view.frame = (CGRect){ { self.frame.size.width * 0.5f - self.menuController.view.bounds.size.width * 0.5f, self.frame.size.height + 20.0f }, { width, 0.0f } };
    self.menuBottomAdornmentView.frame = (CGRect){{self.menuController.view.frame.origin.x, self.menuController.view.frame.origin.y + self.menuController.view.frame.size.height }, self.menuBottomAdornmentView.frame.size };

    self.tabOpen = NO;
    self.menuBottomAdornmentView.hidden = YES;

    [self.menuContainer removeFromSuperview];
}

- (void)dismissPullMenuWithCompletionBlock:(void (^)(void))completion
{
    if(self.tabOpen)
    {
        [self togglePullMenuWithCompletionBlock:completion];
    }
}

- (CGFloat)availableHeight
{
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    UIWindow* topMostWindow = [UIApplication sharedApplication].windows.lastObject;
    CGSize topMostWindowSize = topMostWindow.bounds.size;
    CGFloat height = UIInterfaceOrientationIsPortrait(orientation) ? MAX(topMostWindowSize.height, topMostWindowSize.width) : MIN(topMostWindowSize.height, topMostWindowSize.width);

    CGFloat navHeight = self.frame.size.height;

    if(navHeight == 0.0f)
        navHeight += 44.0f;
    navHeight += MIN([UIApplication sharedApplication].statusBarFrame.size.height, [UIApplication sharedApplication].statusBarFrame.size.width);

    // Take into account the menuAdornment at the bottom of the menu and some extra so that the adornment does not butt up against the bottom of the screen.
    navHeight += _menuBottomAdornmentView.frame.size.height + (_menuBottomAdornmentView ? 2.0f : 0.0f);

    return height - navHeight;
}

@end

@implementation SDPullNavigationMenuContainer

#ifdef DEBUG

- (void)layoutSubviews
{
    [super layoutSubviews];

}

#endif

@end
