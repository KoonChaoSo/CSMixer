//
//  CSVideoFrameModel.h
//  CSMixer
//
//  Created by 苏冠超 on 2018/11/14.
//  Copyright © 2018 ChaoSo. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface CSVideoFrameModel : NSObject

@property (strong, nonatomic) NSData * frameData;
@property (assign, nonatomic) NSTimeInterval ts;
@property (assign, nonatomic) BOOL isKeyFrame;

@property (strong, nonatomic) NSData *sps; //又称作序列参数集。SPS中保存了一组编码视频序列(Coded video sequence)的全局参数
@property (strong, nonatomic) NSData *pps; //H.264中另一重要的参数集合为图像参数集Picture Paramater Set(PPS)。
@end

