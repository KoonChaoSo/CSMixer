//
//  CSVideoEncoder.m
//  CSMixer
//
//  Created by ChaoSo on 2018/7/25.
//  Copyright © 2018年 ChaoSo. All rights reserved.
//

#import "CSVideoEncoder.h"
#import "CSRtmpPushManager.h"
#import "CSVideoFrameModel.h"
@interface CSVideoEncoder()
{
    char *aacBuf;
    char *pcmBuffer;
    char *aacBuffer;
}

typedef void(^CompletionBlock)(CSVideoFrameModel *model);
@property (assign, nonatomic) NSInteger frameId;
@property (strong, nonatomic) NSFileHandle *fileHandle;

@property (assign ,nonatomic) VTCompressionSessionRef compressionSession;

@property (strong, nonatomic) NSData *sps;
@property (strong, nonatomic) NSData *pps;

@property (assign, nonatomic) AudioConverterRef audioConverter;
@property (assign, nonatomic) size_t pcmBufferSize;
@property (assign, nonatomic) size_t aacBufferSize;

@property (assign, nonatomic) BOOL sendAudioHead;
@property (copy, nonatomic) CompletionBlock completionBlock;

@end
@implementation CSVideoEncoder

- (instancetype)init
{
    if (self = [super init])
    {
        [self setupVideoSession];
//        [self setupFileHandler];
    }
    return self;
}

- (void)setupFileHandler
{
    NSFileHandle *outfile;   //输入文件、输出文件
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *homePath = NSHomeDirectory( );
    NSString *outPath = [homePath stringByAppendingPathComponent:@"/Documents/testH264"];   //输出文件路径
    BOOL sucess  = [fileManager createFileAtPath:outPath contents:nil attributes:nil];
    if (sucess)
    {
        outfile = [NSFileHandle fileHandleForWritingAtPath:outPath];   //创建并打开要输出的文件
        if (outfile != nil)
        {
            self.fileHandle = outfile;
            [self.fileHandle seekToFileOffset:0];
        }
    }
}

//TODO: 单独获取配置
- (void)setupVideoSession
{
    self.frameId = 0;
    
    // 2.录制视频的宽度&高度
    int width = 320;
    int height = 480;
    
    if (_compressionSession) {
        VTCompressionSessionCompleteFrames(_compressionSession, kCMTimeInvalid);
        
        VTCompressionSessionInvalidate(_compressionSession);
        CFRelease(_compressionSession);
        _compressionSession = NULL;
    }
    
    // 3.创建CompressionSession对象,该对象用于对画面进行编码
    // kCMVideoCodecType_H264 : 表示使用h.264进行编码
    // didCompressH264 : 当一次编码结束会在该函数进行回调,可以在该函数中将数据,写入文件中
    OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self),  &_compressionSession);
    if (status != noErr) {
        return;
    }

    // 4.设置实时编码输出（直播必然是实时输出,否则会有延迟）
    VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    
    // 5.设置期望帧率(每秒多少帧,如果帧率过低,会造成画面卡顿)
    int fps = 20;
    CFNumberRef  fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
    VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);
    VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, (__bridge CFTypeRef)@(16));
    
    // 6.设置码率(码率: 编码效率, 码率越高,则画面越清晰, 如果码率较低会引起马赛克 --> 码率高有利于还原原始画面,但是也不利于传输)
    int bitRate = 320*480;
    CFNumberRef bitRateRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRate);
    VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_AverageBitRate, bitRateRef);
    NSArray *limit = @[@(bitRate * 1.5/8), @(1)];
    VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
    VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel);
    VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
    // 7.设置关键帧（GOPsize)间隔
    int frameInterval = 30;
    CFNumberRef  frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
    VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef);
    VTSessionSetProperty(self.compressionSession, kVTCompressionPropertyKey_H264EntropyMode, kVTH264EntropyMode_CABAC);
    // 8.基本设置结束, 准备进行编码
    VTCompressionSessionPrepareToEncodeFrames(self.compressionSession);
}

// 编码完成回调
void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    
    // 1.判断状态是否等于没有错误
    if (status != noErr) {
        return;
    }
    if (sampleBuffer == nil || !sampleBuffer)
    {
        return ;
    }
    
    // 2.根据传入的参数获取对象
    CSVideoEncoder* encoder = (__bridge CSVideoEncoder*)outputCallbackRefCon;
    // 3.判断是否是关键帧
    bool isKeyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    
    CSVideoFrameModel *model = [CSVideoFrameModel new];
    model.isKeyFrame = isKeyframe;
    // 获取sps & pps数据
    if (isKeyframe && !encoder.sps)
    {
        // 获取编码后的信息（存储于CMFormatDescriptionRef中）
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        // 获取SPS信息
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
        if (statusCode == noErr)
        {
            // 获取PPS信息
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
            if (statusCode == noErr)
            {
                // 装sps/pps转成NSData，以方便写入文件
                NSData *sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                NSData *pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                encoder.sps = sps;
                encoder.pps = pps;
                // 写入文件
                model.sps = sps;
                model.pps = pps;
                //回调
                if (encoder.completionBlock)
                {
                    encoder.completionBlock(model);
                }
            }
        }
    }
    
    // 获取数据块
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData *data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            model.frameData = data;
            //回调
            if (encoder.completionBlock)
            {
                encoder.completionBlock(model);
            }
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}

//- (void)callbackVideoFrame:(CSFrameVideoInfo *)info
//{
//    if ([self.delegate respondsToSelector:@selector(videoEncoder:videoFrame:)])
//    {
//        [self.delegate videoEncoder:self videoFrame:info];
//    }
//
//    if(info && info.sps && info.pps)
//    {
//        [[CSRtmpPushManager getInstance] send_video_sps_pps:(unsigned char*)info.sps.bytes andSpsLength:(long)info.sps.length andPPs:(unsigned char*)info.pps.bytes andPPsLength:(long)info.pps.length];
//    }
//    else
//    {
//        [[CSRtmpPushManager getInstance] sendVideo:info];
//    }
//}

- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps
{
    // 1.拼接NALU的header
    
    NSLog(@"gotSpsPps sps.length==%d,pps.length==%d", (int)[sps length],(int)[pps length]);
    [[CSRtmpPushManager getInstance] send_video_sps_pps:(unsigned char*)sps.bytes andSpsLength:sps.length andPPs:(unsigned char*)pps.bytes andPPsLength:pps.length];
    
    // 2.将NALU的头&NALU的体写入文件
//    [self.fileHandle writeData:ByteHeader];
//    [self.fileHandle writeData:sps];
//    [self.fileHandle writeData:ByteHeader];
//    [self.fileHandle writeData:pps];
    
}
- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame
{
    NSLog(@"gotEncodedData %d", (int)[data length]);
//    if (self.fileHandle != NULL)
//    {
//        const char bytes[] = "\x00\x00\x00\x01";
//        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
//        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
//    NSMutableData *cData = [[NSMutableData alloc] initWithData:ByteHeader];
//    [cData appendData:data];
//        [self.fileHandle writeData:ByteHeader];
//        [self.fileHandle writeData:data];
//    NSLog(@"data == %@,length === %d",cData,length);
    
    //上传到rtmpa
//    [[CSRtmpPushManager getInstance] send_rtmp_video:data andLength:data.length isKeyFrame:isKeyFrame];
//    }
    
    //TODO:可以用delegate回调到外面
}

- (void)endEncode
{
    
}

- (void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer
                 timeStamp:(uint64_t)timeStamp
           completionBlock:(void (^)(CSVideoFrameModel *model))completionBlock
{
    self.completionBlock = completionBlock;
    
    // 1.将sampleBuffer转成imageBuffer
    CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // 2.根据当前的帧数,创建CMTime的时间
    CMTime presentationTimeStamp = CMTimeMake(self.frameId++, 1000);
    VTEncodeInfoFlags flags;
    CMTime duration = CMTimeMake(1, (int32_t)15);
    
    NSDictionary *properties = nil;
    if (self.frameId % (int32_t)30 == 0) {
        properties = @{(__bridge NSString *)kVTEncodeFrameOptionKey_ForceKeyFrame: @YES};
    }
    NSNumber *timeNumber = @(timeStamp);
    
    // 3.开始编码该帧数据
    OSStatus statusCode = VTCompressionSessionEncodeFrame(self.compressionSession,
                                                          imageBuffer,
                                                          presentationTimeStamp,
                                                          duration,
                                                          (__bridge CFDictionaryRef)properties,
                                                          (__bridge_retained void *)timeNumber,
                                                          &flags);
    if (statusCode == noErr) {
        NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
    }
}
@end
