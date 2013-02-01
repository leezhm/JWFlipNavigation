//
//  DemoNavigationController.m
//  DemoProject
//
//  Created by John Willsund on 2013-01-24.
//  Copyright (c) 2013 John Willsund. All rights reserved.
//

#import "DemoNavigationController.h"
#import "ViewController.h"

@interface DemoNavigationController ()

@end

@implementation DemoNavigationController

- (UIViewController *)viewControllerForIndex:(NSInteger)index {

  ViewController *controller = [[ViewController alloc] initWithNibName:@"ViewController" bundle:nil];
  controller.digit = index + 1;
  
  return controller;

}

-(FlipMode)flipMode {
 
  return FlipModeVertical;

}

@end
