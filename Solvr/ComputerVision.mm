//
//  RecogniseBoard.m
//  Solvr
//
//  Created by Chris Lewis on 26/10/14.
//  Copyright (c) 2014 Chris Lewis. All rights reserved.
//

#import "ComputerVision.h"

#import <opencv2/opencv.hpp>
#import <vector>

@implementation ComputerVision

- (UIImage*)recogniseBoardFromImage:(UIImage*)image {
    cv::Mat src = [ self cvMatFromUIImage:image ];
    
    // Pre-Process Image
    
    cv::Mat bw;
    cv::cvtColor( src, bw, CV_BGR2GRAY );
    cv::GaussianBlur( bw, bw, cv::Size( 5, 5 ), 0, 0 );
    cv::adaptiveThreshold( bw, bw, 255, cv::ADAPTIVE_THRESH_MEAN_C, cv::THRESH_BINARY_INV, 5, 2 );

    // Find Biggest Rectangle
    
    std::vector<std::vector<cv::Point>> contours;
    std::vector<cv::Vec4i> hierarchy;

    cv::findContours(bw, contours, cv::RETR_LIST, cv::CHAIN_APPROX_SIMPLE);
    
    std::vector<cv::Point> largest_contour;
    double temp_area = 0;
    double largest_area = 0;
    std::vector<cv::Point> approx; // output of approxPolyDP
    for( auto i : contours ) {
        cv::approxPolyDP( i, approx, cv::arcLength( i, true ) * 0.02, true );
        
        if( approx.size() != 4 ) { // quadrilateral?
            continue;
        }
        
        if( !cv::isContourConvex( approx ) ) { // convex?
            continue;
        }
        
        temp_area = cv::contourArea( i );
        if( temp_area > largest_area ) {
            largest_area = temp_area;
            largest_contour = approx;
        }
    }

    polarSort( largest_contour ); // order Points clockwise

    // Transform and Return Image
    
    auto corners = convertToPoint2f( largest_contour );
    cv::Mat quad = cv::Mat::zeros(300, 300, CV_8UC3);
    for( auto i : corners ) {
        std::cout << i << std::endl;
    }
    
    std::vector<cv::Point2f> quad_pts;
    quad_pts.push_back(cv::Point2f(0, 0));
    quad_pts.push_back(cv::Point2f(quad.cols, 0));
    quad_pts.push_back(cv::Point2f(quad.cols, quad.rows));
    quad_pts.push_back(cv::Point2f(0, quad.rows));
    
    cv::Mat transmtx = cv::getPerspectiveTransform(corners, quad_pts);
    cv::warpPerspective(src, quad, transmtx, quad.size());
 //   std::vector<std::vector<cv::Point>> temp;
   // temp.push_back( largest_contour );
   // cv::Scalar color( 200, 0, 0 );
    //cv::drawContours( src, temp, -1, color );
    
    return [ self UIImageFromCVMat:quad ];
    
   /*
 //   return [ self UIImageFromCVMat:bw ];
  //  cv::blur( bw, bw, cv::Size( 5, 5 ) );
   // cv::Canny( bw, bw, 100, 100, 3 );

    std::vector<cv::Vec4i> lines;
    cv::HoughLinesP( bw, lines, 1, CV_PI / 180, 70, 30, 10 );

    // expand the lines
   for (int i = 0; i < lines.size(); i++) {
        cv::Vec4i v = lines[i];
        lines[i][0] = 0;
        lines[i][1] = ((float)v[1] - v[3]) / (v[0] - v[2]) * -v[0] + v[1];
        lines[i][2] = src.cols;
        lines[i][3] = ((float)v[1] - v[3]) / (v[0] - v[2]) * (src.cols - v[2]) + v[3];
    }

    std::vector<cv::Point2f> corners;
    for (int i = 0; i < lines.size(); i++) {
        for (int j = i+1; j < lines.size(); j++) {
            cv::Point2f pt = computeIntersect(lines[i], lines[j]);
            if (pt.x >= 0 && pt.y >= 0) {
                corners.push_back(pt);
            }
        }
    }

    std::vector<cv::Point2f> approx;
    cv::approxPolyDP(cv::Mat(corners), approx, cv::arcLength(cv::Mat(corners), true) * 0.02, true);

    if (approx.size() != 4) {
        std::cout << "The object is not quadrilateral!" << std::endl;
        return [ self UIImageFromCVMat:bw ];
    }

    // Get mass center
    for (int i = 0; i < corners.size(); i++) {
        center += corners[i];
    }
    center *= (1. / corners.size());

    sortCorners(corners, center);

    cv::Mat quad = cv::Mat::zeros(300, 300, CV_8UC3);

    std::vector<cv::Point2f> quad_pts;
    quad_pts.push_back(cv::Point2f(0, 0));
    quad_pts.push_back(cv::Point2f(quad.cols, 0));
    quad_pts.push_back(cv::Point2f(quad.cols, quad.rows));
    quad_pts.push_back(cv::Point2f(0, quad.rows));

    cv::Mat transmtx = cv::getPerspectiveTransform(corners, quad_pts);
    cv::warpPerspective(src, quad, transmtx, quad.size());
    
    return [ self UIImageFromCVMat:quad ];*/
}

std::vector<cv::Point2f> convertToPoint2f( std::vector<cv::Point>& input ) {
    std::vector<cv::Point2f> output;
    
    for( auto i : input ) {
        output.push_back( cv::Point2f( i.x, i.y ) );
    }
    
    return output;
}

void polarSort( std::vector<cv::Point>& corners )
{
    auto size = corners.size();
    if( size != 4 ) {
        NSLog( @"Shape invalid. Does not have four corners" );
        return;
    }
    
    // Find center
    
    cv::Point centroid;
    double sumX = 0, sumY = 0;
    for( auto i : corners ) {
        sumX += i.x;
        sumY += i.y;
    }
    centroid.x = sumX / size;
    centroid.y = sumY / size;
    
    // Sort
    
    cv::Point tl, tr, bl, br;
    for( auto i : corners ) {
        if( i.x <= centroid.x && i.y <= centroid.y ) {
            tl = i;
        } else if( i.x >= centroid.x && i.y <= centroid.y ) {
            tr = i;
        } else if( i.x <= centroid.x && i.y >= centroid.y ) {
            bl = i;
        } else if( i.x >= centroid.x && i.y >= centroid.y ) {
            br = i;
        }
    }
    
    // Update with new values
    
    corners[ 0 ] = tl;
    corners[ 1 ] = tr;
    corners[ 2 ] = br;
    corners[ 3 ] = bl;
}

- (cv::Mat)cvMatFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}

-(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

@end
