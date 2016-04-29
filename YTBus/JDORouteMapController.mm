//
//  JDORouteMapController.m
//  YTBus
//
//  Created by zhang yi on 14-11-25.
//  Copyright (c) 2014年 胶东在线. All rights reserved.
//

#import "JDORouteMapController.h"
#import "JDOConstants.h"
#import "JDOUtils.h"
#import "math.h"

#define MYBUNDLE_NAME @ "mapapi.bundle"
#define MYBUNDLE_PATH [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: MYBUNDLE_NAME]
#define MYBUNDLE [NSBundle bundleWithPath: MYBUNDLE_PATH]

@interface RouteAnnotation : NSObject

@property (nonatomic) int type; ///<0:起点 1：终点 2：公交 3：步行
@property (nonatomic) int degree;
@end

@implementation RouteAnnotation

@end

@interface JDORouteMapController () <UITableViewDelegate,UITableViewDataSource>

@property (nonatomic,weak) IBOutlet UITableView *tableView;
@property (nonatomic,weak) IBOutlet UILabel *lineLabel;

@end

@implementation JDORouteMapController{
    NSInteger firstBusRow;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
//    _lineLabel.text = self.lineTitle;
}

-(void)viewWillAppear:(BOOL)animated {
    [MobClick beginLogPageView:@"transfermap"];
    [MobClick event:@"transfermap"];
    [MobClick beginEvent:@"transfermap"];
    
}

-(void)viewWillDisappear:(BOOL)animated {
    [MobClick endLogPageView:@"transfermap"];
    [MobClick endEvent:@"transfermap"];
    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
//    BMKTransitStep *step = self.route.steps[indexPath.row];
//    float contentHeight = [JDOUtils JDOSizeOfString:step.instruction :CGSizeMake(256.0f, MAXFLOAT) :[UIFont systemFontOfSize:14] :NSLineBreakByWordWrapping :0].height+2;
//    return contentHeight + 24;
    return 40;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
//    BMKTransitStep *step = self.route.steps[indexPath.row];
//    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"StepCell"]; // forIndexPath:indexPath];
//    UIImageView *bg = (UIImageView *)[cell viewWithTag:1000];
//    UIImageView *iv = (UIImageView *)[cell viewWithTag:1001];
//    UILabel *label = (UILabel *)[cell viewWithTag:1002];
//    UIImageView *separator = (UIImageView *)[cell viewWithTag:1003];
//    float rowHeight = [self tableView:tableView heightForRowAtIndexPath:indexPath];
//    label.frame = CGRectMake(50, 12, 256, rowHeight-24);
//    label.text = step.instruction;
//    separator.frame = CGRectMake(50, rowHeight-1, 256, 1);
//    iv.frame = CGRectMake(10, (rowHeight-42)/2, 22, 42);
//    if (indexPath.row == 0) {
//        bg.frame = CGRectMake(10, rowHeight/2, 22, rowHeight/2);
//        iv.image = [UIImage imageNamed:@"换乘-起"];
//    }else if (indexPath.row == self.route.steps.count-1){
//        bg.frame = CGRectMake(10, 0, 22, rowHeight/2);
//        iv.image = [UIImage imageNamed:@"换乘-终"];
//    }else if (step.stepType == BMK_WAKLING) {
//        bg.frame = CGRectMake(10, 0, 22, rowHeight);
//        iv.image = [UIImage imageNamed:@"换乘-步行"];
//    }else if(step.stepType == BMK_BUSLINE){
//        bg.frame = CGRectMake(10, 0, 22, rowHeight);
//        if (firstBusRow == 0) {
//            firstBusRow = indexPath.row;
//            iv.image = [UIImage imageNamed:@"换乘-上车"];
//        }else if(firstBusRow == indexPath.row){
//            iv.image = [UIImage imageNamed:@"换乘-上车"];
//        }else{
//            iv.image = [UIImage imageNamed:@"换乘-换成"];
//        }
//    }
    return nil;
}

@end
