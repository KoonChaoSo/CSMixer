//
//  CSMixerCollectorProtocol.h
//  CSMixer
//
//  Created by 苏冠超[产品技术中心] on 2018/11/16.
//  Copyright © 2018 ChaoSo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef enum : NSUInteger {
    CSMixerCaptureVideoType,
    CSMixerCaptureAudioType,
} CSMixerCaptureType;

@protocol CSMixerCollectorProtocol <NSObject>
- (void)startCapture:(UIView *)preview;
- (void)stopCapture;
//- (id)initWithDelegate:(id)delegate;
@end

