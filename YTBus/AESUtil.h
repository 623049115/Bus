//
//  AESUtil.h
//  YTBus
//
//  Created by 张大蓓 on 15/9/1.
//  Copyright (c) 2015年 胶东在线. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AESUtil : NSObject

+ (NSString*) AES128Encrypt:(NSString *)plainText;

+ (NSString*) AES128Decrypt:(NSString *)encryptText;

@end
