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
@protocol CSMixerGPUImageCollectorDelegate <NSObject>

- (void)csGPUImageColletorOutput:(CSMixerGPUImageCollector *)outputColletor
           didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
                  fromConnection:(CSMixerCaptureType)connection;

@end

@interface CSMixerGPUImageCollector<CSMixerCollectorDelegate> : NSObject
@property (weak, nonatomic) id<CSMixerGPUImageCollectorDelegate> delegate;

- (instancetype)initWithDelegate:(id<CSMixerGPUImageCollectorDelegate>)delegate;
@end

