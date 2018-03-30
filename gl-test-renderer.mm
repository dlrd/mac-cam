#import "gl-test-renderer.h"
#import <OpenGL/gl3.h>
#import "utilities.h"

#define kFailedToInitialiseGLException @"Failed to initialise OpenGL"

void
GLTestRenderer::initWithDefaultFBO (GLuint defaultFBOName)
{
    _fbo = defaultFBOName;

    loadShader();
    loadBufferData();
}

void
GLTestRenderer::destroyGL ()
{
    glDeleteProgram(shaderProgram);
    GL_GET_ERROR();
    glDeleteBuffers(1, &vertexBuffer);
    GL_GET_ERROR();
}


void
GLTestRenderer::resize (GLuint width, GLuint height)
{

}

void
GLTestRenderer::loadShader ()
{
    GLuint vertexShader;
    GLuint fragmentShader;
    
    vertexShader   = compileShaderOfType(GL_VERTEX_SHADER  , [[NSBundle mainBundle] pathForResource:@"test" ofType:@"vsh"].UTF8String);
    fragmentShader = compileShaderOfType(GL_FRAGMENT_SHADER, [[NSBundle mainBundle] pathForResource:@"test" ofType:@"fsh"].UTF8String);
    
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
        
        positionUniform = glGetUniformLocation(shaderProgram, "p");
        GL_GET_ERROR();
        if (positionUniform < 0)
        {
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'p' uniform."];
        }
        colourAttribute = glGetAttribLocation(shaderProgram, "colour");
        GL_GET_ERROR();
        if (colourAttribute < 0)
        {
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'colour' attribute."];
        }
        positionAttribute = glGetAttribLocation(shaderProgram, "position");
        GL_GET_ERROR();
        if (positionAttribute < 0)
        {
            [NSException raise:kFailedToInitialiseGLException format:@"Shader did not contain the 'position' attribute."];
        }
        
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

void
GLTestRenderer::loadBufferData ()
{
    Vertex vertexData[4] =
    {
        { /* position */ { -0.5, -0.5, 0.0, 1.0 }, /* colour */ { 1.0, 0.0, 0.0, 1.0 } },
        { /* position */ { -0.5,  0.5, 0.0, 1.0 }, /* colour */ { 0.0, 1.0, 0.0, 1.0 } },
        { /* position */ {  0.5,  0.5, 0.0, 1.0 }, /* colour */ { 0.0, 0.0, 1.0, 1.0 } },
        { /* position */ {  0.5, -0.5, 0.0, 1.0 }, /* colour */ { 1.0, 1.0, 1.0, 1.0 } }
    };
    
    glGenVertexArrays(1, &vertexArrayObject);
    GL_GET_ERROR();
    glBindVertexArray(vertexArrayObject);
    GL_GET_ERROR();
    
    glGenBuffers(1, &vertexBuffer);
    GL_GET_ERROR();
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    GL_GET_ERROR();
    glBufferData(GL_ARRAY_BUFFER, 4 * sizeof(Vertex), vertexData, GL_STATIC_DRAW);
    GL_GET_ERROR();
    
    glEnableVertexAttribArray((GLuint)positionAttribute);
    GL_GET_ERROR();
    glEnableVertexAttribArray((GLuint)colourAttribute  );
    GL_GET_ERROR();
    glVertexAttribPointer((GLuint)positionAttribute, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *)offsetof(Vertex, position));
    GL_GET_ERROR();
    glVertexAttribPointer((GLuint)colourAttribute  , 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *)offsetof(Vertex, colour  ));
    GL_GET_ERROR();
}

CVReturn
GLTestRenderer::renderForTime (CVTimeStamp time)
{
    glClearColor(0.0, 0.0, 0.0, 1.0);
    GL_GET_ERROR();
    
    glUseProgram(shaderProgram);
    GL_GET_ERROR();

    glClear(GL_COLOR_BUFFER_BIT);
    GL_GET_ERROR();
    
    GLfloat timeValue = GLfloat(M_PI * toHostSeconds(time));

    Vector2 p = { .x = 0.5f * sinf(timeValue), .y = 0.5f * cosf(timeValue) };

    glUniform2fv(positionUniform, 1, (const GLfloat *)&p);
    GL_GET_ERROR();
    
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    GL_GET_ERROR();
    
    return kCVReturnSuccess;
}

GLuint
GLTestRenderer::defaultFBOName ()
{
    return _fbo;
}
