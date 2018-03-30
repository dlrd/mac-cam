#pragma once

#import <Cocoa/Cocoa.h>
#import "gl-renderer.h"

@interface OpenGLView : NSOpenGLView

- (GLRenderer*) createRendererWithDefaultFBO: (GLuint)fbo;

@end

// FIXME: Wrong spot.
@interface OpenGLTestView : OpenGLView
@end

// FIXME: Wrong spot.
@interface OpenGLCamView : OpenGLView

@property (nonatomic) unsigned textureName;
@property (nonatomic) unsigned textureTarget;
@property (strong) __attribute__((NSObject)) CVPixelBufferRef lastFrame;

@end
