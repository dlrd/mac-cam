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
    
    GLint positionUniform;
    GLint colourAttribute;
    GLint positionAttribute;

    GLuint _fbo;
    
    GLuint textureName;
};

