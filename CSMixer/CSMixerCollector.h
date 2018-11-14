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

typedef enum : NSUInteger {
    CSMixerCaptureVideoType,
    CSMixerCaptureAudioType,
} CSMixerCaptureType;

@class CSMixerCollector;
@protocol CSMixerCollectorDelegate <NSObject>

- (void)csColletorOutput:(CSMixerCollector *)outputColletor
   didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
          fromConnection:(CSMixerCaptureType)connection;

@end

@interface CSMixerCollector : NSObject
@property (weak, nonatomic) id<CSMixerCollectorDelegate> delegate;

- (void)startCapture:(UIView *)preview;
- (void)stopCapture;
@end
