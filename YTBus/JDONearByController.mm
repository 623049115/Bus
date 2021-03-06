//
//  JDONearByTableController.m
//  YTBus
//
//  Created by zhang yi on 14-10-21.
//  Copyright (c) 2014年 胶东在线. All rights reserved.
//

#import "JDONearByController.h"
#import "JDORealTimeController.h"
//#import "BMapKit.h"
#import "JDOStationModel.h"
#import "JDOBusLineDetail.h"
#import "JDOBusLine.h"
#import "JDONearMapController.h"
#import "JDODatabase.h"
#import "MBProgressHUD.h"
#import "JDOConstants.h"
#import "AppDelegate.h"
#import "JDOAlertTool.h"

@interface JDONearByCell : UITableViewCell

@property (nonatomic,strong) JDOBusLine *busLine;

@property (nonatomic,assign) UITableView *tableView;
@property (nonatomic,strong) NSIndexPath *indexPath;

@property (nonatomic,assign) IBOutlet UILabel *lineNameLabel;
@property (nonatomic,assign) IBOutlet UILabel *lineDetailLabel;
@property (nonatomic,assign) IBOutlet UILabel *stationLabel;
@property (nonatomic,assign) IBOutlet UILabel *distanceLabel;
@property (nonatomic,assign) IBOutlet UIButton *switchDirection;

- (IBAction) onSwitchClicked:(UIButton *)btn;

@end

@implementation JDONearByCell

- (IBAction) onSwitchClicked:(UIButton *)btn{
    self.busLine.showingIndex = self.busLine.showingIndex==0?1:0;
    [self.tableView reloadRowsAtIndexPaths:@[self.indexPath] withRowAnimation:UITableViewRowAnimationRight];
}

- (void) startAnimationWithDelay:(CGFloat) delayTime{
    self.transform = CGAffineTransformMakeTranslation(320, 0);
    [UIView animateWithDuration:1 delay:delayTime usingSpringWithDamping:0.6f initialSpringVelocity:0 options:0 animations:^{
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end

@interface JDONearByController () {
//    BMKLocationService *_locService;
//    BMKUserLocation *currentUserLocation;
    CLLocation *currentLocation;
    NSMutableArray *_nearbyStations;
    FMDatabase *_db;
    NSMutableArray *_linesInfo;
    id distanceObserver;
    id dbObserver;
    long distanceRadius;
    MBProgressHUD *hud;
    NSMutableSet *animationIndexPath;
    UILabel *hintLabel;
    UIImageView *hintImage;
    UILabel *noDataLabel;
    UIImageView *noDataImage;
//    CLLocationManager *locationManger;
    BOOL showLocationErrorHint;
}

@end

@implementation JDONearByController{
//    BMKGeoCodeSearch *_searcher;
    UILabel *myLocation;
    UILabel *myMovement;
    int sectionHeight;
    NSString *myLocationText1;
    NSString *myLocationText2;
    __strong JDOAlertTool *alert;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"JDO_Hint_Guide"]) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"setting_light"] style:UIBarButtonItemStylePlain target:self action:@selector(showHintGuide)];
    }
    self.navigationItem.rightBarButtonItem.enabled = false;
    self.tableView.backgroundColor = [UIColor colorWithHex:@"dfded9"];
//    self.tableView.showsVerticalScrollIndicator = false;
    self.tableView.bounces = false;
    sectionHeight = 0;
    
    float deltaY = Screen_Height>480?50:0;
    hintLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 250+deltaY, 280, 110)];
    hintLabel.backgroundColor = [UIColor clearColor];
    hintLabel.font = [UIFont systemFontOfSize:15];
    hintLabel.numberOfLines = 4;
    hintImage = [[UIImageView alloc] initWithFrame:CGRectMake(10, 10+deltaY, 300, 351)];
    
    noDataLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 250+deltaY, 280, 110)];
    noDataLabel.backgroundColor = [UIColor clearColor];
    noDataLabel.font = [UIFont systemFontOfSize:15];
    noDataLabel.textColor = [UIColor colorWithHex:@"5f5e59"];
    NSString *originalText = @"          “掌上公交”仅覆盖掌上市辖区范围内的公交数据，您的位置附近没有找到相关信息。若您在掌上市区，请移动一段距离后重试，或在“更多->系统设置->附近站点半径范围”中增加查询范围。";
    [self setLabel:noDataLabel text:originalText lineSpacing:2];
    noDataLabel.numberOfLines = 5;
    noDataLabel.hidden = true;
    noDataImage = [[UIImageView alloc] initWithFrame:CGRectMake(10, 10+deltaY, 300, 351)];
    noDataImage.image = [UIImage imageNamed:@"超出范围"];
    noDataImage.hidden = true;
    [self.tableView addSubview:noDataImage];
    [self.tableView addSubview:noDataLabel];
    
    // 另外启用一个定位服务，因为百度定位无法获取授权状态变化的回调
//    locationManger = [[CLLocationManager alloc] init];
//    locationManger.delegate = self;
//    if (After_iOS8) {
//        [locationManger requestWhenInUseAuthorization];
//    }
////    [locationManger startUpdatingLocation];
//    
//    _searcher =[[BMKGeoCodeSearch alloc] init];
//    _locService = [[BMKLocationService alloc] init];
    _nearbyStations = [[NSMutableArray alloc] init];
    animationIndexPath = [NSMutableSet set];
    distanceRadius = [[NSUserDefaults standardUserDefaults] integerForKey:@"nearby_distance"]?:1000;
    
    _db = [JDODatabase sharedDB];
//    if (!_db) {
//        dbObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"db_finished" object:nil queue:nil usingBlock:^(NSNotification *note) {
//            _db = [JDODatabase sharedDB];
//            [self checkLocationState];
//            [self refreshData];
//        }];
//    }
//    distanceObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"nearby_distance_changed" object:nil queue:nil usingBlock:^(NSNotification *note) {
//        distanceRadius = [[NSUserDefaults standardUserDefaults] integerForKey:@"nearby_distance"];
//        [self refreshData];
//    }];
    
}

- (void) showHintGuide {
    alert = [[JDOAlertTool alloc] init];
    [alert showAlertView:self title:@"温馨提醒" message:@"您可以访问“更多->新手指南”，对本应用的使用方式进行更全面的了解。" cancelTitle:@"我知道了" otherTitle1:nil otherTitle2:nil cancelAction:^{
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"JDO_Hint_Guide"];
        self.navigationItem.leftBarButtonItem = nil;
    } otherAction1:nil otherAction2:nil];
}

- (void) checkLocationState{
    if (showLocationErrorHint) {
        hud = [MBProgressHUD showHUDAddedTo:self.view animated:true];
        hud.minShowTime = 1.0f;
        hud.labelText = @"定位中,请稍候";
    }
}

//- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
//    if(![CLLocationManager locationServicesEnabled]){
//        sectionHeight = 0;
//        [_linesInfo removeAllObjects];
//        [self.tableView reloadData];
//        self.navigationItem.rightBarButtonItem.enabled = false;
//        
//        NSString *originalText = @"          您当前已关闭定位服务，请按以下顺序操作以开启定位服务：设置->隐私->定位服务->开启。";
//        [self setLabel:hintLabel text:originalText lineSpacing:4];
//        hintLabel.textColor = [UIColor colorWithHex:@"5f5e59"];
//        hintImage.image = [UIImage imageNamed:@"关闭定位"];
//        [self.tableView addSubview:hintImage];
//        [self.tableView addSubview:hintLabel];
//    }else if([CLLocationManager authorizationStatus]==kCLAuthorizationStatusDenied || [CLLocationManager authorizationStatus]==kCLAuthorizationStatusNotDetermined){
//        sectionHeight = 0;
//        [_linesInfo removeAllObjects];
//        [self.tableView reloadData];
//        self.navigationItem.rightBarButtonItem.enabled = false;
//        
//        NSString *originalText = @"          您尚未允许“掌上公交”使用定位服务，请按以下顺序操作以开启定位:设置->隐私->定位服务->掌上公交->选择“使用应用程序期间”。";;
//        [self setLabel:hintLabel text:originalText lineSpacing:4];
//        hintLabel.textColor = [UIColor colorWithHex:@"8f8e89"];
//        hintImage.image = [UIImage imageNamed:@"不允许使用定位"];
//        [self.tableView addSubview:hintImage];
//        [self.tableView addSubview:hintLabel];
//        //TODO 直接进入设置页面
////        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
//    }else{
//        self.navigationItem.rightBarButtonItem.enabled = true;
//        sectionHeight = 46;
//        
//        [hintLabel removeFromSuperview];
//        [hintImage removeFromSuperview];
//        [self refreshData];
//    }
//}

- (void) setLabel:(UILabel *)label text:(NSString *) originalText lineSpacing:(int) spacing{
    if (After_iOS6) {
        NSMutableAttributedString * attrString = [[NSMutableAttributedString alloc] initWithString:originalText];
        NSMutableParagraphStyle * paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        [paragraphStyle setLineSpacing:4];
        [attrString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, [originalText length])];
        label.attributedText = attrString;
    }else{
        label.text = originalText;
    }
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"toRealtimeFromNearby"]) {
        JDORealTimeController *rt = segue.destinationViewController;
        JDONearByCell *cell = (JDONearByCell *)sender;
        rt.busLine = cell.busLine;
        rt.busLine.zhixian = cell.busLine.zhixian;
        rt.busLine.attach = cell.busLine.attach;
        self.navigationItem.backBarButtonItem.title = @"附近";
    }else if([segue.identifier isEqualToString:@"toNearMap"]){
        JDONearMapController *nm = segue.destinationViewController;
//        nm.myselfLocation = currentUserLocation;
        nm.nearbyStations = _nearbyStations;// 目的是在地图界面nearbyStations变化时，后退能直接同步
        self.navigationItem.backBarButtonItem.title = @"返回";
    }
}

-(void)viewWillAppear:(BOOL)animated {
    [MobClick beginLogPageView:@"nearby"];
    [MobClick event:@"nearby"];
    [MobClick beginEvent:@"nearby"];
//    _locService.delegate = self;
//    _searcher.delegate = self;
//    [_locService startUserLocationService];
}

-(void)viewWillDisappear:(BOOL)animated {
    [MobClick endLogPageView:@"nearby"];
    [MobClick endEvent:@"nearby"];
//    [_locService stopUserLocationService];
//    _locService.delegate = nil;
//    _searcher.delegate = nil;
}

- (void)didFailToLocateUserWithError:(NSError *)error {
    NSLog(@"location error:%@",error);
    // 若启动时候无网络，使用GPS定位可能需要定位很久，iPhone下及时关闭移动数据和启用飞行模式都可以定位成功
//    if (error.code == kCLErrorLocationUnknown) {
//        if (!hud && _linesInfo.count==0 ) {
//            showLocationErrorHint = true;
//            if (_db) {
//                [self checkLocationState];
//            }
//        }
//    }else if (error.code == kCLErrorDenied){    // 启动的时候不允许，或运行过程中从系统设置里关闭
//        NSLog(@"didFailToLocateUserWithError：kCLErrorDenied");
//    }
}

// 每次回调的userLocation是同一个，只改变里其中的内容，所以不能直接用userLocation跟currentUserLocation进行比较
//- (void)didUpdateBMKUserLocation:(BMKUserLocation *)userLocation
//{
//    if (hud) {
//        [hud hide:true];
//        hud = nil;
//    }
//    showLocationErrorHint = false;
////    [(AppDelegate *)[[UIApplication sharedApplication] delegate] setUserLocation:userLocation];
//    
//    
////    if (currentUserLocation) {
////        // 每次startUserLocationService都会触发一次忽略位移的定位，若两次viewWillAppear调用之间若距离变化不足则不刷新
////        double moveDistance = [userLocation.location distanceFromLocation:currentLocation];
////        long autoRefreshDistance = [[NSUserDefaults standardUserDefaults] integerForKey:@"nearby_refresh_move"]?:200;
////        if (moveDistance != -1 && moveDistance < autoRefreshDistance) {
////            myMovement.text = [NSString stringWithFormat:@"距上次刷新位置%d米",(int)moveDistance];
//////            [JDOUtils showHUDText:[NSString stringWithFormat:@"距离上次刷新位置:%g米",moveDistance] inView:self.view];
////            return;
////        }
////    }
//////    发起反向地理编码检索
////    CLLocationCoordinate2D pt = userLocation.location.coordinate;
////    BMKReverseGeoCodeOption *reverseGeoCodeSearchOption = [[BMKReverseGeoCodeOption alloc] init];
//    reverseGeoCodeSearchOption.reverseGeoPoint = pt;
//    BOOL flag = [_searcher reverseGeoCode:reverseGeoCodeSearchOption];
//    if(!flag){
//        NSLog(@"反geo检索发送失败");
//    }
//    
//    currentUserLocation = userLocation;
//    currentLocation = userLocation.location;
//    
//    [self refreshData];
//}

//- (void) refreshData{
//    if (!_db) {
//        return;
//    }
//    if (!currentUserLocation) {
//        return;
//    }
//    [_nearbyStations removeAllObjects];
//    
//    // 先根据经纬度缩小范围，圈定一个以当前坐标为中心的正方形区域
//    // 因为地图坐标不能转到GPS坐标，所以地图坐标必须在数据库里有字段保存
//    // 另外一个解决方案是，使用CLLocationManager，不使用百度定位
//    // 经度1度 = 85.39km    经度1分 = 1.42km   经度1秒 = 23.6m
//    // 纬度1度 = 大约111km    纬度1分 = 大约1.85km 纬度1秒 = 大约30.9m
//    
//    double longitudeDelta = distanceRadius/85390.0;
//    double latitudeDelta = distanceRadius/111000.0;
//
//    CLLocationCoordinate2D currentCoor = currentUserLocation.location.coordinate;
//    NSArray *argu = @[@(currentCoor.longitude-longitudeDelta),@(currentCoor.longitude+longitudeDelta),@(currentCoor.latitude-latitudeDelta),@(currentCoor.latitude+latitudeDelta)];
//    FMResultSet *s = [_db executeQuery:GetNearbyStations withArgumentsInArray:argu];
//    while ([s next]) {
//        JDOStationModel *station = [JDOStationModel new];
//        station.fid = [NSString stringWithFormat:@"%d",[s intForColumn:@"ID"]];
//        station.name = [s stringForColumn:@"STATIONNAME"];
//        station.direction = [s stringForColumn:@"DIRECTION"];
//        station.gpsX = [NSNumber numberWithDouble:[s doubleForColumn:@"GPSX"]];
//        station.gpsY = [NSNumber numberWithDouble:[s doubleForColumn:@"GPSY"]];
//        station.attach = [s intForColumn:@"ATTACH"];
//        
//        // 对比与当前地理位置的距离小于1000的站点
//        CLLocationCoordinate2D bdStation = CLLocationCoordinate2DMake(station.gpsY.doubleValue, station.gpsX.doubleValue);
//        // gps坐标转百度坐标
//        //        CLLocationCoordinate2D bdStation = BMKCoorDictionaryDecode(BMKConvertBaiduCoorFrom(CLLocationCoordinate2DMake(station.gpsY.doubleValue, station.gpsX.doubleValue),BMK_COORDTYPE_GPS));
//        // 转化为直角坐标测距
//        CLLocationDistance distance = BMKMetersBetweenMapPoints(BMKMapPointForCoordinate(currentCoor),BMKMapPointForCoordinate(bdStation));
//        if (distance < distanceRadius) {  // 附近站点
//            station.distance = @(distance);
//            [_nearbyStations addObject:station];
//        }
//    }
//    [s close];
//    
//    // 按距离由近及远排序
//    [_nearbyStations sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
//        JDOStationModel *station1 = (JDOStationModel *)obj1;
//        JDOStationModel *station2 = (JDOStationModel *)obj2;
//        if (station1.distance.doubleValue < station2.distance.doubleValue) {
//            return NSOrderedAscending;
//        }
//        return NSOrderedDescending;
//    }];
//    
//    // 测试超出掌上范围无公交站点的情况
////    [_nearbyStations removeAllObjects];
//    
//    // 将同一线路的上下行两个方向分别离当前最近的站点合并成一个数组，距离近的在前，保存在busLine的nearbyStation中
//    _linesInfo = [[NSMutableArray alloc] init];
//    for (int i=0; i<_nearbyStations.count; i++) {
//        JDOStationModel *station = _nearbyStations[i];
//        FMResultSet *rs = [_db executeQuery:GetLinesByStation,station.fid, @(station.attach)];
//        while ([rs next]) {
//            NSString *lineId = [rs stringForColumn:@"LINEID"];
//            
//            JDOBusLine *busLine;
//            for (int i=0; i<_linesInfo.count; i++) {
//                JDOBusLine *aLine = _linesInfo[i];
//                if ([aLine.lineId isEqualToString:lineId]) {
//                    busLine = aLine;
//                    break;
//                }
//            }
//            
//            if(!busLine) {
//                busLine = [JDOBusLine new];
//                busLine.lineId = lineId;
//                busLine.lineName = [rs stringForColumn:@"LINENAME"];
//                busLine.runTime = [rs stringForColumn:@"RUNTIME"];
//                busLine.zhixian = [rs intForColumn:@"ZHIXIAN"];
//                busLine.attach = [rs intForColumn:@"ATTACH"];
//                
//                busLine.lineDetailPair = [[NSMutableArray alloc] initWithCapacity:2];
//                JDOBusLineDetail *lineDetail = [JDOBusLineDetail new];
//                lineDetail.detailId = [rs stringForColumn:@"LINEDETAILID"];
//                lineDetail.lineDetail = [rs stringForColumn:@"LINEDETAIL"];
//                lineDetail.direction = [rs stringForColumn:@"LINEDIRECTION"];
//                lineDetail.attach = [rs intForColumn:@"ATTACH"];
//                [busLine.lineDetailPair addObject:lineDetail];
//                
//                busLine.nearbyStationPair = [[NSMutableArray alloc] initWithCapacity:2];
//                [busLine.nearbyStationPair addObject:station];
//                
//                [_linesInfo addObject:busLine];
//            }else{
//                if (busLine.lineDetailPair.count == 2) {
//                    continue;
//                }
//                // stationPair中的第二个必须保证跟前一个是对向站点。并且上下行的两个站点不一定同名，也就是说，离当前位置最近的两侧站点可能分别是前后两站
//                JDOBusLineDetail *preLineDetail = busLine.lineDetailPair[0];
//                NSString *detailId = [rs stringForColumn:@"LINEDETAILID"];
//                if ([preLineDetail.detailId isEqualToString:detailId]) {
//                    continue;
//                }
//                
//                JDOBusLineDetail *lineDetail = [JDOBusLineDetail new];
//                lineDetail.detailId = [rs stringForColumn:@"LINEDETAILID"];
//                lineDetail.lineDetail = [rs stringForColumn:@"LINEDETAIL"];
//                lineDetail.direction = [rs stringForColumn:@"LINEDIRECTION"];
//                lineDetail.attach = [rs intForColumn:@"ATTACH"];
//                [busLine.lineDetailPair addObject:lineDetail];
//                
//                [busLine.nearbyStationPair addObject:station];
//            }
//        }
//        [rs close];
//    }
//    [animationIndexPath removeAllObjects];
//    if (_linesInfo.count>0) {
//        noDataLabel.hidden = true;
//        noDataImage.hidden = true;
//        sectionHeight = 46;
//        [self.tableView reloadData];
//        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:false];
//        self.navigationItem.rightBarButtonItem.enabled = true;
//    }else{
//        noDataLabel.hidden = false;
//        noDataImage.hidden = false;
//        sectionHeight = 0;
//        [self.tableView reloadData];    // 防止反向定位栏显示在最上面
//        self.navigationItem.rightBarButtonItem.enabled = false;
//    }
//}
//
////接收反向地理编码结果
//-(void) onGetReverseGeoCodeResult:(BMKGeoCodeSearch *)searcher result: (BMKReverseGeoCodeResult *)result errorCode:(BMKSearchErrorCode)error{
//    if (error == BMK_SEARCH_NO_ERROR) {
//        if (result.poiList.count>0) {
//            myLocationText1 = [(BMKPoiInfo *)result.poiList[0] name];
//            myLocationText2 = [[result.addressDetail.district stringByAppendingString:result.addressDetail.streetName] stringByAppendingString:result.addressDetail.streetNumber];
//            myLocation.text = [NSString stringWithFormat:@"%@[%@]",myLocationText2,myLocationText1];
//        }else{
//            myLocationText1 = nil;
//            myLocationText2 = [[result.addressDetail.district stringByAppendingString:result.addressDetail.streetName] stringByAppendingString:result.addressDetail.streetNumber];
//            myLocation.text = myLocationText2;
//        }
//    }else{
//        NSLog(@"抱歉，未找到结果");
//    }
//}

- (void) changeDisplayLocation:(UITapGestureRecognizer *)gesture{
    if ([myLocation.text isEqualToString:myLocationText1]) {
        myLocation.text = myLocationText2;
    }else if([myLocation.text isEqualToString:myLocationText2]){
        myLocation.text = myLocationText1;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _linesInfo.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
    return sectionHeight;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    UIImageView *bg = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 320, 46)];
    bg.image = [UIImage imageNamed:@"附近头部"];
    // 父视图不开启userInteractionEnabled，只开子视图的无效
    bg.userInteractionEnabled = true;
    myLocation = [[UILabel alloc] initWithFrame:CGRectMake(30, 10, 280, 21)];
    myLocation.textColor = [UIColor colorWithWhite:240/255.0f alpha:1.0f];
    myLocation.backgroundColor = [UIColor clearColor];
    myLocation.font = [UIFont systemFontOfSize:14];
    myLocation.minimumFontSize = 10;
    myLocation.text = @"我的位置";
//    myLocation.userInteractionEnabled = true;
//    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(changeDisplayLocation:)];
//    [myLocation addGestureRecognizer:gesture];
    [bg addSubview:myLocation];
//    myMovement = [[UILabel alloc] initWithFrame:CGRectMake(178, 10, 140, 21)];
//    myMovement.textColor = [UIColor colorWithWhite:240/255.0f alpha:1.0f];
//    myMovement.backgroundColor = [UIColor clearColor];
//    myMovement.font = [UIFont systemFontOfSize:14];
//    myMovement.minimumFontSize = 10;
//    myMovement.text = @"正在定位";
//    [bg addSubview:myMovement];
    return bg;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    JDONearByCell *cell = [tableView dequeueReusableCellWithIdentifier:@"busLine"]; // forIndexPath:indexPath];
    if(!cell.backgroundView){
        cell.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"公交车列表"]];
        cell.backgroundColor = [UIColor clearColor];
        cell.contentView.backgroundColor = [UIColor clearColor];
    }
    
    JDOBusLine *busLine = _linesInfo[indexPath.row];
    cell.indexPath = indexPath;
    cell.tableView = self.tableView;
    cell.busLine = busLine;
    
    [cell.lineNameLabel setText:busLine.lineName];
    
    JDOBusLineDetail *lineDetail = busLine.lineDetailPair[busLine.showingIndex];
    [cell.lineDetailLabel setText:lineDetail.lineDetail];
    
    JDOStationModel *station = busLine.nearbyStationPair[busLine.showingIndex];
    [cell.stationLabel setText:[NSString stringWithFormat:@"%@ [%@]",station.name,station.direction]];
//    [cell.distanceLabel setText:[NSString stringWithFormat:@"%d米",[station.distance intValue]]];
    
    cell.switchDirection.hidden = (busLine.lineDetailPair.count==1);
    
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath{
    if (After_iOS7) {
        JDONearByCell *nearbyCell = (JDONearByCell *)cell;
        if (![animationIndexPath containsObject:indexPath]) {
            [nearbyCell startAnimationWithDelay:(indexPath.row*0.06f)];
            [animationIndexPath addObject:indexPath];
        }
    }
}

-(void)dealloc{
    if (distanceObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:distanceObserver];
    }
    if (dbObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:dbObserver];
    }
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
}


@end
