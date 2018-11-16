//
//  CSMixerGPUImageCollector.m
//  CSMixer
//
//  Created by 苏冠超[产品技术中心] on 2018/11/16.
//  Copyright © 2018 ChaoSo. All rights reserved.
//

#import "CSMixerGPUImageCollector.h"
#import "CSMixerGPUImageCarmera.h"
#import "GPUImageBeautifyFilter.h"
@interface CSMixerGPUImageCollector()<CSMixerGPUImageCarmeraDelegate>
{
    dispatch_queue_t captureQueue;
    dispatch_queue_t audioQueue;
}
@property (nonatomic , strong) GPUImageView *myGPUImageView;
@property (nonatomic , strong) CSMixerGPUImageCarmera *myGPUVideoCamera;

@end

@implementation CSMixerGPUImageCollector


- (instancetype)initWithDelegate:(id<CSMixerGPUImageCollectorDelegate>)delegate
{
    self = [self init];
    if (self)
    {
        _delegate = delegate;
    }
    return self;;
}
- (instancetype)init
{
    self = [super init];
    if (self)
    {
        captureQueue = dispatch_queue_create("com.csmixer.gpuimage.videocapture.queue", DISPATCH_QUEUE_SERIAL);
        audioQueue = dispatch_queue_create("com.csmixer.gpuimage.audiocapture.queue", DISPATCH_QUEUE_SERIAL);
        
        
        _myGPUVideoCamera = [[CSMixerGPUImageCarmera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
        _myGPUVideoCamera.outputImageOrientation = UIDeviceOrientationLandscapeLeft;
        _myGPUVideoCamera.horizontallyMirrorRearFacingCamera = NO;
        _myGPUVideoCamera.horizontallyMirrorFrontFacingCamera = NO;
        [_myGPUVideoCamera addAudioInputsAndOutputs];
        _myGPUVideoCamera.customDelegate = self;
        _myGPUVideoCamera.frameRate = (int32_t)20;
    }
    return self;
}

- (void)startCapture:(UIView *)preview
{
    self.myGPUImageView = [[GPUImageView alloc] initWithFrame:preview.bounds];
    self.myGPUImageView.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    [self.myGPUImageView setInputRotation:kGPUImageFlipHorizonal atIndex:0];
    [preview addSubview:self.myGPUImageView];
    [self.myGPUVideoCamera addTarget:self.myGPUImageView];
    [self setBeautyFace];
    if (self.myGPUVideoCamera.connection.isVideoMirroringSupported)
    {
        self.myGPUVideoCamera.connection.videoMirrored = NO;
    }
    [self.myGPUVideoCamera.connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    [self.myGPUVideoCamera startCameraCapture];
    
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

- (void)stopCapture
{
    [self.myGPUVideoCamera stopCameraCapture];
    [self.myGPUVideoCamera removeInputsAndOutputs];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (void)setBeautyFace
{
//    GPUImageBrightnessFilter *filter = [[GPUImageBrightnessFilter alloc] init];
//    filter.brightness = 0.1;
    GPUImageBeautifyFilter *filter = [[GPUImageBeautifyFilter alloc] init];
    [_myGPUVideoCamera addTarget:filter];
}


#pragma mark - GPUImageVideoCameraDelegate
- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if ([self.delegate respondsToSelector:@selector(csGPUImageColletorOutput:didOutputSampleBuffer:fromConnection:)])
    {
        [self.delegate csGPUImageColletorOutput:self didOutputSampleBuffer:sampleBuffer fromConnection:CSMixerCaptureVideoType];
    }
}

- (void)myCaptureOutput:(CSMixerGPUImageCarmera *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer type:(CSMixerCaptureType)type
{
    if (type == CSMixerCaptureVideoType)
    {        
        if ([self.delegate respondsToSelector:@selector(csGPUImageColletorOutput:didOutputSampleBuffer:fromConnection:)])
        {
            [self.delegate csGPUImageColletorOutput:self didOutputSampleBuffer:sampleBuffer fromConnection:CSMixerCaptureVideoType];
        }
    }
    else
    {
        if ([self.delegate respondsToSelector:@selector(csGPUImageColletorOutput:didOutputSampleBuffer:fromConnection:)])
        {
            [self.delegate csGPUImageColletorOutput:self didOutputSampleBuffer:sampleBuffer fromConnection:CSMixerCaptureAudioType];
        }
    }
}



@end
