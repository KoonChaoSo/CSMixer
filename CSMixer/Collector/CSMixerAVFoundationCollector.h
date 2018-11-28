//
//  CSMixerCollector.h
//  CSMixer
//
//  Created by ChaoSo on 2018/7/24.
//  Copyright © 2018年 ChaoSo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "CSMixerCollectorProtocol.h"



@class CSMixerAVFoundationCollector;
@protocol CSMixerCaptureDelegate <NSObject>

- (void)csColletorOutput:(id<CSMixerCollectorProtocol>)outputColletor
   didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
          fromConnection:(CSMixerCaptureType)connection;

@end

@interface CSMixerAVFoundationCollector : NSObject
@property (weak, nonatomic) id<CSMixerCaptureDelegate> delegate;

- (instancetype)initWithDelegate:(id<CSMixerCaptureDelegate>)delegate;
- (void)startCapture:(UIView *)preview;
- (void)stopCapture;
@end
