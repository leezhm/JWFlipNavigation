//
//  JWFlipImageTools.m
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

#import "JWFlipImageTools.h"
#import <QuartzCore/QuartzCore.h>

@implementation JWFlipImageTools

+ (CALayer *)rightHalfLayerFromView:(UIView *)view {
  
  CGRect frame = CGRectMake(view.frame.size.width / 2, 0, view.frame.size.width / 2, view.frame.size.height);
  CALayer *layer = [self _layerWithSize:frame.size];
  layer.frame = frame;
  [self _renderRect:frame ofView:view inLayer:layer];
  
  return layer;
  
}
  
+ (CALayer *)leftHalfLayerFromView:(UIView *)view {
  
  CGRect frame = CGRectMake(0, 0, view.frame.size.width / 2, view.frame.size.height);
  CALayer *layer = [self _layerWithSize:frame.size];
  layer.anchorPoint = CGPointMake(1, 0);
  layer.frame = frame;
  [self _renderRect:frame ofView:view inLayer:layer];
  
  return layer;
  
}

#pragma mark - Shadow Methods

+ (UIImageView *)leftGradientForFrame:(CGRect)frame {
  
  CGFloat components[] = {0, 0, 0, 0, 0, 0, 0, 1};
  
  return [self _gradientImageForFrame:frame withCompoments:components];
  
}


+ (UIImageView *)rightGradientForFrame:(CGRect)frame {
  
  CGFloat components[] = {0, 0, 0, 1, 0, 0, 0, 0};
  
  return [self _gradientImageForFrame:frame withCompoments:components];
  
}

#pragma mark - Private Methods

+ (UIImageView *)_gradientImageForFrame:(CGRect)frame withCompoments:(CGFloat*)components {
  
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

+ (CALayer *)_layerWithSize:(CGSize)size {
  
  CALayer *layer = [[CALayer alloc] init];
  
  CGRect layerFrame = CGRectMake(0, 0, size.width, size.height);
  layer.bounds = layerFrame;
  layer.doubleSided = NO;
  layer.anchorPoint = CGPointZero;
  layer.position = CGPointZero;
  return layer;
  
}

+ (void)_renderRect:(CGRect)rect ofView:(UIView *)view inLayer:(CALayer *)layer {
  
  CGPoint contextTranslation = CGPointMake(-rect.origin.x, -rect.origin.y);
  
  UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0.0);
  
  if ([view isKindOfClass:[UIScrollView class]]) {
    
    // If view is a UISCrollView (or inherrits from, like UITableView,
    // the context has to be offset to capture the visible are and not top of content
    UIScrollView *scrollView = (UIScrollView *)view;
    contextTranslation.x -= scrollView.contentOffset.x;
    contextTranslation.y -= scrollView.contentOffset.y;
    
  }

  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGContextTranslateCTM(ctx, contextTranslation.x, contextTranslation.y);
  
  [view.layer renderInContext:ctx];
  layer.contents = (__bridge id)(UIGraphicsGetImageFromCurrentImageContext().CGImage);
  
  UIGraphicsEndImageContext();
  
}


@end
