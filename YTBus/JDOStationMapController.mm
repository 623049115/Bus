//
//  JDOStationMapController.m
//  YTBus
//
//  Created by zhang yi on 14-11-18.
//  Copyright (c) 2014年 胶东在线. All rights reserved.
//

#import "JDOStationMapController.h"
#import "JDODatabase.h"
#import "JDOBusLine.h"
#import "JDOBusLineDetail.h"
#import "JDOStationAnnotation.h"
#import "JDORealTimeController.h"
#import "JDOConstants.h"
#import "AppDelegate.h"
#import <objc/runtime.h>
#import "JDOStationController.h"
#import "TBCoordinateQuadTree.h"
#import "TBClusterAnnotationView.h"
#import "TBClusterAnnotation.h"

#import <BaiduMapAPI_Search/BMKSearchComponent.h>

#define PaoPaoLineHeight 35

static const void *LabelKey = &LabelKey;

@interface BMKGeoCodeSearch (JDOCategory)

@property (nonatomic,retain) UILabel *titleLabel;

@end

@implementation BMKGeoCodeSearch (JDOCategory)

@dynamic titleLabel;

- (UILabel *)titleLabel {
    return objc_getAssociatedObject(self, LabelKey);
}

- (void)setTitleLabel:(UILabel *)titleLabel{
    objc_setAssociatedObject(self, LabelKey, titleLabel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@interface JDOPaoPaoTable2 : UITableView

@property (nonatomic,strong) NSArray *lines;

@end

@implementation JDOPaoPaoTable2

@end

@interface JDOStationMapController () <UITableViewDataSource,UITableViewDelegate,UIGestureRecognizerDelegate,BMKMapViewDelegate,BMKLocationServiceDelegate,BMKPoiSearchDelegate,BMKGeoCodeSearchDelegate,JDOStationControllerDelegate>

@property (nonatomic,assign) IBOutlet BMKMapView *mapView;
@property (nonatomic,assign) IBOutlet UITableView *tableView;
@property (nonatomic,assign) IBOutlet UIView *lineView;
@property (nonatomic,assign) IBOutlet UILabel *stationLabel;
@property (nonatomic,assign) IBOutlet UISwitch *busMonitor;
@property (nonatomic,assign) IBOutlet UIButton *closeBtn;
@property (nonatomic,strong) TBCoordinateQuadTree *coordinateQuadTree;

@property (nonatomic,strong) BMKLocationService *locationService;
@property (nonatomic,strong) BMKPoiSearch *poiSearch;
@property (nonatomic,strong) TBClusterAnnotation *selectedAnnotation;
@property (nonatomic,strong) NSArray *annotations;

@end

@implementation JDOStationMapController {
    FMDatabase *_db;
    NSMutableArray *_stations;
    NSIndexPath *selectedIndexPath;
    NSOperationQueue *_queryQueue;
    BOOL rightBtnIsSearch;
    NSMutableArray *combinedStations;
}

#pragma mark - getter
- (BMKLocationService *)locationService {
    if (!_locationService) {
        _locationService = [[BMKLocationService alloc] init];
    }
    return _locationService;
}

- (BMKPoiSearch *)poiSearch {
    if (!_poiSearch) {
        _poiSearch = [[BMKPoiSearch alloc] init];
    }
    return _poiSearch;
}

#pragma mark - life cycle
- (void)dealloc {
    if (_mapView) {
        _mapView = nil;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.bounces = true;
    
    self.lineView.frame = CGRectMake(10, CGRectGetHeight(self.view.bounds)-44, 300, 44);
    self.stationLabel.text = @"请选择站点";
    self.busMonitor.hidden = true;
    self.closeBtn.hidden = true;
    [self.closeBtn addTarget:self action:@selector(closeLineView) forControlEvents:UIControlEventTouchUpInside];
    [self.busMonitor addTarget:self action:@selector(switchMonitor) forControlEvents:UIControlEventValueChanged];
    rightBtnIsSearch = true;
    

    _mapView.zoomEnabled = true;
    _mapView.zoomEnabledWithTap = true;
    _mapView.scrollEnabled = true;
    _mapView.rotateEnabled = true;
    _mapView.overlookEnabled = false;
    _mapView.showMapScaleBar = false;
    _mapView.minZoomLevel = 12;
    _mapView.centerCoordinate = CLLocationCoordinate2DMake(30.6976020000,111.2929710000);
    
    _queryQueue = [[NSOperationQueue alloc] init];
    _queryQueue.maxConcurrentOperationCount = 1;
    
    self.coordinateQuadTree = [[TBCoordinateQuadTree alloc] init];
    
    [self addCustomGestures];
    [_queryQueue addOperationWithBlock:^{
        [self loadAllStations];
    }];
}

-(void)viewWillAppear:(BOOL)animated {
    
    [self.mapView viewWillAppear];
    self.mapView.delegate = self;
    //搜索公交站点
//    self.poiSearch.delegate = self;
//    [self searchBusPoint];
    
    //定位
//    self.locationService.delegate = self;
//    [self startLocation];
//
//
//    if (self.selectedStation) {
//        [self showLineView];
//    }
}

-(void)viewWillDisappear:(BOOL)animated {
    [self.mapView viewWillDisappear];
    self.mapView.delegate = nil;
    
//    self.poiSearch.delegate = nil;
    
//    self.locationService.delegate = nil;
//    [self stopLocation];
}

#pragma mark - 添加自定义的手势（若不自定义手势，不需要下面的代码）
- (void)addCustomGestures {
    /*
     *注意：
     *添加自定义手势时，必须设置UIGestureRecognizer的属性cancelsTouchesInView 和 delaysTouchesEnded 为NO,
     *否则影响地图内部的手势处理
     */
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTap.delegate = self;
    doubleTap.numberOfTapsRequired = 2;
    doubleTap.cancelsTouchesInView = NO;
    doubleTap.delaysTouchesEnded = NO;
    
    [self.view addGestureRecognizer:doubleTap];
    
    /*
     *注意：
     *添加自定义手势时，必须设置UIGestureRecognizer的属性cancelsTouchesInView 和 delaysTouchesEnded 为NO,
     *否则影响地图内部的手势处理
     */
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    singleTap.delegate = self;
    singleTap.cancelsTouchesInView = NO;
    singleTap.delaysTouchesEnded = NO;
    [singleTap requireGestureRecognizerToFail:doubleTap];
    [self.view addGestureRecognizer:singleTap];
}

- (void)handleSingleTap:(UITapGestureRecognizer *)theSingleTap {
    /*
     *do something
     */
    NSLog(@"my handleSingleTap");
    [self closeLineView];
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)theDoubleTap {
    /*
     *do something
     */
    NSLog(@"my handleDoubleTap");
}

#pragma mark - BMKLocationServiceDelegate
/**
 *在地图View将要启动定位时，会调用此函数
 *@param mapView 地图View
 */
- (void)willStartLocatingUser
{
    NSLog(@"start locate");
}

/**
 *用户方向更新后，会调用此函数
 *@param userLocation 新的用户位置
 */
- (void)didUpdateUserHeading:(BMKUserLocation *)userLocation
{
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:userLocation.location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        
        if (placemarks.count > 0) {
            CLPlacemark *placemark = placemarks[0];
            userLocation.title = placemark.name;
            [_mapView updateLocationData:userLocation];
            _mapView.centerCoordinate = userLocation.location.coordinate;
            [self stopLocation];
        }
    }];

    NSLog(@"heading is %@",userLocation.heading);
}

/**
 *用户位置更新后，会调用此函数
 *@param userLocation 新的用户位置
 */
- (void)didUpdateBMKUserLocation:(BMKUserLocation *)userLocation
{
    NSLog(@"didUpdateUserLocation lat %f,long %f",userLocation.location.coordinate.latitude,userLocation.location.coordinate.longitude);
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:userLocation.location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {

        if (placemarks.count > 0) {
            CLPlacemark *placemark = placemarks[0];
            userLocation.title = placemark.name;
            [_mapView updateLocationData:userLocation];
            _mapView.centerCoordinate = userLocation.location.coordinate;
            [self stopLocation];
        }
    }];

}

/**
 *在地图View停止定位后，会调用此函数
 *@param mapView 地图View
 */
- (void)didStopLocatingUser
{
    NSLog(@"stop locate");
}

/**
 *定位失败后，会调用此函数
 *@param mapView 地图View
 *@param error 错误号，参考CLError.h中定义的错误号
 */
- (void)didFailToLocateUserWithError:(NSError *)error
{
    NSLog(@"location error");
}


#pragma mark implement BMKSearchDelegate
- (void)onGetPoiResult:(BMKPoiSearch *)searcher result:(BMKPoiResult*)result errorCode:(BMKSearchErrorCode)error
{
    // 清楚屏幕中所有的annotation
//    NSArray* array = [NSArray arrayWithArray:_mapView.annotations];
//    [_mapView removeAnnotations:array];
//    
//    if (error == BMK_SEARCH_NO_ERROR) {
//        NSMutableArray *annotations = [NSMutableArray array];
//        for (int i = 0; i < result.poiInfoList.count; i++) {
//            BMKPoiInfo* poi = [result.poiInfoList objectAtIndex:i];
//            BMKPointAnnotation* item = [[BMKPointAnnotation alloc]init];
//            item.coordinate = poi.pt;
//            item.title = poi.name;
//            [annotations addObject:item];
//            NSLog(@"------>%@",poi.name);
//        }
//        [_mapView addAnnotations:annotations];
//        [_mapView showAnnotations:annotations animated:YES];
//    } else if (error == BMK_SEARCH_AMBIGUOUS_ROURE_ADDR){
//        NSLog(@"起始点有歧义");
//    } else {
//        // 各种情况的判断。。。
//    }
}

#pragma mark - BMKMapViewDelegate
//- (void)mapView:(BMKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
//{
//    [_queryQueue addOperationWithBlock:^{
//        self.annotations = [self.coordinateQuadTree clusteredAnnotationsWithinMapView:mapView];
//        [self updateMapViewAnnotationsWithAnnotations:self.annotations];
//    }];
//}

- (BMKAnnotationView *)mapView:(BMKMapView *)mapView viewForAnnotation:(id<BMKAnnotation>)annotation
{
    static NSString *const TBAnnotatioViewReuseID = @"TBAnnotatioViewReuseID";
    
    TBClusterAnnotationView *annotationView = (TBClusterAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:TBAnnotatioViewReuseID];
    
    if (!annotationView) {
        annotationView = [[TBClusterAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:TBAnnotatioViewReuseID];
    }
    
    
    TBClusterAnnotation *ca = (TBClusterAnnotation *)annotation;
    annotationView.count = ca.count;
    annotationView.canShowCallout = true;
//    if (ca.stations.count == 0) {
//        ca.title = [NSString stringWithFormat:@"%ld个站点,放大可显示详情",(long)ca.count];
//    }else
    if(ca.stations.count ==1) {
        JDOStationModel *station = ca.stations[0];
        ca.title = station.name;
        ca.coordinate = CLLocationCoordinate2DMake([station.gpsY doubleValue], [station.gpsX  doubleValue]);
    }
    //else{
//        annotationView.paopaoView = [self createPaoPaoView:ca.stations];
//    }
    
//    annotationView.annotation = annotation;
    
    return annotationView;
}



//- (BMKActionPaopaoView *)createPaoPaoView:(NSArray *)paopaoLines{
//    float tableHeight = paopaoLines.count*PaoPaoLineHeight;
//    // 计算最长的站点名称宽度
//    float tableWidth = 0;
//    for (int i=0; i<paopaoLines.count; i++) {
//        NSDictionary *station = paopaoLines[i];
//        float width = [station[@"stationName"] sizeWithFont:[UIFont systemFontOfSize:14] forWidth:MAXFLOAT lineBreakMode:NSLineBreakByWordWrapping].width;
//        tableWidth = MAX(tableWidth, width+10);
//    }
//    tableWidth = MAX(tableWidth,140);
//    
//    UIView *customView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableWidth, 35+tableHeight+12)];
//    UIImageView *header = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, tableWidth, 35)];
//    header.image = [UIImage imageNamed:@"弹出列表01"];
//    [customView addSubview:header];
//    
//    UILabel *title = [[UILabel alloc] initWithFrame:header.bounds];
//    title.backgroundColor = [UIColor clearColor];   // iOS7以下label背景色为白色，以上为透明
//    title.font = [UIFont boldSystemFontOfSize:15];
//    title.minimumFontSize = 12;
//    title.adjustsFontSizeToFitWidth = true;
//    title.textColor = [UIColor whiteColor];
//    title.textAlignment = NSTextAlignmentCenter;
//    title.tag = 8001;
//    //    title.text = @"正在获取位置";
//    [customView addSubview:title];
//    
//    UIImageView *footer = [[UIImageView alloc] initWithFrame:CGRectMake(0, 35+tableHeight+12-51, tableWidth, 51)];
//    footer.image = [UIImage imageNamed:@"弹出列表04"];
//    [customView addSubview:footer];
//    
//    JDOPaoPaoTable2 *paopaoTable = [[JDOPaoPaoTable2 alloc] initWithFrame:CGRectMake(0, 35, tableWidth, tableHeight)];
//    paopaoTable.stations = paopaoLines;
//    paopaoTable.rowHeight = PaoPaoLineHeight;
//    paopaoTable.bounces = false;
//    paopaoTable.separatorStyle = UITableViewCellSeparatorStyleNone;
//    paopaoTable.delegate = self;
//    paopaoTable.dataSource = self;
//    paopaoTable.tag = 8002;
//    [customView addSubview:paopaoTable];
//    
//    BMKActionPaopaoView *paopaoView = [[BMKActionPaopaoView alloc] initWithCustomView:customView];
//    return paopaoView;
//}

- (void)mapView:(BMKMapView *)mapView didAddAnnotationViews:(NSArray *)views
{
    for (UIView *view in views) {
        [self addBounceAnnimationToView:view];
    }
}

- (void)addBounceAnnimationToView:(UIView *)view
{
    CAKeyframeAnimation *bounceAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    
    bounceAnimation.values = @[@(0.05), @(1.1), @(0.9), @(1)];
    
    bounceAnimation.duration = 0.6;
    NSMutableArray *timingFunctions = [[NSMutableArray alloc] initWithCapacity:bounceAnimation.values.count];
    for (NSUInteger i = 0; i < bounceAnimation.values.count; i++) {
        [timingFunctions addObject:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    }
    [bounceAnimation setTimingFunctions:timingFunctions.copy];
    bounceAnimation.removedOnCompletion = NO;
    
    [view.layer addAnimation:bounceAnimation forKey:@"bounce"];
}

- (void)updateMapViewAnnotationsWithAnnotations:(NSArray *)annotations
{
//    NSMutableSet *before = [NSMutableSet setWithArray:self.mapView.annotations];
//    NSSet *after = [NSSet setWithArray:annotations];
//    
//    NSMutableSet *toKeep = [NSMutableSet setWithSet:before];
//    [toKeep intersectSet:after];
//    
//    NSMutableSet *toAdd = [NSMutableSet setWithSet:after];
//    [toAdd minusSet:toKeep];
//    
//    NSMutableSet *toRemove = [NSMutableSet setWithSet:before];
//    [toRemove minusSet:after];
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
//        [self.mapView addAnnotations:[toAdd allObjects]];
//        [self.mapView removeAnnotations:[toRemove allObjects]];
        [self.mapView addAnnotations:annotations];
    }];
}

- (void)mapView:(BMKMapView *)mapView didSelectAnnotationView:(BMKAnnotationView *)view{
    TBClusterAnnotation *ca = (TBClusterAnnotation *)view.annotation;
//
//    if (ca.stations.count == 0) {
//
//    }else
    if(ca.stations.count ==1) {
        [mapView setCenterCoordinate:view.annotation.coordinate animated:YES];
        // 若marker上只有一个站点，则不弹出paopaoView，直接打开线路列表
        _selectedStation = ca.stations[0];
        _selectedAnnotation = view.annotation;
        [self showLineView];
    }
#if 0
//    else{
        // 选中某个marker后，将此marker移动到地图中心
        [mapView setCenterCoordinate:view.annotation.coordinate animated:YES];

        TBClusterAnnotationView *annotationView = (TBClusterAnnotationView *)view;
        UIView *customView = [annotationView.paopaoView subviews][0];
        UILabel *title = (UILabel *)[customView viewWithTag:8001];

        // 多个站点的时候，取位置进行反地理编码填充表格头部
        BMKReverseGeoCodeOption *reverseGeoCodeSearchOption = [[BMKReverseGeoCodeOption alloc] init];
        reverseGeoCodeSearchOption.reverseGeoPoint = ca.coordinate;
        BMKGeoCodeSearch *searcher =[[BMKGeoCodeSearch alloc] init];
        searcher.delegate = self;
        searcher.titleLabel = title;
        BOOL flag = [searcher reverseGeoCode:reverseGeoCodeSearchOption];
        if(!flag){
            NSLog(@"反geo检索发送失败");
        }
        UITableView *tv = (UITableView *)[customView viewWithTag:8002];
        [tv scrollsToTop];
//    }
#endif
}


#pragma mark - BMKGeoCodeSearchDelegate
//接收反向地理编码结果
-(void) onGetReverseGeoCodeResult:(BMKGeoCodeSearch *)searcher result: (BMKReverseGeoCodeResult *)result errorCode:(BMKSearchErrorCode)error{
    if (error == BMK_SEARCH_NO_ERROR) {
        searcher.titleLabel.text = [[result.addressDetail.district stringByAppendingString:result.addressDetail.streetName] stringByAppendingString:result.addressDetail.streetNumber];
    }else{
        searcher.titleLabel.text = @"无法获取位置信息";
    }
    searcher.delegate = nil;
}

#pragma mark- JDOStationControllerDelegate 
- (void)jdoStationControllerDidSelectedStation:(JDOStationModel *)stationModel {
    [self.annotations enumerateObjectsUsingBlock:^(TBClusterAnnotation *annotation, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([stationModel.name isEqualToString:((JDOStationModel *)annotation.stations[0]).name]) {
            _selectedStation = stationModel;
            _selectedAnnotation = annotation;
            *stop = YES;
            [self.mapView selectAnnotation:_selectedAnnotation animated:YES];
            [self showLineView];
        }
    }];
}
#pragma mark- myPrivate
//获得选中站点的个数
- (NSInteger)getBusesCountWithStationId:(NSString *)stationId {
    __block NSInteger count = 0;
    [_stations enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([_selectedStation.fid isEqualToString:obj[@"stationId"]]) {
            count = [obj[@"buses"] count];
            *stop = YES;
        }
    }];
    return count;

}

//获得路线
- (NSDictionary *)getSelectedStationLineWithIdx:(NSInteger)index {
    
    NSString *busPath = [[NSBundle mainBundle] pathForResource:@"yc_bus_list" ofType:@"plist"];
    NSArray *buses = [NSArray arrayWithContentsOfFile:busPath];
    
    __block NSArray *lines;
    
    [_stations enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([_selectedStation.fid isEqualToString:obj[@"stationId"]]) {
            lines = obj[@"buses"];
            *stop = YES;
        }
    }];
    
    if (!lines) {
        return nil;
    }
    
    __block NSDictionary *route = [NSDictionary dictionary];
    [buses enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([lines[index] isEqualToString:obj[@"routeId"]]) {
            route = obj;
            *stop = YES;
        }
    }];
    
    return route;
}

//添加大头针
-(void)addStationAnnotation {
    for (int i=0; i<_stations.count; i++) {
        NSDictionary *station = _stations[i];
        JDOStationAnnotation *annotation = [[JDOStationAnnotation alloc] init];
        annotation.coordinate = CLLocationCoordinate2DMake([station[@"lat"] doubleValue], [station[@"lon"] doubleValue]);
        annotation.station = station;
        annotation.selected = (i==0);
        annotation.index = i+1;
        annotation.title = @""; //didSelectAnnotationView回调触发必须设置title，设置title后若不想弹出paopao，只能设置空customView
        [_mapView addAnnotation:annotation];
    }
}

//加载所有站点
- (void)loadAllStations {
    NSString *stationsPath = [[NSBundle mainBundle] pathForResource:@"yc_bus_station_list" ofType:@"plist"];
    NSArray *stationArray = [NSArray arrayWithContentsOfFile:stationsPath];
    
    _stations = [NSMutableArray arrayWithArray:stationArray];
    [self.coordinateQuadTree buildTree:_stations];
    
    self.annotations = [self.coordinateQuadTree clusteredAnnotationsWithinMapView:_mapView];
    [self updateMapViewAnnotationsWithAnnotations:self.annotations];
    
    
}

//搜索公交站点
- (void)searchBusPoint {
    BMKCitySearchOption *option = [[BMKCitySearchOption alloc] init];
    
    option.city = @"宜昌市";
    option.keyword = @"公交车站";
    option.pageCapacity = 1;
    option.pageIndex = 0;
    BOOL flag = [self.poiSearch poiSearchInCity:option];
    if (!flag) {
        NSLog(@"城市内检索发生失败！");
    }
    
}

//自定义精度圈
- (void)customLocationAccuracyCircle {
    BMKLocationViewDisplayParam *param = [[BMKLocationViewDisplayParam alloc] init];
    param.accuracyCircleStrokeColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:0.5];
    param.accuracyCircleFillColor = [UIColor colorWithRed:0 green:1 blue:0 alpha:0.3];
    [_mapView updateLocationViewWithParam:param];
}

//普通态
-(void)startLocation
{
    NSLog(@"进入普通定位态");
    _mapView.showsUserLocation = NO;//先关闭显示的定位图层
    [self.locationService startUserLocationService];
    _mapView.showsUserLocation = YES;//显示定位图层
}

//停止定位
-(void)stopLocation
{
    [self.locationService stopUserLocationService];
//    _mapView.showsUserLocation = NO;
}

#pragma mark - private
- (void) searchOrClear:(id)sender {
    if (rightBtnIsSearch) {
        self.navigationItem.rightBarButtonItem.image = [UIImage imageNamed:@"地图-清除"];
    }else{
        self.navigationItem.rightBarButtonItem.image = [UIImage imageNamed:@"地图-搜索"];
    }
    rightBtnIsSearch = !rightBtnIsSearch;
}

- (void)loadData2{
//    FMResultSet *rs = [_db executeQuery:GetAllStationsInfo];
//    while ([rs next]) {
//        JDOStationModel *station = [JDOStationModel new];
//        station.fid = [rs stringForColumn:@"STATIONID"];
//        station.name = [NSString stringWithFormat:@"%@[%@]",[rs stringForColumn:@"STATIONNAME"],[rs stringForColumn:@"DIRECTION"]];
//        station.gpsX = [NSNumber numberWithDouble:[rs doubleForColumn:@"GPSX"]];
//        station.gpsY = [NSNumber numberWithDouble:[rs doubleForColumn:@"GPSY"]];
//        station.attach = [rs intForColumn:@"ATTACH"];
//        [_stations addObject:station];
//    }
//    [rs close];
    // Mark:合并站点
//    AppDelegate *delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
//    NSMutableDictionary *sameIdStationMap = delegate.sameIdStationMap;
//    NSMutableDictionary *sameNameStationMap = delegate.sameNameStationMap;
//    for (int i=0; i<_stations.count; i++) {
//        JDOStationModel *station = _stations[i];
//        JDOStationModel *mapStation1 = (JDOStationModel *)[sameIdStationMap objectForKey:station.fid];
//        JDOStationModel *mapStation2 = (JDOStationModel *)[sameNameStationMap objectForKey:station.name];
//        if (mapStation1) {
//            if (station.attach == mapStation1.attach) {
//                station.linkStations = [mapStation1.linkStations mutableCopy];
//                [combinedStations addObject:station];
//            }
//        }else if(mapStation2){
//            if (station.attach == mapStation2.attach) {
//                station.linkStations = [mapStation2.linkStations mutableCopy];
//                [combinedStations addObject:station];
//            }
//        }else{  // 未映射的站点直接添加
//            [combinedStations addObject:station];
//        }
//    }
//
    combinedStations = [NSMutableArray new];
    
    [self.coordinateQuadTree buildTree:combinedStations];
    [_stations removeAllObjects];
    [combinedStations removeAllObjects];
}


//- (void)mapView:(BMKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
//{
//    [_queryQueue addOperationWithBlock:^{
//        double scale = mapView.bounds.size.width / mapView.visibleMapRect.size.width;
////        NSArray *annotations = [self.coordinateQuadTree clusteredAnnotationsWithinMapRect:mapView.visibleMapRect withZoomScale:scale];
//        NSArray *annotations = [self.coordinateQuadTree clusteredAnnotationsWithinMapView:mapView];
//        [self updateMapViewAnnotationsWithAnnotations:annotations];
//    }];
//}
//
//- (void)mapView:(BMKMapView *)mapView didSelectAnnotationView:(BMKAnnotationView *)view{
//    TBClusterAnnotation *ca = (TBClusterAnnotation *)view.annotation;
//    
//    if (ca.stations.count == 0) {
//
//    }else if(ca.stations.count ==1) {
//        [mapView setCenterCoordinate:view.annotation.coordinate animated:YES];
//        // 若marker上只有一个站点，则不弹出paopaoView，直接打开线路列表
//        _selectedStation = ca.stations[0];
//        [self showLineView];
//    }else{
//        // 选中某个marker后，将此marker移动到地图中心
//        [mapView setCenterCoordinate:view.annotation.coordinate animated:YES];
//        
//        TBClusterAnnotationView *annotationView = (TBClusterAnnotationView *)view;
//        UIView *customView = [annotationView.paopaoView subviews][0];
//        UILabel *title = (UILabel *)[customView viewWithTag:8001];
//        
//        // 多个站点的时候，取位置进行反地理编码填充表格头部
//        BMKReverseGeoCodeOption *reverseGeoCodeSearchOption = [[BMKReverseGeoCodeOption alloc] init];
//        reverseGeoCodeSearchOption.reverseGeoPoint = ca.coordinate;
//        BMKGeoCodeSearch *searcher =[[BMKGeoCodeSearch alloc] init];
//        searcher.delegate = self;
//        searcher.titleLabel = title;
//        BOOL flag = [searcher reverseGeoCode:reverseGeoCodeSearchOption];
//        if(!flag){
//            NSLog(@"反geo检索发送失败");
//        }
//        UITableView *tv = (UITableView *)[customView viewWithTag:8002];
//        [tv scrollsToTop];
//    }
//}
//
//接收反向地理编码结果
//-(void) onGetReverseGeoCodeResult:(BMKGeoCodeSearch *)searcher result: (BMKReverseGeoCodeResult *)result errorCode:(BMKSearchErrorCode)error{
//    if (error == BMK_SEARCH_NO_ERROR) {
////        if (result.poiList.count>0) {
////            searcher.titleLabel.text = [(BMKPoiInfo *)result.poiList[0] name];
////        }else{
//            searcher.titleLabel.text = [[result.addressDetail.district stringByAppendingString:result.addressDetail.streetName] stringByAppendingString:result.addressDetail.streetNumber];
////        }
//    }else{
//        searcher.titleLabel.text = @"无法获取位置信息";
//    }
//    searcher.delegate = nil;
//}
//

//

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
//    if ([tableView isKindOfClass:[JDOPaoPaoTable2 class]]) {
//        JDOPaoPaoTable2 *paopaoTable = (JDOPaoPaoTable2 *)tableView;
//        return paopaoTable.lines.count;
//    }else{
        return [self getBusesCountWithStationId:_selectedStation.fid];
//    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
//    if ([tableView isKindOfClass:[JDOPaoPaoTable2 class]]) {
//        static NSString *lineIdentifier = @"lineIdentifier";
//        
//        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:lineIdentifier];
//        if( cell == nil){
//            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:lineIdentifier];
//            cell.selectionStyle = UITableViewCellSelectionStyleNone;
//            
//            UILabel *lineLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 0, CGRectGetWidth(tableView.frame)-10, PaoPaoLineHeight)];
//            lineLabel.backgroundColor = [UIColor clearColor];
//            lineLabel.font = [UIFont systemFontOfSize:14];
//            lineLabel.minimumFontSize = 12;
//            lineLabel.numberOfLines = 1;
//            lineLabel.adjustsFontSizeToFitWidth = true;
//            lineLabel.textColor = [UIColor colorWithRed:110/255.0f green:110/255.0f blue:110/255.0f alpha:1];
//            lineLabel.tag = 3001;
//            [cell addSubview:lineLabel];
//        }
//        if (indexPath.row%2 == 0) {
//            cell.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"弹出列表02"]];
//        }else{
//            cell.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"弹出列表03"]];
//        }
//        
//        UILabel *lineLabel = (UILabel *)[cell viewWithTag:3001];
//        
//        JDOPaoPaoTable2 *paopaoTable = (JDOPaoPaoTable2 *)tableView;
//        NSArray *paopaoLines = paopaoTable.lines;
//        NSDictionary *station = paopaoLines[indexPath.row];
//        lineLabel.text = station[@"stationName"];
//        
//        return cell;
//    }else{
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"stationLine"]; // forIndexPath:indexPath];
        if (indexPath.row%2==0) {
            cell.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"隔行1"]];
        }else{
            cell.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"隔行2"]];
        }
    
        NSDictionary *line = [self getSelectedStationLineWithIdx:indexPath.row];
        [(UILabel *)[cell viewWithTag:1001] setText:line[@"routeName"]];
        [(UILabel *)[cell viewWithTag:1002] setText:[NSString stringWithFormat:@"%@-%@",line[@"start"],line[@"end"]]];
        [[cell viewWithTag:1004] setHidden:(indexPath.row == _selectedStation.passLines.count-1)];  //最后一行不显示分割线
        return cell;
//    }
}

//- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
//    if ([tableView isKindOfClass:[JDOPaoPaoTable2 class]]) {
//        return nil;
//    }else{
//        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 320, 15)];
//        iv.image = [UIImage imageNamed:@"表格圆角上"];
//        return iv;
//    }
//}
//
//- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section{
//    if ([tableView isKindOfClass:[JDOPaoPaoTable2 class]]) {
//        return nil;
//    }else{
//        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 320, 15)];
//        iv.image = [UIImage imageNamed:@"表格圆角下"];
//        return iv;
//    }
//}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    if ([tableView isKindOfClass:[JDOPaoPaoTable2 class]]) {
        JDOPaoPaoTable2 *paopaoTable = (JDOPaoPaoTable2 *)tableView;
        _selectedStation = [paopaoTable.lines objectAtIndex:indexPath.row];
        [self showLineView];
    }
}

- (void) showLineView{
    
#if 0
    _selectedStation.passLines = [NSMutableArray new];
    // 根据站点id查询通过的线路，并实时刷新最近的车辆
    int count = 0;
    FMResultSet *rs = [_db executeQuery:GetLinesByStation,_selectedStation.fid,@(_selectedStation.attach)];
    while ([rs next]) {
        JDOBusLine *busLine = [JDOBusLine new];
        [_selectedStation.passLines addObject:busLine];
        busLine.lineId = [rs stringForColumn:@"LINEID"];
        busLine.lineName = [rs stringForColumn:@"LINENAME"];
        busLine.zhixian = [rs intForColumn:@"ZHIXIAN"];
        busLine.attach = [rs intForColumn:@"ATTACH"];
        busLine.lineDetailPair = [NSMutableArray new];
        
        JDOBusLineDetail *lineDetail = [JDOBusLineDetail new];
        [busLine.lineDetailPair addObject:lineDetail];
        lineDetail.detailId = [rs stringForColumn:@"LINEDETAILID"];
        lineDetail.lineDetail = [rs stringForColumn:@"LINEDETAIL"];
        lineDetail.direction = [rs stringForColumn:@"LINEDIRECTION"];
        lineDetail.attach = [rs intForColumn:@"ATTACH"];
        
        count++;
    }
    [rs close];
    
    // Mark:合并站点
    // 遍历linkStation，把其对应的线路也增加到主站对应的passLines中
    if (!_selectedStation.linkStations) {
        AppDelegate *delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        NSMutableDictionary *sameIdStationMap = delegate.sameIdStationMap;
        JDOStationModel *mapStation = (JDOStationModel *)[sameIdStationMap objectForKey:_selectedStation.fid];
        if (mapStation) {
            if (_selectedStation.attach == mapStation.attach) {
                _selectedStation.linkStations = [mapStation.linkStations mutableCopy];
            }
        }
    }
    for (int i=0; i<_selectedStation.linkStations.count; i++) {
        JDOStationModel *linkStation = (JDOStationModel *)_selectedStation.linkStations[i];
        FMResultSet *rs = [_db executeQuery:GetLinesByStation,linkStation.fid, @(linkStation.attach)];
        while ([rs next]) {
            JDOBusLine *busLine = [JDOBusLine new];
            busLine.lineId = [rs stringForColumn:@"LINEID"];
            busLine.lineName = [rs stringForColumn:@"LINENAME"];
            busLine.zhixian = [rs intForColumn:@"ZHIXIAN"];
            busLine.attach = [rs intForColumn:@"ATTACH"];
            
            JDOBusLineDetail *lineDetail = [JDOBusLineDetail new];
            lineDetail.detailId = [rs stringForColumn:@"LINEDETAILID"];
            lineDetail.lineDetail = [rs stringForColumn:@"LINEDETAIL"];
            lineDetail.direction = [rs stringForColumn:@"LINEDIRECTION"];
            lineDetail.attach = [rs intForColumn:@"ATTACH"];
            busLine.lineDetailPair = [@[lineDetail] mutableCopy];
            
            [_selectedStation.passLines addObject:busLine];
        }
        [rs close];
    }
    if (_selectedStation.passLines.count >0) {
        // 按名称排序线路，不排序的话，attach大的总是在后面
        [_selectedStation.passLines sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            JDOBusLine *line1 = (JDOBusLine *)obj1;
            JDOBusLine *line2 = (JDOBusLine *)obj2;
            NSComparisonResult result = [line1.lineName compare:line2.lineName options:NSNumericSearch];
            if (result != NSOrderedSame) {
                return result;
            }
            JDOBusLineDetail *detail1 = line1.lineDetailPair[0];
            JDOBusLineDetail *detail2 = line2.lineDetailPair[0];
            return [detail1.direction compare:detail2.direction];
        }];
    }
#endif
    
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
//    [self.tableView reloadData];
//    
    self.stationLabel.text = _selectedStation.name;
    self.closeBtn.hidden = false;
    
    NSInteger busCount = [self getBusesCountWithStationId:_selectedStation.fid];
    
    [UIView animateWithDuration:0.25f animations:^{
        float height = 56+36*MIN(busCount,4);
        self.lineView.frame = CGRectMake(10, CGRectGetHeight(self.view.bounds)-height, 300, height);
        self.tableView.frame = CGRectMake(0, 49, 300, 36*MIN(busCount,4));
    } completion:^(BOOL finished) {
        
    }];
    
}

- (void)closeLineView{
    [UIView animateWithDuration:0.25f animations:^{
        self.lineView.frame = CGRectMake(10, CGRectGetHeight(self.view.bounds)-44, 300, 44);
    } completion:^(BOOL finished) {
        self.stationLabel.text = @"请选择站点";
//        self.busMonitor.hidden = true;
        self.closeBtn.hidden = true;
    }];
    
    [self.mapView deselectAnnotation:_selectedAnnotation animated:YES];
    self.selectedAnnotation = nil;
}

- (void)switchMonitor{
    for (UITableViewCell *cell in [self.tableView visibleCells]){
        [[cell viewWithTag:1003] setHidden:!self.busMonitor.on];
    }
    // 停止计时器
}



// ========================================================================

//- (void)loadData{
//    _stations = [NSMutableArray new];
//    FMResultSet *rs = [_db executeQuery:GetStationsWithLinesByName,self.stationName];
//    JDOStationModel *preStation;
//    while ([rs next]) {
//        JDOStationModel *station;
//        // 相同id的站点的线路填充到station中
//        NSString *stationId = [rs stringForColumn:@"STATIONID"];
//        if (preStation && [stationId isEqualToString:preStation.fid]) {
//            station = preStation;
//        }else{
//            station = [JDOStationModel new];
//            station.fid = [rs stringForColumn:@"STATIONID"];
//            station.name = [rs stringForColumn:@"STATIONNAME"];
//            station.gpsX = [NSNumber numberWithDouble:[rs doubleForColumn:@"GPSX"]];
//            station.gpsY = [NSNumber numberWithDouble:[rs doubleForColumn:@"GPSY"]];
//            station.passLines = [NSMutableArray new];
//            
//            [_stations addObject:station];
//            preStation = station;
//        }
//        JDOBusLine *busLine = [JDOBusLine new];
//        [station.passLines addObject:busLine];
//        busLine.lineId = [rs stringForColumn:@"BUSLINEID"];
//        busLine.lineName = [rs stringForColumn:@"BUSLINENAME"];
//        busLine.lineDetailPair = [NSMutableArray new];
//        
//        JDOBusLineDetail *lineDetail = [JDOBusLineDetail new];
//        [busLine.lineDetailPair addObject:lineDetail];
//        lineDetail.detailId = [rs stringForColumn:@"LINEDETAILID"];
//        lineDetail.lineDetail = [rs stringForColumn:@"BUSLINEDETAIL"];
//        lineDetail.direction = [rs stringForColumn:@"DIRECTION"];
//    }
//    selectedStation = _stations[0];
//    _stationLabel.text = selectedStation.name;
//    [_tableView reloadData];
//    
//    if(_stations.count > 2){
//        _mapView.zoomLevel = 16;
//    }else{
//        _mapView.zoomLevel = 18;
//    }
//    [self setMapCenter];
//    [self addStationAnnotation];
//}
//
//- (void) setMapCenter{
//    // 将地图的中心定位到所有站点的中心。所有站点的经纬度大致范围应该是北纬37-38，东经121-122
//    double minX = 180, minY = 180, maxX = 0, maxY = 0;
//    for (int i=0; i<_stations.count; i++) {
//        JDOStationModel *station = _stations[i];
//        if (station.gpsX.doubleValue < minX) {
//            minX = station.gpsX.doubleValue;
//        }
//        if(station.gpsX.doubleValue > maxX ){
//            maxX = station.gpsX.doubleValue;
//        }
//        if (station.gpsY.doubleValue < minY) {
//            minY = station.gpsY.doubleValue;
//        }
//        if(station.gpsY.doubleValue > maxY ){
//            maxY = station.gpsY.doubleValue;
//        }
//    }
//    _mapView.centerCoordinate = CLLocationCoordinate2DMake( (maxY+minY)/2, (maxX+minX)/2);
//}
//
//-(void)addStationAnnotation{
//    for (int i=0; i<_stations.count; i++) {
//        JDOStationModel *station = _stations[i];
//        JDOStationAnnotation *annotation = [[JDOStationAnnotation alloc] init];
//        annotation.coordinate = CLLocationCoordinate2DMake(station.gpsY.doubleValue, station.gpsX.doubleValue);
//        annotation.station = station;
//        annotation.selected = (i==0);
//        annotation.index = i+1;
//        annotation.title = @""; //didSelectAnnotationView回调触发必须设置title，设置title后若不想弹出paopao，只能设置空customView
//        [_mapView addAnnotation:annotation];
//    }
//}
//
//- (BMKAnnotationView *)mapView:(BMKMapView *)mapView viewForAnnotation:(id <BMKAnnotation>)annotation{
//    static NSString *AnnotationViewID = @"annotationView";
//    BMKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:AnnotationViewID];
//    if (!annotationView) {
//        annotationView = [[BMKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:AnnotationViewID];
//        annotationView.centerOffset = CGPointMake(0, -16);
//        annotationView.paopaoView = [[BMKActionPaopaoView alloc] initWithCustomView:[[UIView alloc] initWithFrame:CGRectZero]];
//    }else{
//        annotationView.annotation = annotation;
//    }
//    JDOStationAnnotation *sa = (JDOStationAnnotation *)annotation;
//    if (sa.selected) {
//        annotationView.image = [UIImage imageNamed:[NSString stringWithFormat:@"地图标注蓝%d",sa.index]];
//    }else{
//        annotationView.image = [UIImage imageNamed:[NSString stringWithFormat:@"地图标注红%d",sa.index]];
//    }
//    return annotationView;
//}
//
//- (void)mapView:(BMKMapView *)mapView didSelectAnnotationView:(BMKAnnotationView *)view{
//    JDOStationAnnotation *sa = view.annotation;
//    sa.selected = true;
//    view.image = [UIImage imageNamed:[NSString stringWithFormat:@"地图标注蓝%d",sa.index]];
//    for(JDOStationAnnotation *other in _mapView.annotations){
//        if(other != sa){
//            other.selected = false;
//            [_mapView viewForAnnotation:other].image = [UIImage imageNamed:[NSString stringWithFormat:@"地图标注红%d",other.index]];
//        }
//    }
//    selectedStation = sa.station;
//    _stationLabel.text = selectedStation.name;
//    [_tableView reloadData];
//}


- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    if (tableView == self.tableView) {
        selectedIndexPath = indexPath;
    }
    return indexPath;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"toRealtimeFromStation"]) {
        JDORealTimeController *rt = segue.destinationViewController;
        
        JDOBusLine *busLine = [[JDOBusLine alloc]init];
        NSDictionary *line = [self getSelectedStationLineWithIdx:selectedIndexPath.row];
        busLine.lineId = line[@"routeId"];
        busLine.lineName = line[@"routeName"];
        busLine.stationA = line[@"start"];
        busLine.stationB = line[@"end"];
        
        rt.busLine = busLine;
        rt.busLine.zhixian = busLine.zhixian;
        rt.busLine.attach = busLine.attach;
    }
    
    if ([segue.identifier isEqualToString:@"toStationSearch"]) {
        JDOStationController *stationController = segue.destinationViewController;
        stationController.delegate = self;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
