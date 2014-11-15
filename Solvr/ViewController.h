//
//  ViewController.h
//  Solvr
//
//  Created by Chris Lewis on 20/10/14.
//  Copyright (c) 2014 Chris Lewis. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <UIWebViewDelegate>

@property( retain, nonatomic ) IBOutlet UIImageView* backgroundImage;
@property( retain, nonatomic ) IBOutlet UIWebView* board;

@end

