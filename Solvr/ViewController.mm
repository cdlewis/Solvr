//
//  ViewController.m
//  Solvr
//
//  Created by Chris Lewis on 20/10/14.
//  Copyright (c) 2014 Chris Lewis. All rights reserved.
//

#import "ViewController.h"

#import <sstream>
#import <string>
#import <TesseractOCR/TesseractOCR.h>

#import "ComputerVision.h"
#import "NorvigSolver.h"
#import "EricaSadanCookbook.h"

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
    
    // Omnibutton
    self.omnibutton.layer.borderWidth = 4.0f;
    self.omnibutton.layer.borderColor = [ [ UIColor blackColor ] CGColor ];
    self.omnibutton.layer.cornerRadius = 40;
    [ self.omnibutton setTitle:@"Solving" forState:UIControlStateDisabled ];

    // AVCapture
    
    AVCaptureSession *session = [ [ AVCaptureSession alloc ] init ];
    session.sessionPreset = AVCaptureSessionPresetMedium;
    
    // User feedback
    self.captureVideoPreviewLayer = [ [ AVCaptureVideoPreviewLayer alloc ] initWithSession:session ];
    self.captureVideoPreviewLayer.frame = self.view.frame;
    [ self.captureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill ];
    [ self.backgroundImage.layer addSublayer:self.captureVideoPreviewLayer ];
    
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
    } else {
        NSLog( @"ERROR: trying to open camera: %@", error );
    }
}

- (void) didReceiveMemoryWarning {
    [ super didReceiveMemoryWarning ];
    // Dispose of any resources that can be recreated.
}

// Results Board Webview

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

// Omnibutton Press

- (IBAction) captureNow:(id)sender {
    // when board is visible, override default functionality and clear
    if( self.board.hidden == NO ) {
        [ self.omnibutton setTitle:@"Solve" forState:UIControlStateNormal ];
        self.board.hidden = YES;
        return;
    }
    
    // disable button to avoid mashing
    self.omnibutton.enabled = NO;
    
    // capture frame from camera
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
             image = applyAspectFillImage( image, self.captureVideoPreviewLayer.frame );
             //image = [ self applyAspectFillImage:image InRect:self.captureVideoPreviewLayer.frame ];

             // Process image

              NSString* flat_board = [ cv recogniseSudokuFromImage:image withOCR:tesseract ];
             
             // Basic check for validity of scanned board. Technically this
             // means the scanned board must have only one complete solution.
             // An empty board (all zeroes) will have multiple solutions. But
             // obviously there are other cases where this will occur. A
             // better solution could be to algorithmically check for
             // for multiple solutions, perhaps using the Norvig solver.
             NSLog( @"%@", flat_board );
         //    flat_board = @"4370680000003008070500050600400010008030506090006000300105000907050060000009 0 56";
             if( [ flat_board isEqualToString:@"000000000000000000000000000000000000000000000000000000000000000000000000000000000" ] ) {
                 NSLog( @"No solution: empty board" );
                 [ self.omnibutton setTitle:@"Solve" forState:UIControlStateNormal ];
             } else {
                 // convert to c++ string and feed to solver
                 Sudoku::init();
                 auto sc = new Sudoku( std::string( [ flat_board UTF8String ] ) );
                 
                 // contradiction detected in puzzle
                 if( sc->valid ) {
                     if( auto S = solve( std::unique_ptr<Sudoku>( sc ) ) ) {
                        [ self update:[ NSString stringWithUTF8String:S->flatten().c_str() ] ];
                        [ self.omnibutton setTitle:@"Clear" forState:UIControlStateNormal ];
                    } else {
                        NSLog( @"No solution: invalid board" );
                        [ self.omnibutton setTitle:@"Solve" forState:UIControlStateNormal ];
                    }
                 } else {
                     NSLog( @"No solution: contradiction" );
                     [ self.omnibutton setTitle:@"Solve" forState:UIControlStateNormal ];
                 }
             }
             
             // e-enable button if disabled
             self.omnibutton.enabled = YES;
         }
     }
     ];
}

@end
