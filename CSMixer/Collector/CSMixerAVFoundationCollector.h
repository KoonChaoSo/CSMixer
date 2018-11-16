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
@protocol CSMixerCollectorDelegate <NSObject>

- (void)csColletorOutput:(CSMixerAVFoundationCollector *)outputColletor
   didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
          fromConnection:(CSMixerCaptureType)connection;

@end

@interface CSMixerAVFoundationCollector<CSMixerCollectorProtocol> : NSObject
@property (weak, nonatomic) id<CSMixerCollectorDelegate> delegate;
- (instancetype)initWithDelegate:(id<CSMixerCollectorProtocol>)delegate;
- (void)startCapture:(UIView *)preview;
- (void)stopCapture;
@end
