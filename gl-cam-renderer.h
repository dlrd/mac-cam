#pragma once

#import "gl-renderer.h"

struct GLCamRenderer : GLRenderer
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
    
    GLuint _fbo;
    
    GLint u_resolution = -1;
    GLint u_time = -1;
    GLint u_frame = -1;

    GLint in_color = -1;
    GLint in_position = -1;
    GLint in_uv = -1;

    GLenum textureTarget = 0;
    GLuint textureName = 0;
    
    unsigned width = 0;
    unsigned height = 0;
};
