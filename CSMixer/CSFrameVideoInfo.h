//
//  CSFrameInfo.h
//  CSMixer
//
//  Created by ChaoSo on 2018/8/12.
//  Copyright © 2018年 ChaoSo. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CSFrameVideoInfo : NSObject
@property (nonatomic, assign) uint64_t timestamp;
@property (nonatomic, strong) NSData *data;
///< flv或者rtmp包头
@property (nonatomic, strong) NSData *header;

@property (nonatomic, assign) BOOL isKeyFrame;
@property (nonatomic, strong) NSData *sps;
@property (nonatomic, strong) NSData *pps;
@end

NS_ASSUME_NONNULL_END
