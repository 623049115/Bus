//
//  AppDelegate.m
//  YTBus
//
//  Created by zhang yi on 14-10-17.
//  Copyright (c) 2014年 胶东在线. All rights reserved.
//

#import "AppDelegate.h"
#import "JDOConstants.h"
#import "iVersion.h"
#import "Reachability.h"
#import "JSONKit.h"
#import "MBProgressHUD.h"
#import "JDOHttpClient.h"
#import "UMFeedback.h"
#import "IQKeyboardManager.h"

// ShareSDK
#import <ShareSDK/ShareSDK.h>
#import <TencentOpenAPI/QQApiInterface.h>
#import <TencentOpenAPI/TencentOAuth.h>
#import "WXApi.h"
#import "WeiboSDK.h"
#import <QZoneConnection/ISSQZoneApp.h>


#import "JDOStartupController.h"
#import "JDOAlertTool.h"
#import "JDODatabase.h"
#import "JDOStationModel.h"
#import "AESUtil.h"

#define Adv_Min_Show_Seconds 2.0f
#define Param_Max_Wait_Seconds 5.0f

@interface AppDelegate (){
//    BMKOfflineMap* _offlineMap;
}

@end

@implementation AppDelegate{
    BOOL canEnterMain;
    __strong JDOStartupController *controller;
    UIImage *advImage;
    BOOL checkVersionFinished;
    BOOL showAdvFinished;
    MBProgressHUD *hud;
    __strong JDOAlertTool *alert;
    id dbObserver;
}

+ (void)initialize{
    //发布时替换bundleId,注释掉就可以
//    [iVersion sharedInstance].applicationBundleID = @"com.jiaodong.JiaodongOnlineNews";
//    [iVersion sharedInstance].applicationVersion = @"3.5.0";
    
    [iVersion sharedInstance].verboseLogging = false;   // 调试信息
    [iVersion sharedInstance].appStoreCountry = @"CN";
    [iVersion sharedInstance].showOnFirstLaunch = false; // 不显示当前版本特性
    [iVersion sharedInstance].checkAtLaunch = NO;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    canEnterMain = false;
    checkVersionFinished = false;
    _realtimeRequestCount = 0;
    
    // 百度地图配置
    [self initBMKConfig];
    // 全局样式定义
    [self initAppearance];
    
    // 使用LaunchImage作为背景占位图，如果从友盟检测到的最小允许版本高于当前版本，则不进入storyboard，直接退出应用或进入appstore下载
    controller = [[JDOStartupController alloc] init];
    if (Screen_Height > 480) {
        controller.view = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"LaunchImage-568h"]];
    }else{
        controller.view = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"LaunchImage"]];
    }
    controller.view.frame = [[UIScreen mainScreen] bounds];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    
    [[IQKeyboardManager sharedManager] setEnable:false];
    [[IQKeyboardManager sharedManager] setEnableAutoToolbar:false];
    [[IQKeyboardManager sharedManager] setShouldResignOnTouchOutside:true];
    
    checkVersionFinished = true;
    canEnterMain = YES;
    [self enterMainStoryboard];
    
    return YES;
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    return [ShareSDK handleOpenURL:url wxDelegate:self];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    return [ShareSDK handleOpenURL:url sourceApplication:sourceApplication annotation:annotation wxDelegate:self];
}

- (void) initBMKConfig{
    // 要使用百度地图，请先启动BaiduMapManager
//    _mapManager = [[BMKMapManager alloc]init];
//    BOOL ret = [_mapManager start:@"BI3iLNMvqHHWiELxAi5kkbn2" generalDelegate:self];
//    if (!ret) {
//        NSLog(@"manager start failed!");
//    }else{
//        [BMKLocationService setLocationDesiredAccuracy:kCLLocationAccuracyBestForNavigation];
//        [BMKLocationService setLocationDistanceFilter:kCLDistanceFilterNone];//kCLDistanceFilterNone,Location_Auto_Refresh_Distance
//    }
}

- (void) initAppearance{
//    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
    if (After_iOS7) {
        // 若设置该选项=false，则self.view的origin.y从导航栏以下开始计算，否则从屏幕顶端开始计算，
        // 这是因为iOS7的controller中extendedLayoutIncludesOpaqueBars属性默认是false，也就是说不透明的bar不启用extendedLayout，
        // 若背景是半透明的情况下，也可以通过设置controller的edgesForExtendedLayout使view从导航栏下方开始计算
        
        // iOS7未实现translucent的appearance，iOS8以后可用，已经改为在所有的storyboard中的navigationbar中设置该属性
//        [[UINavigationBar appearance] setTranslucent:false];
        [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
        [[UINavigationBar appearance] setBackgroundImage:[UIImage imageNamed:@"navigation_iOS7"] forBarMetrics:UIBarMetricsDefault];
        [[UIBarButtonItem appearance] setTintColor:[UIColor whiteColor]];
    }else{
        [[UINavigationBar appearance] setBackgroundImage:[UIImage imageNamed:@"navigation_iOS6"] forBarMetrics:UIBarMetricsDefault];
        [[UIBarButtonItem appearance] setTintColor:[UIColor colorWithHex:@"233247"]];
    }
    //    UITextAttributeFont,UITextAttributeTextShadowOffset,UITextAttributeTextShadowColor
    [[UINavigationBar appearance] setTitleTextAttributes: @{UITextAttributeTextColor:[UIColor whiteColor]}];
    [[UISegmentedControl appearanceWhenContainedIn:[UISearchBar class], nil] setTintColor:[UIColor whiteColor]];
}


/*
１.　当程序处于关闭状态收到推送消息时，点击图标会调用- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions　这个方法，那么消息给通过launchOptions这个参数获取到。
２.　当程序处于前台工作时，这时候若收到消息推送，会调用- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo这个方法
３.　当程序处于后台运行时，这时候若收到消息推送，如果点击消息或者点击消息图标时，也会调用- (void)application:(UIApplication*)application didReceiveRemoteNotification:(NSDictionary *)userInfo这个方法
４.　当程序处于后台运行时，这时候若收到消息推送，如果点击桌面应用图标，则不会调用didFinishLaunchingWithOptions和didReceiveRemoteNotification方法，所以无法获取消息
*/



// 从后台获取在线参数，友盟的在线参数有如下几个问题：
// 1.网络丢包率高的情况下，请求超时时间太长，会导致界面卡在版本检查的地方
// 2.[MobClick getAdURL]同样会触发该回调，若被调用过早，会导致逻辑错乱
// 3.在客户端同样的网络情况下，响应时间不稳定。
// 4.程序在前台运行阶段，应该按一定的时间间隔检查最低版本，以防止在启动时由于网络差或者暂时关闭网络导致跳过版本检查。

// 新的在线参数在notification.userInfo中，可能是从网络获取的，也可能是本地缓存在NSUserDefault中的
//- (void)UMOnlineConfigDidFinished:(NSNotification *)noti{
//    onlineParam = (NSDictionary *)noti.userInfo;
//    [self onVersionCheckFinished];
//    // 加载完成后即移除该观察者，否则获取广告的[MobClick getAdURL]会引起该回调再次被执行
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:UMOnlineConfigDidFinishedNotification object:nil];
//}

- (void) onVersionCheckFinished:(BOOL)success{
    checkVersionFinished = true;
    if (hud) {
        [hud hide:true];
    }
    
    canEnterMain = true;
}

- (void)enterMainStoryboard{
    [UIApplication sharedApplication].statusBarHidden = false;
    // 保证只被执行一次
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            UIStoryboard * storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
            UIView *previousView = self.window.rootViewController.view;
            self.window.rootViewController = [storyBoard instantiateInitialViewController];
            [self.window.rootViewController.view addSubview:previousView];
            [UIView animateWithDuration:0.25f animations:^{
                CGRect frame = previousView.frame;
                previousView.frame = CGRectMake(-frame.size.width*0.5f,-frame.size.height*0.5f,frame.size.width*2,frame.size.height*2);
                previousView.alpha = 0;
            } completion:^(BOOL finished) {
                [previousView removeFromSuperview];
            }];
        });
    });
}

//- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
//    if (notificationSettings.types != UIUserNotificationTypeNone) {
//        [application registerForRemoteNotifications];
//    }
//}
//
//
//- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
//
//}
//
//- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
//
//}

//- (void)application:(UIApplication *)applicatio didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler{
//    
//}

//- (void)application:(UIApplication *)applicatio didReceiveRemoteNotification:(NSDictionary *)userInfo {
//    
//}


//- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler{
//    NSLog(@"执行抓取，时间是：%@",[NSDate date]);
//    // 获取数据，并执行viewController的刷新界面方法，根据获取的结果调用completionHandler
//    UIView *view = (UIView *)[[[(UITabBarController *)[((AppDelegate *)application.delegate).window rootViewController] viewControllers][0] topViewController] view];
//    view.backgroundColor = [UIColor colorWithRed:arc4random()%255/255.0f green:arc4random()%255/255.0f blue:arc4random()%255/255.0f alpha:1.0f];
//    completionHandler(UIBackgroundFetchResultNewData);
//}

- (void)applicationWillResignActive:(UIApplication *)application {
    //[BMKMapView willBackGround];//当应用即将后台时调用，停止一切调用opengl相关的操作
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    //[BMKMapView didForeGround];//当应用恢复前台状态时调用，回复地图的渲染和opengl相关的操作
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)onGetNetworkState:(int)iError {
    if (0 == iError) {
        NSLog(@"联网成功");
    }else{
        NSLog(@"onGetNetworkState %d",iError);
    }
}

- (void)onGetPermissionState:(int)iError {
    if (0 == iError) {
        NSLog(@"授权成功");
    }else {
        NSLog(@"onGetPermissionState %d",iError);
    }
}

// Mark:合并站点
- (void) mappingSameStation{
    // 合并同id且距离小于100米的站点
    self.sameIdStationMap = [NSMutableDictionary new];
    FMDatabase *db = [JDODatabase sharedDB];
    FMResultSet *rs = [db executeQuery:GetStationsSameId];
    while ([rs next]) {
        // 相同的gpsx2，gpsy2转换到mapx，mapy以后可能在第四位以后出现误差，所以先用字符串类型的gpsx2，gpsy2进行对比
        NSString *gpsx1 = [rs stringForColumn:@"gpsx1"];
        NSString *gpsx2 = [rs stringForColumn:@"gpsx2"];
        NSString *gpsy1 = [rs stringForColumn:@"gpsy1"];
        NSString *gpsy2 = [rs stringForColumn:@"gpsy2"];
        double mapx1 = [rs doubleForColumn:@"mapx1"];
        double mapx2 = [rs doubleForColumn:@"mapx2"];
        double mapy1 = [rs doubleForColumn:@"mapy1"];
        double mapy2 = [rs doubleForColumn:@"mapy2"];
//        
//        if (![gpsx1 isEqualToString:gpsx2] || ![gpsy1 isEqualToString:gpsy2]) {
//            CLLocationCoordinate2D coor1 = CLLocationCoordinate2DMake(mapy1, mapx1);
//            CLLocationCoordinate2D coor2 = CLLocationCoordinate2DMake(mapy2, mapx2);
//            // 转化为直角坐标测距
//            CLLocationDistance distance = BMKMetersBetweenMapPoints(BMKMapPointForCoordinate(coor1),BMKMapPointForCoordinate(coor2));
//            if (distance > 100){
//                continue;
//            }
//        }
        
        NSString *sid = [rs stringForColumn:@"id"];
        JDOStationModel *station = [self.sameIdStationMap objectForKey:sid];
        if (!station) {
            station = [JDOStationModel new];
            station.fid = sid;
            station.name = [rs stringForColumn:@"name1"];
            station.direction = [rs stringForColumn:@"direction1"];
            station.attach = [rs intForColumn:@"attach1"];
            station.gpsX = @(mapx1);
            station.gpsY = @(mapy1);
            station.linkStations = [NSMutableArray new];
            
            [self.sameIdStationMap setObject:station forKey:sid];
        }
        int attach2 = [rs intForColumn:@"attach2"];
        // 若增加福山区attach = 3，则三个相同id不同attach的站点会由三种组合12、13、23，为了防止3被添加2次，添加之前先遍历去重
        BOOL hasLinked = false;
        for (int i=0; i<station.linkStations.count; i++) {
            JDOStationModel *linkStation = station.linkStations[i];
            if (linkStation.attach == attach2) {
                hasLinked = true;
                break;
            }
        }
        if (!hasLinked) {
            JDOStationModel *linkStation = [JDOStationModel new];
            linkStation.fid = sid;
            linkStation.attach = attach2;
            [station.linkStations addObject:linkStation];
        }
    }
    [rs close];
    
    // 合并同名同方向且距离小于100米的站点
    self.sameNameStationMap = [NSMutableDictionary new];
    rs = [db executeQuery:GetStationsSameName];
    while ([rs next]) {
        double mapx1 = [rs doubleForColumn:@"mapx1"];
        double mapx2 = [rs doubleForColumn:@"mapx2"];
        double mapy1 = [rs doubleForColumn:@"mapy1"];
        double mapy2 = [rs doubleForColumn:@"mapy2"];
//        
//        CLLocationCoordinate2D coor1 = CLLocationCoordinate2DMake(mapy1, mapx1);
//        CLLocationCoordinate2D coor2 = CLLocationCoordinate2DMake(mapy2, mapx2);
//        // 转化为直角坐标测距
//        CLLocationDistance distance = BMKMetersBetweenMapPoints(BMKMapPointForCoordinate(coor1),BMKMapPointForCoordinate(coor2));
//        if (distance > 100){
//            continue;
//        }
        
        NSString *name = [rs stringForColumn:@"name"];
        NSString *direction = [rs stringForColumn:@"direction"];
        NSString *key = [NSString stringWithFormat:@"%@[%@]",name,direction];
        JDOStationModel *station = [self.sameNameStationMap objectForKey:key];
        if (!station) {
            station = [JDOStationModel new];
            station.fid = [rs stringForColumn:@"id1"];
            station.name = name;
            station.direction = direction;
            station.attach = [rs intForColumn:@"attach1"];
            station.gpsX = @(mapx1);
            station.gpsY = @(mapy1);
            station.linkStations = [NSMutableArray new];
            
            [self.sameNameStationMap setObject:station forKey:key];
        }
        int attach2 = [rs intForColumn:@"attach2"];
        // 若增加福山区attach = 3，则三个相同id不同attach的站点会由三种组合12、13、23，为了防止3被添加2次，添加之前先遍历去重
        BOOL hasLinked = false;
        for (int i=0; i<station.linkStations.count; i++) {
            JDOStationModel *linkStation = station.linkStations[i];
            if (linkStation.attach == attach2) {
                hasLinked = true;
                break;
            }
        }
        if (!hasLinked) {
            JDOStationModel *linkStation = [JDOStationModel new];
            linkStation.fid = [rs stringForColumn:@"id2"];;
            linkStation.attach = attach2;
            [station.linkStations addObject:linkStation];
        }
    }
    [rs close];
}

@end
