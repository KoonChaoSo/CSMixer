//
//  CSMixerCollector.m
//  CSMixer
//
//  Created by ChaoSo on 2018/7/24.
//  Copyright © 2018年 ChaoSo. All rights reserved.
//

#import "CSMixerAVFoundationCollector.h"


@interface CSMixerAVFoundationCollector()<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate>
@property (weak, nonatomic) UIView *preview;
@property (strong, nonatomic) CALayer *prelayer;

@property (strong, nonatomic) AVCaptureSession *session;

@property (strong, nonatomic) AVCaptureConnection *videoConnection;
@property (strong, nonatomic) AVCaptureConnection *audioConnection;

@property (strong, nonatomic) dispatch_queue_t captureQueue;
@property (strong, nonatomic) dispatch_queue_t audioQueue;

//@property (nonatomic, assign) uint64_t timestamp;
///// 时间戳锁
//@property (nonatomic, strong) dispatch_semaphore_t lock;
//@property (nonatomic, assign) uint64_t currentTimestamp;
//@property (nonatomic, assign) BOOL isFirstFrame;

@end
@implementation CSMixerAVFoundationCollector

- (instancetype)initWithDelegate:(id<CSMixerCollectorProtocol>)delegate
{
    self = [super init];
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
        _captureQueue = dispatch_queue_create("com.csmixer.videocapture.queue", DISPATCH_QUEUE_SERIAL);
        _audioQueue = dispatch_queue_create("com.csmixer.audiocapture.queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - Public
- (void)startCapture:(UIView *)preview
{
    _preview = preview;
    
    //Video
    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPreset640x480;
    
    NSError *err;
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *deviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&err];
    if (err != nil)
    {
        NSLog(@"生成设备输入失败");
    }
    if ([self.session canAddInput:deviceInput])
    {
        [self.session addInput:deviceInput];
    }
    
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [videoOutput setSampleBufferDelegate:self queue:self.captureQueue];
    
    if ([self.session canAddOutput:videoOutput])
    {
        [self.session addOutput:videoOutput];
    }
    self.videoConnection = [videoOutput connectionWithMediaType:AVMediaTypeVideo];
    [self.videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
    //收集到的图像放到preview上面
    AVCaptureVideoPreviewLayer *preLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    preLayer.frame = self.preview.frame;
    [self.preview.layer insertSublayer:preLayer atIndex:0];
    self.prelayer = preLayer;
    
    //Audio
    NSError *err2;
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&err2];
    if ([self.session canAddInput:audioInput])
        [self.session addInput:audioInput];

    AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    [audioOutput setSampleBufferDelegate:self queue:self.audioQueue];
    if ([self.session canAddOutput:audioOutput])
        [self.session addOutput:audioOutput];
    
    self.audioConnection = [audioOutput connectionWithMediaType:AVMediaTypeAudio];
    
    [self.session startRunning];
}

- (void)stopCapture
{
    [self.session stopRunning];
    [self.prelayer removeFromSuperlayer];
}

#pragma mark - Delegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (self.videoConnection == connection)
    {
        if ([self.delegate respondsToSelector:@selector(csColletorOutput:didOutputSampleBuffer:fromConnection:)])
        {
            [self.delegate csColletorOutput:self didOutputSampleBuffer:sampleBuffer fromConnection:CSMixerCaptureVideoType];
        }
    }
    else
    {
        if ([self.delegate respondsToSelector:@selector(csColletorOutput:didOutputSampleBuffer:fromConnection:)])
        {
            [self.delegate csColletorOutput:self didOutputSampleBuffer:sampleBuffer fromConnection:CSMixerCaptureAudioType];
        }
    }
}
@end
