#pragma once

#import <OpenGL/OpenGL.h>
#import <CoreVideo/CoreVideo.h>

void  validateProgram (GLuint program);
void   linkProgram (GLuint program);
GLuint compileShaderOfType (GLenum type, const char* file);

struct GLRenderer
{
    virtual ~GLRenderer () {}

    virtual void initWithDefaultFBO (GLuint defaultFBOName) = 0;
    virtual void             resize (GLuint width, GLuint height) = 0;
    virtual CVReturn renderForTime (CVTimeStamp time) = 0;
    virtual GLuint   defaultFBOName () = 0;
    virtual void     destroyGL () = 0;
};
