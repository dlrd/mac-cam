#pragma once

#import <Cocoa/Cocoa.h>

@class AVCaptureVideoPreviewLayer;
@class AVCaptureSession;
@class AVCaptureDeviceInput;
@class AVCaptureMovieFileOutput;
@class AVCaptureAudioPreviewOutput;
@class AVCaptureConnection;
@class AVCaptureDevice;
@class AVCaptureDeviceFormat;
@class AVFrameRateRange;
@class AVCaptureVideoDataOutput;
@class OpenGLTextureView;

@interface AVRecorderDocument : NSDocument
{
@private
	NSView						*previewView;
	AVCaptureVideoPreviewLayer	*previewLayer;
	NSLevelIndicator			*audioLevelMeter;
	
	AVCaptureSession			*session;
	AVCaptureDeviceInput		*videoDeviceInput;
	AVCaptureDeviceInput		*audioDeviceInput;
	AVCaptureMovieFileOutput	*movieFileOutput;
	AVCaptureAudioPreviewOutput	*audioPreviewOutput;
    AVCaptureVideoDataOutput    *videoOutput;
	
	NSArray						*videoDevices;
	NSArray						*audioDevices;
	
	NSTimer						*audioLevelTimer;
	
	NSArray						*observers;
}

#pragma mark Device Selection
@property (retain) NSArray *videoDevices;
@property (retain) NSArray *audioDevices;
@property (assign) AVCaptureDevice *selectedVideoDevice;
@property (assign) AVCaptureDevice *selectedAudioDevice;

#pragma mark - Device Properties
@property (assign) AVCaptureDeviceFormat *videoDeviceFormat;
@property (assign) AVCaptureDeviceFormat *audioDeviceFormat;
@property (assign) AVFrameRateRange *frameRateRange;
- (IBAction)lockVideoDeviceForConfiguration:(id)sender;

#pragma mark - Recording
@property (retain) AVCaptureSession *session;
@property (readonly) NSArray *availableSessionPresets;
@property (readonly) BOOL hasRecordingDevice;
@property (assign,getter=isRecording) BOOL recording;

#pragma mark - Preview
@property (assign) IBOutlet NSView *previewView;
@property (assign) float previewVolume;
@property (assign) IBOutlet NSLevelIndicator *audioLevelMeter;
@property (assign) IBOutlet OpenGLTextureView *glTextureView;

#pragma mark - Transport Controls
@property (readonly,getter=isPlaying) BOOL playing;
@property (readonly,getter=isRewinding) BOOL rewinding;
@property (readonly,getter=isFastForwarding) BOOL fastForwarding;
- (IBAction)stop:(id)sender;

@end
