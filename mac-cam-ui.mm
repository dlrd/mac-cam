#import "mac-cam-ui.h"
#import "mac-gl-view.h"
#import <AVFoundation/AVFoundation.h>

//------------------------------------------------------------------------------

@implementation AVCaptureDocument
{
    CameraCapture cameraCapture;
}

- (void)windowControllerDidLoadNib:(NSWindowController*) aController
{
    [super windowControllerDidLoadNib:aController];

    self->cameraCapture.delegate.cameraFrameWasCaptured = [self] (CameraCapture::FramePtr frame) {
    
        self.glCamView.cameraFrame = frame;

    };

    self->cameraCapture.delegate.makeOpenGLContextCurrent = [self] () {
    
        [self.glCamView.openGLContext makeCurrentContext];
    
    };

    self->cameraCapture.delegate.textureType = CameraCapture::TextureType::_422YpCbCr8;

    CameraCapture::Settings settings = CameraCapture::defaults();

    cameraCapture.setup(settings);
    
    // Start the session aysnchronously, or GL init may happen too late.
    dispatch_async(dispatch_get_main_queue(), ^{

        self->cameraCapture.start();

    });

    self.displayName = @"mac-cam";
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
    return objc(&cameraCapture);
}

@end
