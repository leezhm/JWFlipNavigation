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

#import "JWFlipNavigationController.h"
#import <QuartzCore/QuartzCore.h>

typedef enum {
  FlipDirectionNone,
  FlipDirectionLeft,
  FlipDirectionRight
} FlipDirection;

@interface JWFlipNavigationController ()

@property (nonatomic, assign) NSInteger currentPageIndex;
@property (nonatomic, assign) CGFloat panStartX;
@property (nonatomic, assign) CGFloat rotationRadius;
@property (nonatomic, assign) FlipDirection rotationDirection;

// Page flipping image halves, shadows
@property (nonatomic, strong) UIImageView *bgLeftHalf;
@property (nonatomic, strong) UIImageView *bgRightHalf;
@property (nonatomic, strong) UIImageView *leftShadow;
@property (nonatomic, strong) UIImageView *rightShadow;
@property (nonatomic, strong) UIImageView *fgLeftHalf;
@property (nonatomic, strong) UIImageView *fgRightHalf;

@property (nonatomic, strong) NSMutableArray *views;

@property (nonatomic, strong) UIPanGestureRecognizer *recognizer;

@end

@implementation JWFlipNavigationController

- (id)initWithRootViewController:(UIViewController *)rootViewController {
  
  self = [super initWithRootViewController:rootViewController];
  if (self) {
    _views = [NSMutableArray arrayWithObject:self.topViewController];
    self.navigationBarHidden = YES;
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  _recognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
  [self.view addGestureRecognizer:_recognizer];
  
}

- (UIViewController *)_viewControllerForIndex:(NSInteger)index {
  
  NSLog(@"View for index %d", index);
  if (index < _views.count) {
    return [_views objectAtIndex:index];
  } else {
    NSLog(@"Requesting new view for index %d", index);
    
    UIViewController *controller = [self viewControllerForIndex:index];

    if (controller) {
      [_views addObject:controller];
    }

    return controller;
    
  }
  
}

- (UIViewController *)viewControllerForIndex:(NSInteger)index {
  
  // Override this method to return view controllers at given index
  return nil;
  
}

#pragma mark - Shadow Methods

- (UIImageView *)leftGradientForFrame:(CGRect)frame {
  
  CGFloat components[] = {0, 0, 0, 0, 0, 0, 0, 1};
  
  return [self gradientImageForFrame:frame withCompoments:components];
  
}


- (UIImageView *)rightGradientForFrame:(CGRect)frame {
  
  CGFloat components[] = {0, 0, 0, 1, 0, 0, 0, 0};
  
  return [self gradientImageForFrame:frame withCompoments:components];
  
}

- (UIImageView *)gradientImageForFrame:(CGRect)frame withCompoments:(CGFloat*)components {
  
  UIGraphicsBeginImageContextWithOptions(frame.size, NO, 0.0);

  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGFloat locations[] = {0, 1};

  
  CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);
  CGContextDrawLinearGradient(UIGraphicsGetCurrentContext(), gradient, CGPointZero, CGPointMake(frame.size.width, 0), 0);
  CGGradientRelease(gradient);
  
  
  UIImageView *image = [[UIImageView alloc] initWithImage:UIGraphicsGetImageFromCurrentImageContext()];
  image.frame = frame;
  UIGraphicsEndImageContext();

  return image;
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

#pragma mark - Rendering

- (UIImageView *)imageFromView:(UIView *)view {
  
  CGSize renderSize = view.frame.size;
  
  UIGraphicsBeginImageContextWithOptions(renderSize, NO, 0.0);
  
  [view.layer renderInContext:UIGraphicsGetCurrentContext()];
  UIImageView *image = [[UIImageView alloc] initWithImage:UIGraphicsGetImageFromCurrentImageContext()];
  UIGraphicsEndImageContext();
  image.clipsToBounds = YES;
  
  CGRect frame = image.frame; frame.origin.y = 20.0; image.frame = frame;

  return image;
}

- (UIImageView *)rightHalfOfView:(UIView *)view {
  
  UIImageView *image = [self imageFromView:view];
  image.layer.anchorPoint = CGPointMake(0, 0.5);
  
  CGRect frame = image.frame;
  frame.size.width = roundf(frame.size.width / 2);
  frame.origin.x = frame.size.width;
  image.frame = frame;
  
  image.contentMode = UIViewContentModeRight;

  return image;
  
}

- (UIImageView *)leftHalfOfView:(UIView *)view {

  UIImageView *image = [self imageFromView:view];
  
  image.layer.anchorPoint = CGPointMake(1, 0.5);
  image.contentMode = UIViewContentModeLeft;
  
  CGRect frame = image.frame;
  frame.size.width = roundf(frame.size.width / 2);
  frame.origin.x = 0;
  image.frame = frame;

  return image;
  
}

- (void)initializePageViews {
  
  UIViewController *currentView = [self _viewControllerForIndex:_currentPageIndex];
  NSInteger nextIndex = (_rotationDirection == FlipDirectionLeft) ? (_currentPageIndex + 1) : (_currentPageIndex - 1);
  
  UIViewController *nextView = [self _viewControllerForIndex:nextIndex];

  if (_rotationDirection == FlipDirectionLeft) {

    self.bgLeftHalf = [self leftHalfOfView:currentView.view];
    self.bgRightHalf = nil; // Instead of covering new view with copy - show view and trigger viewWillAppear()
    self.fgLeftHalf = nil;
    self.fgRightHalf = [self rightHalfOfView:currentView.view];
    
    self.fgLeftHalf.hidden = YES;
    
    // After rendering the new view behind the current - set is as front view controller
    NSMutableArray *viewControllers = [NSMutableArray arrayWithArray:self.viewControllers];
    [viewControllers addObject:nextView];
    self.viewControllers = viewControllers;
    
  } else {
    
    self.bgLeftHalf = [self leftHalfOfView:nextView.view];
    self.bgRightHalf = [self rightHalfOfView:currentView.view];
    self.fgLeftHalf = [self leftHalfOfView:currentView.view];
    self.fgRightHalf = [self rightHalfOfView:nextView.view];
    self.fgRightHalf.hidden = YES;
    self.leftShadow = [self leftGradientForFrame:_fgLeftHalf.frame];
    _leftShadow.alpha = 0;
    
  }
  
  self.rightShadow = [self rightGradientForFrame:_fgRightHalf.frame];
  _rightShadow.alpha = 0;
  
  [self.view addSubview:_bgLeftHalf];
  [self.view addSubview:_bgRightHalf];
  [self.view addSubview:_leftShadow];
  [self.view addSubview:_rightShadow];
  [self.view addSubview:_fgLeftHalf];
  [self.view addSubview:_fgRightHalf];
  
}

- (CGFloat)pageWidth {
  
  return self.topViewController.view.frame.size.width;
  
}


#pragma mark - Rotation

- (void)setRotationAngle:(CGFloat)angle forView:(UIView *)view {
  
  CATransform3D transform = CATransform3DIdentity;
  [view.layer removeAllAnimations];
  transform = CATransform3DRotate(transform, angle, 0, 1, 0);
  
  float height = _rotationRadius * sinf(angle);
  
  // Setting the perspective
  transform.m14 = 0.0005 * height / _rotationRadius;
  
  view.layer.transform = transform;
  
}

- (float)angleFromPosition:(float)position {
  
  CGFloat panDelta;
  if (_rotationDirection == FlipDirectionLeft) {
    panDelta = _rotationRadius - (_panStartX - position);
  } else {
    panDelta = _rotationRadius - (position - _panStartX);
  }
  panDelta = MAX(-_rotationRadius, MIN(_rotationRadius, panDelta));
  NSInteger leftOrRightSign = 1;
  CGFloat angle = leftOrRightSign * acosf(panDelta / _rotationRadius);
  return angle;
  
}
#pragma mark - Pan And Flip Control

- (void)_panBegan:(UIGestureRecognizer *)recognizer {
  
  self.panStartX = [recognizer locationInView:self.view.window].x;
  
  _rotationRadius = fabsf(_panStartX - self.view.frame.size.width / 2);
  if (_panStartX < (self.view.frame.size.width / 2)) {
    
    _rotationDirection = FlipDirectionRight;
    
  } else {
    
    _rotationDirection = FlipDirectionLeft;
    
  }
  if (_rotationDirection == FlipDirectionRight && _currentPageIndex == 0) {
    
    _rotationDirection = FlipDirectionNone;
    return;
  }
  
  if (_rotationDirection == FlipDirectionLeft) {
    // If flipping to a new view controller - first check if one is available, else abort gesture.
    UIViewController *nextView = [self _viewControllerForIndex:(_currentPageIndex + 1)];
    if (nextView) {
      nextView.view.frame = self.topViewController.view.frame;
      
    } else {
      _rotationDirection = FlipDirectionNone;
      recognizer.enabled = NO;
      recognizer.enabled = YES;
      return;
    }
  }
  
  [self initializePageViews];
  
}

- (void)finalizeRenderingNewViewComponents {
  UIViewController *nextController = [_views objectAtIndex:(_currentPageIndex + 1)];
  self.fgLeftHalf = [self leftHalfOfView:nextController.view];
  [self.view insertSubview:_fgLeftHalf aboveSubview:_bgLeftHalf];
  self.leftShadow = [self leftGradientForFrame:_fgLeftHalf.frame];
  _leftShadow.alpha = 0;
  [self.view insertSubview:_leftShadow aboveSubview:_leftShadow];

}

- (void)_panChanged:(UIGestureRecognizer *)recognizer {
  
  if (_rotationDirection == FlipDirectionNone) {
    return;
  }
  

  CGFloat currentPosition = [recognizer locationInView:self.view.window].x;
  
  CGFloat angle = [self angleFromPosition:currentPosition];
  
//  NSLog(@"Angle: %g", angle);
  
  CGFloat shadowOffset = 0;
  
  if (_rotationDirection == FlipDirectionLeft) {
    
    if (!_fgLeftHalf) {
      // If this view-half hasn't been rendered yet, do it now
      [self finalizeRenderingNewViewComponents];
    }
    
    if (angle < M_PI_2) { // Still showing old page
      
//      NSLog(@"Swipe left, show old right");
      _fgLeftHalf.hidden = YES, _fgRightHalf.hidden = NO;
      
      [self setRotationAngle:(-angle) forView:_fgRightHalf];
      shadowOffset = _fgRightHalf.frame.size.width;
      
    } else {
      
//      NSLog(@"Swipe left, show new left");
      _fgLeftHalf.hidden = NO, _fgRightHalf.hidden = YES;
      
      [self setRotationAngle:(-angle + M_PI) forView:_fgLeftHalf];
      shadowOffset = _fgLeftHalf.frame.size.width;
      
    }
    
  } else {
    
    if (angle < M_PI_2) { // Still showing old page
//      NSLog(@"Swipe right, show old left");
      _fgLeftHalf.hidden = NO, _fgRightHalf.hidden = YES;
      [self setRotationAngle:(angle) forView:_fgLeftHalf];
      shadowOffset = _fgLeftHalf.frame.size.width;
      
    } else {
      
//      NSLog(@"Swipe right, show new right");
      _fgLeftHalf.hidden = YES, _fgRightHalf.hidden = NO;
      [self setRotationAngle:(angle + M_PI) forView:_fgRightHalf];
      shadowOffset = _fgRightHalf.frame.size.width;
      
    }
    
  }
  
  // Adjust shadows:
  CGFloat maxOffset = [self pageWidth] / 2;
  float shadowAlpha = shadowOffset / maxOffset;
  
  if ((_rotationDirection == FlipDirectionLeft && angle < M_PI_2) ||
      (_rotationDirection == FlipDirectionRight && angle > M_PI_2)) {
    
    _leftShadow.alpha = 0;
    
    _rightShadow.alpha = shadowAlpha;
    [self setRightShadowOffset:shadowOffset];
//        NSLog(@"Right shadow offset: %g, alpha: %g", _rightShadow.frame.origin.x, _rightShadow.alpha);
    
  } else {
    
    _rightShadow.alpha = 0;
    _leftShadow.alpha = shadowAlpha;
    [self setLeftShadowOffset:shadowOffset];
    
  }

}

- (void)_panEnded:(UIGestureRecognizer *)recognizer {
  
  if (_rotationDirection == FlipDirectionNone) {
    // If no rotation is set, e.g. when no next controller and pan is manually ended,
    // then nothing to clean up, aborting...
    return;
  }
  
  float currentPosition = [recognizer locationInView:self.view.window].x;
  
  float angle = [self angleFromPosition:currentPosition];
  
  [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationCurveEaseOut animations:^{
    
    [self setRotationAngle:0 forView:_fgLeftHalf];
    [self setRotationAngle:0 forView:_fgRightHalf];
    
    if ((_rotationDirection == FlipDirectionLeft && angle < M_PI_2) ||
        (_rotationDirection == FlipDirectionRight && angle > M_PI_2)) {
      [self setRightShadowOffset:[self pageWidth] / 2];
      _rightShadow.alpha = 1;
    } else {
      [self setLeftShadowOffset:[self pageWidth] / 2];
      _leftShadow.alpha = 1;
    }
    
  } completion:^(BOOL finished) {

    
    if (angle > M_PI_2) {
      if (_rotationDirection == FlipDirectionRight) {
        
        UIViewController *oldView = [_views objectAtIndex:_currentPageIndex];
        [self popViewControllerAnimated:NO];
        [_views removeObject:oldView];
        _currentPageIndex--;
        
      } else {
        _currentPageIndex++;
      }
    } else {
      
      if (_rotationDirection == FlipDirectionLeft) {
        // Remove the view that was just instantiated but never eventually pushed
        [self popViewControllerAnimated:NO];
        [_views removeObjectAtIndex:(_currentPageIndex + 1)];
      }
      
    }
    NSLog(@"Current page index: %d", _currentPageIndex);
    
    
    [_leftShadow removeFromSuperview];
    [_rightShadow removeFromSuperview];
    [_fgLeftHalf removeFromSuperview];
    [_fgRightHalf removeFromSuperview];
    [_bgLeftHalf removeFromSuperview];
    [_bgRightHalf removeFromSuperview];
    
  }];
}


- (void)pan:(UIGestureRecognizer *)recognizer {
  
  switch (recognizer.state) {
    case UIGestureRecognizerStateBegan:
      [self _panBegan:recognizer];
      break;
      
    case UIGestureRecognizerStateChanged:

      if (_rotationDirection == FlipDirectionNone) {
        return;
      }
      
      [self _panChanged:recognizer];
            
      break;
      
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateEnded:
      
      if (_rotationDirection == FlipDirectionNone) {
        return;
      }
      
      [self _panEnded:recognizer];
      

      break;
      
      
    default:
      break;
  }
  
}

@end
