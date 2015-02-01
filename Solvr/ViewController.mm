//
//  ViewController.m
//  Solvr
//
//  Created by Chris Lewis on 20/10/14.
//  Copyright (c) 2014 Chris Lewis. All rights reserved.
//

#import "ViewController.h"
#import <string>
#import <TesseractOCR/TesseractOCR.h>
#import "ComputerVision.h"
#import "NorvigSolver.h"
#import "EricaSadanCookbook.h"

@implementation ViewController

BOOL usingSampleImage = NO;
ComputerVision* cv = NULL;
NSString* empty_board = @"000000000000000000000000000000000000000000000000000000000000000000000000000000000";

// Track webview load status and inputs waiting to be sent
BOOL boardLoaded = NO;
NSString* boardToShow = @"";
NSString* solutionForBoard = @"";

- (void) viewDidLoad {
    [ super viewDidLoad ];
    
    // Board Detection
    cv = [ [ ComputerVision alloc ] init ];
    
    // Results Board
    NSLog( @"Load HTML Board" );
    self.board.hidden = YES;
    self.board.delegate = self;
    boardLoaded = NO;
    NSURL *url = [ [ NSBundle mainBundle ] URLForResource:@"board" withExtension:@"html" ];
    [ self.board loadRequest:[ NSURLRequest requestWithURL:url ] ];
    
    // AVCapture
    AVCaptureSession *session = [ [ AVCaptureSession alloc ] init ];
    session.sessionPreset = AVCaptureSessionPresetMedium;
    
    // Find camera
    AVCaptureDevice *device = [ AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo ];
    NSError *error = nil;
    AVCaptureDeviceInput *input = [ AVCaptureDeviceInput deviceInputWithDevice:device error:&error ];
    if( input ) {
        [ session addInput:input ];
        
        self.stillImageOutput = [ [ AVCaptureStillImageOutput alloc ] init ];
        NSDictionary *outputSettings = [ [ NSDictionary alloc ] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil ];
        [ self.stillImageOutput setOutputSettings:outputSettings ];
        
        [ session addOutput:self.stillImageOutput ];
        [ session startRunning ];
        
        self.captureVideoPreviewLayer = [ [ AVCaptureVideoPreviewLayer alloc ] initWithSession:session ];
        self.captureVideoPreviewLayer.frame = self.view.frame;
        [ self.captureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill ];
        [ self.backgroundImage.layer addSublayer:self.captureVideoPreviewLayer ];
    } else {
        NSLog( @"ERROR: trying to open camera: %@", error );
        [ self showFeedback:@"Camera not found, using sample image instead." withDuration:0 ];
        self.backgroundImage.image = [ UIImage imageNamed:@"SampleImage" ];
        usingSampleImage = YES;
    }
}

- (void) didReceiveMemoryWarning {
    [ super didReceiveMemoryWarning ];
    // Dispose of any resources that can be recreated.
}

// Results Board Webview

- (void) webViewDidFinishLoad:(UIWebView*)webView {
    boardLoaded = YES; // one would expect this to be covered by `webView.loading`
    if( ![ boardToShow isEqualToString:@"" ] ) {
        [ self update:boardToShow withSolution:solutionForBoard ];
    }
}

- (void) update:(NSString*)board withSolution:(NSString*)solution {
    // passing the empty board to update will hide the current board if it's visible
    if( [board isEqualToString:empty_board] && !self.board.hidden ) {
        self.board.hidden = YES;
        [UIView animateWithDuration:0.3 animations:^(void) {
            self.board.alpha = 0;
        }];
    } else {
        boardToShow = board;
        solutionForBoard = solution;
        if( boardLoaded ) {
            NSString* js = [ [ NSString alloc ] initWithFormat:@"set_board('%@', '%@' );", boardToShow, solutionForBoard ];
            [ self.board stringByEvaluatingJavaScriptFromString:js ];
            self.board.hidden = NO;
            self.board.alpha = 0;
            [UIView animateWithDuration:0.3 animations:^(void) {
                self.board.alpha = 1;
            }];
        }
    }
}

// Omnibutton Press

- (IBAction) captureNow:(id)sender {
    // when board is visible, override default functionality and clear
    if( self.board.hidden == NO ) {
        [ self.omnibutton setTitle:@"Press to Solve" forState:UIControlStateNormal ];
        [self update:empty_board withSolution:empty_board];
        return;
    }

    // disable button to avoid mashing
    self.omnibutton.enabled = NO;

    if( usingSampleImage ) {
        [ self processImage:self.backgroundImage.image ];
    } else { // capture frame from camera
        AVCaptureConnection *videoConnection = [ self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
        [ videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait ];

        [ self.stillImageOutput
         captureStillImageAsynchronouslyFromConnection:videoConnection
         completionHandler:^( CMSampleBufferRef imageDataSampleBuffer, NSError *error ) {
             if( error ) { // todo: better error
                 NSLog( @"error (lol this is super helpful isn't it.)" );
             } else {
                 NSData *jpegData = [ AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer ];
                 UIImage *image = [ UIImage imageWithData:jpegData ];
                 image = applyAspectFillImage( image, self.captureVideoPreviewLayer.frame );
                 [ self processImage:image ];
             }
         }
         ];
    }
}

- (void) processImage:(UIImage*)image {
    // Tesseract is initialised here due to an ongoing bug where doing so in
    // global scope leads to bizzare misreads after second image. This does
    // harm performance due to wasted cycles re-initialising but the hit
    // doesn't appear to be noticable.
    Tesseract* tesseract = [ [ Tesseract alloc ] initWithLanguage:@"eng" ];
    [ tesseract setVariableValue:@"123456789" forKey:@"tessedit_char_whitelist" ]; // only numbers
    [ tesseract setVariableValue:@"7" forKey:@"tessedit_pageseg_mode" ]; // one character per image
    
    NSString* flat_board = [ cv recogniseSudokuFromImage:image withOCR:tesseract ];
    
    // Basic check for validity of scanned board. Technically this
    // means the scanned board must have only one complete solution.
    // An empty board (all zeroes) will have multiple solutions. But
    // obviously there are other cases where this will occur. A
    // better solution could be to algorithmically check for
    // for multiple solutions, perhaps using the Norvig solver.
    if( [ flat_board isEqualToString:empty_board ] ) {
        [ self showFeedback:@"Sorry! I couldn't find the board :(" withDuration:5.0 ];
    } else {
        // convert to c++ string and feed to solver
        Sudoku::init();
        auto sc = new Sudoku( std::string( [ flat_board UTF8String ] ) );
        
        // contradiction detected in puzzle
        if( sc->valid ) {
            if( auto S = solve( std::unique_ptr<Sudoku>( sc ) ) ) {
                [ self update:flat_board withSolution:[ NSString stringWithUTF8String:S->flatten().c_str() ] ];
                [ self.omnibutton setTitle:@"Clear" forState:UIControlStateNormal ];

            } else {
                [ self showFeedback:@"Sorry! I couldn't find the board :(" withDuration:5.0 ];
            }
        } else {
            [ self showFeedback:@"Unable to solve. The puzzle contained a contradiction :(" withDuration:5.0 ];
            [ self update:empty_board withSolution:flat_board ];
            [ self.omnibutton setTitle:@"Clear" forState:UIControlStateNormal ];
        }
    }

    self.omnibutton.enabled = YES; // e-enable button if disabled
}

// Handle user feedback label
- (void) showFeedback:(NSString*)message withDuration:(float)duration {
    self.feedback.text = message;
    if( self.feedback.hidden ) {
        // unhide but maintain 0 alpha for fade-in effect
        self.feedback.hidden = NO;
        self.feedback.alpha = 0;

        // modify autolayout to accomodate the translation
        int distance = self.feedback.layer.frame.size.height;
        self.feedbackSpacing.constant = distance;
        [self.feedback layoutIfNeeded];
        
        [UIView animateWithDuration:0.6
                         animations:^(void){
                             self.feedback.transform = CGAffineTransformMakeTranslation(0, distance);
                             self.feedback.alpha = 1;
                         }
                         completion:^(BOOL finished) {
                             // fade-out if non-zero duration specified
                             if( duration ) {
                                 [UIView animateWithDuration:0.6
                                                       delay:2.0
                                                     options:UIViewAnimationOptionCurveEaseInOut
                                                  animations:^(void) {
                                                      self.feedback.transform = CGAffineTransformMakeTranslation(0, 0);
                                                      self.feedback.alpha = 0;
                                                  }
                                                  completion:^(BOOL finished) {
                                                      self.feedback.hidden = YES;
                                                  }
                                  ];
                             }
                         }
         ];
    }
}

@end
