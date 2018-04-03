#pragma once

#import "gl-app.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface AVCaptureDeviceFormat (AVRecorderAdditions)

@property (readonly) NSString *localizedName;

@end

@interface AVFrameRateRange (AVRecorderAdditions)

@property (readonly) NSString *localizedName;

@end
