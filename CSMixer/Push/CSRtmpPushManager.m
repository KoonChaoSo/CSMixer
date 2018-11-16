//
//  CSRtmpPushManager.m
//  CSMixer
//
//  Created by ChaoSo on 2018/8/6.
//  Copyright © 2018年 ChaoSo. All rights reserved.
//

#import "CSRtmpPushManager.h"
#import "rtmp.h"
#import "CSVideoFrameModel.h"
#import "CSAudioFrameModel.h"
#define RTMP_HEAD_SIZE (sizeof(RTMPPacket)+RTMP_MAX_HEADER_SIZE)


#define DATA_ITEMS_MAX_COUNT 100
#define RTMP_DATA_RESERVE_SIZE 400

#define SAVC(x)    static const AVal av_##x = AVC(#x)

static const AVal av_setDataFrame = AVC("@setDataFrame");
static const AVal av_SDKVersion = AVC("ChaoSoLive 1.5.2");
SAVC(onMetaData);
SAVC(duration);
SAVC(width);
SAVC(height);
SAVC(videocodecid);
SAVC(videodatarate);
SAVC(framerate);
SAVC(audiocodecid);
SAVC(audiodatarate);
SAVC(audiosamplerate);
SAVC(audiosamplesize);
SAVC(audiochannels);
SAVC(stereo);
SAVC(encoder);
SAVC(av_stereo);
SAVC(fileSize);
SAVC(avc1);
SAVC(mp4a);
@interface CSRtmpPushManager()
{
    PILI_RTMP *rtmp;
    double startTime;
    dispatch_queue_t rtmp_push_queue;
    
}

@property (strong, nonatomic) NSString *rtmpUrlString;
@property (assign, nonatomic) RTMPError error;
@end
@implementation CSRtmpPushManager

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self->rtmp_push_queue = dispatch_queue_create("rtmpSendQueue", NULL);
    }
    return self;
}

static CSRtmpPushManager* shareInstace = nil;
+ (instancetype)getInstance
{
    static dispatch_once_t instance;
    dispatch_once(&instance, ^{
        shareInstace = [[self alloc] init];
    });
    return shareInstace;
}

- (BOOL)startRtmpConnect:(NSString *)rtmpUrlStr
{
    self.rtmpUrlString = rtmpUrlStr;
    
    //如果存在当前rtmp的话，重新推流
    if (self->rtmp)
    {
        //TODO:stop
        [self stopRtmpConnect];
    }
    
    //如果没有
    //内存申请
    self->rtmp = PILI_RTMP_Alloc();
    //初始化
    PILI_RTMP_Init(self->rtmp);
    //设置rtmpurl
    RTMPError err;
    if (PILI_RTMP_SetupURL(self->rtmp, (char*)[self.rtmpUrlString cStringUsingEncoding:NSASCIIStringEncoding],&_error) < 0){
        NSLog(@"fail");
        PILI_RTMP_Free(self->rtmp);
        return NO;
    }
    
    self->rtmp->m_errorCallback = RTMPErrorCallback;
    self->rtmp->m_connCallback = ConnectionTimeCallback;
    self->rtmp->m_userData = (__bridge void *)self;
    self->rtmp->m_msgCounter = 1;
    self->rtmp->Link.timeout = 2;
    
    //设置可写，即发布流，这个函数必须在连接前使用，否则无效
    PILI_RTMP_EnableWrite(self->rtmp);
    //设置失败
    
    //连接服务器
    if (PILI_RTMP_Connect(self->rtmp, NULL, &_error) < 0){
        NSLog(@"fail");
        PILI_RTMP_Free(self->rtmp);
        return NO;
    }
    //连接流
    if (PILI_RTMP_ConnectStream(self->rtmp, 0, &_error) == FALSE) {
        NSLog(@"fail");
        PILI_RTMP_Free(self->rtmp);
        return NO;
    }
    
    [self sendMetaData];
    self->startTime = [[NSDate date] timeIntervalSince1970]*1000;
    return YES;
}

- (void)sendMetaData {
    PILI_RTMPPacket packet;
    
    char pbuf[2048], *pend = pbuf+sizeof(pbuf);
    
    packet.m_nChannel = 0x03;     // control channel (invoke)
    packet.m_headerType = RTMP_PACKET_SIZE_LARGE;
    packet.m_packetType = RTMP_PACKET_TYPE_INFO;
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = self->rtmp->m_stream_id;
    packet.m_hasAbsTimestamp = TRUE;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;
    
    char *enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_setDataFrame);
    enc = AMF_EncodeString(enc, pend, &av_onMetaData);

    *enc++ = AMF_OBJECT;

    enc = AMF_EncodeNamedNumber(enc, pend, &av_duration,        0.0);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_fileSize,        0.0);

    // videosize
    enc = AMF_EncodeNamedNumber(enc, pend, &av_width,           480);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_height,          640);

    // video
    enc = AMF_EncodeNamedString(enc, pend, &av_videocodecid,    &av_avc1);
//640x480
    enc = AMF_EncodeNamedNumber(enc, pend, &av_videodatarate,   480 * 640 / 1000.f);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_framerate,       20);

    // audio
    enc = AMF_EncodeNamedString(enc, pend, &av_audiocodecid,    &av_mp4a);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_audiodatarate,   96000);

    enc = AMF_EncodeNamedNumber(enc, pend, &av_audiosamplerate, 44100);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_audiosamplesize, 16.0);
    enc = AMF_EncodeNamedBoolean(enc, pend, &av_stereo,     NO);

    // sdk version
    enc = AMF_EncodeNamedString(enc, pend, &av_encoder,         &av_SDKVersion);

    *enc++ = 0;
    *enc++ = 0;
    *enc++ = AMF_OBJECT_END;
    
    packet.m_nBodySize = enc - packet.m_body;
    RTMPError err;
    if(!PILI_RTMP_SendPacket(self->rtmp, &packet, FALSE, &_error)) {
        return;
    }
}
void RTMPErrorCallback(RTMPError *error, void *userData) {
    
    if (error->code < 0) {
        
    }
}

void ConnectionTimeCallback(PILI_CONNECTION_TIME *conn_time, void *userData) {
    CSRtmpPushManager *socket = (__bridge CSRtmpPushManager*)userData;
}
- (BOOL)stopRtmpConnect
{
    if (self->rtmp)
    {
        RTMPError err;
        PILI_RTMP_Close(self->rtmp,&_error);
        PILI_RTMP_Free(self->rtmp);
        return YES;
    }
    return NO;
}


- (void)send_video_sps_pps:(unsigned char*)sps andSpsLength:(long)sps_len andPPs:(unsigned char*)pps andPPsLength:(long)pps_len
{
    dispatch_async(self->rtmp_push_queue, ^{
        if(self->rtmp!= NULL)
        {
            unsigned char *body = NULL;
            NSInteger iIndex = 0;
            NSInteger rtmpLength = 1024;
            
            body = (unsigned char *)malloc(rtmpLength);
            memset(body, 0, rtmpLength);
            
            body[iIndex++] = 0x17;
            body[iIndex++] = 0x00;
            
            body[iIndex++] = 0x00;
            body[iIndex++] = 0x00;
            body[iIndex++] = 0x00;
            
            body[iIndex++] = 0x01;
            body[iIndex++] = sps[1];
            body[iIndex++] = sps[2];
            body[iIndex++] = sps[3];
            body[iIndex++] = 0xff;
            
            /*sps*/
            body[iIndex++] = 0xe1;
            body[iIndex++] = (sps_len >> 8) & 0xff;
            body[iIndex++] = sps_len & 0xff;
            memcpy(&body[iIndex], sps, sps_len);
            iIndex += sps_len;
            
            /*pps*/
            body[iIndex++] = 0x01;
            body[iIndex++] = (pps_len >> 8) & 0xff;
            body[iIndex++] = (pps_len) & 0xff;
            memcpy(&body[iIndex], pps, pps_len);
            iIndex += pps_len;
            
            [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:iIndex nTimestamp:0];
            free(body);
        }
    });
    
}

- (void)sendVideo:(CSVideoFrameModel *)frame
{
    if (frame.isKeyFrame && (frame.sps && frame.pps))
    {
        //是否关键帧和是否已经pps和sps
        [self send_video_sps_pps:(unsigned char *)frame.sps.bytes andSpsLength:frame.sps.length andPPs:(unsigned char *)frame.pps.bytes andPPsLength:frame.pps.length];
    }
    else
    {
        [self send_rtmp_video:frame.frameData andLength:frame.frameData.length isKeyFrame:frame.isKeyFrame];
    }
}

- (void)sendAudio:(CSAudioFrameModel *)frame
{
    if (frame.headerData)
    {
        [self sendAudioHeader:frame.headerData.length data:frame.headerData];
    }
    else
    {
        [self sendAudio:frame.frameData.length data:frame.frameData];
    }
}

- (void)send_rtmp_video:(NSData *)data andLength:(long)len isKeyFrame:(BOOL)isKeyFrame
{
    __block uint32_t length = len;
    dispatch_async(self->rtmp_push_queue, ^{
        if(self->rtmp != NULL)
        {
            uint32_t timeoffset = [[NSDate date] timeIntervalSince1970]*1000 - self->startTime;  /*start_time为开始直播时的时间戳*/
            NSInteger i = 0;
            NSInteger rtmpLength = data.length + 9;
            unsigned char *body = (unsigned char *)malloc(rtmpLength);
            memset(body, 0, rtmpLength);
            
            if (isKeyFrame) {
                body[i++] = 0x17;        // 1:Iframe  7:AVC
            } else {
                body[i++] = 0x27;        // 2:Pframe  7:AVC
            }
            body[i++] = 0x01;    // AVC NALU
            body[i++] = 0x00;
            body[i++] = 0x00;
            body[i++] = 0x00;
            body[i++] = (data.length >> 24) & 0xff;
            body[i++] = (data.length >> 16) & 0xff;
            body[i++] = (data.length >>  8) & 0xff;
            body[i++] = (data.length) & 0xff;
            memcpy(&body[i], data.bytes, data.length);
            
            [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:(rtmpLength) nTimestamp:timeoffset];
            free(body);
        }
    });
}


- (void)sendAudioHeader:(NSInteger )audioLength data:(NSData *)data{
    
    dispatch_async(self->rtmp_push_queue, ^{
        NSInteger rtmpLength = audioLength + 2;     /*spec data长度,一般是2*/
        unsigned char *body = (unsigned char *)malloc(rtmpLength);
        memset(body, 0, rtmpLength);
        
        /*AF 00 + AAC RAW data*/
        body[0] = 0xAF;
        body[1] = 0x00;
        memcpy(&body[2], data.bytes, audioLength);          /*spec_buf是AAC sequence header数据*/
        [self sendPacket:RTMP_PACKET_TYPE_AUDIO data:body size:rtmpLength nTimestamp:0];
        free(body);
    });
}

- (void)sendAudio:(NSInteger )audioLength data:(NSData *)data {
    
    dispatch_async(self->rtmp_push_queue, ^{
        uint32_t timeoffset = [[NSDate date] timeIntervalSince1970]*1000 - self->startTime;
        NSInteger rtmpLength = audioLength + 2;    /*spec data长度,一般是2*/
        unsigned char *body = (unsigned char *)malloc(rtmpLength);
        memset(body, 0, rtmpLength);
        
        /*AF 01 + AAC RAW data*/
        body[0] = 0xAF;
        body[1] = 0x01;
        memcpy(&body[2], data.bytes, audioLength);
        [self sendPacket:RTMP_PACKET_TYPE_AUDIO data:body size:rtmpLength nTimestamp:timeoffset];
        free(body);
    });
}


-(NSInteger)sendPacket:(unsigned int)nPacketType data:(unsigned char *)data size:(NSInteger) size nTimestamp:(uint64_t) nTimestamp
{
    NSInteger rtmpLength = size;
    PILI_RTMPPacket rtmp_pack;
    PILI_RTMPPacket_Reset(&rtmp_pack);
    PILI_RTMPPacket_Alloc(&rtmp_pack,(uint32_t)rtmpLength);
    
    rtmp_pack.m_nBodySize = (uint32_t)size;
    memcpy(rtmp_pack.m_body,data,size);
    rtmp_pack.m_hasAbsTimestamp = 0;
    rtmp_pack.m_packetType = nPacketType;
    if(self->rtmp) rtmp_pack.m_nInfoField2 = self->rtmp->m_stream_id;
    rtmp_pack.m_nChannel = 0x04;
    rtmp_pack.m_headerType = RTMP_PACKET_SIZE_LARGE;
    if (RTMP_PACKET_TYPE_AUDIO == nPacketType && size !=4){
        rtmp_pack.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    }
    rtmp_pack.m_nTimeStamp = (uint32_t)nTimestamp;
    
    NSInteger nRet = [self RtmpPacketSend:&rtmp_pack];
    
    PILI_RTMPPacket_Free(&rtmp_pack);
    return nRet;
}

- (NSInteger)RtmpPacketSend:(PILI_RTMPPacket*)packet{
//    RTMPError error;
    if (PILI_RTMP_IsConnected(self->rtmp)){
        int success = PILI_RTMP_SendPacket(self->rtmp,packet,0,&_error);
//        if(success){
//            self.isSending = NO;
//            [self sendFrame];
//        }
        return success;
    }
    
    return -1;
}



@end
