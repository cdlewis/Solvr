//
//  ViewController.m
//  Solvr
//
//  Created by Chris Lewis on 20/10/14.
//  Copyright (c) 2014 Chris Lewis. All rights reserved.
//

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

- (void)viewDidLoad {
    NSLog( @"View Loaded" );
    [ super viewDidLoad ];
    
    ComputerVision *cv = [ [ ComputerVision alloc ] init ];
    
    // Tesseract
    NSLog( @"Initialise Tesseract" );
    Tesseract* tesseract = [ [ Tesseract alloc ] initWithLanguage:@"eng" ];
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

    // load sample image
    NSLog( @"Process Image" );
    UIImage *image = [UIImage imageNamed:@"Image"];
    
    NSString* flat_board = [ cv recogniseSudokuFromImage:image withOCR:tesseract ];

    // convert to c++ string and feed to solver
    Sudoku::init();
    auto sc = new Sudoku( std::string( [ flat_board UTF8String ] ) );
    if (auto S = solve( std::unique_ptr<Sudoku>( sc ) ) ) {
        std::cout << S->flatten();
        [ self update:[ NSString stringWithUTF8String:S->flatten().c_str() ] ];
    } else {
        std::cout << "No solution";
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// WebView Fun

- (void) webViewDidFinishLoad:(UIWebView*)webView {
    boardLoaded = YES; // one would expect this to be covered by webView.loading or something
    if( ![ stateCache isEqualToString:@"" ] ) {
        [ self update:stateCache ];
        stateCache = @"";
    }
}

- (void) update:(NSString*)state {
    if( boardLoaded ) {
        NSString* js = [ [ NSString alloc ] initWithFormat:@"set_board('%@');", stateCache ];
        [ self.board stringByEvaluatingJavaScriptFromString:js ];
        self.board.hidden = NO;
    } else {
        stateCache = state;
    }
}


///////////////////////////////


@end
