//
//  JDOStationController.h
//  YTBus
//
//  Created by zhang yi on 14-11-14.
//  Copyright (c) 2014年 胶东在线. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JDOStationModel.h"

@protocol JDOStationControllerDelegate <NSObject>

@optional
- (void)jdoStationControllerDidSelectedStation:(JDOStationModel *)stationModel;

@end

@interface JDOStationController : UITableViewController

@property (nonatomic,weak) id<JDOStationControllerDelegate> delegate;

@end
