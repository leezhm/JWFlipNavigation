//
//  ViewController.m
//  JWDemoProject
//
//  Created by John Willsund on 2013-01-24.
//  Copyright (c) 2013 John Willsund. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (CGFloat)randFloat {
  
  return (arc4random() % 100) / 100.;
  
}

- (void)viewDidLoad {
 [super viewDidLoad];
  float hue = [self randFloat];
  self.view.backgroundColor = [UIColor colorWithHue:hue saturation:.8 brightness:.8 alpha:1];
  
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  _digitLabel.text = [NSString stringWithFormat:@"%d", _digit];
  
}

@end
