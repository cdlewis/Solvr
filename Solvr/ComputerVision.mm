//
//  RecogniseBoard.m
//  Solvr
//
//  Created by Chris Lewis on 26/10/14.
//

#import "ComputerVision.h"
#import <vector>
#import <opencv2/opencv.hpp>

@implementation ComputerVision

const int SUDOKU_RESIZE = 450;
const int NUM_ROWS = 9;

//  Google's Python-based parser (http://goo.gl/66K7vg) was very helpful

- (NSString*) recogniseSudokuFromImage:(UIImage*)image withOCR:(Tesseract*)ocr {
    char output[] = "000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    
    auto src = [ self cvMatFromUIImage:image ];
    
    auto quad = getBiggestSqaure( src );
  
    // Setup OCR
    
    auto cv_image = quad.clone();
    auto ui_image = [ self UIImageFromCVMat:quad ];
    [ ocr setImage:ui_image ];
    
    // Get major contours
  
    cv::cvtColor( quad, quad, CV_BGR2GRAY );
    cv::GaussianBlur( quad, quad, cv::Size( 3, 3 ), 0, 0 );
    cv::adaptiveThreshold( quad, quad, 255, cv::ADAPTIVE_THRESH_MEAN_C, cv::THRESH_BINARY, 5, 2 );
    
    std::vector<std::vector<cv::Point>> contours;
    std::vector<cv::Vec4i> hierarchy;
    cv::Mat quad_copy = quad.clone(); // findContours will modify quad
    cv::Mat quad_copy_copy = quad.clone(); // findContours will modify quad
    cv::findContours( quad, contours, cv::RETR_LIST, cv::CHAIN_APPROX_SIMPLE );
    
    // Erode and dilate the image to further amplify features
    
    auto kernel = cv::getStructuringElement( cv::MORPH_CROSS, cv::Size( 3, 3 ) );
    cv::erode( quad_copy, quad_copy, kernel );
    cv::dilate( quad_copy, quad_copy, kernel );
    
    double area;
    cv::Rect r;
    for( auto contour : contours ) {
        area = cv::contourArea( contour );
        if( area > 50 && area < 800 ) {
            r = cv::boundingRect( contour );
            if( (r.width*r.height) > 100 && (r.width*r.height) < 1200 && r.width > 5 && r.width < 40 && r.height > 10 && r.height < 45 ) {
                [ ocr setRect:CGRectMake( r.x, r.y, r.width, r.height ) ];
                [ ocr recognize ];
                int gridx = ( r.x + r.width / 2 ) / ( SUDOKU_RESIZE / NUM_ROWS );
                int gridy = ( r.y + r.height / 2 ) / ( SUDOKU_RESIZE / NUM_ROWS );
                
                // avoid awkward situations where the empty string is 'recognized'
                if( [ [ ocr recognizedText ] length ] != 0 ) {
                    output[ gridx + gridy * 9 ] = [ [ ocr recognizedText ] characterAtIndex:0 ];
                }
            }
        }
    }
    
    return [ [ NSString alloc ] initWithUTF8String:output ];
}

cv::Mat getBiggestSqaure( cv::Mat& image ) {
    // Pre-Process Image
    
    cv::Mat bw;
    cv::cvtColor( image, bw, CV_BGR2GRAY );
    cv::GaussianBlur( bw, bw, cv::Size( 5, 5 ), 0, 0 );
    cv::adaptiveThreshold( bw, bw, 255, cv::ADAPTIVE_THRESH_MEAN_C, cv::THRESH_BINARY_INV, 5, 2 );
    
    // Find Board (Biggest Rectangle)
    
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
    
    polarSort( largest_contour );
    
    // Transform Image to Focus on Board
    
    auto corners = convertToPoint2f( largest_contour );
    cv::Mat quad = cv::Mat::zeros( SUDOKU_RESIZE, SUDOKU_RESIZE, CV_8UC3 );
    
    std::vector<cv::Point2f> quad_pts;
    quad_pts.push_back( cv::Point2f( 0, 0 ) );
    quad_pts.push_back( cv::Point2f( quad.cols, 0 ) );
    quad_pts.push_back( cv::Point2f( quad.cols, quad.rows ) );
    quad_pts.push_back( cv::Point2f( 0, quad.rows ) );
    
    cv::Mat transmtx = cv::getPerspectiveTransform( corners, quad_pts );
    cv::warpPerspective( image, quad, transmtx, quad.size() );
    
    return quad;
}

// Convert a vector of points to a vector of 2d floating points
std::vector<cv::Point2f> convertToPoint2f( std::vector<cv::Point>& input ) {
    std::vector<cv::Point2f> output;
    
    for( auto i : input ) {
        output.push_back( cv::Point2f( i.x, i.y ) );
    }
    
    return output;
}

// Calculate center of rectangle and order points clockwise
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

// Conversion functions courtesy of: http://docs.opencv.org/doc/tutorials/ios/image_manipulation/image_manipulation.html

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
