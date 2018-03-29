#include "gl-renderer.h"
#import <OpenGL/gl3.h>
#import "utilities.h"

#define kFailedToInitialiseGLException @"Failed to initialise OpenGL"

GLuint
compileShaderOfType (GLenum type, const char* file)
{
    GLuint shader;
    const GLchar *source = (GLchar *)[[NSString stringWithContentsOfFile:[NSString stringWithUTF8String:file] encoding:NSASCIIStringEncoding error:nil] cStringUsingEncoding:NSASCIIStringEncoding];
    
    if (nil == source)
    {
        [NSException raise:kFailedToInitialiseGLException format:@"Failed to read shader file %s", file];
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
        [NSException raise:kFailedToInitialiseGLException format:@"Shader compilation failed for file %s", file];
    }
    
    return shader;
}

void
linkProgram (GLuint program)
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

void
validateProgram (GLuint program)
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

