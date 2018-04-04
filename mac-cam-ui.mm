#import "mac-cam-ui.h"
#import "mac-gl-view.h"
#import <AVFoundation/AVFoundation.h>

//------------------------------------------------------------------------------


@interface AVCaptureDocument ()
@end

//------------------------------------------------------------------------------

@implementation AVCaptureDocument
{
    CameraCapture cameraCapture;
}

- (void)windowControllerDidLoadNib:(NSWindowController*) aController
{
    [super windowControllerDidLoadNib:aController];

    CameraCapture::Settings settings;
    
    self->cameraCapture.delegate.cameraFrameWasCaptured = [self] (CameraCapture::FramePtr frame) {
    
        self.glCamView.cameraFrame = frame;

    };

    self->cameraCapture.delegate.makeOpenGLContextCurrent = [self] () {
    
        [self.glCamView.openGLContext makeCurrentContext];
    
    };

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
