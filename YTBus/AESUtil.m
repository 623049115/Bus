//
//  AESUtil.m
//  YTBus
//
//  Created by 张大蓓 on 15/9/1.
//  Copyright (c) 2015年 胶东在线. All rights reserved.
//

#import "AESUtil.h"
#import <CommonCrypto/CommonCryptor.h>
//#import "GTMBase64.h"

#define gkey			@"DF23>&L*F4sn09!)" //秘钥
#define gIv             @"H&%k12}:ct@(<>6P" //向量

@implementation AESUtil

+ (NSString *)AES128Encrypt:(NSString *)plainText{  //282602108
    char keyPtr[kCCKeySizeAES128+1];
    memset(keyPtr, 0, sizeof(keyPtr));
    [gkey getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    
    char ivPtr[kCCKeySizeAES128+1];
    memset(ivPtr, 0, sizeof(ivPtr));
    [gIv getCString:ivPtr maxLength:sizeof(ivPtr) encoding:NSUTF8StringEncoding];
    
    NSData *data = [plainText dataUsingEncoding:NSUTF8StringEncoding];  // <32383236 30323130 38>
    NSUInteger dataLength = [data length];
    
    int diff = kCCKeySizeAES128 - (dataLength % kCCKeySizeAES128);
    NSUInteger newSize = 0;
    
    if(diff > 0){
        newSize = dataLength + diff;
    }
    
    char dataPtr[newSize];
    memcpy(dataPtr, [data bytes], [data length]);
    for(int i = 0; i < diff; i++){
        dataPtr[i + dataLength] = 0x07;
    }
    
    size_t bufferSize = newSize + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    memset(buffer, 0, bufferSize);
    
    size_t numBytesCrypted = 0;
    
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt,
                                          kCCAlgorithmAES128,
                                          0x0000,               //No padding
                                          keyPtr,
                                          kCCKeySizeAES128,
                                          ivPtr,
                                          dataPtr,
                                          sizeof(dataPtr),
                                          buffer,
                                          bufferSize,
                                          &numBytesCrypted);
    
    // TODO iOS7以下处理Base64
    if (cryptStatus == kCCSuccess) {
        NSData *resultData = [NSData dataWithBytesNoCopy:buffer length:numBytesCrypted];//<df1f02cb 7eb5249a c2d8d628 4f0cb30f>
//        return [GTMBase64 stringByEncodingData:resultData];
//        NSLog(@"data:%@",resultData);
        NSString* encodeResult = [resultData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
//        NSLog(@"string:%@",encodeResult);   //3x8Cy361JJrC2NYoTwyzDw==
        return encodeResult;
    }
    
    free(buffer);
    return nil;
}

+ (NSString *)AES128Decrypt:(NSString *)encryptText //3x8Cy361JJrC2NYoTwyzDw==
{
    char keyPtr[kCCKeySizeAES128 + 1];
    memset(keyPtr, 0, sizeof(keyPtr));
    [gkey getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    
    char ivPtr[kCCBlockSizeAES128 + 1];
    memset(ivPtr, 0, sizeof(ivPtr));
    [gIv getCString:ivPtr maxLength:sizeof(ivPtr) encoding:NSUTF8StringEncoding];
    
//    NSData *data = [GTMBase64 decodeData:[encryptText dataUsingEncoding:NSUTF8StringEncoding]];
//    NSData *data = [encryptText dataUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [[NSData alloc] initWithBase64EncodedString:encryptText options:NSDataBase64DecodingIgnoreUnknownCharacters];    //<df1f02cb 7eb5249a c2d8d628 4f0cb30f>

    NSUInteger dataLength = [data length];
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    memset(buffer, 0, bufferSize);
    
    size_t numBytesCrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt,
                                          kCCAlgorithmAES128,
                                          0x0000,
                                          keyPtr,
                                          kCCBlockSizeAES128,
                                          ivPtr,
                                          [data bytes],
                                          dataLength,
                                          buffer,
                                          bufferSize,
                                          &numBytesCrypted);
    if (cryptStatus == kCCSuccess) {
        NSData *resultData = [NSData dataWithBytesNoCopy:buffer length:numBytesCrypted];//<32383236 30323130 38070707 07070707>
        return [[NSString alloc] initWithData:resultData encoding:NSUTF8StringEncoding];
    }
    free(buffer);
    return nil;
}


@end
