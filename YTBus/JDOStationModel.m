//
//  JDOStationModel.m
//  YTBus
//
//  Created by zhang yi on 14-10-28.
//  Copyright (c) 2014年 胶东在线. All rights reserved.
//

#import "JDOStationModel.h"

@implementation JDOStationModel

- (NSString *)description{
    return [NSString stringWithFormat:@"id:%@,name:%@,direction:%@,linkStation:%@",self.fid,self.name,self.direction,self.linkStations];
}

@end
