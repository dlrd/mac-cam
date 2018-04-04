#import "mac-cam.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#import <OpenGL/OpenGL.h>
#import "gl-mac-app.h" // FIXME: Remove this.

//------------------------------------------------------------------------------

// TODO: Proper error reporting.

//------------------------------------------------------------------------------

using STR  = CameraCapture::String;
using STRS = CameraCapture::Strings;

//------------------------------------------------------------------------------

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
debugStrings (const STRS& strings, const char* prefix = "")
{
    for (auto s : strings)
        printf("%s%s\n", prefix, s.data());
}

inline AVCaptureDevice*
findDevice (const STR& name)
{
    for (AVCaptureDevice* device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
        if (name == device.localizedName.UTF8String)
            return device;

    return nil;
}

inline AVCaptureDeviceFormat*
findFormat (AVCaptureDevice* device, const STR& formatName)
{
    if (!device)
        return nil;

    for (AVCaptureDeviceFormat* format in device.formats)
        if (formatName == format.localizedName.UTF8String)
            return format;

    return nil;
}

using DeviceAndFormat = std::pair<AVCaptureDevice*, AVCaptureDeviceFormat*>;

inline DeviceAndFormat
findDeviceAndFormat (const STR& deviceName, const STR& formatName)
{
    auto device = findDevice(deviceName);
    auto format = findFormat(device, formatName);

    return DeviceAndFormat(device, format);
}

inline AVFrameRateRange*
findFramerate (AVCaptureDevice* device, AVCaptureDeviceFormat* format, const STR& framerateName)
{
    if (!device || !format)
        return nil;
    
    for (AVFrameRateRange* framerate in format.videoSupportedFrameRateRanges)
        if (framerateName == framerate.localizedName.UTF8String)
            return framerate;
    
    return nil;
}

inline AVFrameRateRange*
findFramerate (const DeviceAndFormat& deviceAndFormat, const STR& framerateName)
{
    return findFramerate(deviceAndFormat.first, deviceAndFormat.second, framerateName);
}

//inline AVCaptureSessionPreset*
//findPreset (const STR& presetName)
//{
//
//}

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
    @public CameraCapture* cxx;
}

@property (strong)        AVCaptureSession*         session;
@property (strong)        AVCaptureVideoDataOutput* videoOutput;
@property (strong)        NSOperationQueue*         messageQueue;
@property (strong) CF_ARC dispatch_queue_t          outputQueue;
@property (strong)        NSArray*                  observers;
@property (strong) CF_ARC CVOpenGLTextureCacheRef   videoTextureCache;
@property (strong)        AVCaptureDeviceInput*     videoDeviceInput;
@property (strong)        NSArray*                  videoDevices;
@property (readonly)      NSArray*                  availableSessionPresets;
@property (assign)        AVCaptureDevice*          selectedVideoDevice;
@property (assign)        AVCaptureDeviceFormat*    videoDeviceFormat;
@property (assign)        AVFrameRateRange*         frameRateRange;

@end

//------------------------------------------------------------------------------

struct CameraCapture::That
{
    Settings            settings;
    objc_CameraCapture* objc     = [[objc_CameraCapture alloc] init];
};

//------------------------------------------------------------------------------

@implementation objc_CameraCapture

- (void) presentError:(NSError*) error
{
    // FIXME: Implement.
}

- (id) init
{
    if (!(self = [super init]))
        return nil;

    _session     = [[AVCaptureSession         alloc] init];
    _videoOutput = [[AVCaptureVideoDataOutput alloc] init];

    _outputQueue  = dispatch_queue_create("mac-cam.frames"  , DISPATCH_QUEUE_SERIAL);

    [_videoOutput setSampleBufferDelegate:self queue:_outputQueue];

    [_session addOutput:_videoOutput];

    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];

    _messageQueue = [[NSOperationQueue alloc] init];
    _messageQueue.underlyingQueue = dispatch_queue_create("mac-cam.messages", DISPATCH_QUEUE_SERIAL);

    _observers = @[
        [notificationCenter addObserverForName:AVCaptureSessionRuntimeErrorNotification
            object: _session
            queue: _messageQueue
            usingBlock: ^(NSNotification *note) {
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [self presentError:[[note userInfo] objectForKey:AVCaptureSessionErrorKey]];
                });
            }
        ],
        [notificationCenter addObserverForName:AVCaptureSessionDidStartRunningNotification
            object: _session
            queue: _messageQueue
            usingBlock: ^(NSNotification *note) {
                NSLog(@"Capture session started.");
            }
        ],
        [notificationCenter addObserverForName:AVCaptureSessionDidStopRunningNotification
            object: _session
            queue: _messageQueue
            usingBlock: ^(NSNotification *note) {
                NSLog(@"Capture session stopped.");
            }
        ],
        [notificationCenter addObserverForName:AVCaptureDeviceWasConnectedNotification
            object:nil
            queue:_messageQueue
            usingBlock:^(NSNotification *note) {
                [self refreshDevices];
            }
        ],
        [notificationCenter addObserverForName:AVCaptureDeviceWasDisconnectedNotification
            object:nil
            queue:_messageQueue
            usingBlock:^(NSNotification *note) {
                [self refreshDevices];
            }
        ]
    ];

    return self;
}

- (void) dealloc
{
    for (id observer in self.observers)
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

- (void) setupCapture
{
    // _session.sessionPreset = [NSString stringWithUTF8String: findPreset(cxx->that->settings.preset)];

    _videoOutput.videoSettings = @{
        (NSString*)kCVPixelBufferPixelFormatTypeKey : @(toCVPixelFormatType(cxx->delegate.textureType)),
        (NSString*)kCVPixelBufferOpenGLCompatibilityKey : @YES,
        (NSString*)kCVPixelBufferIOSurfacePropertiesKey : @{},
    };

    auto device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    device = findDevice(cxx->that->settings.device);
    
    if (device)
    {
        [device lockForConfiguration:nil];
    
        auto format = findFormat(device, cxx->that->settings.format);

        device.activeFormat = format;
        
        auto framerate = findFramerate(device, format, cxx->that->settings.framerate);

        device.activeVideoMinFrameDuration = framerate.minFrameDuration;
        device.activeVideoMaxFrameDuration = framerate.maxFrameDuration;

        self.selectedVideoDevice = device;

        [device unlockForConfiguration];
    }

    [self refreshDevices];
}

- (void) startCapture
{
    [self.session startRunning];
}

- (void) stopCapture
{
    [self.session stopRunning];
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

- (void)refreshDevices
{
    self.videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    [_session beginConfiguration];
    
    if (![self.videoDevices containsObject:self.selectedVideoDevice])
        self.selectedVideoDevice = nil;
    
    [_session commitConfiguration];
}

+ (NSSet *)keyPathsForValuesAffectingVideoDeviceFormat
{
    return [NSSet setWithObjects: @"selectedVideoDevice.activeFormat", nil];
}

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
            [self.selectedVideoDevice setActiveVideoMaxFrameDuration:frameRateRange.maxFrameDuration];
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
    NSMutableArray *availableSessionPresets = [NSMutableArray arrayWithCapacity:allSessionPresets.count];
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

    if (toCVPixelFormatType(cxx->delegate.textureType) != CMFormatDescriptionGetMediaSubType(formatDescription))
        return;
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);

    if (!pixelBuffer)
        return;

    cxx->delegate.makeOpenGLContextCurrent();

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

    cxx->delegate.cameraFrameWasCaptured(frame);
}

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;
{

}

@end

//------------------------------------------------------------------------------

CameraCapture::CameraCapture ()
    : that(new That())
{
    that->objc->cxx = this;
}

CameraCapture::~CameraCapture ()
{
    delete that;
}

STRS
CameraCapture::queryDevices ()
{
    Strings ret;

    for (AVCaptureDevice* device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
        ret.emplace_back(device.localizedName.UTF8String);

    return ret;
}

STRS
CameraCapture::queryFormats (String cameraName)
{
    Strings ret;
    
    AVCaptureDevice* device = findDevice(cameraName);

    if (!device)
        return ret;

    for (AVCaptureDeviceFormat* format in device.formats)
        ret.emplace_back(format.localizedName.UTF8String);

    return ret;
}

STRS
CameraCapture::queryFramerates (String cameraName, String resolutionName)
{
    Strings ret;
    
    DeviceAndFormat deviceAndFormat = findDeviceAndFormat(cameraName, resolutionName);
 
    if (!deviceAndFormat.first || !deviceAndFormat.second)
        return ret;

    for (AVFrameRateRange* framerate in deviceAndFormat.second.videoSupportedFrameRateRanges)
        ret.emplace_back(framerate.localizedName.UTF8String);
    
    return ret;
}

STRS
CameraCapture::queryPresets (String cameraName)
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

CameraCapture::Settings
CameraCapture::defaults ()
{
    Settings ret;

    Strings devices = queryDevices();
    
    if (devices.empty())
        return ret;

    ret.device = devices.front();
    
    Strings formats = queryFormats(ret.device);

    if (formats.empty())
        return ret;
    
    ret.format = formats.back();

    Strings framerates = queryFramerates(ret.device, ret.format);

    if (framerates.empty())
        return ret;

    ret.framerate = framerates.front();

    Strings presets = queryPresets(ret.device);

    if (presets.empty())
        return ret;

    ret.preset = presets.back();

    return ret;
}

const CameraCapture::Settings&
CameraCapture::settings ()
{
    return that->settings;
}

void
CameraCapture::setup (const Settings& settings)
{
    Strings devices = queryDevices();

#if DEBUG
    debugStrings(devices, "Device: ");

    for (auto device : devices)
    {
        Strings formats = queryFormats(device);
        debugStrings(formats, "Format: ");

        for (String format : formats)
        {
            Strings framerates = queryFramerates(device, format);

            debugStrings(framerates, (String("Framerate (") + format + "): ").data());
        }

        Strings presets = queryPresets(device);
        debugStrings(presets, "Preset: ");
    }
#endif

    that->settings = settings;

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
//capture.videoDevices
//capture.videoDevices.localizedName
//capture.selectedVideoDevice.formats
//capture.selectedVideoDevice.formats.localizedName
//capture.videoDeviceFormat
//capture.frameRateRange
//capture.selectedVideoDevice.activeFormat.videoSupportedFrameRateRanges
//capture.selectedVideoDevice.activeFormat.videoSupportedFrameRateRanges.localizedName
//capture.availableSessionPresets
//capture.session.sessionPreset


