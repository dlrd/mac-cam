#pragma once

#import <Cocoa/Cocoa.h>
#import "gl-renderer.h"

@interface OpenGLView : NSOpenGLView

- (id<OpenGLRenderer>) createRendererWithDefaultFBO: (GLuint)fbo;

@end

// FIXME: Wrong spot.
@interface OpenGLTextureView : OpenGLView

@end
