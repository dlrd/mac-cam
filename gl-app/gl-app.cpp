#include "gl-app.h"
#include <fstream>
#include <vector>
#include <cassert>

inline void
glSingleShaderSource (GLuint shader, GLchar* src, GLint len = 0)
{
    glShaderSource(shader, 1, &src, len ? &len : nullptr);
}

inline bool
readBinaryFile (const char* path, std::vector<char>& contents)
{
    std::ifstream file(path, std::ios::binary | std::ios::ate);
    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);

    contents.resize(size);
    return file.read(contents.data(), size).good();
}

const char* shaderExtension (GLenum type)
{
    switch (type)
    {
        case GL_VERTEX_SHADER  : return "vsh";
        case GL_FRAGMENT_SHADER: return "fsh";

        default:
            assert(false);
            return "";
    }
}

#if !GL_MAC_APP
GLuint
compileShaderResource (GLenum type, const char* path)
{
    return compileShaderFile(type, (std::string("./shaders/")
        + path + "." + shaderExtension(type)).data());
}
#endif

GLuint
compileShaderFile (GLenum type, const char* file)
{
    printf("%s\n", file);

    GLuint shader;
    std::vector<char> source;
    if (!readBinaryFile(file, source))
    {
        GL_REPORT_FAILURE("Failed to read shader file %s", file);
    }

    printf("%s\n", source.data());
    
    shader = glCreateShader(type);

    GL_GET_ERROR();
    glSingleShaderSource(shader, source.data(), source.size());
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
        GL_REPORT_FAILURE("Shader compilation failed with error:\n%s", log);
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
        GL_REPORT_FAILURE("Shader compilation failed for file %s", file);
    }

    printf("%d\n", shader);

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
        GL_REPORT_FAILURE("Shader program linking failed with error:\n%s", log);
        free(log);
    }
#endif
    
    GLint status;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    GL_GET_ERROR();
    if (0 == status)
    {
        GL_REPORT_FAILURE("Failed to link shader program.");
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
        GL_REPORT_FAILURE("Program validation produced errors:\n%s", log);
        free(log);
    }
    
    GLint status;
    glGetProgramiv(program, GL_VALIDATE_STATUS, &status);
    GL_GET_ERROR();
    if (0 == status)
    {
        GL_REPORT_FAILURE("Failed to link shader program");
    }
}

