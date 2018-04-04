#pragma once

//------------------------------------------------------------------------------

#include <memory>
#include <functional>
#include <string>
#include <vector>

//------------------------------------------------------------------------------

#define MAC_CAM_DECLARE_OPAQUE_INTERNALS(Class) \
public: \
    struct That; \
     Class (That* that_) : that(that_) {} \
    ~Class (); \
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

    struct Delegate
    {
        TextureType textureType = TextureType::_422YpCbCr8;

        std::function<void ()        > makeOpenGLContextCurrent = [] ()         { abort(); };
        std::function<void (FramePtr)> cameraFrameWasCaptured   = [] (FramePtr) { abort(); };
    };

    struct Settings
    {
        String cameraName;
        String cameraPreset;
        String cameraResolution;
        String cameraFramerate;
    };

    CameraCapture ();

    Delegate delegate;

    const Settings& currentSettings ();

    void  setup (const Settings& settings);

    void  start ();
    void  stop ();

    MAC_CAM_DECLARE_OPAQUE_INTERNALS(CameraCapture)
};

//------------------------------------------------------------------------------

#if __OBJC__
NSObject* objc (CameraCapture*);
#endif
