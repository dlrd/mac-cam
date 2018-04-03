#import "gl-mac-app.h"
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <unistd.h>
#include <cassert>

static uint64_t program_startup_time = mach_absolute_time();

double toSeconds (uint64_t mach_host_time)
{
    static mach_timebase_info_data_t info;

    if (info.denom == 0)
        mach_timebase_info(&info);

    return (double(mach_host_time) * double(info.numer)) / double(info.denom) / 1e9;
}

double toHostSeconds (CVTimeStamp t)
{
    return toSeconds(t.hostTime - program_startup_time);
}

GLuint
compileShaderResource (GLenum type, const char* name)
{
    return compileShaderFile(
        type,
        [[NSBundle mainBundle]
            pathForResource:[NSString stringWithUTF8String: name]
            ofType: [NSString stringWithUTF8String: shaderExtension(type)]
        ].UTF8String
    );
}

@implementation AVCaptureDeviceFormat (AVRecorderAdditions)

- (NSString *)localizedName
{
	NSString *localizedName = nil;
	
	CMMediaType mediaType = CMFormatDescriptionGetMediaType([self formatDescription]);
	
	switch (mediaType)
	{
		case kCMMediaType_Video:
		{
			CFStringRef formatName = (CFStringRef) CMFormatDescriptionGetExtension([self formatDescription], kCMFormatDescriptionExtension_FormatName);
			CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions((CMVideoFormatDescriptionRef)[self formatDescription]);
			localizedName = [NSString stringWithFormat:@"%@, %d x %d", formatName, dimensions.width, dimensions.height];
		}
			break;
		case kCMMediaType_Audio:
		{
			CFStringRef formatName = NULL;
			AudioStreamBasicDescription const *originalASBDPtr = CMAudioFormatDescriptionGetStreamBasicDescription((CMAudioFormatDescriptionRef)[self formatDescription]);
			if (originalASBDPtr)
			{
				size_t channelLayoutSize = 0;
				AudioChannelLayout const *channelLayoutPtr = CMAudioFormatDescriptionGetChannelLayout((CMAudioFormatDescriptionRef)[self formatDescription], &channelLayoutSize);
				
				CFStringRef channelLayoutName = NULL;
				if (channelLayoutPtr && (channelLayoutSize > 0))
				{
					UInt32 propertyDataSize = (UInt32)sizeof(channelLayoutName);
					AudioFormatGetProperty(kAudioFormatProperty_ChannelLayoutName, (UInt32)channelLayoutSize, channelLayoutPtr, &propertyDataSize, &channelLayoutName);
				}
				
				if (channelLayoutName && (0 == CFStringGetLength(channelLayoutName)))
				{
					CFRelease(channelLayoutName);
					channelLayoutName = NULL;
				}
				
				AudioStreamBasicDescription modifiedASBD = *originalASBDPtr;
				if (channelLayoutName)
				{
					// If the format will include the description of a channel layout, zero out mChannelsPerFrame so that the number of channels does not redundantly appear in the format string.
					modifiedASBD.mChannelsPerFrame = 0;
				}
				
				UInt32 propertyDataSize = (UInt32)sizeof(formatName);
				AudioFormatGetProperty(kAudioFormatProperty_FormatName, (UInt32)sizeof(modifiedASBD), &modifiedASBD, &propertyDataSize, &formatName);
				if (!formatName)
				{
					formatName = (CFStringRef) CMFormatDescriptionGetExtension([self formatDescription], kCMFormatDescriptionExtension_FormatName);
					if (formatName)
						CFRetain(formatName);
				}
				
				if (formatName)
				{
					if (channelLayoutName)
					{
						localizedName = [NSString stringWithFormat:@"%@, %@", formatName, channelLayoutName];
					}
					else
					{
						localizedName = [NSString stringWithFormat:@"%@", formatName];
					}
					
					CFRelease(formatName);
				}
				
				if (channelLayoutName)
					CFRelease(channelLayoutName);
			}
		}
			break;
		default:
			break;
	}
	
	return localizedName;
}

@end

@implementation AVFrameRateRange (AVRecorderAdditions)

- (NSString *)localizedName
{
    if ([self minFrameRate] != [self maxFrameRate]) {
        NSString *formatString = NSLocalizedString(@"FPS: %0.2f-%0.2f", @"FPS when minFrameRate != maxFrameRate");
        return [NSString stringWithFormat:formatString, [self minFrameRate], [self maxFrameRate]];
    }
    NSString *formatString = NSLocalizedString(@"FPS: %0.2f", @"FPS when minFrameRate == maxFrameRate");
    return [NSString stringWithFormat:formatString, [self minFrameRate]];
}

@end
