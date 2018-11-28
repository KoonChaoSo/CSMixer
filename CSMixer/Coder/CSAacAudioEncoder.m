//
//  CSAccAudioEncoder.m
//  TestAudioCapture
//
//  Created by ChaoSo on 2018/10/30.
//  Copyright © 2018 ChaoSo. All rights reserved.
//

#import "CSAacAudioEncoder.h"
#import "CSAudioFrameModel.h"

@interface CSAacAudioEncoder()
@property (nonatomic) AudioConverterRef audioConverter;
@property (nonatomic) uint8_t *aacBuffer;
@property (nonatomic) NSUInteger aacBufferSize;
@property (nonatomic) char *pcmBuffer;
@property (nonatomic) size_t pcmBufferSize;
@property (nonatomic) BOOL sentAudioHead;

@property (strong, nonatomic) NSFileHandle *handle;
@property (nonatomic, copy) NSString *path;
@property (nonatomic ,assign,readonly) char *asc;
@end

@implementation CSAacAudioEncoder
- (void) dealloc {
    AudioConverterDispose(_audioConverter);
    free(_aacBuffer);
}

- (void)setAudioSampleRate{
    NSInteger sampleRateIndex = 4;
    self.asc[0] = 0x10 | ((sampleRateIndex>>1) & 0x3);
    self.asc[1] = ((sampleRateIndex & 0x1)<<7) | ((/*self.numberOfChannels*/1 & 0xF) << 3);
}

- (void)setNumberOfChannels{
//    NSInteger sampleRateIndex = [self sampleRateIndex:self.audioSampleRate];
    NSInteger sampleRateIndex = 4;
    self.asc[0] = 0x10 | ((sampleRateIndex>>1) & 0x3);
    self.asc[1] = ((sampleRateIndex & 0x1)<<7) | ((/*numberOfChannels*/1 & 0xF) << 3);
}

- (id) init {
    if (self = [super init]) {
        _encoderQueue = dispatch_queue_create("AAC Encoder Queue", DISPATCH_QUEUE_SERIAL);
        _callbackQueue = dispatch_queue_create("AAC Encoder Callback Queue", DISPATCH_QUEUE_SERIAL);
        _audioConverter = NULL;
        _pcmBufferSize = 0;
        _pcmBuffer = NULL;
        _aacBufferSize = 1024;
        _aacBuffer = malloc(_aacBufferSize * sizeof(uint8_t));
        memset(_aacBuffer, 0, _aacBufferSize);
        
        self.path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"audio.aac"];
        NSFileManager *manager = [NSFileManager defaultManager];
        BOOL a =  [manager createFileAtPath:_path contents:nil attributes:nil];
        if (a) {
            NSLog(@"creat file success");
        }else{
            NSLog(@"creat file fail");
        }
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:_path];
        self.handle = handle;
        
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setActive:YES withOptions:kAudioSessionSetActiveFlag_NotifyOthersOnDeactivation error:nil];
        
        
        NSError *error = nil;
        
        [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers error:nil];
        
        [session setMode:AVAudioSessionModeVideoRecording error:&error];
        
        if (![session setActive:YES error:&error]) {
//            [self handleAudioComponentCreationFailure];
        }
        
        _asc = malloc(2);
        [self setAudioSampleRate];
        [self setNumberOfChannels];
    }
    return self;
}

- (void) setupEncoderFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    AudioStreamBasicDescription inputFormat = {0};
    inputFormat.mSampleRate = 44100;
    inputFormat.mFormatID = kAudioFormatLinearPCM;
    inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    inputFormat.mChannelsPerFrame = (UInt32)1;
    inputFormat.mFramesPerPacket = 1;
    inputFormat.mBitsPerChannel = 16;
    inputFormat.mBytesPerFrame = inputFormat.mBitsPerChannel / 8 * inputFormat.mChannelsPerFrame;
    inputFormat.mBytesPerPacket = inputFormat.mBytesPerFrame * inputFormat.mFramesPerPacket;
    
    AudioStreamBasicDescription outputFormat; // 这里开始是输出音频格式
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate       = inputFormat.mSampleRate; // 采样率保持一致
    outputFormat.mFormatID         = kAudioFormatMPEG4AAC;    // AAC编码 kAudioFormatMPEG4AAC kAudioFormatMPEG4AAC_HE_V2
    outputFormat.mChannelsPerFrame = (UInt32)1;;
    outputFormat.mFramesPerPacket  = 1024;                    // AAC一帧是1024个字节
    
    const OSType subtype = kAudioFormatMPEG4AAC;
    AudioClassDescription requestedCodecs[2] = {
        {
            kAudioEncoderComponentType,
            subtype,
            kAppleSoftwareAudioCodecManufacturer
        },
        {
            kAudioEncoderComponentType,
            subtype,
            kAppleHardwareAudioCodecManufacturer
        }
    };
    
    OSStatus result = AudioConverterNewSpecific(&inputFormat, &outputFormat, 2, requestedCodecs, &_audioConverter);
    if (result != 0) {
        NSLog(@"setup converter: %d", (int)result);
    }
}

- (AudioClassDescription *)getAudioClassDescriptionWithType:(UInt32)type
                                           fromManufacturer:(UInt32)manufacturer
{
    static AudioClassDescription desc;
    
    UInt32 encoderSpecifier = type;
    OSStatus st;
    
    UInt32 size;
    st = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders,
                                    sizeof(encoderSpecifier),
                                    &encoderSpecifier,
                                    &size);
    if (st) {
        NSLog(@"error getting audio format propery info: %d", (int)(st));
        return nil;
    }
    
    unsigned int count = size / sizeof(AudioClassDescription);
    AudioClassDescription descriptions[count];
    st = AudioFormatGetProperty(kAudioFormatProperty_Encoders,
                                sizeof(encoderSpecifier),
                                &encoderSpecifier,
                                &size,
                                descriptions);
    if (st) {
        NSLog(@"error getting audio format propery: %d", (int)(st));
        return nil;
    }
    
    for (unsigned int i = 0; i < count; i++) {
        if ((type == descriptions[i].mSubType) &&
            (manufacturer == descriptions[i].mManufacturer)) {
            memcpy(&desc, &(descriptions[i]), sizeof(desc));
            return &desc;
        }
    }
    
    return nil;
}

static OSStatus inInputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
    CSAacAudioEncoder *encoder = (__bridge CSAacAudioEncoder *)(inUserData);
    UInt32 requestedPackets = *ioNumberDataPackets;
    //NSLog(@"Number of packets requested: %d", (unsigned int)requestedPackets);
    size_t copiedSamples = [encoder copyPCMSamplesIntoBuffer:ioData];
    if (copiedSamples < requestedPackets) {
        //NSLog(@"PCM buffer isn't full enough!");
        *ioNumberDataPackets = 0;
        return -1;
    }
    *ioNumberDataPackets = 1;
    //NSLog(@"Copied %zu samples into ioData", copiedSamples);
    return noErr;
}

- (size_t) copyPCMSamplesIntoBuffer:(AudioBufferList*)ioData {
    size_t originalBufferSize = _pcmBufferSize;
    if (!originalBufferSize) {
        return 0;
    }
    ioData->mBuffers[0].mData = _pcmBuffer;
    ioData->mBuffers[0].mDataByteSize = _pcmBufferSize;
    _pcmBuffer = NULL;
    _pcmBufferSize = 0;
    return originalBufferSize;
}


- (void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer completionBlock:(void (^)(CSAudioFrameModel *model))completionBlock {
    CFRetain(sampleBuffer);
    dispatch_async(_encoderQueue, ^{
        if (!_audioConverter) {
            [self setupEncoderFromSampleBuffer:sampleBuffer];
        }
        CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
        CFRetain(blockBuffer);
        OSStatus status = CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &self->_pcmBufferSize, &_pcmBuffer);
        NSError *error = nil;
        if (status != kCMBlockBufferNoErr) {
            error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        }
        //NSLog(@"PCM Buffer Size: %zu", _pcmBufferSize);
        
        memset(_aacBuffer, 0, self->_aacBufferSize);
        AudioBufferList outAudioBufferList = {0};
        outAudioBufferList.mNumberBuffers = 1;
        outAudioBufferList.mBuffers[0].mNumberChannels = 1;
        outAudioBufferList.mBuffers[0].mDataByteSize = _aacBufferSize;
        outAudioBufferList.mBuffers[0].mData = _aacBuffer;
        AudioStreamPacketDescription *outPacketDescription = NULL;
        UInt32 ioOutputDataPacketSize = 1;
        status = AudioConverterFillComplexBuffer(_audioConverter, inInputDataProc, (__bridge void *)(self), &ioOutputDataPacketSize, &outAudioBufferList, outPacketDescription);
        //NSLog(@"ioOutputDataPacketSize: %d", (unsigned int)ioOutputDataPacketSize);
        NSData *data = nil;
        if (status == 0) {
            static int64_t totoalLength = 0;
            if (totoalLength >= 1024 * 1024 * 1) {
                return;
            }
            
            CSAudioFrameModel *model = [CSAudioFrameModel new];
            NSData *rawAAC = [NSData dataWithBytes:outAudioBufferList.mBuffers[0].mData length:outAudioBufferList.mBuffers[0].mDataByteSize];
            if (!self.sentAudioHead)
            {
                char exeData[2];
                exeData[0] = self.asc[0];
                exeData[1] = self.asc[1];
                NSData *headerData =[NSData dataWithBytes:exeData length:2];
                model.headerData = headerData;
                if (completionBlock) {
                    dispatch_async(_callbackQueue, ^{
                        NSLog(@"====== header");
                        completionBlock(model);
                        self.sentAudioHead = YES;
                    });
                }
            }
            else
            {
                data = rawAAC;
                model.frameData = data;
                if (completionBlock) {
                    dispatch_async(_callbackQueue, ^{
                        completionBlock(model);
                    });
                }
            }
            
            //  设置adts头 acc录音成功噢
            //            int headerLength = 0;
            //            NSData *adtsHeader = [self adtsDataForPacketLength:rawAAC.length];
            //            NSMutableData *fullData = [NSMutableData dataWithData:adtsHeader];
            //            [fullData appendData:rawAAC];
            //            [_handle seekToEndOfFile];
            //            [_handle writeData:fullData];
            //            fullData = nil;
            //            rawAAC = nil;
            //            totoalLength+=fullData.length;
            //            if (totoalLength >= 1024 * 1024 *1) {
            //                [_handle closeFile];
            //            }
            
        } else {
            error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        }
        
        CFRelease(sampleBuffer);
        CFRelease(blockBuffer);
    });
}

- (void)reset
{
    self.sentAudioHead = NO;
    [_handle closeFile];
}



/**
 *  Add ADTS header at the beginning of each and every AAC packet.
 *  This is needed as MediaCodec encoder generates a packet of raw
 *  AAC data.
 *
 *  Note the packetLen must count in the ADTS header itself.
 *  See: http://wiki.multimedia.cx/index.php?title=ADTS
 *  Also: http://wiki.multimedia.cx/index.php?title=MPEG-4_Audio#Channel_Configurations
 **/
- (NSData*) adtsDataForPacketLength:(NSUInteger)packetLength {
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;  //AAC LC
    //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
    int freqIdx = 4;  //44.1KHz
    int chanCfg = 1;  //MPEG-4 Audio Channel Configuration. 1 Channel front-center
    NSUInteger fullLength = adtsLength + packetLength;
    // fill in ADTS data
    packet[0] = (char)0xFF; // 11111111     = syncword
    packet[1] = (char)0xF9; // 1111 1 00 1  = syncword MPEG-2 Layer CRC
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    return data;
}
@end
