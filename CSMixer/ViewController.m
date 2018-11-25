//
//  ViewController.m
//  CSMixer
//
//  Created by ChaoSo on 2018/7/24.
//  Copyright © 2018年 ChaoSo. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "CSVideoEncoder.h"
#import "CSRtmpPushManager.h"
#import "CSAacAudioEncoder.h"
#import "CSMixerAVFoundationCollector.h"
#import "CSMixerGPUImageCollector.h"


static  NSString *const kPushRtmpUrl = @"rtmp://192.168.147.216:1935/myapp/room";
@interface ViewController ()<CSMixerCollectorDelegate,CSMixerGPUImageCollectorDelegate>
{
    NSInteger frameCount;
}
@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (assign, nonatomic) dispatch_queue_t captureQueue;
@property (strong, nonatomic) dispatch_queue_t audioQueue;

@property (strong, nonatomic) CALayer *preLayer;

@property (assign, nonatomic) BOOL isLive;
@property (strong, nonatomic) UIButton *button;
@property (strong, nonatomic) CSVideoEncoder *encoder;
@property (strong, nonatomic) CSAacAudioEncoder *audioEncoder;
@property (nonatomic, assign) uint64_t timestamp;
/// 时间戳锁
@property (nonatomic, strong) dispatch_semaphore_t lock;
@property (nonatomic, assign) uint64_t currentTimestamp;
@property (nonatomic, assign) BOOL isFirstFrame;


@property (strong, nonatomic) AVCaptureConnection *videoConnection;
@property (strong, nonatomic) AVCaptureConnection *audioConnection;

//@property (strong, nonatomic) CSMixerAVFoundationCollector *collector;
//@property (strong, nonatomic) CSMixerGPUImageCollector *gpuImageCollector;

@property (strong, nonatomic) id<CSMixerCollectorProtocol> collector;
@property (strong, nonatomic) UIView *showView;
@end

#define NOW (CACurrentMediaTime()*1000)
#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    UIView *showView = [[UIView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:showView];
    _showView = showView;
    
    UIView *operationView = [[UIView alloc] initWithFrame:self.view.bounds];
    [operationView setBackgroundColor:[UIColor clearColor]];
    [self.view addSubview:operationView];
    
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 50, 100, 100)];
    if (self.isLive)
        [button setTitle:@"停止直播" forState:0];
    else
        [button setTitle:@"开始直播" forState:0];
    
    [button setBackgroundColor:[UIColor blackColor]];
    [button addTarget:self action:@selector(onClickButton:) forControlEvents:UIControlEventTouchUpInside];
    [operationView addSubview:button];
    _isFirstFrame = YES;
    _button = button;
    
    self.collector = [[CSMixerGPUImageCollector alloc] initWithDelegate:self];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];

}

- (void)csColletorOutput:(id)outputColletor didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(CSMixerCaptureType)connection
{
    if (connection == CSMixerCaptureVideoType)
    {
        [self.encoder encodeSampleBuffer:sampleBuffer timeStamp:self.currentTimestamp completionBlock:^(CSVideoFrameModel *model) {
            [[CSRtmpPushManager getInstance] sendVideo:model];
        }];
    }
    else
    {
        [self.audioEncoder encodeSampleBuffer:sampleBuffer completionBlock:^(CSAudioFrameModel *model) {
            [[CSRtmpPushManager getInstance] sendAudio:model];
        }];
    }
}

//- (void)csColletorOutput:(id)outputColletor didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(CSMixerCaptureType)connection
//{
//    if (connection == CSMixerCaptureVideoType)
//    {
//        [self.encoder encodeSampleBuffer:sampleBuffer timeStamp:self.currentTimestamp completionBlock:^(CSVideoFrameModel *model) {
//            [[CSRtmpPushManager getInstance] sendVideo:model];
//        }];
//    }
//    else
//    {
//        [self.audioEncoder encodeSampleBuffer:sampleBuffer completionBlock:^(CSAudioFrameModel *model) {
//            [[CSRtmpPushManager getInstance] sendAudio:model];
//        }];
//    }
//}

- (void)csGPUImageColletorOutput:(CSMixerGPUImageCollector *)outputColletor
           didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
                  fromConnection:(CSMixerCaptureType)connection
{
    if (connection == CSMixerCaptureVideoType)
    {
        [self.encoder encodeSampleBuffer:sampleBuffer timeStamp:self.currentTimestamp completionBlock:^(CSVideoFrameModel *model) {
            [[CSRtmpPushManager getInstance] sendVideo:model];
        }];
    }
    else
    {
        [self.audioEncoder encodeSampleBuffer:sampleBuffer completionBlock:^(CSAudioFrameModel *model) {
            [[CSRtmpPushManager getInstance] sendAudio:model];
        }];
    }
}


- (void)onClickButton:(id)sender
{
    if (self.isLive)
    {
        [_button setTitle:@"开始直播" forState:0];
        self.isLive = NO;
    }
    else
    {
        [_button setTitle:@"停止直播" forState:0];
        self.isLive = YES;
    }
}

- (void)setIsLive:(BOOL)isLive
{
    _isLive = isLive;
    
    if (isLive)
    {
        if ([[CSRtmpPushManager getInstance] startRtmpConnect:kPushRtmpUrl])
        {
            [self.collector startCapture:self.showView];
        }
    }
    else
    {
        [self.collector stopCapture];
        [self.audioEncoder reset];
    }
}

- (dispatch_semaphore_t)lock{
    if(!_lock){
        _lock = dispatch_semaphore_create(1);
    }
    return _lock;
}

- (uint64_t)currentTimestamp {
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    uint64_t currentts = 0;
    if (_isFirstFrame) {
        _timestamp = NOW;
        _isFirstFrame = NO;
        currentts = 0;
    } else {
        currentts = NOW - _timestamp;
    }
    dispatch_semaphore_signal(self.lock);
    return currentts;
}

- (CSVideoEncoder *)encoder
{
    if (!_encoder)
    {
        _encoder = [[CSVideoEncoder alloc] init];
    }
    return _encoder;
}

- (CSAacAudioEncoder *)audioEncoder
{
    if (!_audioEncoder)
    {
        _audioEncoder = [[CSAacAudioEncoder alloc] init];
    }
    return _audioEncoder;
}


//- (CSMixerAVFoundationCollector *)collector
//{
//    if (!_collector)
//    {
//        _collector = [[CSMixerAVFoundationCollector alloc] init];
//    }
//    return _collector;
//}
//
//- (CSMixerGPUImageCollector *)gpuImageCollector
//{
//    if (!_gpuImageCollector)
//    {
//        _gpuImageCollector = [[CSMixerGPUImageCollector alloc] init];
//    }
//    return _gpuImageCollector;
//}
@end
