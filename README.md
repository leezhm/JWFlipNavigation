JWFlipNavigation
==========================

A simple and easy to use navigation controller for flipping through the views like pages in a book.

### Usage


Subclass ```JWFlipNavigationController``` and override the inherited method ```- (void)viewControllerForIndex:(NSInteger)index``` to return the view controller for the requested index. Return ```nil``` when no more view controllers are available.

Override the method ```- (FlipMode)flipMode``` to control horizontal or vertical page flipping.

### Requirements

#### Frameworks
Requires the frameworks ```QuartzCore``` and ```CoreGraphics``` to be added to your project.

#### ARC
JWFlipNavigation uses ARC. If you would like to add JWFlipNavigation to a project not using ARC, you can enable ARC for the JWFlipNavigation source files explicitly by adding the compiler flag ```-fobjc-arc``` for each file.


### License

Available under the MIT license. See the LICENSE file for more info.
