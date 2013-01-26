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

#define RELEASE_PAGE_DROP_DURATION .4 // seconds

typedef enum {
  FlipDirectionNone,
  FlipDirectionLeft,
  FlipDirectionRight
} FlipDirection;

@interface JWFlipNavigationController ()

@property (nonatomic, assign) NSInteger currentPageIndex;
@property (nonatomic, assign) CGFloat panStartX;
@property (nonatomic, assign) CGFloat rotationRadius;
@property (nonatomic, assign) FlipDirection flipDirection;

// Page flipping image halves, shadows
@property (nonatomic, strong) UIImageView *bgLeftHalf;
@property (nonatomic, strong) UIImageView *bgRightHalf;

@property (nonatomic, strong) UIView *flipPage;
@property (nonatomic, strong) CATransformLayer *flipLayer;
@property (assign) BOOL didInitializeNewBackgroundImage;

@property (nonatomic, strong) UIImageView *leftShadow;
@property (nonatomic, strong) UIImageView *rightShadow;

@property (nonatomic, strong) NSMutableArray *views;

@property (nonatomic, strong) UIPanGestureRecognizer *recognizer;
@property (assign) BOOL isFlipping;

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
  _recognizer.delegate = self;
  
}

- (UIViewController *)_viewControllerForIndex:(NSInteger)index {
  
//  NSLog(@"View for index %d", index);
  if (index < _views.count) {
    return [_views objectAtIndex:index];
  } else {
//    NSLog(@"Requesting new view for index %d", index);
    
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
  UIScrollView *scrollView = ([view isKindOfClass:[UIScrollView class]]) ? (UIScrollView *)view : nil;
  
  UIGraphicsBeginImageContextWithOptions(renderSize, NO, 0.0);

  if (scrollView) {

    // If view is a UISCrollView (or inherrits from, like UITableView,
    // the context has to be offset to capture the visible are and not top of content
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(ctx, -scrollView.contentOffset.x, -scrollView.contentOffset.y);

    [view.layer renderInContext:UIGraphicsGetCurrentContext()];

  } else {

    [view.layer renderInContext:UIGraphicsGetCurrentContext()];

  }
  

  UIImageView *image = [[UIImageView alloc] initWithImage:UIGraphicsGetImageFromCurrentImageContext()];
  UIGraphicsEndImageContext();
  image.clipsToBounds = YES;
  
  CGRect frame = image.frame; frame.origin.y = 20.0; image.frame = frame;

  return image;
}

- (CALayer *)rightHalfLayerFromImage:(UIImageView *)image {
  
  CGRect frame = image.frame;
  frame.size.width /= 2;
  frame.origin.x = frame.size.width;
  CALayer *layer = [[CALayer alloc] init];
  layer.bounds = frame;
  layer.anchorPoint = CGPointZero;
  layer.position = CGPointMake([self pageWidth] / 2, 0);

  layer.contents = image.layer.contents;
  layer.contentsRect = CGRectMake(.5, 0, .5, 1);
  layer.doubleSided = NO;
  
  return layer;
  
}

- (CALayer *)leftHalfLayerFromImage:(UIImageView *)image {

  CGRect frame = image.frame;
  frame.size.width /= 2;
  
  CALayer *layer = [[CALayer alloc] init];
  layer.contents = image.layer.contents;
  layer.contentsRect = CGRectMake(0, 0, 0.5, 1);
  layer.anchorPoint = CGPointZero;
  layer.position = CGPointZero;
  frame.origin = CGPointZero;
  layer.frame = frame;
  layer.doubleSided = NO;

  return layer;
}

- (void)initializePageViews {
  
  UIViewController *currentView = [self _viewControllerForIndex:_currentPageIndex];
  NSInteger nextIndex = (_flipDirection == FlipDirectionLeft) ? (_currentPageIndex + 1) : (_currentPageIndex - 1);
  
  UIViewController *nextView = [self _viewControllerForIndex:nextIndex];
  
  CGRect frame = currentView.view.frame;
  frame.origin.y = 20;
  _flipPage = [[UIView alloc] initWithFrame:frame];
  
  // Snapshot of the current visible view
  UIImageView *currentViewImage = [self imageFromView:currentView.view];

  // Setting up the layer that will hold the back-to-back sublayers
  _flipLayer = [[CATransformLayer alloc] init];
  _flipLayer.anchorPoint = CGPointMake(.5, .5);
  _flipLayer.position = CGPointMake(frame.size.width / 2, frame.size.height / 2);
  _flipLayer.bounds = CGRectMake(0, 0, frame.size.width, frame.size.height);
  _flipLayer.doubleSided = YES;
  [_flipPage.layer addSublayer:_flipLayer];

  if (_flipDirection == FlipDirectionLeft) {
    
    // Render left and right existing view

    CALayer *rightHalfLayer = [self rightHalfLayerFromImage:currentViewImage];
    [_flipLayer addSublayer:rightHalfLayer];

    // Reuse the snapshot for left half
    frame.size.width /= 2;
    currentViewImage.frame = frame;
    currentViewImage.contentMode = UIViewContentModeLeft;
    self.bgLeftHalf = currentViewImage;
    [self.view addSubview:_bgLeftHalf];
    
    // After rendering the new view behind the current - set is as front view controller
    NSMutableArray *viewControllers = [NSMutableArray arrayWithArray:self.viewControllers];
    [viewControllers addObject:nextView];
    self.viewControllers = viewControllers;
    
  } else {
    
    // Setup layer halves from current, visible view
    
    CALayer *leftHalfLayer = [self leftHalfLayerFromImage:currentViewImage];
    [_flipLayer addSublayer:leftHalfLayer];

    frame.size.width /= 2;
    frame.origin.x = frame.size.width;
    currentViewImage.frame = frame;
    currentViewImage.contentMode = UIViewContentModeRight;
    self.bgRightHalf = currentViewImage;
    [self.view addSubview:_bgRightHalf];
    
    // Render layers for previous layer
    UIImageView *previousViewImage = [self imageFromView:nextView.view];
    
    leftHalfLayer = [self leftHalfLayerFromImage:previousViewImage];
    [_flipPage.layer insertSublayer:leftHalfLayer atIndex:0];
    
    CALayer *rightHalfLayer = [self rightHalfLayerFromImage:previousViewImage];
    rightHalfLayer.transform = CATransform3DMakeRotation(M_PI, 0, 1, 0);
    
    [_flipLayer addSublayer:rightHalfLayer];

    self.leftShadow = [self leftGradientForFrame:leftHalfLayer.frame];
    _leftShadow.alpha = 0;
    
  }
  
  self.rightShadow = [self rightGradientForFrame:CGRectMake(0, 0, [self pageWidth] / 2, self.view.frame.size.height)];
  _rightShadow.alpha = 0;
  
  [_flipPage addSubview:_leftShadow];
  [self.view addSubview:_rightShadow];
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
  if (_flipDirection == FlipDirectionLeft) {
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

- (void)finalizeRenderingNewViewComponents {
  
  UIViewController *nextController = [_views objectAtIndex:(_currentPageIndex + 1)];
  
  UIImageView *nextViewImage = [self imageFromView:nextController.view];
  CALayer *leftHalf = [[CALayer alloc] init];
  leftHalf.contents = nextViewImage.layer.contents;
  leftHalf.contentsRect = CGRectMake(0, 0, .5, 1);
  leftHalf.anchorPoint = CGPointMake(.5, .5);
  leftHalf.frame = CGRectMake([self pageWidth] / 2, 0, [self pageWidth] / 2, nextViewImage.frame.size.height);
  leftHalf.doubleSided = NO;
  
  CATransform3D transform = CATransform3DMakeRotation(M_PI, 0, 1, 0);
  leftHalf.transform = transform;
  
  [_flipLayer insertSublayer:leftHalf atIndex:1];
  
  self.leftShadow = [self leftGradientForFrame:leftHalf.frame];
  _leftShadow.alpha = 0;
  [_flipPage insertSubview:_leftShadow atIndex:0];
  
}

- (void)_panBegan:(UIGestureRecognizer *)recognizer {
  
  self.panStartX = [recognizer locationInView:self.view.window].x;
  
  _rotationRadius = fabsf(_panStartX - self.view.frame.size.width / 2);
  if (_panStartX < (self.view.frame.size.width / 2)) {
    
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
    UIViewController *nextView = [self _viewControllerForIndex:(_currentPageIndex + 1)];
    if (nextView) {
      nextView.view.frame = self.topViewController.view.frame;
      
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
  
//  NSLog(@"Angle: %g", angle);
  
  CGFloat shadowOffset = 0;
  
  if (_flipDirection == FlipDirectionLeft) {
    
    if (!_didInitializeNewBackgroundImage) {

      // If this view-half hasn't been rendered yet, do it now
      [self finalizeRenderingNewViewComponents];
      
      _didInitializeNewBackgroundImage = YES;
    }
    
    [self setRotationAngle:-angle forLayer:_flipLayer];
    shadowOffset = _flipLayer.frame.size.width / 2;
    
  } else {
    
    [self setRotationAngle:(angle) forLayer:_flipLayer];
    shadowOffset = _flipLayer.frame.size.width / 2;
    
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
    
    if (angle < M_PI_2) {
      [self setRotationAngle:0 forLayer:_flipLayer animationDuration:RELEASE_PAGE_DROP_DURATION];
    } else {
      [self setRotationAngle:M_PI forLayer:_flipLayer animationDuration:RELEASE_PAGE_DROP_DURATION];
    }

    [UIView animateWithDuration:RELEASE_PAGE_DROP_DURATION delay:0 options:UIViewAnimationCurveEaseOut animations:^{
      
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
    
    if (_flipDirection == FlipDirectionRight) {
      
      // User has navigated back to previous view controller, the last one will be released.
      UIViewController *oldView = [_views objectAtIndex:_currentPageIndex];
      [self popViewControllerAnimated:NO];
      [_views removeObject:oldView];
      _currentPageIndex--;
      
    } else {
      _currentPageIndex++;
    }
  } else {
    
    if (_flipDirection == FlipDirectionLeft) {
      /*
       User has begun navigating forward, but aborted,
       the view controller that was added when begin flipping will now be released.
       */
      [self popViewControllerAnimated:NO];
      [_views removeObjectAtIndex:(_currentPageIndex + 1)];
    }
    
  }
  
  _isFlipping = NO;
  
  // Final cleanup
  [_leftShadow removeFromSuperview], _leftShadow = nil;
  [_rightShadow removeFromSuperview], _rightShadow = nil;
  [_flipLayer removeFromSuperlayer];
  [_flipPage removeFromSuperview];
  [_bgLeftHalf removeFromSuperview];
  [_bgRightHalf removeFromSuperview];
  
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
    return NO;
  }

  return YES;
}

@end
