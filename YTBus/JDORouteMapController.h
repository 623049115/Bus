//
//  JDORouteMapController.h
//  YTBus
//
//  Created by zhang yi on 14-11-25.
//  Copyright (c) 2014年 胶东在线. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <BaiduMapAPI_Map/BMKMapComponent.h>
#import <BaiduMapAPI_Search/BMKRouteSearchType.h>
#import <BaiduMapAPI_Location/BMKLocationComponent.h>

@interface JDORouteMapController : UIViewController

@property (nonatomic,strong) BMKTransitRouteLine *route;
@property (nonatomic,strong) NSString *lineTitle;

@end
