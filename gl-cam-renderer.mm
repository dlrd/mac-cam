#import "gl-cam-renderer.h"
#import <OpenGL/gl3.h>
#import "utilities.h"

#define kFailedToInitialiseGLException @"Failed to initialise OpenGL"

void
GLCamRenderer::initWithDefaultFBO (GLuint defaultFBOName)
{
    _fbo = defaultFBOName;

    loadShader();
    loadBufferData();
}

void
GLCamRenderer::destroyGL ()
{
    glDeleteProgram(shaderProgram);
    GL_GET_ERROR();
    glDeleteBuffers(1, &vertexBuffer);
    GL_GET_ERROR();
}


void
GLCamRenderer::resize (GLuint width_, GLuint height_)
{
    glViewport(0, 0, width_, height_);
    
    width = width_;
    height = height_;
}

void
GLCamRenderer::loadShader ()
{
    GLuint vertexShader;
    GLuint fragmentShader;
    
    vertexShader   = compileShaderOfType(GL_VERTEX_SHADER, [[NSBundle mainBundle] pathForResource:@"cam" ofType:@"vsh"].UTF8String);
    fragmentShader = compileShaderOfType(GL_FRAGMENT_SHADER, [[NSBundle mainBundle] pathForResource:@"cam" ofType:@"fsh"].UTF8String);
    
    if (0 != vertexShader && 0 != fragmentShader)
    {
        shaderProgram = glCreateProgram();
        GL_GET_ERROR();
        
        glAttachShader(shaderProgram, vertexShader  );
        GL_GET_ERROR();
        glAttachShader(shaderProgram, fragmentShader);
        GL_GET_ERROR();
        
        glBindFragDataLocation(shaderProgram, 0, "fragColour");
        
        linkProgram(shaderProgram);
        
        resolutionUniform = glGetUniformLocation(shaderProgram, "resolution");
        GL_GET_ERROR();
        if (resolutionUniform < 0)
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'resolution' uniform."];

        positionUniform = glGetUniformLocation(shaderProgram, "p");
        GL_GET_ERROR();
        if (positionUniform < 0)
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'p' uniform."];

        colourAttribute = glGetAttribLocation(shaderProgram, "colour");
        GL_GET_ERROR();
        if (colourAttribute < 0)
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'colour' attribute."];

        positionAttribute = glGetAttribLocation(shaderProgram, "position");
        GL_GET_ERROR();
        if (positionAttribute < 0)
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'position' attribute."];

        texCoordAttribute = glGetAttribLocation(shaderProgram, "inTexcoord");
        GL_GET_ERROR();
        if (positionAttribute < 0)
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'texCoord' attribute."];

        lumaUniform = glGetUniformLocation(shaderProgram, "luma");
        GL_GET_ERROR();
        if (lumaUniform < 0)
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'luma' uniform."];

//        chromaUniform = glGetUniformLocation(shaderProgram, "chroma");
//        GL_GET_ERROR();
//        if (chromaUniform < 0)
//            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'chroma' uniform."];

        glDeleteShader(vertexShader  );
        GL_GET_ERROR();
        glDeleteShader(fragmentShader);
        GL_GET_ERROR();
    }
    else
    {
        [NSException raise:kFailedToInitialiseGLException format:@"Shader compilation failed."];
    }
}

struct VertexData
{
    Vector4 position;
    Colour  colour;
    Vector2 texCoord;
};

void
GLCamRenderer::loadBufferData ()
{

    VertexData vertexData [4] =
    {
        { /* position */ { -0.5, -0.5, 0.0, 1.0 }, /* colour */ { 1.0, 0.0, 0.0, 1.0 }, /* tex coord */ { 0.0, 0.0 } },
        { /* position */ { -0.5,  0.5, 0.0, 1.0 }, /* colour */ { 0.0, 1.0, 0.0, 1.0 }, /* tex coord */ { 0.0, 1.0 } },
        { /* position */ {  0.5,  0.5, 0.0, 1.0 }, /* colour */ { 0.0, 0.0, 1.0, 1.0 }, /* tex coord */ { 1.0, 1.0 } },
        { /* position */ {  0.5, -0.5, 0.0, 1.0 }, /* colour */ { 1.0, 1.0, 1.0, 1.0 }, /* tex coord */ { 1.0, 0.0 } }
    };
    
    glGenVertexArrays(1, &vertexArrayObject);
    GL_GET_ERROR();
    glBindVertexArray(vertexArrayObject);
    GL_GET_ERROR();
    
    glGenBuffers(1, &vertexBuffer);
    GL_GET_ERROR();
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    GL_GET_ERROR();
    glBufferData(GL_ARRAY_BUFFER, 4 * sizeof(VertexData), vertexData, GL_STATIC_DRAW);
    GL_GET_ERROR();
    
    glEnableVertexAttribArray((GLuint)positionAttribute);
    GL_GET_ERROR();
    glEnableVertexAttribArray((GLuint)colourAttribute  );
    GL_GET_ERROR();
    glEnableVertexAttribArray((GLuint)texCoordAttribute  );
    GL_GET_ERROR();
    glVertexAttribPointer((GLuint)positionAttribute, 4, GL_FLOAT, GL_FALSE, sizeof(VertexData), (const GLvoid *)offsetof(VertexData, position));
    GL_GET_ERROR();
    glVertexAttribPointer((GLuint)colourAttribute  , 4, GL_FLOAT, GL_FALSE, sizeof(VertexData), (const GLvoid *)offsetof(VertexData, colour  ));
    GL_GET_ERROR();
    glVertexAttribPointer((GLuint)texCoordAttribute, 2, GL_FLOAT, GL_FALSE, sizeof(VertexData), (const GLvoid *)offsetof(VertexData, texCoord  ));
    GL_GET_ERROR();
}

CVReturn
GLCamRenderer::renderForTime (CVTimeStamp time)
{
    glClearColor(0.0, 0.0, 0.0, 1.0);
    GL_GET_ERROR();
    
    glUseProgram(shaderProgram);
    GL_GET_ERROR();

    glClear(GL_COLOR_BUFFER_BIT);
    GL_GET_ERROR();
    
    GLfloat timeValue = GLfloat(M_PI * toHostSeconds(time));

    Vector2 p = { .x = 0.5f * sinf(timeValue), .y = 0.5f * cosf(timeValue) };

    glUniform2f(resolutionUniform, width, height);
    GL_GET_ERROR();

    glUniform2fv(positionUniform, 1, (const GLfloat *)&p);
    GL_GET_ERROR();

    GLint lumaUnit = 0;
    glUniform1i(lumaUniform, lumaUnit);
    GL_GET_ERROR();

    GLint chromaUnit = 1;
    glUniform1i(chromaUniform, chromaUnit);
    GL_GET_ERROR();
    
    if (textureName > 0)
    {
        glActiveTexture(GL_TEXTURE0);
        GL_GET_ERROR();
        glBindTexture(textureTarget, textureName);
        GL_GET_ERROR();

        glTexParameteri(textureTarget, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(textureTarget, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(textureTarget, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(textureTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

        GL_GET_ERROR();
    }
    
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    GL_GET_ERROR();
    
    return kCVReturnSuccess;
}

GLuint
GLCamRenderer::defaultFBOName ()
{
    return _fbo;
}

