//
//  ViewController.h
//  Solvr
//
//  Created by Chris Lewis on 20/10/14.
//  Copyright (c) 2014 Chris Lewis. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <UIWebViewDelegate>

@property (retain, nonatomic) IBOutlet UIWebView* board;

// avcapture variables
@property AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (retain, nonatomic) IBOutlet UIImageView* backgroundImage;
@property (nonatomic, retain) AVCaptureStillImageOutput *stillImageOutput; // used by capturer

// Omnibutton
- (IBAction) captureNow:(id)sender;
@property (retain, nonatomic) IBOutlet UIButton* omnibutton;

@end