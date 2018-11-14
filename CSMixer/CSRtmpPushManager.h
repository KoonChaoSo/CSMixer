//
//  CSRtmpPushManager.h
//  CSMixer
//
//  Created by ChaoSo on 2018/8/6.
//  Copyright © 2018年 ChaoSo. All rights reserved.
//

#import <Foundation/Foundation.h>


@class CSAudioFrameModel;
@class CSVideoFrameModel;
@interface CSRtmpPushManager : NSObject

+ (instancetype)getInstance;
/**
 *  开始连接服务器
 *  urlString: 流媒体服务器地址
 *  @return 是否成功
 */
- (BOOL)startRtmpConnect:(NSString *)rtmpUrlStr;

- (BOOL)stopRtmpConnect;

- (void)sendVideo:(CSVideoFrameModel*)frame;
- (void)sendAudio:(CSAudioFrameModel*)frame;
-(NSInteger)sendPacket:(unsigned int)nPacketType data:(unsigned char *)data size:(NSInteger) size nTimestamp:(uint64_t) nTimestamp;
- (void)send_video_sps_pps:(unsigned char*)sps andSpsLength:(long)sps_len andPPs:(unsigned char*)pps andPPsLength:(long)pps_len;

- (void)send_rtmp_video:(NSData *)data andLength:(long)len isKeyFrame:(BOOL)isKeyFrame;

- (void)sendAudio:(NSInteger )audioLength data:(NSData *)data;
- (void)sendAudioHeader:(NSInteger )audioLength data:(NSData *)data;

@end
