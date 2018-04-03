#pragma once

#include <cstdio>
#include <cstdlib>
#include <cmath>

#if GL_MAC_APP
#   include <OpenGL/OpenGL.h>
#   include <OpenGL/gl3.h>
#else
#   define GLFW_INCLUDE_GLCOREARB 1
#   define GLFW_INCLUDE_GLEXT 1
#   define GL_GLEXT_PROTOTYPES
#   include <GLFW/glfw3.h>
#endif

typedef struct
{
    GLfloat x,y;
} Vector2;

typedef struct
{
    GLfloat x,y,z,w;
} Vector4;

typedef struct
{
    GLfloat r,g,b,a;
} Colour;

typedef struct
{
    Vector4 position;
    Colour colour;
} Vertex;

#if GL_MAC_APP
#   define kFailedToInitialiseGLException @"Failed to initialise OpenGL"
#   define GL_REPORT_FAILURE(...) \
[NSException raise:kFailedToInitialiseGLException format:@__VA_ARGS__];
#else
#   define GL_REPORT_FAILURE(...) \
    { printf(__VA_ARGS__); fflush(stdout); abort(); }
#endif

#if DEBUG && !defined(NDEBUG)

#include <cstdlib>
#include <cassert>

#define GL_GET_ERROR()\
        {\
            for ( GLenum Error = glGetError( ); ( GL_NO_ERROR != Error ); Error = glGetError( ) )\
            {\
                switch ( Error )\
                {\
                    case GL_INVALID_ENUM:      printf( "\n%s\n\n", "GL_INVALID_ENUM"      ); assert( 0 ); break;\
                    case GL_INVALID_VALUE:     printf( "\n%s\n\n", "GL_INVALID_VALUE"     ); assert( 0 ); break;\
                    case GL_INVALID_OPERATION: printf( "\n%s\n\n", "GL_INVALID_OPERATION" ); assert( 0 ); break;\
                    case GL_OUT_OF_MEMORY:     printf( "\n%s\n\n", "GL_OUT_OF_MEMORY"     ); assert( 0 ); break;\
                    default:                                                                              break;\
                }\
            }\
        }

#define GL_CHECK_FRAMEBUFFER_STATUS()\
        {\
            switch ( glCheckFramebufferStatus( GL_FRAMEBUFFER ) )\
            {\
                case GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT:         printf( "\n%s\n\n", "GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT"         ); assert( 0 ); break;\
                case GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT: printf( "\n%s\n\n", "GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT" ); assert( 0 ); break;\
                case GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER:        printf( "\n%s\n\n", "GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER"        ); assert( 0 ); break;\
                case GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER:        printf( "\n%s\n\n", "GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER"        ); assert( 0 ); break;\
                case GL_FRAMEBUFFER_UNSUPPORTED:                   printf( "\n%s\n\n", "GL_FRAMEBUFFER_UNSUPPORTED"                   ); assert( 0 ); break;\
                case GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE:        printf( "\n%s\n\n", "GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE"        ); assert( 0 ); break;\
                case GL_FRAMEBUFFER_UNDEFINED:                     printf( "\n%s\n\n", "GL_FRAMEBUFFER_UNDEFINED"                     ); assert( 0 ); break;\
                default:                                                                                                                              break;\
            }\
        }

#define GL_GET_SHADER_INFO_LOG(Shader, Source)\
        {\
            GLint   Status, Count;\
            GLchar *Error;\
            \
            glGetShaderiv( Shader, GL_COMPILE_STATUS, &Status );\
            \
            if ( !Status )\
            {\
                glGetShaderiv( Shader, GL_INFO_LOG_LENGTH, &Count );\
                \
                if ( Count > 0 )\
                {\
                    glGetShaderInfoLog( Shader, Count, NULL, ( Error = calloc( 1, Count ) ) );\
                    \
                    printf( "%s\n\n%s\n", Source, Error );\
                    \
                    free( Error );\
                    \
                    assert( 0 );\
                }\
            }\
        }
#else
#   define GL_GET_ERROR()
#   define GL_CHECK_FRAMEBUFFER_STATUS()
#   define GL_GET_SHADER_INFO_LOG(Shader, Source)
#endif

#if GL_MAC_APP
#   include <OpenGL/OpenGL.h>
#   include <CoreVideo/CoreVideo.h>
#else
#   define CVTimeStamp double
#   define CVReturn void
#endif

void  validateProgram (GLuint program);
void   linkProgram (GLuint program);
GLuint compileShaderResource (GLenum type, const char* path);
GLuint compileShaderFile (GLenum type, const char* path);

struct GLRenderer
{
    virtual ~GLRenderer () {}

    virtual void initWithDefaultFBO (GLuint defaultFBOName) = 0;
    virtual void             resize (GLuint width, GLuint height) = 0;
    virtual CVReturn renderForTime (CVTimeStamp time) = 0;
    virtual GLuint   defaultFBOName () = 0;
    virtual void     destroyGL () = 0;
};
