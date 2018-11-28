//
//  CSMixerGPUImageCollector.h
//  CSMixer
//
//  Created by 苏冠超[产品技术中心] on 2018/11/16.
//  Copyright © 2018 ChaoSo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "CSMixerCollectorProtocol.h"

@class CSMixerGPUImageCollector;
@protocol CSMixerCaptureDelegate <NSObject>

- (void)csColletorOutput:(id<CSMixerCollectorProtocol>)outputColletor
   didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
          fromConnection:(CSMixerCaptureType)connection;

@end

@interface CSMixerGPUImageCollector : NSObject
@property (weak, nonatomic) id<CSMixerCaptureDelegate> delegate;

- (instancetype)initWithDelegate:(id<CSMixerCaptureDelegate>)delegate;
@end

