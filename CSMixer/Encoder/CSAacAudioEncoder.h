//
//  CSAccAudioEncoder.h
//  TestAudioCapture
//
//  Created by ChaoSo on 2018/10/30.
//  Copyright © 2018 ChaoSo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@class CSAudioFrameModel;
@interface CSAacAudioEncoder : NSObject
@property (nonatomic) dispatch_queue_t encoderQueue;
@property (nonatomic) dispatch_queue_t callbackQueue;

- (void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer completionBlock:(void (^)(CSAudioFrameModel *model))completionBlock;

//- (void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer completionBlock:(void (^)(NSData * encodedData, BOOL sentAudioHead,NSError* error))completionBlock;

- (void)reset;

@end

