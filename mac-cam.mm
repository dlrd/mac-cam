#import "mac-cam.h"
#import <AVFoundation/AVFoundation.h>
#import <OpenGL/OpenGL.h>
#include <CoreVideo/CoreVideo.h>
#import "mac-gl-view.h"

//------------------------------------------------------------------------------

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

#define CF_ARC __attribute__((NSObject))

@interface objc_CameraCapture : NSObject
<
    AVCaptureVideoDataOutputSampleBufferDelegate
>

@property                 CameraCapture::Settings   settings;
@property (strong)        AVCaptureSession*         session;
@property (assign)        AVCaptureDevice*          selectedVideoDevice;
@property (assign)        AVCaptureDeviceFormat*    videoDeviceFormat;
@property (assign)        AVFrameRateRange*         frameRateRange;
@property (strong)        AVCaptureDeviceInput*     videoDeviceInput;
@property (strong)        NSArray*                  observers;
@property (strong)        AVCaptureVideoDataOutput* videoOutput;
@property (strong) CF_ARC dispatch_queue_t          cameraOutputQueue;
@property (strong) CF_ARC CVOpenGLTextureCacheRef   videoTextureCache;

@property (strong) NSArray *videoDevices;
@property (readonly) NSArray *availableSessionPresets;

@end

@implementation objc_CameraCapture

- (void) presentError:(NSError*) error
{
    // FIXME: Implement.
}

- (void) setupCapture
{
    // Create a capture session
    _session = [[AVCaptureSession alloc] init];

    // Capture Notification Observers
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    id runtimeErrorObserver = [notificationCenter addObserverForName:AVCaptureSessionRuntimeErrorNotification
                                                              object:_session
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification *note) {
                                                              dispatch_async(dispatch_get_main_queue(), ^(void) {
                                                                  [self presentError:[[note userInfo] objectForKey:AVCaptureSessionErrorKey]];
                                                              });
                                                          }];
    id didStartRunningObserver = [notificationCenter addObserverForName:AVCaptureSessionDidStartRunningNotification
                                                                 object:_session
                                                                  queue:[NSOperationQueue mainQueue]
                                                             usingBlock:^(NSNotification *note) {
                                                                 NSLog(@"did start running");
                                                             }];
    id didStopRunningObserver = [notificationCenter addObserverForName:AVCaptureSessionDidStopRunningNotification
                                                                object:_session
                                                                 queue:[NSOperationQueue mainQueue]
                                                            usingBlock:^(NSNotification *note) {
                                                                NSLog(@"did stop running");
                                                            }];
    id deviceWasConnectedObserver = [notificationCenter addObserverForName:AVCaptureDeviceWasConnectedNotification
                                                                    object:nil
                                                                     queue:[NSOperationQueue mainQueue]
                                                                usingBlock:^(NSNotification *note) {
                                                                    [self refreshDevices];
                                                                }];
    id deviceWasDisconnectedObserver = [notificationCenter addObserverForName:AVCaptureDeviceWasDisconnectedNotification
                                                                       object:nil
                                                                        queue:[NSOperationQueue mainQueue]
                                                                   usingBlock:^(NSNotification *note) {
                                                                       [self refreshDevices];
                                                                   }];
    _observers = [[NSArray alloc] initWithObjects:runtimeErrorObserver, didStartRunningObserver, didStopRunningObserver, deviceWasConnectedObserver, deviceWasDisconnectedObserver, nil];

    _cameraOutputQueue = dispatch_queue_create("CameraOutputQueue", DISPATCH_QUEUE_SERIAL);

    _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [_videoOutput setSampleBufferDelegate:self queue:_cameraOutputQueue];

    _videoOutput.videoSettings = @{
        (NSString*)kCVPixelBufferPixelFormatTypeKey : @(toCVPixelFormatType(_settings.cameraTextureType)),
        (NSString*)kCVPixelBufferOpenGLCompatibilityKey : @YES,
        (NSString*)kCVPixelBufferIOSurfacePropertiesKey : @{},
    };

    [_session addOutput:_videoOutput];

    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (videoDevice) {
        [self setSelectedVideoDevice:videoDevice];
    } else {
        [self setSelectedVideoDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeMuxed]];
    }

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
    return [_videoDeviceInput device];
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
            if (![selectedVideoDevice supportsAVCaptureSessionPreset:[_session sessionPreset]])
                [_session setSessionPreset:AVCaptureSessionPresetHigh];
            
            [_session addInput:newVideoDeviceInput];
            [self setVideoDeviceInput:newVideoDeviceInput];
        }
    }
    
    [_session commitConfiguration];
}

+ (NSSet *)keyPathsForValuesAffectingVideoDeviceFormat
{
    return [NSSet setWithObjects:@"selectedVideoDevice.activeFormat", nil];
}

- (AVCaptureDeviceFormat *)videoDeviceFormat
{
    return [[self selectedVideoDevice] activeFormat];
}

- (void)setVideoDeviceFormat:(AVCaptureDeviceFormat *)deviceFormat
{
    NSError *error = nil;
    AVCaptureDevice *videoDevice = [self selectedVideoDevice];
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
    return [NSSet setWithObjects:@"selectedVideoDevice.activeFormat.videoSupportedFrameRateRanges", nil];
}

- (AVFrameRateRange *)frameRateRange
{
    AVFrameRateRange *activeFrameRateRange = nil;
    for (AVFrameRateRange *frameRateRange in [[[self selectedVideoDevice] activeFormat] videoSupportedFrameRateRanges])
    {
        if (CMTIME_COMPARE_INLINE([frameRateRange minFrameDuration], ==, [[self selectedVideoDevice] activeVideoMinFrameDuration]))
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
    if ([[[[self selectedVideoDevice] activeFormat] videoSupportedFrameRateRanges] containsObject:frameRateRange])
    {
        if ([[self selectedVideoDevice] lockForConfiguration:&error]) {
            [[self selectedVideoDevice] setActiveVideoMinFrameDuration:[frameRateRange minFrameDuration]];
            [[self selectedVideoDevice] unlockForConfiguration];
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
    NSArray *allSessionPresets = [NSArray arrayWithObjects:
        AVCaptureSessionPresetLow,
        AVCaptureSessionPresetMedium,
        AVCaptureSessionPresetHigh,
        AVCaptureSessionPreset320x240,
        AVCaptureSessionPreset352x288,
        AVCaptureSessionPreset640x480,
        AVCaptureSessionPreset960x540,
        AVCaptureSessionPreset1280x720,
        AVCaptureSessionPresetPhoto,
    nil];

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

    if (toCVPixelFormatType(_settings.cameraTextureType) != CMFormatDescriptionGetMediaSubType(formatDescription))
        return;
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);

    if (!pixelBuffer)
        return;

    self.settings.makeOpenGLContextCurrent();
    
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

    self.settings.cameraFrameWasCaptured(frame);
}

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection NS_AVAILABLE(10_7, 6_0);
{

}

@end

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

void
CameraCapture::setup (const Settings& settings)
{
    that->objc.settings = settings;

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

@interface AVCaptureDocument ()

@property (strong) AVCaptureVideoPreviewLayer *previewLayer;

@end

@implementation AVCaptureDocument
{
    CameraCapture cameraCapture;
}

- (void)windowControllerDidLoadNib:(NSWindowController*) aController
{
    [super windowControllerDidLoadNib:aController];

    CameraCapture::Settings settings;
    
    settings.cameraFrameWasCaptured = [self] (CameraCapture::FramePtr frame) {
    
        self.glCamView.cameraFrame = frame;

    };

    settings.makeOpenGLContextCurrent = [self] () {
    
        [self.glCamView.openGLContext makeCurrentContext];
    
    };

    cameraCapture.setup(settings);
    
    // Start the session aysnchronously, or GL init may happen too late.
    dispatch_async(dispatch_get_main_queue(), ^{

        self->cameraCapture.start();

    });
}

- (void)windowWillClose:(NSNotification *)notification
{
    cameraCapture.stop();
}

- (NSString *)windowNibName
{
    return @"window";
}

- (IBAction)stop:(id)sender
{
    cameraCapture.stop();
}

- (NSObject*) capture
{
    return cameraCapture.that->objc;
}

//- (void)forwardInvocation:(NSInvocation *)anInvocation
//{
//    if ([cameraCapture.that->objc respondsToSelector: [anInvocation selector]])
//        [anInvocation invokeWithTarget:cameraCapture.that->objc];
//    else
//        [super forwardInvocation:anInvocation];
//}
//
//- (id)forwardingTargetForSelector:(SEL)sel
//{
//    return cameraCapture.that->objc;
//}

@end

