//
//  CSMixerGPUImageCarmera.m
//  CSMixer
//
//  Created by 苏冠超[产品技术中心] on 2018/11/16.
//  Copyright © 2018 ChaoSo. All rights reserved.
//

#import "CSMixerGPUImageCarmera.h"

@implementation CSMixerGPUImageCarmera
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    [super captureOutput:captureOutput didOutputSampleBuffer:sampleBuffer fromConnection:connection];
    if (captureOutput == videoOutput)
    {
        if ([self.customDelegate respondsToSelector:@selector(myCaptureOutput:didOutputSampleBuffer:type:)])
        {
            [self.customDelegate myCaptureOutput:self didOutputSampleBuffer:sampleBuffer type:CSMixerCaptureVideoType];
        }
    }
    else
    {
        if ([self.customDelegate respondsToSelector:@selector(myCaptureOutput:didOutputSampleBuffer:type:)])
        {
            [self.customDelegate myCaptureOutput:self didOutputSampleBuffer:sampleBuffer type:CSMixerCaptureAudioType];
        }
    }
}

- (AVCaptureConnection *)connection
{
    _connection = [self->videoOutput connectionWithMediaType:AVMediaTypeVideo];
    _connection.automaticallyAdjustsVideoMirroring = NO;
    return _connection;
}


@end
