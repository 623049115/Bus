//
//  TBClusterAnnotationView.h
//  TBAnnotationClustering
//
//  Created by Theodore Calmes on 10/4/13.
//  Copyright (c) 2013 Theodore Calmes. All rights reserved.
//

//#import "BMKAnnotationView.h"
#import <UIKit/UIKit.h>
#import <BaiduMapAPI_Map/BMKAnnotationView.h>

@interface TBClusterAnnotationView :BMKAnnotationView

@property (assign, nonatomic) NSUInteger count;
@property (nonatomic,strong) UIColor *markerColor;

@end
