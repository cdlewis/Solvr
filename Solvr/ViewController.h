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

// board
@property (retain, nonatomic) IBOutlet UIWebView* board;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* boardSpacing;

// feedback label
@property (retain, nonatomic) IBOutlet UILabel* feedback;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint* feedbackSpacing;

// AVCapture
@property AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (retain, nonatomic) IBOutlet UIImageView* backgroundImage;
@property (nonatomic, retain) AVCaptureStillImageOutput *stillImageOutput;

// omnibutton
- (IBAction) captureNow:(id)sender;
@property (retain, nonatomic) IBOutlet UIButton* omnibutton;


@end