//
//  JWFlipNavigationController.m
//
//Copyright (c) 2013 John Willsund (john.willsund@gmail.com)
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in
//all copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//THE SOFTWARE.

#import <QuartzCore/QuartzCore.h>
#import "JWFlipNavigationController.h"
#import "JWFlipImageTools.h"

#define RELEASE_PAGE_MAX_DROP_DURATION .4

typedef enum {
  FlipDirectionNone,
  FlipDirectionLeft,
  FlipDirectionRight,
  FlipDirectionUp,
  FlipDirectionDown
} FlipDirection;

@interface JWFlipNavigationController ()

@property (nonatomic, assign) NSInteger currentPageIndex;

@property (nonatomic, strong) UIPanGestureRecognizer *recognizer;
@property (nonatomic, assign) CGPoint panStart;
@property (nonatomic, assign) CGFloat rotationRadius;
@property (nonatomic, assign) FlipDirection flipDirection;
@property (assign) BOOL isFlipping;

@property (nonatomic, strong) UIView *flipPage;
@property (nonatomic, strong) CATransformLayer *flipLayer;
@property (assign) BOOL didInitializeNewBackgroundImage;

@property (nonatomic, strong) UIImageView *firstHalfShadow;
@property (nonatomic, strong) UIImageView *secondHalfShadow;

 //Placeholder for new VC until added to self.viewControllers
@property (nonatomic, strong) UIViewController *nextViewController;


@end

@implementation JWFlipNavigationController

- (id)initWithRootViewController:(UIViewController *)rootViewController {
  
  self = [super initWithRootViewController:rootViewController];
  if (self) {
    self.navigationBarHidden = YES;
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  _recognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
  [self.view addGestureRecognizer:_recognizer];
  _recognizer.delegate = self;
  
}

- (UIViewController *)_viewControllerForIndex:(NSInteger)index {
  
  if (index < self.viewControllers.count) {
    return [self.viewControllers objectAtIndex:index];
  } else {
    UIViewController *controller = [self viewControllerForIndex:index];
    return controller;
  }
  
}

- (UIViewController *)viewControllerForIndex:(NSInteger)index {
  
  // Override this method to return view controllers at given index
  return nil;
  
}

- (void)setFirstHalfShadowOffset:(CGFloat)offset {
  
  CGRect frame = _firstHalfShadow.frame;

  if ([self flipMode] == FlipModeHorizontal) {
    frame.origin.x = [self pageWidth] / 2 - frame.size.width - offset;
  } else {
    frame.origin.y = [self pageHeight] / 2 - frame.size.height - offset;
  }
  _firstHalfShadow.frame = frame;
  
}

- (void)setSecondHalfShadowOffset:(CGFloat)offset {
  
  CGRect frame = _secondHalfShadow.frame;
  if ([self flipMode] == FlipModeHorizontal) {
    frame.origin.x = [self pageWidth] / 2 + offset;
  } else {
    frame.origin.y = [self pageHeight] / 2 + offset;
  }
  _secondHalfShadow.frame = frame;
  
}

- (void)initializePageViews {
  
  UIViewController *currentController = [self _viewControllerForIndex:_currentPageIndex];
  NSInteger nextIndex = ([self isFlippingForward]) ?
    (_currentPageIndex + 1) : (_currentPageIndex - 1);
  
  
  CGRect frame = currentController.view.frame;
  frame.origin.y = 20;
  _flipPage = [[UIView alloc] initWithFrame:frame];
  
  // Setting up the layer that will hold the back-to-back sublayers
  _flipLayer = [[CATransformLayer alloc] init];
  _flipLayer.anchorPoint = CGPointMake(.5, .5);
  _flipLayer.position = CGPointMake(frame.size.width / 2, frame.size.height / 2);
  _flipLayer.bounds = CGRectMake(0, 0, frame.size.width, frame.size.height);
  _flipLayer.doubleSided = YES;

  CALayer *firstHalfLayer;
  CALayer *secondHalfLayer;
  
  if ([self flipMode] == FlipModeHorizontal) {
    firstHalfLayer = [JWFlipImageTools leftHalfLayerFromView:currentController.view];
    secondHalfLayer = [JWFlipImageTools rightHalfLayerFromView:currentController.view];
    
    self.firstHalfShadow = [JWFlipImageTools leftGradientForFrame:CGRectMake(0,
                                                                             0,
                                                                             [self pageWidth] / 2,
                                                                             self.view.frame.size.height)];
    _firstHalfShadow.alpha = 0;
    
    _secondHalfShadow = [JWFlipImageTools rightGradientForFrame:_firstHalfShadow.frame];
    _secondHalfShadow.alpha = 0;

    
  } else {
    firstHalfLayer = [JWFlipImageTools topHalfLayerFromView:currentController.view];
    secondHalfLayer = [JWFlipImageTools bottomHalfLayerFromView:currentController.view];
    
    self.firstHalfShadow = [JWFlipImageTools topGradientForFrame:CGRectMake(0,
                                                                             0,
                                                                             self.view.frame.size.width,
                                                                             [self pageHeight] / 2)];
    _firstHalfShadow.alpha = 0;
    
    _secondHalfShadow = [JWFlipImageTools bottomGradientForFrame:_firstHalfShadow.frame];
    _secondHalfShadow.alpha = 0;

  }

  if ([self isFlippingForward]) {
    
    // When flipping left, the right half is inserted into the rotating layer,
    // the left half is left static in _flipPage.
    [_flipLayer addSublayer:secondHalfLayer];
    [_flipPage.layer addSublayer:firstHalfLayer];
    
    
  } else {
    
    // When flipping right, the left half is inserted into the rotating layer,
    // the right half is left static in _flipPage.
    [_flipLayer addSublayer:firstHalfLayer];
    [_flipPage.layer addSublayer:secondHalfLayer];
    
    UIViewController *nextView = [self _viewControllerForIndex:nextIndex];

    // Render layers for previous controller that is currently behind the current controller
    if ([self flipMode] == FlipModeHorizontal) {
      firstHalfLayer = [JWFlipImageTools leftHalfLayerFromView:nextView.view];
      secondHalfLayer = [JWFlipImageTools rightHalfLayerFromView:nextView.view];
    } else {
      firstHalfLayer = [JWFlipImageTools topHalfLayerFromView:nextView.view];
      secondHalfLayer = [JWFlipImageTools bottomHalfLayerFromView:nextView.view];
    }

    [_flipPage.layer insertSublayer:firstHalfLayer atIndex:0];
    
    // Rotate layer to end up on the back side of the flipping layer.
    if ([self flipMode] == FlipModeHorizontal) {
      secondHalfLayer.transform = CATransform3DMakeRotation(M_PI, 0, 1, 0);
    } else {
      secondHalfLayer.transform = CATransform3DMakeRotation(M_PI, 1, 0, 0);
    }
    [_flipLayer addSublayer:secondHalfLayer];

    
  }
  
  if ([self isFlippingForward]) {
    
    // After rendering the new view behind the current - set is as front view controller
    NSMutableArray *viewControllers = [NSMutableArray arrayWithArray:self.viewControllers];
    [viewControllers addObject:_nextViewController], _nextViewController = nil;
    self.viewControllers = viewControllers;
    
  }

  
  [_flipPage addSubview:_firstHalfShadow];
  [_flipPage addSubview:_secondHalfShadow];
  [_flipPage.layer addSublayer:_flipLayer];
  
  [self.view addSubview:_flipPage];

}

- (CGFloat)pageWidth {
  
  return self.topViewController.view.frame.size.width;
  
}

- (CGFloat)pageHeight {
  
  return self.topViewController.view.frame.size.height;
  
}


#pragma mark - Rotation
- (void)setRotationAngle:(CGFloat)angle forLayer:(CALayer *)layer animationDuration:(float)duration {
  
  [CATransaction begin];
  [CATransaction setAnimationDuration:duration];
  [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
  
  layer.transform = [self rotationTransformForAngle:angle];
  
  [CATransaction commit];
  
}

- (void)setRotationAngle:(CGFloat)angle forLayer:(CALayer *)layer {
  

  [CATransaction begin];
  [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
  
  layer.transform = [self rotationTransformForAngle:angle];
  
  [CATransaction commit];
  
}

- (CATransform3D)rotationTransformForAngle:(float)angle {
  float height = _rotationRadius * sinf(angle);
  float perspective = 0.0005 * height / _rotationRadius;
  
  CATransform3D transform;
  if ([self flipMode] == FlipModeHorizontal) {
    transform = CATransform3DMakeRotation(angle, 0, 1, 0);
    // Setting the perspective
    transform.m14 = perspective;
  } else {
    transform = CATransform3DMakeRotation(-angle, 1, 0, 0);
    // Setting the perspective
    transform.m24 = perspective;
  }
  return transform;
}

- (float)angleFromPosition:(CGPoint)pos {
  
  CGFloat panDelta;
  switch (_flipDirection) {

    case FlipDirectionLeft:
      panDelta = _panStart.x - pos.x;
      break;

    case FlipDirectionRight:
      panDelta = pos.x - _panStart.x;
      break;
      
    case FlipDirectionUp:
      panDelta = _panStart.y - pos.y;
      break;
      
    case FlipDirectionDown:
      panDelta = pos.y - _panStart.y;
      break;
      
    default:
#ifdef DEBUG
      NSLog(@"%s WARNING: Unhandled flip direction!", __PRETTY_FUNCTION__);
#endif
      break;
  }
  
  CGFloat cosineBase = _rotationRadius - panDelta;

  cosineBase = MAX(-_rotationRadius, MIN(_rotationRadius, cosineBase));
  CGFloat angle = acosf(cosineBase / _rotationRadius);
  return angle;
  
}
#pragma mark - Pan And Flip Control

- (void)renderNewViewsFirstHalfInFlipLayer {
  
  UIViewController *nextController = [self.viewControllers objectAtIndex:(_currentPageIndex + 1)];
  
  CALayer *firstHalf;
  CATransform3D transform;
  if ([self flipMode] == FlipModeHorizontal) {
    firstHalf = [JWFlipImageTools leftHalfLayerFromView:nextController.view];
    transform = CATransform3DMakeRotation(M_PI, 0, 1, 0);
  } else {
    firstHalf = [JWFlipImageTools topHalfLayerFromView:nextController.view];
    transform = CATransform3DMakeRotation(M_PI, 1, 0, 0);
  }

  firstHalf.transform = transform;
  
  [_flipLayer addSublayer:firstHalf];
  
}

- (FlipMode) flipMode {
  
  // Override this method to set vertical or horizontal flipping
  return FlipModeVertical;
  
}

- (BOOL)isFlippingForward {
  
  return _flipDirection == FlipDirectionLeft || _flipDirection == FlipDirectionUp;
  
}

- (void) updateShadowsForAngle:(float)angle {
  
  CGFloat maxOffset = [self flipMode] == FlipModeHorizontal ? [self pageWidth] / 2 : [self pageHeight] / 2;
  CGFloat shadowOffset = fabsf(maxOffset * cosf(angle));
  float shadowAlpha = shadowOffset / maxOffset;
  
  if (([self isFlippingForward] && angle < M_PI_2) ||
      (![self isFlippingForward] && angle > M_PI_2)) {
    
    _firstHalfShadow.alpha = 0;
    _secondHalfShadow.alpha = shadowAlpha;
    [self setSecondHalfShadowOffset:shadowOffset];
    
  } else {
    
    _secondHalfShadow.alpha = 0;
    _firstHalfShadow.alpha = shadowAlpha;
    [self setFirstHalfShadowOffset:shadowOffset];
    
  }
  
}

- (void)_panBegan:(UIGestureRecognizer *)recognizer {
  
  self.panStart = [recognizer locationInView:self.view.window];
  
  CGPoint position = [_recognizer locationInView:_recognizer.view];
  
  // Determine flip direction
  
  if ([self flipMode] == FlipModeHorizontal) {

    if (position.x > [self pageWidth] / 2) {
      _flipDirection = FlipDirectionLeft;
    } else {
      _flipDirection = FlipDirectionRight;
    }

  } else {
    if (position.y > [self pageHeight] / 2) {
      _flipDirection = FlipDirectionUp;
    } else {
      _flipDirection = FlipDirectionDown;
    }
  }
  
  _rotationRadius = ([self flipMode] == FlipModeHorizontal)
    ? fabsf(_panStart.x - self.view.frame.size.width / 2)
    : fabsf(_panStart.y - self.view.frame.size.height / 2);
  
  if (![self isFlippingForward] && _currentPageIndex == 0) {
    // Do not flip back past 0:th page
    _flipDirection = FlipDirectionNone;
    return;
  }
  
  _didInitializeNewBackgroundImage = NO;
  _isFlipping = YES;
  
  // If flipping to a new view controller - first check if one is available, else abort gesture.
  if ([self isFlippingForward]) {

    _nextViewController = [self _viewControllerForIndex:(_currentPageIndex + 1)];
    if (_nextViewController) {
      _nextViewController.view.frame = self.topViewController.view.frame;
      
    } else {
      _flipDirection = FlipDirectionNone;
      recognizer.enabled = NO;
      recognizer.enabled = YES;
      return;
    }
  }
  
  [self initializePageViews];

}


- (void)_panChanged:(UIGestureRecognizer *)recognizer {
  
  if (_flipDirection == FlipDirectionNone) {
    return;
  }
  

  CGFloat angle = [self angleFromPosition:[recognizer locationInView:self.view.window]];
  
  if ([self isFlippingForward]) {
    
    if (!_didInitializeNewBackgroundImage) {
      
      // If this view-half hasn't been rendered yet, do it now
      [self renderNewViewsFirstHalfInFlipLayer];
      
      _didInitializeNewBackgroundImage = YES;
    }
    [self setRotationAngle:-angle forLayer:_flipLayer];
    
  } else {
    
    [self setRotationAngle:(angle) forLayer:_flipLayer];
    
  }
  
  [self updateShadowsForAngle:angle];

}

- (void)_panEnded:(UIGestureRecognizer *)recognizer {
  
  if (_flipDirection == FlipDirectionNone) {
    // If no rotation is set, e.g. when no next controller and pan is manually ended,
    // then nothing to clean up, aborting...
    return;
  }
  
  float angle = [self angleFromPosition:[recognizer locationInView:self.view.window]];
  
  /*
   Finalize flip page and shadow's final position through animation,
   end with removing the animated views and layers.
   */
  
  if (angle == 0 || angle == M_PI_2) {
    
    // If the page lies flat to the surface, there is no need to animate
    [self finalizeFlipWithAngle:angle];
    
  } else {
    
    // The page's drop time is proportional to the angle's distance to 0 or pi
    float dropDuration = RELEASE_PAGE_MAX_DROP_DURATION * (MIN(angle, (M_PI - angle)) / M_PI_2);
    
    if (angle < M_PI_2) {
      [self setRotationAngle:0 forLayer:_flipLayer animationDuration:dropDuration];
    } else {
      [self setRotationAngle:M_PI forLayer:_flipLayer animationDuration:dropDuration];
    }

    [UIView animateWithDuration:dropDuration delay:0 options:UIViewAnimationCurveEaseOut animations:^{
      
      
      if (angle < M_PI_2) {
        [self updateShadowsForAngle:0];
      } else {
        [self updateShadowsForAngle:M_PI];
      }
      
    } completion:^(BOOL finished) {
      
      [self finalizeFlipWithAngle:angle];
      
    }];
    
  }
}

- (void)finalizeFlipWithAngle:(float)angle {
  
  if (angle > M_PI_2) {
    
    if ([self isFlippingForward]) {
      _currentPageIndex++;
    } else {
      // User has navigated back to previous view controller, the last one will be released.
      [self popViewControllerAnimated:NO];
      _currentPageIndex--;
      
    }
    
  } else {
    
    if ([self isFlippingForward]) {
      /*
       User has begun navigating forward, but aborted,
       the view controller that was added when begin flipping will now be released.
       */
      [self popViewControllerAnimated:NO];
    }
    
  }
  
  _isFlipping = NO;
  
  // Final cleanup
  [_firstHalfShadow removeFromSuperview], _firstHalfShadow = nil;
  [_secondHalfShadow removeFromSuperview], _secondHalfShadow = nil;
  [_flipLayer removeFromSuperlayer];
  [_flipPage removeFromSuperview];
  
}

- (void)pan:(UIGestureRecognizer *)recognizer {
  
  switch (recognizer.state) {
    case UIGestureRecognizerStateBegan:
      [self _panBegan:recognizer];
      break;
      
    case UIGestureRecognizerStateChanged:

      [self _panChanged:recognizer];
            
      break;
      
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateEnded:
      
      [self _panEnded:recognizer];

      break;
      
    default:
      break;
  }
  
}

#pragma mark - UIGestureRegognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
  
  if ([gestureRecognizer isEqual:_recognizer]) {
    if (_isFlipping) {
      // New flipping action is blocked until drop animation is completed.
      return NO;
    }
    
  }

  return YES;
}

@end
