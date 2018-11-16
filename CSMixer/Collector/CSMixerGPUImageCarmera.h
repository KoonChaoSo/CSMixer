//
//  CSMixerGPUImageCarmera.h
//  CSMixer
//
//  Created by 苏冠超[产品技术中心] on 2018/11/16.
//  Copyright © 2018 ChaoSo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GPUImage/GPUImage.h>
#import "CSMixerCollectorProtocol.h"

@class CSMixerGPUImageCarmera;
@protocol CSMixerGPUImageCarmeraDelegate <NSObject>
@optional
- (void)myCaptureOutput:(CSMixerGPUImageCarmera *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer type:(CSMixerCaptureType)type;
@end

@interface CSMixerGPUImageCarmera : GPUImageVideoCamera
@property (assign, nonatomic) id<CSMixerGPUImageCarmeraDelegate> customDelegate;
@property (strong, nonatomic) AVCaptureConnection *connection;
@end

