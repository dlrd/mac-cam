#pragma once

#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>

@protocol OpenGLRenderer

- (instancetype) initWithDefaultFBO:(GLuint) defaultFBOName;
- (void)            resizeWithWidth:(GLuint)width AndHeight:(GLuint)height;
- (CVReturn)          renderForTime:(CVTimeStamp)time;
- (GLuint)           defaultFBOName;

@end
