//
//  JDOStationMapController.h
//  YTBus
//
//  Created by zhang yi on 14-11-18.
//  Copyright (c) 2014年 胶东在线. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JDOStationModel.h"
#import <BaiduMapAPI_Location/BMKLocationComponent.h>
#import <BaiduMapAPI_Search/BMKPoiSearch.h>
#import <BaiduMapAPI_Search/BMKBusLineSearchOption.h>


@interface JDOStationMapController : UIViewController

@property (nonatomic,strong) NSString *stationName;
@property (nonatomic,strong) JDOStationModel *selectedStation;

@end
