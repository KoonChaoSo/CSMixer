//
//  CSVideoEncoder.h
//  CSMixer
//
//  Created by ChaoSo on 2018/7/25.
//  Copyright © 2018年 ChaoSo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolBox/VideoToolBox.h>
#import <AudioToolbox/AudioToolbox.h>
#import <UIKit/UIKit.h>

@class CSVideoFrameModel;
@protocol CSVideoEncoderDelegate <NSObject>

@end

@interface CSVideoEncoder : NSObject
@property (weak, nonatomic) id<CSVideoEncoderDelegate> delegate;

//- (void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer
- (void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer
                 timeStamp:(uint64_t)timeStamp
           completionBlock:(void (^)(CSVideoFrameModel *model))completionBlock;

- (void)endEncode;
@end
