//
//  AppDelegate.m
//  JWDemoProject
//
//  Created by John Willsund on 2013-01-24.
//  Copyright (c) 2013 John Willsund. All rights reserved.
//

#import "AppDelegate.h"

#import "DemoNavigationController.h"
#import "ViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

  ViewController *controller = [[ViewController alloc] initWithNibName:@"ViewController" bundle:nil];
  controller.digit = 1;
  
  self.navigationController = [[DemoNavigationController alloc] initWithRootViewController:controller];
  self.window.rootViewController = self.navigationController;
  [self.window makeKeyAndVisible];
  return YES;

}

@end
