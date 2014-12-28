//
//  ViewController.m
//  Solvr
//
//  Created by Chris Lewis on 20/10/14.
//  Copyright (c) 2014 Chris Lewis. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <TesseractOCR/TesseractOCR.h>
#import "ViewController.h"
#import "ComputerVision.h"

#import "NorvigSolver.h"
#include <string>
#include <sstream>
#include <iostream>

@implementation ViewController

BOOL boardLoaded;
NSString* stateCache;
ComputerVision* cv = NULL;
Tesseract* tesseract = NULL;

- (void) viewDidLoad {
    [ super viewDidLoad ];
    
    // Board Detection
    cv = [ [ ComputerVision alloc ] init ];
    
    // OCR
    NSLog( @"Initialise Tesseract" );
    tesseract = [ [ Tesseract alloc ] initWithLanguage:@"eng" ];
    [ tesseract setVariableValue:@"123456789" forKey:@"tessedit_char_whitelist" ]; // only numbers
    [ tesseract setVariableValue:@"7" forKey:@"tessedit_pageseg_mode" ]; // one character per image
    
    // Results Board
    NSLog( @"Load HTML Board" );
    self.board.hidden = YES;
    self.board.delegate = self;
    boardLoaded = NO;
    stateCache = @"";
    NSURL *url = [ [ NSBundle mainBundle ] URLForResource:@"board" withExtension:@"html" ];
    [ self.board loadRequest:[ NSURLRequest requestWithURL:url ] ];
    
    // initialise avcapture
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPresetMedium;
    //session.sessionPreset = AVCaptureSessionPresetPhoto;
    
    self.captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    
    self.captureVideoPreviewLayer.frame = self.view.frame;
    [ self.captureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill ];
    
    [self.backgroundImage.layer addSublayer:self.captureVideoPreviewLayer];
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input) {
        // Handle the error appropriately.
        NSLog(@"ERROR: trying to open camera: %@", error);
    }
    [session addInput:input];
    
    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [ self.stillImageOutput setOutputSettings:outputSettings];
    
    [session addOutput:self.stillImageOutput];
    
    [session startRunning];
    // end initialise avcapture
}

- (void) didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// WebView Fun

- (void) webViewDidFinishLoad:(UIWebView*)webView {
    boardLoaded = YES; // one would expect this to be covered by `webView.loading`
    if( ![ stateCache isEqualToString:@"" ] ) {
        [ self update:stateCache ];
        stateCache = @"";
    }
}

- (void) update:(NSString*)state {
    stateCache = state;
    if( boardLoaded ) {
        NSString* js = [ [ NSString alloc ] initWithFormat:@"set_board('%@');", stateCache ];
        [ self.board stringByEvaluatingJavaScriptFromString:js ];
        self.board.hidden = NO;
        NSLog( @"board loaded: %@", stateCache );
    }
}

- (IBAction) captureNow:(id)sender {
    // disable button to avoid mashing
    UIButton *button = nil;
    if ([sender isKindOfClass:[UIButton class]]) {
        button = sender;
        button.enabled = NO;
        [ button setTitle:@"Solving..." forState:UIControlStateDisabled ];
    }
    
    AVCaptureConnection *videoConnection = [ self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    [videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];

    [self.stillImageOutput
        captureStillImageAsynchronouslyFromConnection:videoConnection
        completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error)
     {
         if( error ) { // todo: better error
             NSLog( @"error (lol this is super helpful isn't it.)" );
         } else {
             NSData *jpegData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
             UIImage *image = [UIImage imageWithData:jpegData];
             image = [ self applyAspectFillImage:image InRect:self.captureVideoPreviewLayer.frame ];

             // Process image
              
              NSString* flat_board = [ cv recogniseSudokuFromImage:image withOCR:tesseract ];
             
             // Basic check for validity of scanned board. Technically this
             // means the scanned board must have only one complete solution.
             // An empty board (all zeroes) will have multiple solutions. But
             // obviously there are other cases where this will occur. A
             // better solution could be to algorithmically check for
             // for multiple solutions, perhaps using the Norvig solver.
             if( [ flat_board isEqualToString:@"000000000000000000000000000000000000000000000000000000000000000000000000000000000" ] ) {
                 NSLog( @"No solution: empty board" );
             } else {
                 // convert to c++ string and feed to solver
                 Sudoku::init();
                 auto sc = new Sudoku( std::string( [ flat_board UTF8String ] ) );
                 if( auto S = solve( std::unique_ptr<Sudoku>( sc ) ) ) {
                     [ self update:[ NSString stringWithUTF8String:S->flatten().c_str() ] ];
                 } else {
                     NSLog( @"no solution" );
                 }
             }
             
             // Re-enable button if disabled
             if( button != nil ) {
                 button.enabled = YES;
             }
         }
     }
     ];
}

CGRect CGRectCenteredInRect(CGRect rect, CGRect mainRect)
{
    CGFloat xOffset = CGRectGetMidX(mainRect)-CGRectGetMidX(rect);
    CGFloat yOffset = CGRectGetMidY(mainRect)-CGRectGetMidY(rect);
    return CGRectOffset(rect, xOffset, yOffset);
}

CGFloat CGAspectScaleFill(CGSize sourceSize, CGRect destRect)
{
    CGSize destSize = destRect.size;
    CGFloat scaleW = destSize.width / sourceSize.width;
    CGFloat scaleH = destSize.height / sourceSize.height;
    return MAX(scaleW, scaleH);
}


CGRect CGRectAspectFillRect(CGSize sourceSize, CGRect destRect)
{
    CGSize destSize = destRect.size;
    CGFloat destScale = CGAspectScaleFill(sourceSize, destRect);
    CGFloat newWidth = sourceSize.width * destScale;
    CGFloat newHeight = sourceSize.height * destScale;
    CGFloat dWidth = ((destSize.width - newWidth) / 2.0f);
    CGFloat dHeight = ((destSize.height - newHeight) / 2.0f);
    CGRect rect = CGRectMake (dWidth, dHeight, newWidth, newHeight);
    return rect;
}

- (UIImage *) applyAspectFillImage: (UIImage *) image InRect: (CGRect) bounds
{
    CGRect destRect;
    
    UIGraphicsBeginImageContext(bounds.size);
    CGRect rect = CGRectAspectFillRect(image.size, bounds);
    destRect = CGRectCenteredInRect(rect, bounds);
    
    [image drawInRect: destRect];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
    
}

@end
