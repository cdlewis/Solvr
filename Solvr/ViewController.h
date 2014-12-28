//
//  ViewController.h
//  Solvr
//
//  Created by Chris Lewis on 20/10/14.
//  Copyright (c) 2014 Chris Lewis. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <UIWebViewDelegate>

// avcapture variables
@property AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property( retain, nonatomic ) IBOutlet UIImageView* backgroundImage;
@property (nonatomic, retain) AVCaptureStillImageOutput *stillImageOutput; // used by capturer
- (IBAction)captureNow:(id)sender;

// end avcapture variables

@property( retain, nonatomic ) IBOutlet UIWebView* board;

@end

