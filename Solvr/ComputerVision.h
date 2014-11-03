//
//  RecogniseBoard.h
//  Solvr
//
//  Created by Chris Lewis on 26/10/14.
//  Copyright (c) 2014 Chris Lewis. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ComputerVision : NSObject

- (UIImage*)recogniseBoardFromImage:(UIImage*)image;

@end
