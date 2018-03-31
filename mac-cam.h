#pragma once

//------------------------------------------------------------------------------

#include <memory>
#include <functional>

#define MAC_CAM_DECLARE_OPAQUE_INTERNALS(Class) \
public: \
    ~Class (); \
    struct That; \
     Class (That* that_) : that(that_) {} \
    That* that;

struct CameraCapture
{
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

    struct Settings
    {
        TextureType                    cameraTextureType = TextureType::_422YpCbCr8;
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

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

@class OpenGLCamView;

@interface AVCaptureDocument : NSDocument

@property (readonly) NSObject* capture;

@property (assign) IBOutlet OpenGLCamView *glCamView;

- (IBAction)stop:(id)sender;

@end
