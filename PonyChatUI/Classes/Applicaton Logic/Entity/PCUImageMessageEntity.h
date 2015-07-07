//
//  PCUImageMessageEntity.h
//  PonyChatUIV2
//
//  Created by 崔 明辉 on 15/7/7.
//  Copyright (c) 2015年 PonyCui. All rights reserved.
//

#import "PCUMessageEntity.h"

@interface PCUImageMessageEntity : PCUMessageEntity

@property (nonatomic, copy) NSString *imageURLString;

@property (nonatomic, assign) CGSize imageSize;

@end