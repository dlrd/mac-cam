#pragma once

#import "gl-renderer.h"

@interface OpenGLTextureRenderer : NSObject<OpenGLRenderer>

@property (nonatomic) unsigned textureName;

@end
