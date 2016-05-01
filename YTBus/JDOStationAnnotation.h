//
//  JDOStationAnnotation.h
//  YTBus
//
//  Created by zhang yi on 14-11-7.
//  Copyright (c) 2014年 胶东在线. All rights reserved.
//


#import "JDOStationModel.h"
#import <BaiduMapAPI_Map/BMKMapComponent.h>

@interface JDOStationAnnotation : BMKPointAnnotation

@property (nonatomic,strong) NSDictionary *station;
@property (nonatomic,assign) BOOL selected;
@property (nonatomic,assign) int index;

@end
