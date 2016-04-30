//
//  JDORealTimeController.m
//  YTBus
//
//  Created by zhang yi on 14-10-21.
//  Copyright (c) 2014年 胶东在线. All rights reserved.
//

#import "JDORealTimeController.h"
//#import "BMapKit.h"
#import "JDOBusLineDetail.h"
#import "JDOStationModel.h"
#import "JDODatabase.h"
#import "JDORealTimeMapController.h"
#import "JDOConstants.h"
#import "JSONKit.h"
#import "JDOBusModel.h"
#import "CMPopTipView.h"
#import <ShareSDK/ShareSDK.h>
#import "JDOShareController.h"
#import "AppDelegate.h"
#import <QZoneConnection/ISSQZoneApp.h>
#import "JDOReportController.h"
#import "MBProgressHUD.h"
#import "JDOAlertTool.h"
#import "NSString+SSToolkitAdditions.h"
#import "UIViewController+MJPopupViewController.h"
#import "JDOStationMapController.h"
#import "JDOHttpClient.h"
#import "AESUtil.h"

#define GrayColor [UIColor colorWithRed:110/255.0f green:110/255.0f blue:110/255.0f alpha:1.0f]
#define PopViewColor [UIColor colorWithRed:210/255.0f green:250/255.0f blue:210/255.0f alpha:1.0f]
#define PopTextColor [UIColor colorWithHex:@"37aa32"]
#define LineHeight 32

@interface JDORealTimeCell : UITableViewCell

@property (nonatomic,assign) IBOutlet UIImageView *stationIcon;
@property (nonatomic,assign) IBOutlet UILabel *stationName;
@property (nonatomic,assign) IBOutlet UILabel *stationSeq;
@property (nonatomic,assign) IBOutlet UIButton *arrivingBus;
@property (nonatomic,assign) IBOutlet UIButton *arrivedBus;
@property (nonatomic,assign) IBOutlet UILabel *busNumLabel;
@property (nonatomic,assign) IBOutlet UIImageView *busNumBorder;

@property (nonatomic,assign) JDORealTimeController *controller;
@property (nonatomic,strong) CMPopTipView *popTipView;

@end

@implementation JDORealTimeCell

- (void)awakeFromNib{
    [super awakeFromNib];
    [self.stationSeq addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onStationClicked:)]];
    [self.stationName addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onStationClicked:)]];
}

- (IBAction)onBusClicked:(id)sender{
    [self.controller showBusMenu:self];
}

- (void)onStationClicked:(id)sender{
    [self.controller showStationMenu:self];
}

- (void)prepareForReuse{
    [super prepareForReuse];
}

@end

@interface JDOClockButton : UIButton

@property (nonatomic,strong) NSString *busNo;
@property (nonatomic,strong) NSString *stationId;

@end

@implementation JDOClockButton

@end

@interface JDOSetStartButton : UIButton

@property (nonatomic,assign) NSInteger row;
@property (nonatomic,weak) CMPopTipView *popView;

@end

@implementation JDOSetStartButton

@end

@interface JDOToMapButton : UIButton

@property (nonatomic,assign) NSInteger row;
@property (nonatomic,weak) CMPopTipView *popView;

@end

@implementation JDOToMapButton

@end

// 广告弹出

@interface JDOAdvController : UIViewController

@property (nonatomic,strong) UIImage *advImage;
@property (nonatomic,strong) NSString *advLinkUrl;
@property (nonatomic,weak) JDORealTimeController *parent;
@property (nonatomic,assign) MJPopupViewAnimation type;

@end

@implementation JDOAdvController

- (void) viewDidLoad{
    UIImageView *iv = [[UIImageView alloc] initWithImage:_advImage];
    float scale = 1.0f;
    while (_advImage.size.width/scale > 320-60 || _advImage.size.height/scale > App_Height-120) {
        scale += 0.2f;
    }
    iv.frame = CGRectMake(0, 0, _advImage.size.width/scale, _advImage.size.height/scale);
    iv.userInteractionEnabled = true;
    [iv addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gotoNavigator)]];
    self.view.frame = iv.frame;
    self.view.center = _parent.view.center;
    [self.view addSubview:iv];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(CGRectGetMaxX(iv.frame)-20, CGRectGetMinY(iv.frame)-16, 36, 36);
    [btn setImage:[UIImage imageNamed:@"广告-关闭"] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(closeAdvertise) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
}

- (void) gotoNavigator {
    if(_advLinkUrl && ([_advLinkUrl hasPrefix:@"http://"] || [_advLinkUrl hasPrefix:@"https://"]) ){
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:_advLinkUrl]];
        [self.parent dismissPopupViewControllerWithanimationType:self.type];
    }
}

- (void) closeAdvertise{
    [self.parent dismissPopupViewControllerWithanimationType:self.type];
}


@end

@interface JDORealTimeController () <NSXMLParserDelegate,CMPopTipViewDelegate> {
//    NSMutableArray *_stations;
    FMDatabase *_db;
    id dbObserver;
    NSMutableData *_webData;
    NSTimer *_timer;
    BOOL isLoadFinised;
    NSURLConnection *_connection;
    BOOL isRecording;
    NSMutableString *_jsonResult;
    NSMutableSet *_busIndexSet;
    JDOStationModel *selectedStartStation;
    UIImage *screenImage;
    JDORealTimeCell *_currentPopTipViewCell;
    NSIndexPath *_currentPopTipViewIndexPath;
    __strong JDOAlertTool *alert;
    BOOL advCanceled;
    NSString *advLinkUrl;
    BOOL notShowZhixianHint;
    
    NSString *_routeId;
    
}

@property (nonatomic,assign) IBOutlet UILabel *lineDetail;
@property (nonatomic,assign) IBOutlet UILabel *startTime;
@property (nonatomic,assign) IBOutlet UILabel *endTime;
@property (nonatomic,assign) IBOutlet UILabel *price;
@property (nonatomic,assign) IBOutlet UIButton *directionBtn;
@property (nonatomic,assign) IBOutlet UIButton *favorBtn;
@property (nonatomic,assign) IBOutlet UITableView *tableView;
@property (nonatomic,assign) IBOutlet UIView *topBackground;

@property (nonatomic,assign) IBOutlet UIImageView *refreshHint;
@property (nonatomic,assign) IBOutlet UIButton *refreshBtn;

@property (nonatomic,strong) NSMutableArray *realBusList;

@property (nonatomic,strong) NSDictionary *lineDetailsDict;
@property (nonatomic,strong) NSMutableArray *stations;
@property (nonatomic) BOOL isOneDirection;
@property (nonatomic) NSInteger direction;//0表示上行 1表示下行


- (IBAction)changeDirection:(id)sender;
- (IBAction)clickFavor:(id)sender;
- (IBAction)toggleMenu:(id)sender;
- (IBAction)clickReport:(id)sender;
- (IBAction)clickShare:(id)sender;

@end

@implementation JDORealTimeController{
    BOOL isMenuHidden;
    MBProgressHUD *hud;
    BOOL isFirstRefreshData;
    UIImage *advImage;
    UIView *advBackground;
    JDOAdvController *advController;
    BOOL isAnimatingRefresh;
}

-(void)dealloc{
    if (dbObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:dbObserver];
    }
}

#pragma mark - setter
- (void)setBusLine:(JDOBusLine *)busLine {
    _busLine = busLine;
    _routeId = busLine.lineId;
}

#pragma mark - life cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = _busLine.lineName;
    self.navigationItem.rightBarButtonItem.enabled = false;
    isLoadFinised = false;
    isMenuHidden = true;
    _isInit = true;
    
    _stations = [NSMutableArray new];
//    _db = [JDODatabase sharedDB];
//    if (_db) {
//        [self loadData];
//    }else{
//        dbObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"db_finished" object:nil queue:nil usingBlock:^(NSNotification *note) {
//            _db = [JDODatabase sharedDB];
//            [self loadData];
//            [self scrollToTargetStation:false];
//        }];
//    }
    
    self.tableView.sectionHeaderHeight = 15;
    self.tableView.sectionFooterHeight = 15;
    self.tableView.backgroundColor = [UIColor colorWithHex:@"dfded9"];
    
    // 最后一行考虑到选择站点时给弹窗留出空间，高度增加20
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 20)];
    self.tableView.tableFooterView.backgroundColor = [UIColor clearColor];
    
    _topBackground.backgroundColor=(_busLine.showingIndex==0?[UIColor colorWithHex:@"d2ebed"]:[UIColor colorWithHex:@"d2eddb"]);
    
    [self loadLineDetails];
}

- (void)viewWillAppear:(BOOL)animated{
    
    // 标志位用来保证只有创建后第一次显示时执行，防止从下级navigationController返回时也执行
#if 0
    if (_isInit) {
        // 滚动tableView的操作需要在这里执行，因为self.tableView的高度在viewDidLoad后会被改变，在viewDidLoad里滚动会有偏移
        [self scrollToTargetStation:false];
        _isInit = false;
        
        // 是否显示插屏广告的逻辑
        NSMutableDictionary *advTimer = [[[NSUserDefaults standardUserDefaults] objectForKey:@"JDO_Adv_Timer"] mutableCopy];
        if(!advTimer) {
            advTimer = [[NSMutableDictionary alloc] init];
        }
        NSString *key = [NSString stringWithFormat:@"%@-%d",_busLine.lineId,_busLine.attach];
        NSDate *lastShowTime = (NSDate *)[advTimer valueForKey:key];
        NSDate *now = [NSDate date];
        AppDelegate *delegate = [UIApplication sharedApplication].delegate;
        NSString *interval = delegate.systemParam[@"advInterval"]?:@"3600"; /*默认一小时*/
        if ([delegate.systemParam[@"closeLineAdv"] isEqualToString:@"1"]) { // 系统设置中关闭广告
            [self showRealTime];
        }else if([[NSUserDefaults standardUserDefaults] boolForKey:@"JDO_Ban_Adv"]){ // 通过密码操作关闭广告
            [self showRealTime];
        }else if(!lastShowTime || [now timeIntervalSinceDate:lastShowTime] > [interval intValue] ) {
            [advTimer setValue:now forKey:key];
            [[NSUserDefaults standardUserDefaults] setObject:advTimer forKey:@"JDO_Adv_Timer"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            // 处理广告显示和关闭
            [self asyncLoadAdvertise];
            [self performSelector:@selector(cancelAdvertise) withObject:nil afterDelay:2.5f];
        }else{
            [self showRealTime];
        }
    }else{
        [self showRealTime];
    }
    
#endif
}

- (void)viewWillDisappear:(BOOL)animated{
#if 0
    if ( _timer && [_timer isValid]) {
        [_timer invalidate];
        _timer = nil;
    }
    if (_connection) {
        [_connection cancel];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
#endif
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}



//- (void) toggleMenu:(UIButton *)sender {
////    if (isMenuHidden) {
////        UIGraphicsBeginImageContextWithOptions([UIScreen mainScreen].bounds.size, YES, 0);
////        AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
////        [appDelegate.window.rootViewController.view.layer renderInContext:UIGraphicsGetCurrentContext()];
////        screenImage = UIGraphicsGetImageFromCurrentImageContext();
////        UIGraphicsEndImageContext();
////    }
//    
//    [UIView animateWithDuration:0.25f delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
//        CGRect menuFrame = self.menu.frame;
//        menuFrame.origin.y = isMenuHidden?0:-69;
//        self.dropDownBtn.transform = isMenuHidden?CGAffineTransformMakeRotation(M_PI):CGAffineTransformMakeRotation(2*M_PI);
//        self.menu.frame = menuFrame;
//    } completion:^(BOOL finished) {
//        isMenuHidden = !isMenuHidden;
//        if (isMenuHidden) {
//            self.dropDownBtn.transform = CGAffineTransformIdentity;
//        }
//    }];
//}

//- (void)loadData{
//    [self loadBothDirectionLineDetailAndTargetStation];
//    [self loadCurrentLineInfoAndAllStations];
//    
//    self.navigationItem.rightBarButtonItem.enabled = true;
//    [self setFavorBtnState];
//}

//- (void)setFavorBtnState {  // 收藏标志
//    NSArray *favorLineIds = [[NSUserDefaults standardUserDefaults] arrayForKey:@"favor_line"];
//    if (favorLineIds) {
//        _favorBtn.selected = false;
//        JDOBusLineDetail *lineDetail = _busLine.lineDetailPair[_busLine.showingIndex];
//        for (int i=0; i<favorLineIds.count; i++) {
//            NSDictionary *dict = favorLineIds[i];
//            NSString *lineDetailId = dict[@"lineDetailId"];
//            NSNumber *attach = dict[@"attach"];
//            if([lineDetail.detailId isEqualToString:lineDetailId] && lineDetail.attach==[attach intValue]){
//                _favorBtn.selected = true;
//                break;
//            }
//        }
//    }
//}

//- (void)loadBothDirectionLineDetailAndTargetStation{
//    if(_busLine.lineDetailPair.count==2 ){
//        return;
//    }
//    
//    NSMutableArray *lineDetails = [NSMutableArray new];
//    FMResultSet *rs = [_db executeQuery:GetDetailIdByLineId,_busLine.lineId, @(_busLine.attach)];
//    while ([rs next]) {
//        JDOBusLineDetail *aLineDetail = [JDOBusLineDetail new];
//        aLineDetail.detailId = [rs stringForColumn:@"ID"];
//        aLineDetail.direction = [rs stringForColumn:@"DIRECTION"];
//        aLineDetail.attach = [rs intForColumn:@"ATTACH"];
//        [lineDetails addObject:aLineDetail];
//    }
//    [rs close];
//    if(lineDetails.count == 0){
//        NSLog(@"线路无详情数据");
//        return;
//    }
//    // 从线路进入时，没有lineDetail
//    if (!_busLine.lineDetailPair || _busLine.lineDetailPair.count ==0) {
//        _busLine.lineDetailPair = lineDetails;
//        _busLine.nearbyStationPair = [NSMutableArray arrayWithObjects:[NSNull null],[NSNull null],nil];
//    }else if(_busLine.lineDetailPair.count == 1){
//        // 从附近进入，且附近只有单向线路 或者从站点进入 或者从收藏进入
//        if ( lineDetails.count == 2) {  // 重新查询出双向线路
//            JDOBusLineDetail *d0 = _busLine.lineDetailPair[0];
//            JDOBusLineDetail *d1 = lineDetails[0];
//            JDOBusLineDetail *d2 = lineDetails[1];
//            JDOBusLineDetail *converseLine;
//            if ([d0.detailId isEqualToString:d1.detailId]) {
//                converseLine = d2;
//                _busLine.lineDetailPair = [NSMutableArray arrayWithObjects:d1,d2,nil];
//            }else{
//                converseLine = d1;
//                _busLine.lineDetailPair = [NSMutableArray arrayWithObjects:d2,d1,nil];
//            }
////            [_busLine.lineDetailPair addObject:converseLine];
//            
//            if (_busLine.nearbyStationPair && _busLine.nearbyStationPair.count >0) {
//                JDOStationModel *cStation = [self findStationByLine:converseLine andConverseStation:_busLine.nearbyStationPair[0]];
//                if (cStation) {
//                    [_busLine.nearbyStationPair addObject:cStation];
//                }else{
//                    [_busLine.nearbyStationPair addObject:[NSNull null]];
//                }
//            }else{
//                _busLine.nearbyStationPair = [NSMutableArray arrayWithObjects:[NSNull null],[NSNull null],nil];
//            }
//            
//        }
//    }else{
//        NSLog(@"线路超过两条!");
//    }
//}

//- (void) loadCurrentLineInfoAndAllStations{
//    isLoadFinised = false;
//    
//    // 选择显示方向线路详情
//    JDOBusLineDetail *lineDetail = _busLine.lineDetailPair[_busLine.showingIndex];
//    NSString *lineDetailId = lineDetail.detailId;
//    int attach = lineDetail.attach;
//    
//    FMResultSet *rs = [_db executeQuery:GetDetailById,lineDetailId,@(attach)];
//    if ([rs next]) {
//        _lineDetail.text = [rs stringForColumn:@"BUSLINENAME"];
//        //始末车时间
//        [self transformTimeFormat:_startTime value:[rs stringForColumn:@"FIRSTTIME"]];
//        [self transformTimeFormat:_endTime value:[rs stringForColumn:@"LASTTIME"]];
//        _price.text = [NSString stringWithFormat:@"%g元",[rs doubleForColumn:@"PRICE"]];
//    }
//    [rs close];
//    
//    // 加载该线路的所有站点信息
//    [_stations removeAllObjects];
//    rs = [_db executeQuery:GetStationsByLineDetail,lineDetailId,@(attach)];
//    while ([rs next]) {
//        JDOStationModel *station = [JDOStationModel new];
//        station.fid = [rs stringForColumn:@"STATIONID"];
//        station.name = [rs stringForColumn:@"STATIONNAME"];
//        station.direction = [rs stringForColumn:@"DIRECTION"];
//        station.gpsX = [NSNumber numberWithDouble:[rs doubleForColumn:@"GPSX"]];
//        station.gpsY = [NSNumber numberWithDouble:[rs doubleForColumn:@"GPSY"]];
//        station.attach = attach;
//        [_stations addObject:station];
//    }
//    
//    [_busIndexSet removeAllObjects];
//    [_tableView reloadData];
//    
//    isLoadFinised = true;
//}

// 转换始末车时间的格式
//- (void) transformTimeFormat:(UILabel *)timeLbl value:(NSString *)timeString{
//    @try {
//        timeLbl.text = @"--:--";
//        timeString = [timeString stringByReplacingOccurrencesOfString:@";" withString:@":"];
//        timeString = [timeString stringByReplacingOccurrencesOfString:@"：" withString:@":"];
//        timeString = [timeString stringByReplacingOccurrencesOfString:@"." withString:@":"];
//        NSArray *timePair = [timeString componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@", \n"]];
//        if (timePair.count == 1) {
//            NSArray *timeHour = [timePair[0] componentsSeparatedByString:@":"];
//            if (timeHour.count == 2 && ![timeHour[0] isEqualToString:@"0"]) {
//                timeLbl.text = timePair[0];
//            }
//        }else{
//            NSDate *today = [NSDate date];
//            NSCalendar *currentCalendar = [NSCalendar currentCalendar];
//#ifdef __IPHONE_8_0
//            uint flags = NSCalendarUnitMonth;
//#else
//            uint flags = NSMonthCalendarUnit;
//#endif
//            NSDateComponents *components = [currentCalendar components:flags fromDate:today];
//            if(components.month>=5 && components.month<11){ // 夏季
//                for (int i=0; i<timePair.count; i++) {
//                    if ([timePair[i] hasPrefix:@"夏季"]) {
//                        NSString *str = [timePair[i] substringFromIndex:2];
//                        if ([str hasPrefix:@":"]) {
//                            str = [str substringFromIndex:1];
//                        }
//                        if (str.length>0) {
//                            timeLbl.text = str;
//                        }
//                        break;
//                    }    
//                }
//            }else{
//                for (int i=0; i<timePair.count; i++) {
//                    if ([timePair[i] hasPrefix:@"冬季"]) {
//                        NSString *str = [timePair[i] substringFromIndex:2];
//                        if ([str hasPrefix:@":"]) {
//                            str = [str substringFromIndex:1];
//                        }
//                        if (str.length>0) {
//                            timeLbl.text = str;
//                        }
//                        break;
//                    }
//                }
//            }
//        }
//    }
//    @catch (NSException *exception) {
//
//    }
//    
//}

//- (JDOStationModel *) findStationByLine:(JDOBusLineDetail *)lineDetail andConverseStation:(JDOStationModel *)station{
//    FMResultSet *rs = [_db executeQuery:GetConverseStation,station.name,lineDetail.detailId,@(lineDetail.attach)];
//    if ([rs next]) {
//        JDOStationModel *station = [JDOStationModel new];
//        station.fid = [rs stringForColumn:@"STATIONID"];
//        station.name = [rs stringForColumn:@"STATIONNAME"];
//        station.direction = [rs stringForColumn:@"DIRECTION"];
//        station.gpsX = [NSNumber numberWithDouble:[rs doubleForColumn:@"GPSX"]];
//        station.gpsY = [NSNumber numberWithDouble:[rs doubleForColumn:@"GPSY"]];
//        station.attach = [rs intForColumn:@"ATTACH"];
//        return station;
//    }
//    [rs close];
//    return nil;
//}



//- (void) addAdvBg{
//    advBackground = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, App_Height)];
//    advBackground.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
//    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
//    [indicator startAnimating];
//    indicator.center = advBackground.center;
//    [advBackground addSubview:indicator];
//    [[[UIApplication sharedApplication].delegate window] addSubview:advBackground];
//}

//- (void) asyncLoadAdvertise{   // 异步加载广告页
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        NSString *userid = [JDOUtils getUUID];
//        
//        NSMutableDictionary *advCounter = [[[NSUserDefaults standardUserDefaults] objectForKey:@"JDO_Adv_Counter"] mutableCopy];
//        if(!advCounter) {
//            advCounter = [[NSMutableDictionary alloc] init];
//        }
//        NSString *key = [NSString stringWithFormat:@"%@-%d",_busLine.lineId,_busLine.attach];
//        NSNumber *index = (NSNumber *)[advCounter valueForKey:key];
//        if (!index) {
//            index = @(0);
//        }else{
//            index = @((index.intValue+1)%3);
//        }
//        [advCounter setValue:index forKey:key];
//        [[NSUserDefaults standardUserDefaults] setObject:advCounter forKey:@"JDO_Adv_Counter"];
//        [[NSUserDefaults standardUserDefaults] synchronize];
//        
//        NSString *advUrl = [JDO_Bus_Server stringByAppendingString:[NSString stringWithFormat:@"/index/getXlAdv?busid=%@&attach=%d&index=%@&userid=%@",_busLine.lineId,_busLine.attach,index,userid] ];
//        NSError *error ;
//        NSData *jsonData = [NSData dataWithContentsOfURL:[NSURL URLWithString:advUrl] options:NSDataReadingUncached error:&error];
//        if(error){
//            NSLog(@"获取广告页json出错:%@",error);
//            return;
//        }
//        if (advCanceled) {
//            return;
//        }
//        NSDictionary *jsonObject = [jsonData objectFromJSONData];
//        if ([jsonObject[@"status"] isEqualToString:@"nodata"]) {
//            dispatch_async(dispatch_get_main_queue(), ^{    // 取消2秒的等待，立刻关闭广告
//                if (!advCanceled) {
//                    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(cancelAdvertise) object:nil];
//                    [self cancelAdvertise];
//                }
//            });
//            return;
//        }
//        NSDictionary *data = [jsonObject objectForKey:@"data"];
//        NSString *advImgUrl = [data valueForKey:@"picUrl"];
//        id linkUrl = [data valueForKey:@"url"];
//        if ([linkUrl isKindOfClass:[NSString class]] && ![linkUrl isEqualToString:@""]) {
//            advLinkUrl = linkUrl;
//        }else{
//            advLinkUrl = nil;
//        }
//        NSString *sha1Url= [advImgUrl SHA1Sum];
//        NSString *cacheFilePath = [[JDOUtils getJDOCacheDirectory] stringByAppendingPathComponent:sha1Url];
//        NSData *imgData = [[NSFileManager defaultManager] contentsAtPath:cacheFilePath];
//        if(imgData){    // 先查本地缓存
//            if(!advImage) {
//                advImage = [UIImage imageWithData:imgData];
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    if (!advCanceled) {
//                        [self showAdvertiseImage];
//                    }
//                });
//            }
//        }else{
//            NSData *imgData = [NSData dataWithContentsOfURL:[NSURL URLWithString:advImgUrl] options:NSDataReadingUncached error:&error];
//            if(error){
//                NSLog(@"获取广告页图片出错:%@",error);
//                return;
//            }
//            if(!advImage) {
//                advImage = [UIImage imageWithData:imgData];
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    if (!advCanceled) {
//                        [self showAdvertiseImage];
//                    }
//                });
//            }
//            // 图片缓存到磁盘
//            [imgData writeToFile:cacheFilePath options:NSDataWritingAtomic error:&error];
//            if(error){
//                NSLog(@"磁盘缓存广告页图片出错:%@",error);
//                return;
//            }
//        }
//    });
//}

//- (void) showAdvertiseImage {
//    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(cancelAdvertise) object:nil];
//    
//    advController = [[JDOAdvController alloc] init];
//    advController.advImage = advImage;
//    advController.advLinkUrl = advLinkUrl;
//    advController.parent = self;
//    switch (arc4random()%9) {
//        case 0: advController.type = MJPopupViewAnimationFade;   break;
//        case 1: advController.type = MJPopupViewAnimationSlideBottomTop;   break;
//        case 2: advController.type = MJPopupViewAnimationSlideBottomBottom;   break;
//        case 3: advController.type = MJPopupViewAnimationSlideTopTop;   break;
//        case 4: advController.type = MJPopupViewAnimationSlideTopBottom;   break;
//        case 5: advController.type = MJPopupViewAnimationSlideLeftLeft;   break;
//        case 6: advController.type = MJPopupViewAnimationSlideLeftRight;   break;
//        case 7: advController.type = MJPopupViewAnimationSlideRightLeft;   break;
//        case 8: advController.type = MJPopupViewAnimationSlideRightRight;   break;
//        default: break;
//    }
//    [self presentPopupViewController:advController animationType:advController.type dismissed:^{
//        [self showRealTime];
//    }];
//}
//
//- (void) cancelAdvertise{
//    advCanceled = true;
//    [self showRealTime];
//}

//- (void) showRealTime {
//    if (_busLine.zhixian >= 1 /*&& !notShowZhixianHint*/) {
////        notShowZhixianHint = true;
////        NSString *key = [NSString stringWithFormat:@"JDO_IgnoreDispatchHint_%@",_busLine.lineId];
//        BOOL isZhuxian = (_busLine.zhixian==1);
////        BOOL exist = [[NSUserDefaults standardUserDefaults] boolForKey:key];
////        if (!exist) {
////            alert = [[JDOAlertTool alloc] init];
////            NSString *msg = isZhuxian?@"本线路为主线，但线路中显示的实时车辆有可能属于支线线路，请您上车前确认。":@"本线路为支线，车辆实时数据并入主线路显示，若需查看请您切换至对应主线路。";
////            [alert showAlertView:self title:@"温馨提醒" message:msg cancelTitle:@"不再提醒" otherTitle1:@"关闭" otherTitle2:nil cancelAction:^{
////                [[NSUserDefaults standardUserDefaults] setBool:true forKey:key];
////                if (isZhuxian) {    // 支线既然无数据，就不要提示选择上车站点了
////                    [self loadRealTimeData];
////                }
////            } otherAction1:^{
////                if (isZhuxian) {
////                    [self loadRealTimeData];
////                }
////            } otherAction2:nil];
////        }else{
//            if (isZhuxian) {
//                [self loadRealTimeData];
//            }
////        }
//    }else{
//        [self loadRealTimeData];
//    }
//}

//- (void) loadRealTimeData {
//    [self resetTimer];
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetTimer) name:UIApplicationDidBecomeActiveNotification object:nil];
//}

#pragma mark - action

- (IBAction)userRefresh:(id)sender{
//    if (_timer && [_timer isValid]) {
//        [_timer fire];
//    }
//    [self animatingRefresh];
}

//- (void) animatingRefresh{
//    if (isAnimatingRefresh) {
//        return;
//    }
//    isAnimatingRefresh = true;
//    self.refreshBtn.enabled = false;
//    self.refreshHint.hidden = false;
//    CGRect originFrame = self.refreshHint.frame;
//    CGRect endFrame = CGRectMake(200, originFrame.origin.y, 87, originFrame.size.height);
//    [UIView animateWithDuration:1.0f animations:^{
//        self.refreshBtn.transform = CGAffineTransformMakeRotation(M_PI);
//        self.refreshHint.frame = endFrame;
//    } completion:^(BOOL finished) {
//        [UIView animateWithDuration:1.0f delay:0.5f options:0 animations:^{
//            self.refreshBtn.transform = CGAffineTransformMakeRotation(M_PI*2);
//            self.refreshHint.frame = originFrame;
//        } completion:^(BOOL finished) {
//            self.refreshBtn.transform = CGAffineTransformIdentity;
//            self.refreshBtn.enabled = true;
//            self.refreshHint.hidden = true;
//            isAnimatingRefresh = false;
//        }];
//    }];
//}

//- (void) resetTimer {
//    long interval = [[NSUserDefaults standardUserDefaults] integerForKey:@"refresh_interval"]?:10;
//    if (_timer && [_timer isValid]) {
//        [_timer invalidate];
//    }
//    isFirstRefreshData = true;
//    _timer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(refreshData:) userInfo:nil repeats:true];
//    [_timer fire];
//    
//}


//- (void) refreshData:(NSTimer *)timer{
//    // 若开启到站提醒，也可以在后台运行时继续执行定时器，一直到程序进程超时被关闭时再请求后台推送
//    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
//        return;
//    }
//    // 双向站点列表未加载完成,延迟1秒再刷新
//    if( !isLoadFinised ){
//        timer.fireDate = [NSDate dateWithTimeInterval:1 sinceDate:[NSDate date]];
//        return;
//    }
//    
//    if (!_busLine.lineDetailPair || _busLine.lineDetailPair.count==0) {
//        NSLog(@"线路详情不存在");
//        return;
//    }
//    if (!_busLine.nearbyStationPair || _busLine.nearbyStationPair.count==0 ) {
//        NSLog(@"站点信息不存在");
//        return;
//    }
//    
//    JDOStationModel *startStation;
//    if(selectedStartStation){
//        startStation = selectedStartStation;
//    }else if (_busLine.nearbyStationPair[_busLine.showingIndex] == [NSNull null]) {
//        // 没有附近站点的时候，以线路终点站作为实时数据获取的参照物
////        startStation = [_stations lastObject];
//        // 没有附近站点的时候，不显示实时数据
//        [JDOUtils showHUDText:@"请选择上车站点" inView:self.view];
//        [_timer invalidate];
//        _timer= nil;
//        return;
//    }else{
//        startStation = _busLine.nearbyStationPair[_busLine.showingIndex];
//    }
//    
//    if (isFirstRefreshData && !hud) {
//        hud = [MBProgressHUD showHUDAddedTo:self.view animated:true];
//        hud.mode = MBProgressHUDModeIndeterminate;
//        hud.minShowTime = 1.0f;
//        hud.labelText = @"获取车辆实时位置";
//        isFirstRefreshData = false;
//    }else if(!isFirstRefreshData){
//        // 根据用户反馈的意见，静默刷新会让很多人误解为没有刷新，所以自动刷新的时候还是做一个提示比较好
//        [self animatingRefresh];
//    }
//    
//    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
//    if (delegate.encryptKey) {
//        [self sendRealtimeDataRequest:delegate.encryptKey stationId:startStation.fid];
//    }else{
//        [self requestRandomKey:startStation.fid];
//    }
//}


// 请求实时数据之前先从服务器获取一个动态变化的随机数，并对该随机数进行对称加密算法，将生成的数字挂在请求后面以让服务器进行验证
//- (void) requestRandomKey:(NSString *)stationId{
//    NSLog(@"秘钥过期，重新获取");
//    [[JDOHttpClient sharedDFEClient2] getPath:@"BusPosition.asmx/get_random" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
//        NSString *xml = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
//        BOOL error = false;
//        NSString *errorInfo;
//        if(xml){
//            NSRange startRange = [xml rangeOfString:@"<string xmlns=\"http://www.dongfang-china.com/\">"];
//            NSRange endRange = [xml rangeOfString:@"</string>"];
//            if (startRange.location != NSNotFound && endRange.location != NSNotFound) {
//                NSUInteger location = startRange.location+startRange.length;
//                NSRange subRange = NSMakeRange(location, endRange.location-location);
//                try {
//                    NSString *random = [xml substringWithRange:subRange];
//                    NSString *encrypt = [AESUtil AES128Encrypt:random];
//                    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
//                    delegate.encryptKey = encrypt;
//                    [self sendRealtimeDataRequest:encrypt stationId:stationId];
//                } catch (NSException *exception) {
//                    error = true;
//                    if ([exception.name isEqualToString:NSRangeException]) {
//                        errorInfo = @"无法解析秘钥";
//                    }else{
//                        errorInfo = @"解析秘钥出错";
//                    }
//                }
//            }else{
//                error = true;
//                errorInfo = @"秘钥格式错误";
//            }
//        }else{
//            error = true;
//            errorInfo = @"无法获取秘钥";
//        }
//        if (error) {
//            if (hud) {
//                hud.mode = MBProgressHUDModeText;
//                hud.labelText = errorInfo;
//                [hud hide:true afterDelay:1.0f];
//                hud = nil;
//            }else{
//                [JDOUtils showHUDText:errorInfo inView:self.view];
//            }
//        }
//    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
//        if (hud) {
//            hud.mode = MBProgressHUDModeText;
//            hud.labelText = @"无法获取秘钥";
//            hud.detailsLabelText = error.localizedDescription;
//            [hud hide:true afterDelay:2.0f];
//            hud = nil;
//        }else{
//            [JDOUtils showHUDText:@"无法获取秘钥" detailText:error.localizedDescription inView:self.view afterDelay:2.0f];
//        }
//    }];
//}

//- (void) sendRealtimeDataRequest:(NSString *)encrypt stationId:(NSString *)stationId{
//    NSString *busLineId = _busLine.lineId;
//    JDOBusLineDetail *lineDetail = _busLine.lineDetailPair[_busLine.showingIndex];
//    NSString *lineStatus = [lineDetail.direction isEqualToString:@"下行"]?@"1":@"2";
//    int attach = lineDetail.attach;
//    
//    NSString *soapMessage = [NSString stringWithFormat:GetBusLineStatus_SOAP_MSG_Encrypt,stationId,busLineId,lineStatus,attach,encrypt,@"JIAODONG",[JDOUtils getUUID]];
//    // 从系统参数获取端口号，若未加载系统参数的话，使用默认端口
//    AppDelegate *appDelegate = [UIApplication sharedApplication].delegate;
//    NSString *port = appDelegate.systemParam[@"realtimePort"]?:Default_Realtime_Port;
//    NSString *url = [NSString stringWithFormat:GetBusLineStatus_SOAP_URL,port];
//    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:URL_Request_Timeout];
//    [request addValue:@"text/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
//    [request addValue:[NSString stringWithFormat:@"%lu",(unsigned long)[soapMessage length]] forHTTPHeaderField:@"Content-Length"];
//    [request addValue:@"http://www.dongfang-china.com/GetBusLineStatusEncry" forHTTPHeaderField:@"SOAPAction"];
//    [request setHTTPMethod:@"POST"];
//    [request setHTTPBody:[soapMessage dataUsingEncoding:NSUTF8StringEncoding]];
//    
//    if (_connection) {
//        [_connection cancel];
//    }
//    _connection = [NSURLConnection connectionWithRequest:request delegate:self];
//    _webData = [NSMutableData data];
//}

//-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
//    [_webData appendData:data];
//}

//-(void)connectionDidFinishLoading:(NSURLConnection *)connection{
////    NSString *XML = [[NSString alloc] initWithBytes:[_webData mutableBytes] length:[_webData length] encoding:NSUTF8StringEncoding];
////    NSLog(@"%@",XML);
//    NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData: _webData];
//    [xmlParser setDelegate: self];
//    [xmlParser parse];
//}

//- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
//    if (hud) {
//        hud.mode = MBProgressHUDModeText;
//        hud.labelText = [NSString stringWithFormat:@"连接服务器异常:%ld",(long)error.code];
//        [hud hide:true afterDelay:1.0f];
//        hud = nil;
//    }else{
//        [JDOUtils showHUDText:[NSString stringWithFormat:@"连接服务器异常:%ld",(long)error.code] inView:self.view];
//        NSLog(@"error:%@",error);
//    }
//}

//- (void)parserDidStartDocument:(NSXMLParser *)parser{
//    _jsonResult = nil;
//}

//- (void)parserDidEndDocument:(NSXMLParser *)parser{
//    if (_jsonResult == nil) {    // 说明XML中没有GetBusLineStatusExResult节点，即格式错误
//        if (hud) {
//            hud.mode = MBProgressHUDModeText;
//            hud.labelText = @"服务器内部错误";
//            hud.detailsLabelText = @"";
//            [hud hide:true afterDelay:1.0f];
//            hud = nil;
//        }else{
//            [JDOUtils showHUDText:@"服务器内部错误" inView:self.view];
//        }
//    }
//}

//-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *) namespaceURI qualifiedName:(NSString *)qName attributes: (NSDictionary *)attributeDict{
//    if( [elementName isEqualToString:@"GetBusLineStatusEncryResult"]){
//        _jsonResult = [[NSMutableString alloc] init];
//        isRecording = true;
//    }
//}

//-(void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string{
//    if( isRecording ){
//        [_jsonResult appendString: string];
//    }
//}

//TODO 错误的情况应该处理一下
/* <?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><soap:Fault><faultcode>soap:Server</faultcode><faultstring>服务器无法处理请求。 ---&gt; 未将对象引用设置到对象的实例。</faultstring><detail /></soap:Fault></soap:Body></soap:Envelope>
 */

//-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName{
//    if( [elementName isEqualToString:@"GetBusLineStatusEncryResult"]){
////        NSLog(@"%@",_jsonResult);
//        isRecording = false;
//        // TODO 确定提示信息是否能区分开
//        if (_jsonResult.length == 0) {    // 秘钥失效，重新获取
//            AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
//            delegate.encryptKey = nil;
//            JDOStationModel *startStation;
//            if(selectedStartStation){
//                startStation = selectedStartStation;
//            }else{
//                startStation = _busLine.nearbyStationPair[_busLine.showingIndex];
//            }
////            [self requestRandomKey:startStation.fid];
//        }else if ([_jsonResult isEqualToString:@"[]"]) {
//            NSString *info = @"没有下一班次数据";
//            if (hud) {
//                hud.mode = MBProgressHUDModeText;
//                hud.labelText = info;
//                [hud hide:true afterDelay:1.0f];
//                hud = nil;
//            }else{
//                [JDOUtils showHUDText:info inView:self.view];
//            }
//            // 删除掉已经绘制的所有车辆，可能发生的情景是：最后一辆车开过参考站点，则要删除该车辆
//            if (_busIndexSet.count>0) {
//                [_busIndexSet removeAllObjects];
//                [self.tableView reloadData];
//            }
//        }else{
//            _realBusList = [_jsonResult objectFromJSONString];
//            if (!_realBusList) {
//                if (hud) {
//                    hud.mode = MBProgressHUDModeText;
//                    hud.labelText = @"实时数据格式错误";
//                    [hud hide:true afterDelay:1.0f];
//                    hud = nil;
//                }else{
//                    [JDOUtils showHUDText:@"实时数据格式错误" inView:self.view];
//                }
//            }else{
//                if (hud) {
//                    [hud hide:true];
//                    hud = nil;
//                }
//                [self redrawBus];
//            }
//        }
//    }
//}

//- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError{
//    if (hud) {
//        hud.mode = MBProgressHUDModeText;
//        hud.labelText = [NSString stringWithFormat:@"解析XML错误:%ld",(long)parseError.code];
//        [hud hide:true afterDelay:1.0f];
//        hud = nil;
//    }else{
//        [JDOUtils showHUDText:[NSString stringWithFormat:@"解析XML错误:%ld",(long)parseError.code] inView:self.view];
//        NSLog(@"Error:%@",parseError);
//    }
//    
//}

//- (void) redrawBus{
//    NSMutableSet *oldIndexSet;
//    if (!_busIndexSet) {
//        _busIndexSet = [NSMutableSet new];
//    }else{
//        oldIndexSet = [NSMutableSet setWithSet:_busIndexSet];
//        [_busIndexSet removeAllObjects];
//    }
//    
//    for (int i=0; i<_realBusList.count; i++){
//        NSDictionary *dict = _realBusList[i];
//        JDOBusModel *bus = [[JDOBusModel alloc] initWithDictionary:dict];
//        int stationIndex = -1;
//        int errorType = 0;
//        for (int j=0; j<_stations.count; j++) {
//            JDOStationModel *aStation = _stations[j];
//            if ([aStation.fid isEqualToString:bus.toStationId]) {
//                stationIndex = j;
//                // 实时数据返回的车辆停靠站点id在该线路上，但车辆的gps位置离此站点距离相差太大，也认为是错误数据提交后台
//                if ([aStation.gpsY doubleValue]==0 || [aStation.gpsX doubleValue]==0) {
//                    break;
//                }
////                CLLocationCoordinate2D stationCoor = CLLocationCoordinate2DMake([aStation.gpsY doubleValue], [aStation.gpsX doubleValue]);
////                CLLocationCoordinate2D busCoor = CLLocationCoordinate2DMake([bus.gpsY doubleValue], [bus.gpsX doubleValue]);
////                CLLocationDistance distance = BMKMetersBetweenMapPoints(BMKMapPointForCoordinate(stationCoor),BMKMapPointForCoordinate(busCoor));
//////                NSLog(@"车辆离站点距离:%g",distance);
////                if (distance > 3000) {
////                    errorType = 2;
////                }
//                break;
//            }
//        }
//        if (stationIndex >=0) {
//            [_busIndexSet addObject:[NSIndexPath indexPathForRow:stationIndex inSection:0]];
//            // 实时数据返回的车辆停靠站点id在用户选择的上车站点id之后，这种一般也是数据错误
//            JDOStationModel *startStation = [self getStartStation];
//            int startStationIndex = 0;
//            for (int i=0; i<_stations.count; i++) {
//                JDOStationModel *aStation = _stations[i];
//                if ([aStation.fid isEqualToString:startStation.fid]) {
//                    startStationIndex = i;
//                    break;
//                }
//            }
//            if (stationIndex > startStationIndex) {
//                errorType = 3;
//            }
//        }else{  // 实时数据返回的车辆停靠站点id不在该条线路上，这种情况自动向后台提交错误数据，用以收集后排错
//            errorType = 1;
//        }
//        if (errorType != 0) {
//            JDOStationModel *startStation = [self getStartStation];
//            NSString *stationId = startStation.fid;
//            NSString *busLineId = _busLine.lineId;
//            JDOBusLineDetail *lineDetail = _busLine.lineDetailPair[_busLine.showingIndex];
//            NSString *lineStatus = [lineDetail.direction isEqualToString:@"下行"]?@"1":@"2";
//            int attach = lineDetail.attach;
//            NSDictionary *param = @{@"lineid":busLineId,@"attach":@(attach),@"direction":lineStatus,@"busnumber":bus.busNo,@"stationid":bus.toStationId,@"thisstationid":stationId,@"errtype":@(errorType),@"gpsx":bus.gpsX,@"gpsy":bus.gpsY};
//            [[JDOHttpClient sharedBUSClient] getPath:@"index/busError" parameters:param success:^(AFHTTPRequestOperation *operation, id responseObject) {
//                NSData *jsonData = responseObject;
//                NSDictionary *obj = [jsonData objectFromJSONData];
//                if (![obj[@"status"] isEqualToString:@"success"]) {
//                    NSLog(@"提交实时数据错误信息失败:%@",obj[@"info"]);
//                }
//            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
//                NSLog(@"提交实时数据错误信息失败:%@",error);
//            }];
//        }
//    }
//    
//    if (!oldIndexSet) {
//        [self.tableView reloadData];
//    }else{  // 对比可视范围内索引有变化才刷新
//        NSMutableSet *toKeep = [NSMutableSet setWithSet:oldIndexSet];
//        [toKeep intersectSet:_busIndexSet];
//        NSMutableSet *toAdd = [NSMutableSet setWithSet:_busIndexSet];
//        [toAdd minusSet:toKeep];
//        NSMutableSet *toRemove = [NSMutableSet setWithSet:oldIndexSet];
//        [toRemove minusSet:_busIndexSet];
//        NSMutableSet *toRefresh = [NSMutableSet set];
//        
//        NSArray *visibleCells = [self.tableView visibleCells];
//        for (int i=0; i<visibleCells.count; i++) {
//            JDORealTimeCell *cell = visibleCells[i];
//            NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
//            if ([toAdd containsObject:indexPath] || [toRemove containsObject:indexPath] || [toKeep containsObject:indexPath]) {
//                // toKeep也要刷新，因为有可能车辆从1辆变成2辆
//                [toRefresh addObject:indexPath];
//            }
////            cell有可能在上一次刷新的时候在同一个indexPath被替换过，所有目前indexPath位置上的cell不一定是弹出popView的cell
//            if ([toRemove containsObject:indexPath] && _currentPopTipViewIndexPath == indexPath) {
//                [_currentPopTipViewCell.popTipView dismissAnimated:true];
//                _currentPopTipViewCell.popTipView = nil;
//                _currentPopTipViewCell = nil;
//            }
//        }
//        [self.tableView reloadRowsAtIndexPaths:[toRefresh allObjects]  withRowAnimation:UITableViewRowAnimationNone];
//    }
//    
//}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"toRealtimeMap"]) {
        JDORealTimeMapController *rt = segue.destinationViewController;
        rt.stations = _stations;
        JDOStationModel *startStation;
        if(selectedStartStation){
            startStation = selectedStartStation;
        }else if(_busLine.nearbyStationPair.count>0 && _busLine.nearbyStationPair[_busLine.showingIndex]!=[NSNull null]) {
            startStation = _busLine.nearbyStationPair[_busLine.showingIndex];
        }else{
            return;
        }
        startStation.start = true;
        
        rt.stationId = startStation.fid;
        rt.lineId = _busLine.lineId;
        JDOBusLineDetail *lineDetail = _busLine.lineDetailPair[_busLine.showingIndex];
        rt.lineStatus = [lineDetail.direction isEqualToString:@"下行"]?@"1":@"2";
        rt.attach = lineDetail.attach;
        
        // 将当前车辆实时位置数据传递到地图中，避免地图界面第一次获取数据时间较长时没有车辆信息
        if (_realBusList && _realBusList.count>0) {
            rt.realBusList = [NSMutableArray arrayWithArray:_realBusList];
        }
    }else if([segue.identifier isEqualToString:@"showStationDetail"]){
        JDOStationMapController *vc = (JDOStationMapController *)segue.destinationViewController;
        vc.selectedStation = (JDOStationModel *)sender;
    }
}

- (IBAction)changeDirection:(id)sender{
    if (self.isOneDirection) {
        [JDOUtils showHUDText:@"该条线路为单向线路" inView:self.view];
        return;
    }
#if 0
    _busLine.showingIndex = (_busLine.showingIndex==0?1:0);
    _topBackground.backgroundColor=(_busLine.showingIndex==0?[UIColor colorWithHex:@"d2ebed"]:[UIColor colorWithHex:@"d2eddb"]);
//    [self loadCurrentLineInfoAndAllStations];
//    [self setFavorBtnState];
    
    // 若换向前有手动选中的站点，则换向后查找同名站点并选中
    if (selectedStartStation){
        JDOStationModel *converseStation;
        for(int i=0; i<_stations.count; i++){
            JDOStationModel *aStation = _stations[i];
            if([aStation.name isEqualToString:selectedStartStation.name]){
                converseStation = aStation;
                break;
            }
        }
        if(converseStation){
            selectedStartStation = converseStation;
        }
    }
    
#endif
//    [self scrollToTargetStation:true];
//    [self resetTimer];
    if (self.direction == 1) {
        self.stations = [NSMutableArray arrayWithArray:[[self.lineDetailsDict[@"stationsCome"] reverseObjectEnumerator] allObjects]];
    } else {
        self.stations = [NSMutableArray arrayWithArray:self.lineDetailsDict[@"stationsGo"]];
    }
    
    [self.tableView reloadData];
    self.direction = self.direction == 0 ? 1 : 0;
}

//- (void) scrollToTargetStation:(BOOL) animated{
//    JDOStationModel *station;
//    if (selectedStartStation){
//        station = selectedStartStation;
//    }else if (_busLine.nearbyStationPair[_busLine.showingIndex] == [NSNull null]) {
////        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_stations.count-1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:animated];
//    }else{
//        station = _busLine.nearbyStationPair[_busLine.showingIndex];
//    }
//    
//    if(station){
//        NSUInteger index = [_stations indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
//            if ([((JDOStationModel *)obj).fid isEqualToString:station.fid]) {
//                return true;
//            }
//            return false;
//        }];
//        if (index != NSNotFound) {
//            [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:animated];
//        }
//    }
//}

- (IBAction)clickFavor:(UIButton *)sender{
    NSMutableArray *favorLineIds = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"favor_line"] mutableCopy];
    if(!favorLineIds){
        favorLineIds = [NSMutableArray new];
    }
    JDOBusLineDetail *lineDetail = _busLine.lineDetailPair[_busLine.showingIndex];
    sender.selected = !sender.selected;
    if (sender.selected) {
//        JDOStationModel *startStation = [self getStartStation];
        JDOStationModel *startStation = nil;
        if (!startStation) {
            [favorLineIds addObject:@{@"lineDetailId":lineDetail.detailId,@"attach":@(lineDetail.attach)}];
        }else{
            [favorLineIds addObject:@{@"lineDetailId":lineDetail.detailId,@"attach":@(lineDetail.attach),@"startStationId":startStation.fid}];
        }
    }else{
        for (int i=0; i<favorLineIds.count; i++) {
            NSDictionary *dict = favorLineIds[i];
            NSString *lineDetailId = dict[@"lineDetailId"];
            NSNumber *attach = dict[@"attach"];
            if ([lineDetailId isEqualToString:lineDetail.detailId] && lineDetail.attach==[attach intValue]) {
                [favorLineIds removeObject:dict];
            }
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:favorLineIds forKey:@"favor_line"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"favor_line_changed" object:nil];
}

//- (JDOStationModel *) getStartStation{
//    if(selectedStartStation){
//        return selectedStartStation;
//    }else if(_busLine.nearbyStationPair.count>0 && _busLine.nearbyStationPair[_busLine.showingIndex]!=[NSNull null]) {
//        return _busLine.nearbyStationPair[_busLine.showingIndex];
//    }
//    return nil;
//}

- (IBAction)clickReport:(id)sender{
//    JDOStationModel *startStation = [self getStartStation];
    JDOStationModel *startStation = nil;
    NSString *direction = [NSString stringWithFormat:@"%@ 开往 %@ 方向",self.busLine.lineName,[[_stations lastObject] name]];
    
    JDOBusLineDetail *lineDetail = _busLine.lineDetailPair[_busLine.showingIndex];
    NSString *lineStatus = [lineDetail.direction isEqualToString:@"下行"]?@"1":@"2";
    
    JDOReportController *vc = [[JDOReportController alloc] initWithStation:startStation.name direction:direction stationId:startStation.fid lineId:self.busLine.lineId lineDirection:lineStatus];
    UINavigationController *naVC = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:naVC animated:true completion:nil];
}

- (IBAction)clickShare:(id)sender{
    NSString *content;
//    JDOStationModel *startStation = [self getStartStation];
    JDOStationModel *startStation = nil;
    if (startStation) {
        NSMutableArray *stationIds = [NSMutableArray new];
        for (int i=0; i<_stations.count; i++) {
            [stationIds addObject:[_stations[i] fid]];
        }
        NSUInteger maxIndex = 0;
        for (int i=0; i<_realBusList.count; i++){
            NSDictionary *dict = _realBusList[i];
            JDOBusModel *bus = [[JDOBusModel alloc] initWithDictionary:dict];
            NSUInteger index = [stationIds indexOfObject:bus.toStationId];
            if (index != NSNotFound && index > maxIndex) {
                maxIndex = index;
            }
        }
        if (maxIndex>0) {
            NSUInteger startIndex = [stationIds indexOfObject:startStation.fid];
            content = [NSString stringWithFormat:@"实时:%@公交开往\"%@\"方向，距离\"%@\"还有%lu站。",self.busLine.lineName,[[_stations lastObject] name], startStation.name,(startIndex-maxIndex)];
        }else{
            content = [NSString stringWithFormat:@"实时:%@公交开往\"%@\"方向，在\"%@\"之前尚未发车。",self.busLine.lineName,[[_stations lastObject] name], startStation.name];
        }
    }else{
        content = [NSString stringWithFormat:@"我正在查询%@公交车的实时位置，你也来试试吧。",self.busLine.lineName];
    }
    
    //构造分享内容，这里的content和titile提供给非微博类平台使用，微信好友使用titile、content不能超过26个字，朋友圈只使用title，图片使用logo。
    id<ISSContent> publishContent = [ShareSDK content:content
                                       defaultContent:nil
                                                image:[ShareSDK jpegImageWithImage:[UIImage imageNamed:@"分享80"] quality:1.0]
                                                title:@"“掌上公交”上线啦！等车不再捉急，到点准时来接你。"
                                                  url:Redirect_Url
                                          description:content
                                            mediaType:SSPublishContentMediaTypeNews];
    //QQ使用title和content(大概26个字以内)，但能显示字数更少。
    [publishContent addQQUnitWithType:INHERIT_VALUE content:[NSString stringWithFormat:@"我正在查询%@车的实时位置,你也来试试吧!",self.busLine.lineName] title:@"“掌上公交”上线啦！" url:INHERIT_VALUE image:INHERIT_VALUE];
    [publishContent addQQSpaceUnitWithTitle:@"“掌上公交”上线啦！" url:INHERIT_VALUE site:@"掌上公交" fromUrl:Redirect_Url comment:nil summary:content image:INHERIT_VALUE type:INHERIT_VALUE playUrl:INHERIT_VALUE nswb:INHERIT_VALUE];
    
    id<ISSQZoneApp> app =(id<ISSQZoneApp>)[ShareSDK getClientWithType:ShareTypeQQSpace];
    NSObject *qZone;
    if (app.isClientInstalled) {
        qZone = SHARE_TYPE_NUMBER(ShareTypeQQSpace);
    }else{
        qZone = [self getShareItem:ShareTypeQQSpace content:content];
    }
    
    NSArray *shareList = [ShareSDK customShareListWithType:SHARE_TYPE_NUMBER(ShareTypeWeixiSession),SHARE_TYPE_NUMBER(ShareTypeWeixiTimeline),SHARE_TYPE_NUMBER(ShareTypeQQ),qZone,[self getShareItem:ShareTypeSinaWeibo content:content],[self getShareItem:ShareTypeRenren content:content],nil];
    
    [ShareSDK showShareActionSheet:nil shareList:shareList content:publishContent statusBarTips:NO authOptions:nil shareOptions:nil result:^(ShareType type, SSResponseState state, id<ISSPlatformShareInfo> statusInfo, id<ICMErrorInfo> error, BOOL end) {
            if (state == SSResponseStateSuccess){
                NSLog(@"分享成功");
            }else if (state == SSResponseStateFail){
                [JDOUtils showHUDText:[NSString stringWithFormat:@"分享失败:%ld",(long)[error errorCode]] inView:self.view];
            }
        }
     ];
}

- (id<ISSShareActionSheetItem>) getShareItem:(ShareType) type content:(NSString *)content{
    return [ShareSDK shareActionSheetItemWithTitle:[ShareSDK getClientNameWithType:type] icon:[ShareSDK getClientIconWithType:type] clickHandler:^{
        JDOShareController *vc = [[JDOShareController alloc] initWithImage:screenImage content:content type:type];
        UINavigationController *naVC = [[UINavigationController alloc] initWithRootViewController:vc];
        [self presentViewController:naVC animated:true completion:nil];
    }];
}

#pragma mark- UITableViewDelegate && UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_stations count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
    return 15.0f;
}
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section{
    return 15.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 320, 15)];
    iv.image = [UIImage imageNamed:@"表格圆角上"];
    return iv;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section{
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 320, 15)];
    iv.image = [UIImage imageNamed:@"表格圆角下"];
    return iv;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    JDORealTimeCell *cell = [tableView dequeueReusableCellWithIdentifier:@"lineStation"]; // forIndexPath:indexPath];
    cell.controller = self;
#if 0
    JDOStationModel *station = _stations[indexPath.row];
    station.start = false;
    
    if(selectedStartStation){
        if ([station.fid isEqualToString:selectedStartStation.fid]) {
            station.start = true;
        }else{
            station.start = false;
        }
    }else if(_busLine.nearbyStationPair.count>0 && _busLine.nearbyStationPair[_busLine.showingIndex]!=[NSNull null]){
        JDOStationModel *startStation = _busLine.nearbyStationPair[_busLine.showingIndex];
        if ([station.fid isEqualToString:startStation.fid]) {
            station.start = true;
        }else{
            station.start = false;
        }
    }else{
        // 从线路进入，则无法预知起点，默认将终点站设置为参考站点
//        if (indexPath.row == _stations.count-1){
//            station.start = true;
//        }else{
            station.start = false;
//        }
    }
    

    if (station.isStart) {
        cell.stationIcon.image = [self imageAtPosition:indexPath.row selected:true];
        cell.stationSeq.textColor = [UIColor whiteColor];
        cell.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"表格选中背景"]];
    }else{
        cell.stationIcon.image = [self imageAtPosition:indexPath.row selected:false];
        cell.stationSeq.textColor = GrayColor;
        cell.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"表格圆角中"]];
    }
    
    [cell.stationName setText:station.name];
    [cell.stationSeq setText:[NSString stringWithFormat:@"%ld",indexPath.row+1]];
    CGRect stationFrame = cell.stationName.frame;
    
    if (_busIndexSet && [_busIndexSet containsObject:indexPath]) {
        // TODO在图标上区分进站和出站状态
        cell.arrivedBus.hidden = false;
        int busNumInSameStation = 0;    // 检查是否超过1辆车
        for (int i=0; i<_realBusList.count; i++){
            NSDictionary *dict = _realBusList[i];
            JDOBusModel *bus = [[JDOBusModel alloc] initWithDictionary:dict];
            if([bus.toStationId isEqualToString:station.fid]){
                busNumInSameStation++;
            }
        }
        if (busNumInSameStation > 1) {
            cell.busNumLabel.hidden = cell.busNumBorder.hidden = false;
            cell.busNumLabel.text = [NSString stringWithFormat:@"%d",busNumInSameStation];
            stationFrame.size.width = 205;
            cell.stationName.frame = stationFrame;
        }else{
            cell.busNumLabel.hidden = cell.busNumBorder.hidden = true;
            stationFrame.size.width = 223;
            cell.stationName.frame = stationFrame;
        }
    }else{
        cell.arrivedBus.hidden = true;
        cell.busNumLabel.hidden = cell.busNumBorder.hidden = true;
        stationFrame.size.width = 250;
        cell.stationName.frame = stationFrame;
    }
#endif
    
    cell.stationIcon.image = [self imageAtPosition:indexPath.row selected:false];
    cell.stationSeq.textColor = GrayColor;
    cell.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"表格圆角中"]];
    [cell.stationName setText:self.stations[indexPath.row][@"stationName"]];
    [cell.stationSeq setText:[NSString stringWithFormat:@"%ld",indexPath.row+1]];
    cell.arrivedBus.hidden = YES;
    CGRect stationFrame = cell.stationName.frame;
    cell.busNumLabel.hidden = cell.busNumBorder.hidden = true;
    stationFrame.size.width = 250;
    cell.stationName.frame = stationFrame;

    
    return cell;
}

//- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
//}


#pragma mark - private
- (UIImage *) imageAtPosition:(long)pos selected:(BOOL)selected{
    NSString *imageName;
    if (pos == 0) {
        imageName = selected?@"起点选中":@"起点";
    }else if(pos ==_stations.count-1){
        imageName = selected?@"终点选中":@"终点";
    }else{
        imageName = selected?@"中间选中":@"中间";
    }
    return [UIImage imageNamed:imageName];
}

- (void)loadLineDetails {
    NSString *lineDetailsPath = [[NSBundle mainBundle] pathForResource:@"yc_bus_route_details" ofType:@"plist"];
    NSArray *array = [NSArray arrayWithContentsOfFile:lineDetailsPath];
    [array enumerateObjectsUsingBlock:^(NSDictionary * obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([_routeId isEqualToString:obj[@"routeId"]]) {
            self.lineDetailsDict = obj;
            self.isOneDirection = [obj[@"isOneDirection"] boolValue];
            self.lineDetail.text = obj[@"routeName"];
            self.startTime.text = obj[@"startTime"];
            self.endTime.text = obj[@"endTime"];
            self.price.text = obj[@"price"];
            self.stations  = [NSMutableArray arrayWithArray:obj[@"stationsGo"]];
            [self.tableView reloadData];
        }
    }];
}

#pragma mark - public
- (void)showStationMenu:(JDORealTimeCell *)cell{
    
#if 0
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
//    JDOStationModel *station = _stations[indexPath.row];
    
    if (![self getStartStation]) {  // 尚未选择上车站点的时候，单击直接选中
        selectedStartStation = _stations[indexPath.row];
        [_busIndexSet removeAllObjects];
        [self.tableView reloadData];
        [self resetTimer];
        return;
    }
    
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, LineHeight)];
    contentView.backgroundColor = [UIColor clearColor];
    
    JDOSetStartButton *setStartBtn = [JDOSetStartButton buttonWithType:UIButtonTypeCustom];
    setStartBtn.frame = CGRectMake(15, 0, 115, LineHeight);
    setStartBtn.row = indexPath.row;
    setStartBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [setStartBtn setTitleColor:PopTextColor forState:UIControlStateNormal];
    [setStartBtn setTitle:@"选为上车站点" forState:UIControlStateNormal];
    [setStartBtn addTarget:self action:@selector(setToStartStation:) forControlEvents:UIControlEventTouchUpInside];
    [setStartBtn setImage:[UIImage imageNamed:@"小标注"] forState:UIControlStateNormal];
    [setStartBtn setTitleEdgeInsets:UIEdgeInsetsMake(0, 10, 0, 0)];
    [setStartBtn setImageEdgeInsets:UIEdgeInsetsMake(0, 1, 0, 99)];
    [contentView addSubview:setStartBtn];
    
    JDOToMapButton *toMapBtn = [JDOToMapButton buttonWithType:UIButtonTypeCustom];
    toMapBtn.frame = CGRectMake(170, 0, 115, LineHeight);
    toMapBtn.row = indexPath.row;
    toMapBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [toMapBtn setTitleColor:PopTextColor forState:UIControlStateNormal];
    [toMapBtn setTitle:@"查看站点详情" forState:UIControlStateNormal];
    [toMapBtn addTarget:self action:@selector(showStationDetail:) forControlEvents:UIControlEventTouchUpInside];
    [toMapBtn setImage:[UIImage imageNamed:@"小标注"] forState:UIControlStateNormal];
    [toMapBtn setTitleEdgeInsets:UIEdgeInsetsMake(0, 10, 0, 0)];
    [toMapBtn setImageEdgeInsets:UIEdgeInsetsMake(0, 1, 0, 99)];
    [contentView addSubview:toMapBtn];
    
    CMPopTipView *popTipView = [[CMPopTipView alloc] initWithCustomView:contentView];
//    popTipView.delegate = self;
    popTipView.disableTapToDismiss = true;
    popTipView.preferredPointDirection = PointDirectionUp;
    popTipView.hasGradientBackground = NO;
    popTipView.cornerRadius = 0.0f;
    popTipView.sidePadding = 10.0f;
    popTipView.topMargin = 1.0f;
    popTipView.pointerSize = 5.0f;
    popTipView.hasShadow = true;
    popTipView.backgroundColor = PopViewColor;
    popTipView.textColor = [UIColor whiteColor];
    popTipView.animation = CMPopTipAnimationPop;
    popTipView.has3DStyle = false;
    popTipView.dismissTapAnywhere = YES;
    popTipView.borderWidth = 0;
    
    [popTipView presentPointingAtView:cell.stationSeq inView:self.view animated:YES];
    setStartBtn.popView = popTipView;
    toMapBtn.popView = popTipView;
#endif
}

//- (void) setToStartStation:(JDOSetStartButton *)btn{
//    [btn.popView dismissAnimated:true];
//    // 清除之前选中站点的isStart状态，只靠[tableView reloadData]的话，仅仅能清除界面内之前选中站点的isStart，如果之前选中的滚动出界面可视区域，则无法清除，所以遍历一遍是最稳妥的方式
//    for(int i=0; i<_stations.count; i++){
//        JDOStationModel *station = _stations[i];
//        station.start = false;
//    }
//    selectedStartStation = _stations[btn.row];
//    [_busIndexSet removeAllObjects];
//    [self.tableView reloadData];
////    [self resetTimer];
//}

//- (void) showStationDetail:(JDOToMapButton *)btn{
//    [btn.popView dismissAnimated:false];
//    [self performSegueWithIdentifier:@"showStationDetail" sender:_stations[btn.row]];
//}

- (void)showBusMenu:(JDORealTimeCell *)cell{
//    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
//    JDOStationModel *station = _stations[indexPath.row];
//    
//    int count = 0;
//    UIView *contentView = [[UIView alloc] initWithFrame:CGRectZero];
//    contentView.backgroundColor = [UIColor clearColor];
//    
//    for (int i=0; i<_realBusList.count; i++){
//        NSDictionary *dict = _realBusList[i];
//        JDOBusModel *bus = [[JDOBusModel alloc] initWithDictionary:dict];
//        if ([station.fid isEqualToString:bus.toStationId]) {
//            UILabel *state = [[UILabel alloc] initWithFrame:CGRectMake(12, count*LineHeight+5, 30, 22)];
//            state.text = [bus.state intValue]==1?@"进站":@"出站";
//            state.textColor = [bus.state intValue]==1?[UIColor colorWithHex:@"FF6100"]:PopTextColor;
//            state.backgroundColor = [UIColor clearColor];
//            state.font = [UIFont boldSystemFontOfSize:14];
//            [contentView addSubview:state];
//            
//            UILabel *busNo = [[UILabel alloc] initWithFrame:CGRectMake(55, count*LineHeight+5, 105, 22)];
//            busNo.text = [NSString stringWithFormat:@"车牌:%@",bus.busNo];
//            busNo.textColor = PopTextColor;
//            busNo.backgroundColor = [UIColor clearColor];
//            busNo.font = [UIFont boldSystemFontOfSize:14];
//            [contentView addSubview:busNo];
//            
//            double distance = 0;
//            for (NSInteger j=indexPath.row+1; j<_stations.count; j++) {
//                JDOStationModel *aStation = _stations[j];
//                if (j == indexPath.row+1) {
//                    CLLocationCoordinate2D busPos = BMKCoorDictionaryDecode(BMKConvertBaiduCoorFrom(CLLocationCoordinate2DMake(bus.gpsY.doubleValue, bus.gpsX.doubleValue),BMK_COORDTYPE_GPS));
//                    CLLocationCoordinate2D stationPos = CLLocationCoordinate2DMake(aStation.gpsY.doubleValue, aStation.gpsX.doubleValue);
//                    distance+=BMKMetersBetweenMapPoints(BMKMapPointForCoordinate(busPos),BMKMapPointForCoordinate(stationPos));
//                }else{
//                    JDOStationModel *stationB = _stations[j-1];
//                    CLLocationCoordinate2D stationAPos = CLLocationCoordinate2DMake(aStation.gpsY.doubleValue, aStation.gpsX.doubleValue);
//                    CLLocationCoordinate2D stationBPos = CLLocationCoordinate2DMake(stationB.gpsY.doubleValue, stationB.gpsX.doubleValue);
//                    distance+=BMKMetersBetweenMapPoints(BMKMapPointForCoordinate(stationAPos),BMKMapPointForCoordinate(stationBPos));
//                }
//                if (aStation.isStart) {
//                    break;
//                }
//            }
//            UILabel *distanceLabel =[[UILabel alloc] initWithFrame:CGRectMake(168, count*LineHeight+5, 90, 22)];
//            if (distance>999) {    //%.Ng代表N位有效数字(包括小数点前面的)，%.Nf代表N位小数位
//                distanceLabel.text = [NSString stringWithFormat:@"距离:%.1f公里",distance/1000];
//            }else{
//                distanceLabel.text = [NSString stringWithFormat:@"距离:%d米",[@(distance) intValue]];
//            }
//            distanceLabel.textColor = PopTextColor;
//            distanceLabel.backgroundColor = [UIColor clearColor];
//            distanceLabel.font = [UIFont boldSystemFontOfSize:14];
//            [contentView addSubview:distanceLabel];
//            
//            JDOClockButton *clock = [JDOClockButton buttonWithType:UIButtonTypeCustom];
//            clock.frame = CGRectMake(267, count*LineHeight, LineHeight, LineHeight);
//            clock.busNo = bus.busNo;
//            clock.stationId = [self getStartStation].fid;
//            clock.imageEdgeInsets = UIEdgeInsetsMake(8, 6, 7, 8);
//            [clock setImage:[UIImage imageNamed:@"闹钟1"] forState:UIControlStateNormal];
//            [clock setImage:[UIImage imageNamed:@"闹钟2"] forState:UIControlStateSelected];
//            [clock addTarget:self action:@selector(setClock:) forControlEvents:UIControlEventTouchUpInside];
//            [contentView addSubview:clock];
//            
//            count++;
//        }
//    }
//    contentView.frame = CGRectMake(0, 0, 300, count*LineHeight);
//    
//    CMPopTipView *popTipView = [[CMPopTipView alloc] initWithCustomView:contentView];
//    cell.popTipView = popTipView;
//    popTipView.delegate = self;
//    popTipView.disableTapToDismiss = true;
//    popTipView.preferredPointDirection = PointDirectionUp;
//    popTipView.hasGradientBackground = NO;
//    popTipView.cornerRadius = 0.0f;
//    popTipView.sidePadding = 10.0f;
//    popTipView.topMargin = -5.0f;
//    popTipView.pointerSize = 5.0f;
//    popTipView.hasShadow = true;
//    popTipView.backgroundColor = PopViewColor;
//    popTipView.textColor = [UIColor whiteColor];
//    popTipView.animation = CMPopTipAnimationPop;
//    popTipView.has3DStyle = false;
//    popTipView.dismissTapAnywhere = YES;
//    popTipView.borderWidth = 0;
//    
//    [popTipView presentPointingAtView:cell.arrivedBus inView:self.view animated:YES];
//    _currentPopTipViewCell = cell;
//    _currentPopTipViewIndexPath = indexPath;
//    
}

//- (void)setClock:(JDOClockButton *)btn{
//    // TODO 后台设置上次提醒
//    if (btn.stationId) {
//        if (btn.isSelected) {
////            [JDOUtils showHUDText:@"已取消上车提醒" inView:self.view];
//        }else{
////            [JDOUtils showHUDText:@"已设置上车提醒" inView:self.view];
//            [JDOUtils showHUDText:@"到站提醒暂不可用" inView:self.view];
//        }
//        btn.selected = !btn.isSelected;
//    }else{
//        [JDOUtils showHUDText:@"请选择上车站点" inView:self.view];
//    }
//}

//- (void)popTipViewWasDismissedByUser:(CMPopTipView *)popTipView{
//    _currentPopTipViewCell.popTipView = nil;
//    _currentPopTipViewCell = nil;
//    _currentPopTipViewIndexPath = nil;
//}

@end
