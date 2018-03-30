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
    
    GLint resolutionUniform = -1;
    GLint positionUniform = -1;

    GLint colourAttribute = -1;
    GLint positionAttribute = -1;
    GLint texCoordAttribute = -1;

    GLuint _fbo;
    
    GLenum textureTarget = 0;
    GLuint textureName = 0;

    GLint lumaUniform = -1;
    GLint chromaUniform = -1;
    
    unsigned width = 0;
    unsigned height = 0;
};
