//
//  AppDelegate.h
//  YTBus
//
//  Created by zhang yi on 14-10-17.
//  Copyright (c) 2014年 胶东在线. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <BaiduMapAPI_Map/BMKMapComponent.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate,BMKGeneralDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) BMKMapManager *mapManager;

@property (nonatomic, strong) BMKUserLocation *userLocation;
@property (assign, nonatomic) int realtimeRequestCount;
@property (strong, nonatomic) NSMutableDictionary *systemParam;

@property (strong, nonatomic) NSMutableDictionary *sameIdStationMap;
@property (strong, nonatomic) NSMutableDictionary *sameNameStationMap;

@property (strong, nonatomic) NSString *encryptKey;

- (void)enterMainStoryboard;

@end

