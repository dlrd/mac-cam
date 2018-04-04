#import "mac-cam.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#import <OpenGL/OpenGL.h>
#import "gl-mac-app.h" // FIXME: Remove this.

static NSArray* allSessionPresets = @[
    AVCaptureSessionPresetLow,
    AVCaptureSessionPresetMedium,
    AVCaptureSessionPresetHigh,
    AVCaptureSessionPreset320x240,
    AVCaptureSessionPreset352x288,
    AVCaptureSessionPreset640x480,
    AVCaptureSessionPreset960x540,
    AVCaptureSessionPreset1280x720,
    AVCaptureSessionPresetPhoto,
];

//------------------------------------------------------------------------------

inline void
debugStrings (const CameraCapture::Strings& strings, const char* prefix = "")
{
    for (auto s : strings)
        printf("%s%s\n", prefix, s.data());
}

inline OSType
toCVPixelFormatType (CameraCapture::TextureType from)
{
    switch (from)
    {
        case CameraCapture::TextureType::_422YpCbCr8: return kCVPixelFormatType_422YpCbCr8;
        case CameraCapture::TextureType::_32BGRA    : return kCVPixelFormatType_32BGRA;

        default:
            return -1;
    }
}

inline CameraCapture::TextureType
toCameraTextureType (OSType from)
{
    switch (from)
    {
        case kCVPixelFormatType_422YpCbCr8: return CameraCapture::TextureType::_422YpCbCr8;
        case kCVPixelFormatType_32BGRA    : return CameraCapture::TextureType::_32BGRA;

        default:
            return CameraCapture::TextureType::Invalid;
    }
}

//------------------------------------------------------------------------------

struct CameraCapture::Frame::That
{
    That (
        CMSampleBufferRef  sampleBuffer_,
        CVPixelBufferRef   pixelBuffer_,
        CVOpenGLTextureRef texture_
    )
        : sampleBuffer(sampleBuffer_)
        , pixelBuffer(pixelBuffer_)
        , texture(texture_)
    {
        CFRetain(sampleBuffer);
        CFRetain(pixelBuffer);
        CFRetain(texture);
    }
    
    ~That ()
    {
        CFRelease(sampleBuffer);
        CFRelease(pixelBuffer);
        CFRelease(texture);
    }

    CMSampleBufferRef  sampleBuffer;
    CVPixelBufferRef   pixelBuffer;
    CVOpenGLTextureRef texture;
};

//------------------------------------------------------------------------------

int
CameraCapture::Frame::width ()
{
    return int(CVPixelBufferGetWidth(that->pixelBuffer));
}

int
CameraCapture::Frame::height ()
{
    return int(CVPixelBufferGetHeight(that->pixelBuffer));
}

double
CameraCapture::Frame::timeInSeconds ()
{
    return CMTimeGetSeconds(CMSampleBufferGetOutputPresentationTimeStamp(that->sampleBuffer));
}

GLuint
CameraCapture::Frame::glTextureName ()
{
    return CVOpenGLTextureGetName(that->texture);
}

GLenum
CameraCapture::Frame::glTextureTarget ()
{
    return CVOpenGLTextureGetTarget(that->texture);
}

CameraCapture::TextureType
CameraCapture::Frame::textureType ()
{
    return toCameraTextureType(CMFormatDescriptionGetMediaSubType(CMSampleBufferGetFormatDescription(that->sampleBuffer)));
}

CameraCapture::Frame::~Frame ()
{
    delete that;
}

//------------------------------------------------------------------------------

#define CF_ARC __attribute__((NSObject))

@interface objc_CameraCapture : NSObject<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    @public CameraCapture::Settings settings;
}

@property (strong)        AVCaptureSession*         session;
@property (strong)        NSArray*                  observers;
@property (strong)        AVCaptureDeviceInput*     videoDeviceInput;
@property (strong)        AVCaptureVideoDataOutput* videoOutput;
@property (strong) CF_ARC dispatch_queue_t          cameraOutputQueue;
@property (strong) CF_ARC CVOpenGLTextureCacheRef   videoTextureCache;
@property (strong)        NSArray*                  videoDevices;
@property (readonly)      NSArray*                  availableSessionPresets;
@property (assign)        AVCaptureDevice*          selectedVideoDevice;
@property (assign)        AVCaptureDeviceFormat*    videoDeviceFormat;
@property (assign)        AVFrameRateRange*         frameRateRange;

@end

//------------------------------------------------------------------------------

@implementation objc_CameraCapture

- (void) presentError:(NSError*) error
{
    // FIXME: Implement.
}

- (void) setupCapture
{
    _session = [[AVCaptureSession alloc] init];

    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    _observers = @[
        [notificationCenter addObserverForName:AVCaptureSessionRuntimeErrorNotification
            object: _session
            queue: [NSOperationQueue mainQueue]
            usingBlock: ^(NSNotification *note) {
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [self presentError:[[note userInfo] objectForKey:AVCaptureSessionErrorKey]];
                });
            }
        ],
        [notificationCenter addObserverForName:AVCaptureSessionDidStartRunningNotification
            object: _session
            queue: [NSOperationQueue mainQueue]
            usingBlock: ^(NSNotification *note) {
                NSLog(@"Capture session started.");
            }
        ],
        [notificationCenter addObserverForName:AVCaptureSessionDidStopRunningNotification
            object: _session
            queue: [NSOperationQueue mainQueue]
            usingBlock: ^(NSNotification *note) {
                NSLog(@"Capture session stopped.");
            }
        ],
        [notificationCenter addObserverForName:AVCaptureDeviceWasConnectedNotification
            object:nil
            queue:[NSOperationQueue mainQueue]
            usingBlock:^(NSNotification *note) {
                [self refreshDevices];
            }
        ],
        [notificationCenter addObserverForName:AVCaptureDeviceWasDisconnectedNotification
            object:nil
            queue:[NSOperationQueue mainQueue]
            usingBlock:^(NSNotification *note) {
                [self refreshDevices];
            }
        ]
    ];

    _cameraOutputQueue = dispatch_queue_create("CameraOutputQueue", DISPATCH_QUEUE_SERIAL);

    _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [_videoOutput setSampleBufferDelegate:self queue:_cameraOutputQueue];

    _videoOutput.videoSettings = @{
        (NSString*)kCVPixelBufferPixelFormatTypeKey : @(toCVPixelFormatType(settings.textureType)),
        (NSString*)kCVPixelBufferOpenGLCompatibilityKey : @YES,
        (NSString*)kCVPixelBufferIOSurfacePropertiesKey : @{},
    };

    [_session addOutput:_videoOutput];

    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (videoDevice)
        self.selectedVideoDevice = videoDevice;
    else
        self.selectedVideoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeMuxed];

    // Initial refresh of device list
    [self refreshDevices];
}

- (void) startCapture
{
    [self.session startRunning];
}

- (void) stopCapture
{
    // Stop the session
    [self.session stopRunning];
    
    // Remove Observers
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    for (id observer in [self observers])
        [notificationCenter removeObserver:observer];
}

- (void)refreshDevices
{
    self.videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    [_session beginConfiguration];
    
    if (![self.videoDevices containsObject:self.selectedVideoDevice])
        self.selectedVideoDevice = nil;
        
    [_session commitConfiguration];
}

- (AVCaptureDevice *)selectedVideoDevice
{
    return _videoDeviceInput.device;
}

- (void)setSelectedVideoDevice:(AVCaptureDevice *)selectedVideoDevice
{
    [_session beginConfiguration];
    
    if (self.videoDeviceInput) {
        // Remove the old device input from the session
        [_session removeInput:self.videoDeviceInput];
        self.videoDeviceInput = nil;
    }
    
    if (selectedVideoDevice) {
        NSError *error = nil;
        
        // Create a device input for the device and add it to the session
        AVCaptureDeviceInput *newVideoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:selectedVideoDevice error:&error];
        if (newVideoDeviceInput == nil) {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self presentError:error];
            });
        } else {
            if (![selectedVideoDevice supportsAVCaptureSessionPreset:_session.sessionPreset])
                _session.sessionPreset = AVCaptureSessionPresetHigh;
            
            [_session addInput:newVideoDeviceInput];

            self.videoDeviceInput = newVideoDeviceInput;
        }
    }
    
    [_session commitConfiguration];
}

//+ (NSSet *)keyPathsForValuesAffectingVideoDeviceFormat
//{
//    return [NSSet setWithObjects: @"selectedVideoDevice.activeFormat", nil];
//}

- (AVCaptureDeviceFormat *)videoDeviceFormat
{
    return self.selectedVideoDevice.activeFormat;
}

- (void)setVideoDeviceFormat:(AVCaptureDeviceFormat *)deviceFormat
{
    NSError *error = nil;
    AVCaptureDevice *videoDevice = self.selectedVideoDevice;
    if ([videoDevice lockForConfiguration:&error]) {
        [videoDevice setActiveFormat:deviceFormat];
        [videoDevice unlockForConfiguration];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self presentError:error];
        });
    }
}

+ (NSSet *)keyPathsForValuesAffectingFrameRateRange
{
    return [NSSet setWithObjects: @"selectedVideoDevice.activeFormat.videoSupportedFrameRateRanges", nil];
}

- (AVFrameRateRange *)frameRateRange
{
    AVFrameRateRange *activeFrameRateRange = nil;
    for (AVFrameRateRange *frameRateRange in self.selectedVideoDevice.activeFormat.videoSupportedFrameRateRanges)
    {
        if (CMTIME_COMPARE_INLINE([frameRateRange minFrameDuration], ==, self.selectedVideoDevice.activeVideoMinFrameDuration))
        {
            activeFrameRateRange = frameRateRange;
            break;
        }
    }
    
    return activeFrameRateRange;
}

- (void)setFrameRateRange:(AVFrameRateRange *)frameRateRange
{
    NSError *error = nil;
    if ([self.selectedVideoDevice.activeFormat.videoSupportedFrameRateRanges containsObject:frameRateRange])
    {
        if ([self.selectedVideoDevice lockForConfiguration:&error]) {
            [self.selectedVideoDevice setActiveVideoMinFrameDuration:frameRateRange.minFrameDuration];
            [self.selectedVideoDevice unlockForConfiguration];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self presentError:error];
            });
        }
    }
}

+ (NSSet *)keyPathsForValuesAffectingAvailableSessionPresets
{
    return [NSSet setWithObjects:@"selectedVideoDevice", nil];
}

- (NSArray *)availableSessionPresets
{
    NSMutableArray *availableSessionPresets = [NSMutableArray arrayWithCapacity:9];
    for (NSString *sessionPreset in allSessionPresets) {
        if ([_session canSetSessionPreset:sessionPreset])
            [availableSessionPresets addObject:sessionPreset];
    }

    return availableSessionPresets;
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;
{
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);

    if (kCMMediaType_Video != CMFormatDescriptionGetMediaType(formatDescription))
        return;

    if (toCVPixelFormatType(settings.textureType) != CMFormatDescriptionGetMediaSubType(formatDescription))
        return;
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);

    if (!pixelBuffer)
        return;

    settings.makeOpenGLContextCurrent();
    
    if (_videoTextureCache)
    {
        CVOpenGLTextureCacheFlush(_videoTextureCache, 0);
    }
    else
    {
        CVReturn err = CVOpenGLTextureCacheCreate(
            kCFAllocatorDefault,
            NULL,
            CGLGetCurrentContext(),
            CGLGetPixelFormat(CGLGetCurrentContext()),
            NULL,
            &_videoTextureCache
        );
    
        if (err != noErr)
        {
            NSLog(@"CVOpenGLESTextureCacheCreate failed: %d", err);
    
            abort(); // FIXME: Report error instead.
        }
    }

    CVOpenGLTextureRef texture = NULL;

    CVReturn err = CVOpenGLTextureCacheCreateTextureFromImage(
        kCFAllocatorDefault,
        _videoTextureCache,
        pixelBuffer,
        NULL,
        &texture
    );

    if (!texture || err)
    {
        NSLog(@"CVOpenGLTextureCacheCreateTextureFromImage failed: %d", err);
        NSLog(@"%@", pixelBuffer);
    
        abort(); // FIXME: Report error instead.
    }
    
    CameraCapture::FramePtr frame = std::make_shared<CameraCapture::Frame>(new CameraCapture::Frame::That(
        sampleBuffer,
        pixelBuffer,
        texture
    ));
    
    CFRelease(texture);

    settings.cameraFrameWasCaptured(frame);
}

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;
{

}

@end

//------------------------------------------------------------------------------

struct CameraCapture::That
{
    objc_CameraCapture* objc = [[objc_CameraCapture alloc] init];
};

CameraCapture::CameraCapture ()
    : that(new That())
{

}

CameraCapture::~CameraCapture ()
{
    delete that;
}

inline AVCaptureDevice*
findDevice (CameraCapture::String name)
{
    for (AVCaptureDevice* device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
        if (name == device.localizedName.UTF8String)
            return device;

    return nil;
}

using DeviceAndFormat = std::pair<AVCaptureDevice*, AVCaptureDeviceFormat*>;

inline DeviceAndFormat
findDeviceAndFormat (CameraCapture::String deviceName, CameraCapture::String formatName)
{
    for (AVCaptureDevice* device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
    {
        if (deviceName != device.localizedName.UTF8String)
            continue;

        for (AVCaptureDeviceFormat* format in device.formats)
            if (formatName == format.localizedName.UTF8String)
                return DeviceAndFormat(device, format);
    }
    
    return DeviceAndFormat(nil, nil);
}

CameraCapture::Strings
CameraCapture::cameraNames ()
{
    Strings ret;

    for (AVCaptureDevice* device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
        ret.emplace_back(device.localizedName.UTF8String);

    return ret;
}

CameraCapture::Strings
CameraCapture::cameraPresets (String cameraName)
{
    Strings ret;

    AVCaptureDevice* device = findDevice(cameraName);

    if (!device)
        return ret;

    for (NSString* preset in allSessionPresets)
    {
        if (![device supportsAVCaptureSessionPreset:preset])
            continue;

        ret.emplace_back(preset.UTF8String);
    }
    
    return ret;
}

CameraCapture::Strings
CameraCapture::cameraResolutions (String cameraName)
{
    Strings ret;
    
    AVCaptureDevice* device = findDevice(cameraName);

    if (!device)
        return ret;

    for (AVCaptureDeviceFormat* format in device.formats)
        ret.emplace_back(format.localizedName.UTF8String);

    return ret;
}

CameraCapture::Strings
CameraCapture::cameraFramerates (String cameraName, String resolutionName)
{
    Strings ret;
    
    DeviceAndFormat deviceAndFormat = findDeviceAndFormat(cameraName, resolutionName);
 
    if (!deviceAndFormat.first || !deviceAndFormat.second)
        return ret;

    for (AVFrameRateRange* framerate in deviceAndFormat.second.videoSupportedFrameRateRanges)
        ret.emplace_back(framerate.localizedName.UTF8String);
    
    return ret;
}

void
CameraCapture::setup (const Settings& settings)
{
    Strings deviceNames = cameraNames();

#if DEBUG
    debugStrings(deviceNames, "Device: ");

    for (auto cameraName : deviceNames)
    {
        Strings presets     = cameraPresets(cameraName);
        debugStrings(presets, "Preset: ");

        Strings resolutions = cameraResolutions(cameraName);
        debugStrings(resolutions, "Resolution: ");

        for (String resolutionName : resolutions)
        {
            Strings framerates = cameraFramerates(cameraName, resolutionName);

            debugStrings(framerates, (String("Framerate (") + resolutionName + "): ").data());
        }
    }
#endif

    that->objc->settings = settings;

    [that->objc setupCapture];
}

void
CameraCapture::start ()
{
    [that->objc startCapture];
}

void
CameraCapture::stop ()
{
    [that->objc stopCapture];
}

//------------------------------------------------------------------------------

NSObject*
objc (CameraCapture* cameraCapture)
{
    return cameraCapture->that->objc;
}

//capture.selectedVideoDevice
//capture.videoDevices>
//capture.videoDevices.localizedName
//capture.selectedVideoDevice.formats
//capture.selectedVideoDevice.formats.localizedName
//capture.videoDeviceFormat
//capture.frameRateRange
//capture.selectedVideoDevice.activeFormat.videoSupportedFrameRateRanges
//capture.selectedVideoDevice.activeFormat.videoSupportedFrameRateRanges.localizedName
//capture.availableSessionPresets
//capture.session.sessionPreset


