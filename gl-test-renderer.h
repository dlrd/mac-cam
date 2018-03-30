#pragma once

#import "gl-renderer.h"

struct GLTestRenderer : GLRenderer
{
    void initWithDefaultFBO (GLuint defaultFBOName) override;
    void             resize (GLuint width, GLuint height) override;
    CVReturn renderForTime (CVTimeStamp time) override;
    GLuint   defaultFBOName () override;
    void  destroyGL () override;

    void loadShader ();
    void loadBufferData ();

    GLuint shaderProgram;
    GLuint vertexArrayObject;
    GLuint vertexBuffer;
    
    GLint u_origin;

    GLint in_position;
    GLint in_color;

    GLuint _fbo;
};
