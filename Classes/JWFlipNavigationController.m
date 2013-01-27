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
  FlipDirectionRight
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

@property (nonatomic, strong) UIImageView *leftShadow;
@property (nonatomic, strong) UIImageView *rightShadow;

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

- (void)setLeftShadowOffset:(CGFloat)offset {
  
  CGRect frame = _leftShadow.frame;
  frame.origin.x = [self pageWidth] / 2 - frame.size.width - offset;
  _leftShadow.frame = frame;
  
}

- (void)setRightShadowOffset:(CGFloat)offset {
  
  CGRect frame = _rightShadow.frame;
  frame.origin.x = [self pageWidth] / 2 + offset;
  _rightShadow.frame = frame;
  
}

- (void)initializePageViews {
  
  UIViewController *currentController = [self _viewControllerForIndex:_currentPageIndex];
  NSInteger nextIndex = (_flipDirection == FlipDirectionLeft) ?
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

  CALayer *rightHalfLayer = [JWFlipImageTools rightHalfLayerFromView:currentController.view];
  CALayer *leftHalfLayer = [JWFlipImageTools leftHalfLayerFromView:currentController.view];

  if (_flipDirection == FlipDirectionLeft) {
    
    // When flipping left, the right half is inserted into the rotating layer,
    // the left half is left static in _flipPage.
    [_flipLayer addSublayer:rightHalfLayer];
    [_flipPage.layer addSublayer:leftHalfLayer];
    
    // After rendering the new view behind the current - set is as front view controller
    NSMutableArray *viewControllers = [NSMutableArray arrayWithArray:self.viewControllers];
    [viewControllers addObject:_nextViewController], _nextViewController = nil;
    self.viewControllers = viewControllers;
    
  } else {
    
    // When flipping right, the left half is inserted into the rotating layer,
    // the right half is left static in _flipPage.
    [_flipLayer addSublayer:leftHalfLayer];
    [_flipPage.layer addSublayer:rightHalfLayer];
    
    UIViewController *nextView = [self _viewControllerForIndex:nextIndex];

    // Render layers for previous controller that is currently behind the current controller
    leftHalfLayer = [JWFlipImageTools leftHalfLayerFromView:nextView.view];
    [_flipPage.layer insertSublayer:leftHalfLayer atIndex:0];
    
    rightHalfLayer = [JWFlipImageTools rightHalfLayerFromView:nextView.view];
    // Rotate layer to end up on the back side of the flipping layer.
    rightHalfLayer.transform = CATransform3DMakeRotation(M_PI, 0, 1, 0);
    [_flipLayer addSublayer:rightHalfLayer];

    
  }
  
  self.leftShadow = [JWFlipImageTools leftGradientForFrame:CGRectMake(0,
                                                                      0,
                                                                      [self pageWidth] / 2,
                                                                      self.view.frame.size.height)];
  _leftShadow.alpha = 0;

  self.rightShadow = [JWFlipImageTools rightGradientForFrame:_leftShadow.frame];
  _rightShadow.alpha = 0;
  
  [_flipPage addSubview:_leftShadow];
  [_flipPage addSubview:_rightShadow];
  [_flipPage.layer addSublayer:_flipLayer];
  [self.view addSubview:_flipPage];

}

- (CGFloat)pageWidth {
  
  return self.topViewController.view.frame.size.width;
  
}


#pragma mark - Rotation
- (void)setRotationAngle:(CGFloat)angle forLayer:(CALayer *)layer animationDuration:(float)duration {
  
  [CATransaction begin];
  [CATransaction setAnimationDuration:duration];
  [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
  
  CATransform3D transform = CATransform3DMakeRotation(angle, 0, 1, 0);
  
  // Height here is the flipped page's virtual height over the background
  float height = _rotationRadius * sinf(angle);
  
  // Setting the perspective
  transform.m14 = 0.0005 * height / _rotationRadius;
  
  layer.transform = transform;
  
  [CATransaction commit];
  
}

- (void)setRotationAngle:(CGFloat)angle forLayer:(CALayer *)layer {
  

  [CATransaction begin];
  [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
  
  CATransform3D transform = CATransform3DMakeRotation(angle, 0, 1, 0);
  
  float height = _rotationRadius * sinf(angle);
  
  // Setting the perspective
  transform.m14 = 0.0005 * height / _rotationRadius;
  
  layer.transform = transform;
  
  [CATransaction commit];
  
}

- (float)angleFromPosition:(float)position {
  
  CGFloat panDelta;
  switch (_flipDirection) {

    case FlipDirectionLeft:
      panDelta = _rotationRadius - (_panStart.x - position);
      break;

    case FlipDirectionRight:
      panDelta = _rotationRadius - (position - _panStart.x);
      break;
      
    default:
#ifdef DEBUG
      NSLog(@"Warning: Unhandled flip direction!");
#endif
      break;
  }

  panDelta = MAX(-_rotationRadius, MIN(_rotationRadius, panDelta));
  CGFloat angle = acosf(panDelta / _rotationRadius);
  return angle;
  
}
#pragma mark - Pan And Flip Control

- (void)finalizeRenderingNewViewComponents {
  
  UIViewController *nextController = [self.viewControllers objectAtIndex:(_currentPageIndex + 1)];
  
  CALayer *leftHalf = [JWFlipImageTools leftHalfLayerFromView:nextController.view];
  
  CATransform3D transform = CATransform3DMakeRotation(M_PI, 0, 1, 0);
  leftHalf.transform = transform;
  
  [_flipLayer addSublayer:leftHalf];
  
}

- (void)_panBegan:(UIGestureRecognizer *)recognizer {
  
  self.panStart = [recognizer locationInView:self.view.window];
  
  _rotationRadius = fabsf(_panStart.x - self.view.frame.size.width / 2);
  if (_panStart.x < (self.view.frame.size.width / 2)) {
    
    _flipDirection = FlipDirectionRight;
    
  } else {
    
    _flipDirection = FlipDirectionLeft;
    
  }
  if (_flipDirection == FlipDirectionRight && _currentPageIndex == 0) {
    
    _flipDirection = FlipDirectionNone;
    return;
  }
  
  _didInitializeNewBackgroundImage = NO;
  _isFlipping = YES;
  
  if (_flipDirection == FlipDirectionLeft) {
    // If flipping to a new view controller - first check if one is available, else abort gesture.
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
  

  CGFloat currentPosition = [recognizer locationInView:self.view.window].x;
  
  CGFloat angle = [self angleFromPosition:currentPosition];
  
  CGFloat shadowOffset = 0;
  
  switch (_flipDirection) {

    case FlipDirectionLeft:

      if (!_didInitializeNewBackgroundImage) {
        
        // If this view-half hasn't been rendered yet, do it now
        [self finalizeRenderingNewViewComponents];
        
        _didInitializeNewBackgroundImage = YES;
      }
      [self setRotationAngle:-angle forLayer:_flipLayer];
      shadowOffset = _flipLayer.frame.size.width / 2;
      
      break;
      
    case FlipDirectionRight:

      [self setRotationAngle:(angle) forLayer:_flipLayer];
      shadowOffset = _flipLayer.frame.size.width / 2;

      break;
      
    default:
      break;
  }
  
  // Adjust shadows:
  CGFloat maxOffset = [self pageWidth] / 2;
  float shadowAlpha = shadowOffset / maxOffset;
  
  if ((_flipDirection == FlipDirectionLeft && angle < M_PI_2) ||
      (_flipDirection == FlipDirectionRight && angle > M_PI_2)) {
    
    _leftShadow.alpha = 0;
    _rightShadow.alpha = shadowAlpha;

    [self setRightShadowOffset:shadowOffset];
    
  } else {
    
    _rightShadow.alpha = 0;
    _leftShadow.alpha = shadowAlpha;
    [self setLeftShadowOffset:shadowOffset];
    
  }

}

- (void)_panEnded:(UIGestureRecognizer *)recognizer {
  
  if (_flipDirection == FlipDirectionNone) {
    // If no rotation is set, e.g. when no next controller and pan is manually ended,
    // then nothing to clean up, aborting...
    return;
  }
  
  float currentPosition = [recognizer locationInView:self.view.window].x;
  float angle = [self angleFromPosition:currentPosition];
  
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
      
      if ((_flipDirection == FlipDirectionLeft && angle < M_PI_2) ||
          (_flipDirection == FlipDirectionRight && angle > M_PI_2)) {
        
        [self setRightShadowOffset:[self pageWidth] / 2];
        _rightShadow.alpha = 1;
        
      } else {
        
        [self setLeftShadowOffset:[self pageWidth] / 2];
        _leftShadow.alpha = 1;
      }
      
    } completion:^(BOOL finished) {
      
      [self finalizeFlipWithAngle:angle];
      
    }];
    
  }
}

- (void)finalizeFlipWithAngle:(float)angle {
  
  if (angle > M_PI_2) {
    
    
    switch (_flipDirection) {

      case FlipDirectionLeft:
        _currentPageIndex++;
        break;
        
      case FlipDirectionRight:
        // User has navigated back to previous view controller, the last one will be released.
        [self popViewControllerAnimated:NO];
        _currentPageIndex--;
        break;
        
        
      default:
        break;
    }
  } else {
    
    if (_flipDirection == FlipDirectionLeft) {
      /*
       User has begun navigating forward, but aborted,
       the view controller that was added when begin flipping will now be released.
       */
      [self popViewControllerAnimated:NO];
    }
    
  }
  
  _isFlipping = NO;
  
  // Final cleanup
  [_leftShadow removeFromSuperview], _leftShadow = nil;
  [_rightShadow removeFromSuperview], _rightShadow = nil;
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
  
  if ([gestureRecognizer isEqual:_recognizer] && _isFlipping) {
    // New flipping action is blocked until drop animation is completed.
    return NO;
  }

  return YES;
}

@end
