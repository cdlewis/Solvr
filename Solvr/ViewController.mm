//
//  ViewController.m
//  Solvr
//
//  Created by Chris Lewis on 20/10/14.
//  Copyright (c) 2014 Chris Lewis. All rights reserved.
//

#import "ViewController.h"
#import "ComputerVision.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    ComputerVision *cv = [ [ ComputerVision alloc ] init ];
    
    // load sample image
    UIImage *image = [UIImage imageNamed:@"Image"];
    UIImage *board = [ cv recogniseBoardFromImage:image ];
    
    self.backgroundImage.image = board;
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

///////////////////////////////


@end
