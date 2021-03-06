//
//  JDOLocationMapController.h
//  YTBus
//
//  Created by zhang yi on 14-11-27.
//  Copyright (c) 2014年 胶东在线. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JDOInterChangeController.h"
#import <BaiduMapAPI_Map/BMKMapView.h>
#import <BaiduMapAPI_Location/BMKLocationService.h>
#import <BaiduMapAPI_Search/BMKGeocodeSearch.h>
#import <BaiduMapAPI_Search/BMKPoiSearchType.h>

@interface JDOLocationMapController : UIViewController

@property (nonatomic,assign) IBOutlet UINavigationBar *navigationBar;
@property (nonatomic,assign) int startOrEnd;
@property (nonatomic,assign) JDOInterChangeController *parentVC;
@property (nonatomic,strong) BMKPoiInfo *initialPoi;

@end
