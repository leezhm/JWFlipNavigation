JWFlipNavigation
==========================

A simple and easy to use navigation controller for flipping through the views like pages in a book.

Usage
-----

Subclass JWFlipNavigationController and override -(void)viewControllerForIndex:(NSInteger)index and return the view controller for a given index. Return nil when no more view controllers are available.
