//
//  EricaSadanCookbook.h
//  Solvr
//
//  Created by Chris Lewis on 30/12/14.
//  Adpted from: https://github.com/erica
//

#import <UIKit/UIKit.h>

CGRect CGRectCenteredInRect( CGRect rect, CGRect mainRect ) {
    CGFloat xOffset = CGRectGetMidX( mainRect ) - CGRectGetMidX( rect );
    CGFloat yOffset = CGRectGetMidY( mainRect ) - CGRectGetMidY( rect );
    return CGRectOffset( rect, xOffset, yOffset );
}

CGFloat CGAspectScaleFill( CGSize sourceSize, CGRect destRect )
{
    CGSize destSize = destRect.size;
    CGFloat scaleW = destSize.width / sourceSize.width;
    CGFloat scaleH = destSize.height / sourceSize.height;
    return MAX( scaleW, scaleH );
}

CGRect CGRectAspectFillRect( CGSize sourceSize, CGRect destRect ) {
    CGSize destSize = destRect.size;
    CGFloat destScale = CGAspectScaleFill( sourceSize, destRect );
    CGFloat newWidth = sourceSize.width * destScale;
    CGFloat newHeight = sourceSize.height * destScale;
    CGFloat dWidth = ( ( destSize.width - newWidth ) / 2.0f );
    CGFloat dHeight = ( ( destSize.height - newHeight) / 2.0f );
    CGRect rect = CGRectMake( dWidth, dHeight, newWidth, newHeight );
    return rect;
}

UIImage* applyAspectFillImage( UIImage* image, CGRect bounds ) {
    CGRect destRect;
    
    UIGraphicsBeginImageContext( bounds.size );
    CGRect rect = CGRectAspectFillRect( image.size, bounds );
    destRect = CGRectCenteredInRect( rect, bounds );
    
    [ image drawInRect: destRect ];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}