#pragma once

#import <Cocoa/Cocoa.h>
#import "mac-cam.h"

struct GLRenderer;

@interface OpenGLView : NSOpenGLView

- (GLRenderer*) createRendererWithDefaultFBO: (GLuint)fbo;

@end

// FIXME: Wrong spot.
@interface OpenGLTestView : OpenGLView
@end

// FIXME: Wrong spot.
@interface OpenGLCamView : OpenGLView

@property (nonatomic) CameraCapture::FramePtr cameraFrame;

@end
