#pragma once

//------------------------------------------------------------------------------

#include <memory>
#include <functional>
#include <string>
#include <vector>

//------------------------------------------------------------------------------

#define MAC_CAM_DECLARE_OPAQUE_INTERNALS(Class) \
public: \
    ~Class (); \
    struct That; \
     Class (That* that_) : that(that_) {} \
    That* that;

//------------------------------------------------------------------------------

struct CameraCapture
{
    using Strings = std::vector<std::string>;
    using String  = std::string;

    static double nowInSeconds ();

    enum class TextureType
    {
        Invalid = -1,

        _422YpCbCr8,
        _32BGRA,
    };

    struct Frame
    {
        int width ();
        int height ();

        double timeInSeconds ();
    
        GLuint glTextureName ();
        GLenum glTextureTarget ();

        TextureType textureType ();

        MAC_CAM_DECLARE_OPAQUE_INTERNALS(Frame)
    };

    using FramePtr = std::shared_ptr<Frame>;

    Strings cameraNames ();

    Strings cameraPresets     (String cameraName);
    Strings cameraResolutions (String cameraName);
    Strings cameraFramerates  (String cameraName, String cameraResolution);

    struct Settings
    {
        String cameraName;
        String cameraPreset;
        String cameraResolution;
        String cameraFramerate;

        TextureType textureType = TextureType::_422YpCbCr8;

        std::function<void ()        > makeOpenGLContextCurrent;
        std::function<void (FramePtr)> cameraFrameWasCaptured;
    };

    CameraCapture ();

    void  setup (const Settings& settings);

    void  start ();
    void  stop ();

    MAC_CAM_DECLARE_OPAQUE_INTERNALS(CameraCapture)
};

//------------------------------------------------------------------------------

#if __OBJC__
NSObject* objc (CameraCapture*);
#endif
