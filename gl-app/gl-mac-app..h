#pragma once

#import <gl-app.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

double toSeconds (uint64_t mach_host_time);
double toHostSeconds (CVTimeStamp t);

@interface AVCaptureDeviceFormat (AVRecorderAdditions)

@property (readonly) NSString *localizedName;

@end

@interface AVFrameRateRange (AVRecorderAdditions)

@property (readonly) NSString *localizedName;

@end
