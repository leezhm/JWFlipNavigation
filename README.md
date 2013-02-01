JWFlipNavigation
==========================

A simple and easy to use navigation controller for flipping through the views like pages in a book.

### Usage


Subclass ```JWFlipNavigationController``` and override the inherited method ```- (void)viewControllerForIndex:(NSInteger)index``` to return the view controller for the requested index. Return ```nil``` when no more view controllers are available.

Override the method ```- (FlipMode)flipMode``` to control horizontal or vertical page flipping.
