//
//  CSAudioFrameModel.h
//  CSMixer
//
//  Created by 苏冠超[产品技术中心] on 2018/11/14.
//  Copyright © 2018 ChaoSo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CSAudioFrameModel : NSObject

@property (strong, nonatomic) NSData * frameData;
@property (strong, nonatomic) NSData * headerData;
@property (assign, nonatomic) NSTimeInterval ts;
@end

