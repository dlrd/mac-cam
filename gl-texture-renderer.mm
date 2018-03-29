#import "gl-texture-renderer.h"
#import <OpenGL/gl3.h>
#import "utilities.h"

#define kFailedToInitialiseGLException @"Failed to initialise OpenGL"

@interface OpenGLTextureRenderer()

@end

@implementation OpenGLTextureRenderer
{
    GLuint shaderProgram;
    GLuint vertexArrayObject;
    GLuint vertexBuffer;
    
    GLint positionUniform;
    GLint colourAttribute;
    GLint positionAttribute;

    GLuint _fbo;
}

- (instancetype) initWithDefaultFBO: (GLuint) defaultFBOName;
{
    if (!(self = [super init]))
        return nil;

    _fbo = defaultFBOName;

    [self loadShader];
    [self loadBufferData];

    return self;
}

- (void) resizeWithWidth:(GLuint)width AndHeight:(GLuint)height
{
    // FIXME: Implement.
}

- (GLuint) defaultFBOName
{
    return _fbo;
}

- (void)setTextureName:(unsigned int)textureName
{
    _textureName = textureName;
}

- (void)loadShader
{
    GLuint vertexShader;
    GLuint fragmentShader;
    
    vertexShader   = [self compileShaderOfType:GL_VERTEX_SHADER   file:[[NSBundle mainBundle] pathForResource:@"shader" ofType:@"vsh"]];
    fragmentShader = [self compileShaderOfType:GL_FRAGMENT_SHADER file:[[NSBundle mainBundle] pathForResource:@"shader" ofType:@"fsh"]];
    
    if (0 != vertexShader && 0 != fragmentShader)
    {
        shaderProgram = glCreateProgram();
        GL_GET_ERROR();
        
        glAttachShader(shaderProgram, vertexShader  );
        GL_GET_ERROR();
        glAttachShader(shaderProgram, fragmentShader);
        GL_GET_ERROR();
        
        glBindFragDataLocation(shaderProgram, 0, "fragColour");
        
        [self linkProgram:shaderProgram];
        
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

- (GLuint)compileShaderOfType:(GLenum)type file:(NSString *)file
{
    GLuint shader;
    const GLchar *source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSASCIIStringEncoding error:nil] cStringUsingEncoding:NSASCIIStringEncoding];
    
    if (nil == source)
    {
        [NSException raise:kFailedToInitialiseGLException format:@"Failed to read shader file %@", file];
    }
    
    shader = glCreateShader(type);
    GL_GET_ERROR();
    glShaderSource(shader, 1, &source, NULL);
    GL_GET_ERROR();
    glCompileShader(shader);
    GL_GET_ERROR();
    
#if defined(DEBUG)
    GLint logLength;
    
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    GL_GET_ERROR();
    if (logLength > 0)
    {
        GLchar *log = (GLchar*) malloc((size_t)logLength);
        glGetShaderInfoLog(shader, logLength, &logLength, log);
        GL_GET_ERROR();
        NSLog(@"Shader compilation failed with error:\n%s", log);
        free(log);
    }
#endif
    
    GLint status;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    GL_GET_ERROR();
    if (0 == status)
    {
        glDeleteShader(shader);
        GL_GET_ERROR();
        [NSException raise:kFailedToInitialiseGLException format:@"Shader compilation failed for file %@", file];
    }
    
    return shader;
}

- (void)linkProgram:(GLuint)program
{
    glLinkProgram(program);
    GL_GET_ERROR();
    
#if defined(DEBUG)
    GLint logLength;
    
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
    GL_GET_ERROR();
    if (logLength > 0)
    {
        GLchar *log = (GLchar*) malloc((size_t)logLength);
        glGetProgramInfoLog(program, logLength, &logLength, log);
        GL_GET_ERROR();
        NSLog(@"Shader program linking failed with error:\n%s", log);
        free(log);
    }
#endif
    
    GLint status;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    GL_GET_ERROR();
    if (0 == status)
    {
        [NSException raise:kFailedToInitialiseGLException format:@"Failed to link shader program"];
    }
}

- (void)validateProgram:(GLuint)program
{
    GLint logLength;
    
    glValidateProgram(program);
    GL_GET_ERROR();
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
    GL_GET_ERROR();
    if (logLength > 0)
    {
        GLchar *log = (GLchar*) malloc((size_t)logLength);
        glGetProgramInfoLog(program, logLength, &logLength, log);
        GL_GET_ERROR();
        NSLog(@"Program validation produced errors:\n%s", log);
        free(log);
    }
    
    GLint status;
    glGetProgramiv(program, GL_VALIDATE_STATUS, &status);
    GL_GET_ERROR();
    if (0 == status)
    {
        [NSException raise:kFailedToInitialiseGLException format:@"Failed to link shader program"];
    }
}

- (void)loadBufferData
{
    Vertex vertexData[4] = {
        { .position = { .x=-0.5, .y=-0.5, .z=0.0, .w=1.0 }, .colour = { .r=1.0, .g=0.0, .b=0.0, .a=1.0 } },
        { .position = { .x=-0.5, .y= 0.5, .z=0.0, .w=1.0 }, .colour = { .r=0.0, .g=1.0, .b=0.0, .a=1.0 } },
        { .position = { .x= 0.5, .y= 0.5, .z=0.0, .w=1.0 }, .colour = { .r=0.0, .g=0.0, .b=1.0, .a=1.0 } },
        { .position = { .x= 0.5, .y=-0.5, .z=0.0, .w=1.0 }, .colour = { .r=1.0, .g=1.0, .b=1.0, .a=1.0 } }
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

- (CVReturn)renderForTime:(CVTimeStamp)time
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

- (void)dealloc
{
    glDeleteProgram(shaderProgram);
    GL_GET_ERROR();
    glDeleteBuffers(1, &vertexBuffer);
    GL_GET_ERROR();

    [super dealloc];
}

@end
