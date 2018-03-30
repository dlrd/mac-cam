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
        
        glBindFragDataLocation(shaderProgram, 0, "out_rgba");
        
        linkProgram(shaderProgram);
        
        u_resolution = glGetUniformLocation(shaderProgram, "u_resolution");
        GL_GET_ERROR();
        if (u_resolution < 0)
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'resolution' uniform."];

        u_time = glGetUniformLocation(shaderProgram, "u_time");
        GL_GET_ERROR();
        if (u_time < 0)
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'time' uniform."];

        in_color = glGetAttribLocation(shaderProgram, "in_color");
        GL_GET_ERROR();
        if (in_color < 0)
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'color' attribute."];

        in_position = glGetAttribLocation(shaderProgram, "in_position");
        GL_GET_ERROR();
        if (in_position < 0)
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'position' attribute."];

        in_uv = glGetAttribLocation(shaderProgram, "in_uv");
        GL_GET_ERROR();
        if (in_uv < 0)
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'uv' attribute."];

        u_frame = glGetUniformLocation(shaderProgram, "u_frame");
        GL_GET_ERROR();
        if (u_frame < 0)
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'frame' uniform."];

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
    Colour  color;
    Vector2 uv;
};

void
GLCamRenderer::loadBufferData ()
{

    VertexData vertexData [4] =
    {
        { /* position */ { -0.5, -0.5, 0.0, 1.0 }, /* color */ { 1.0, 0.0, 0.0, 1.0 }, /* uv */ { 0.0, 0.0 } },
        { /* position */ { -0.5,  0.5, 0.0, 1.0 }, /* color */ { 0.0, 1.0, 0.0, 1.0 }, /* uv */ { 0.0, 1.0 } },
        { /* position */ {  0.5,  0.5, 0.0, 1.0 }, /* color */ { 0.0, 0.0, 1.0, 1.0 }, /* uv */ { 1.0, 1.0 } },
        { /* position */ {  0.5, -0.5, 0.0, 1.0 }, /* color */ { 1.0, 1.0, 1.0, 1.0 }, /* uv */ { 1.0, 0.0 } }
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
    
    glEnableVertexAttribArray((GLuint)in_position);
    GL_GET_ERROR();
    glEnableVertexAttribArray((GLuint)in_color);
    GL_GET_ERROR();
    glEnableVertexAttribArray((GLuint)in_uv);
    GL_GET_ERROR();
    glVertexAttribPointer((GLuint)in_position, 4, GL_FLOAT, GL_FALSE, sizeof(VertexData), (const GLvoid *)offsetof(VertexData, position));
    GL_GET_ERROR();
    glVertexAttribPointer((GLuint)in_color, 4, GL_FLOAT, GL_FALSE, sizeof(VertexData), (const GLvoid *)offsetof(VertexData, color));
    GL_GET_ERROR();
    glVertexAttribPointer((GLuint)in_uv, 2, GL_FLOAT, GL_FALSE, sizeof(VertexData), (const GLvoid *)offsetof(VertexData, uv));
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
    
    glUniform2f(u_resolution, width, height);
    GL_GET_ERROR();

    glUniform1f(u_time, toHostSeconds(time));
    GL_GET_ERROR();

    GLint lumaUnit = 0;
    glUniform1i(u_frame, lumaUnit);
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
