//
//  JDOStartupController.m
//  YTBus
//
//  Created by zhang yi on 15-4-9.
//  Copyright (c) 2015年 胶东在线. All rights reserved.
//

#import "JDOStartupController.h"
#import "JDODatabase.h"
#import "AFNetworking.h"
#import "SSZipArchive.h"
#import "MBProgressHUD.h"
#import "JDOConstants.h"
#import "JDOHttpClient.h"
#import "AppDelegate.h"
#import "JSONKit.h"
#import "JDOAlertTool.h"
#import "Reachability.h"

@interface JDOStartupController () <SSZipArchiveDelegate,NSXMLParserDelegate> {
    MBProgressHUD *hud;
    NSURLConnection *_connection;
    NSMutableData *_webData;
    NSMutableString *_jsonResult;
    BOOL isRecording;
    int remoteDBVersion;
    __strong JDOAlertTool *alert;
}

@end

@implementation JDOStartupController

- (void)showUpdateLog{
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey];
    NSString *key = [NSString stringWithFormat:@"JDO_Showed_UpdateLog_V%@",version];
    BOOL hadShowed = [[NSUserDefaults standardUserDefaults] boolForKey:key];
    if (!hadShowed) {
        [[NSUserDefaults standardUserDefaults] setBool:true forKey:key];
        NSString *title = @"V2.0版本更新日志";
        if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_7_1) {
            NSString *msg = @"\n1、增加开发区公交线路、站点、以及车辆实时数据。\n2、降低数据包更新频率为每周一次，wifi环境下静默更新。\n3、修正始末班车时间不准确、显示不开的问题。\n4、修正部分车辆实时数据的错误、遗漏。\n5、附近：移除有歧义的站点距离信息，增加周边信息。\n6、线路实时：增加自动刷新提醒、手动刷新按钮。";;
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.alignment = NSTextAlignmentLeft;
            paragraphStyle.lineSpacing = 2.0;
            
            NSDictionary * attributes = @{NSFontAttributeName:[UIFont systemFontOfSize:14.0],NSParagraphStyleAttributeName:paragraphStyle};
            NSMutableAttributedString *attributedTitle = [[NSMutableAttributedString alloc] initWithString:msg];
            [attributedTitle addAttributes:attributes range:NSMakeRange(0, msg.length)];
            [alertController setValue:attributedTitle forKey:@"attributedMessage"];//attributedTitle\attributedMessage
            
            [alertController addAction:[UIAlertAction actionWithTitle:@"我知道了" style: UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self checkDBInfo];
            }]];
            [self presentViewController:alertController animated: YES completion: nil];
        }else{  // TODO iOS7没测试，应该没什么问题，有空可以尝试用SDCAlertView替换
            NSString *message = @"1、增加开发区公交线路、站点、以及车辆实时数据。\n2、降低数据包更新频率为每周一次，wifi环境下静默更新。\n3、修正始末班车时间不准确、显示不开的问题。\n4、修正部分车辆实时数据的错误、遗漏。\n5、附近：移除有歧义的站点距离信息，增加周边信息。\n6、线路实时：增加自动刷新提醒、手动刷新按钮。";
            UIAlertView *tmpAlertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:@"我知道了" otherButtonTitles:nil];
            if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1){
                message = @"     1、增加开发区公交线路、站点、以及车辆实时数据。\n     2、降低数据包更新频率为每周一次，wifi环境下静默更新。\n     3、修正始末班车时间不准确、显示不开的问题。\n     4、修正部分车辆实时数据的错误、遗漏。\n     5、附近：移除有歧义的站点距离信息，增加周边信息。\n     6、线路实时：增加自动刷新提醒、手动刷新按钮。\n";
                CGSize size = [message sizeWithFont:[UIFont systemFontOfSize:14] constrainedToSize:CGSizeMake(240, 999) lineBreakMode:NSLineBreakByTruncatingTail];
                
                UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 240, size.height)];
                textLabel.font = [UIFont systemFontOfSize:14];
                textLabel.textColor = [UIColor blackColor];
                textLabel.backgroundColor = [UIColor clearColor];
                textLabel.lineBreakMode = NSLineBreakByWordWrapping;
                textLabel.numberOfLines = 0;
                textLabel.textAlignment = NSTextAlignmentLeft;
                textLabel.text = message;
                [tmpAlertView setValue:textLabel forKey:@"accessoryView"];
                //这个地方别忘了把alertview的message设为空
                tmpAlertView.message = @"";
            }
            [tmpAlertView show];
        }
    }else{
        [self checkDBInfo];
    }
}

- (void) willPresentAlertView:(UIAlertView *)alertView{
    //在ios7.0一下版本这个方法是可以的
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1){
        //由于不希望标题也居左
        NSInteger labelIndex = 1;
        for (UIView *subView in alertView.subviews){
            if ([subView isKindOfClass: [UILabel class]]){
                if (labelIndex > 1){
                    UILabel *tmpLabel = (UILabel *)subView;
                    tmpLabel.textAlignment = NSTextAlignmentLeft;
                }
                //过滤掉标题
                labelIndex ++;
            }
        }
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if (buttonIndex == 0) {
        [self checkDBInfo];
    }
}

- (void)checkDBInfo {
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey];
    NSString *key = [NSString stringWithFormat:@"JDO_OverrideDB_V%@",version];
    BOOL hadOverrided = [[NSUserDefaults standardUserDefaults] boolForKey:key];
    if (!hadOverrided) {
        // 新版本的App如果是从旧版本升级来的，那么Document目录中会保存有旧版本的bus.db，如果这里不强制覆盖，用户在升级提醒的时候还选择忽略，则会导致App使用旧版本的db文件，出现错误。所以这种情况下，先将Document目录中的bus.db文件删除，之后的逻辑就跟新安装一样了
        BOOL success = [JDODatabase deleteOldDbInDocument];
        if ( success) {
            [[NSUserDefaults standardUserDefaults] setBool:true forKey:key];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
    
    if (![JDODatabase isDBExistInDocument]) {   // 若document中不存在数据库文件，则下载数据库文件
        hud = [MBProgressHUD showHUDAddedTo:self.view animated:true];
        hud.minShowTime = 1.0f;
        hud.labelText = @"下载最新数据";
        [self downloadSQLite_ifFailedUse:1];
    }else{
        //检查是否有数据更新
        hud = [MBProgressHUD showHUDAddedTo:self.view animated:true];
        hud.minShowTime = 1.0f;
        hud.labelText = @"检查数据更新";
        
        NSString *soapMessage = GetDbVersion_SOAP_MSG;
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:GetDbVersion_SOAP_URL] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:URL_Request_Timeout];
        [request addValue:@"text/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
        [request addValue:[NSString stringWithFormat:@"%ld",[soapMessage length]] forHTTPHeaderField:@"Content-Length"];
        [request addValue:@"http://service.epf/getAppVersion" forHTTPHeaderField:@"SOAPAction"];
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:[soapMessage dataUsingEncoding:NSUTF8StringEncoding]];
        
        _connection = [NSURLConnection connectionWithRequest:request delegate:self];
        _webData = [NSMutableData data];
    }
    
    
    // ===============test===============
//    [JDODatabase openDB:1 force:true];
//    [self enterMainStoryboard:true];
    // ===============test===============
}

- (void)downloadSQLite_ifFailedUse:(int) which{
    [[JDOHttpClient sharedDFEClient] getPath:Download_Action parameters:@{@"method":@"downloadNewDb"} success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"下载完成，开始保存");
        NSData *zipData = (NSData *)responseObject;
        BOOL success = [JDODatabase saveZipFile:zipData];
        if ( success) { // 解压缩文件
            NSLog(@"保存完成，开始解压");
            BOOL result = [JDODatabase unzipDBFile:self];
            if (!result) {  // 正在解压
                [self hideHUDWithError:@"解压数据出错" useWhich:which];
            }
        }else{
            [self hideHUDWithError:@"保存数据出错" useWhich:which];
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self hideHUDWithError:@"连接服务器出错" useWhich:which];
    }];
}

- (void)hideHUDWithError:(NSString *)info useWhich:(int) which{
    [hud hide:true];
    
    alert = [[JDOAlertTool alloc] init];
    [alert showAlertView:self title:info message:@"将使用历史数据包，数据可能不准确。" cancelTitle:@"确定" otherTitle1:nil otherTitle2:nil cancelAction:^{
        [self enterMainStoryboard:false];
    } otherAction1:nil otherAction2:nil];

    [JDODatabase openDB:which];
}

- (void) enterMainStoryboard:(BOOL) delay{
    AppDelegate *delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    if (delay) {
        [hud hide:true afterDelay:1.0f];
        [delegate performSelector:@selector(enterMainStoryboard) withObject:nil afterDelay:1.0f];
    }else{
        [hud hide:true];
        [delegate enterMainStoryboard];
    }
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
    [_webData appendData:data];
}


//TODO 服务器错误的格式
/*
 <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><soap:Body><soap:Fault><faultcode>soap:Client</faultcode><faultstring>Fault: java.lang.NullPointerException</faultstring></soap:Fault></soap:Body></soap:Envelope>
*/
-(void)connectionDidFinishLoading:(NSURLConnection *)connection{
    NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData: _webData];
    [xmlParser setDelegate: self];
    [xmlParser parse];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
    hud.mode = MBProgressHUDModeText;
    hud.labelText = @"连接服务器出错";
    hud.detailsLabelText = error.localizedDescription;
    
    [JDODatabase openDB:2];
    [self enterMainStoryboard:true];
}

-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *) namespaceURI qualifiedName:(NSString *)qName attributes: (NSDictionary *)attributeDict{
    if( [elementName isEqualToString:@"ns1:out"]){
        _jsonResult = [[NSMutableString alloc] init];
        isRecording = true;
    }
}

-(void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string{
    if( isRecording ){
        [_jsonResult appendString: string];
    }
}

-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName{
    if( [elementName isEqualToString:@"ns1:out"]){
        isRecording = false;
        NSDictionary *dict = [_jsonResult objectFromJSONString];
        NSNumber *version = [dict objectForKey:@"dbVersion"];
        NSNumber *dbSize = [dict objectForKey:@"dbSize"];
        remoteDBVersion = [version intValue];
        [self compareDBVersion:dbSize];
    }
}

- (void)compareDBVersion:(NSNumber *)dbSize{
    [JDODatabase openDB:2];
    
    long ignoreVersion = [[NSUserDefaults standardUserDefaults] integerForKey:@"JDO_Ignore_Version"];
    if (ignoreVersion >= remoteDBVersion) {
        [self enterMainStoryboard:true];
        return;
    }
    
    FMDatabase *db = [JDODatabase sharedDB];
//    BOOL success = [db executeUpdate:@"update version set versioncode = 264"];  // 测试对比新版本
    FMResultSet *rs = [db executeQuery:@"select versioncode from version"];
    if ([rs next]) {
        int version = [rs intForColumn:@"versioncode"];
        if (version < remoteDBVersion) {
            if ([Reachability isEnableWIFI]){  // wifi环境下自动更新
                hud.labelText = @"下载最新数据";
                [self downloadSQLite_ifFailedUse:2];
            }else if([Reachability isEnable3G]){ // 3G环境下提醒更新
                alert = [[JDOAlertTool alloc] init];
                [alert showAlertView:self title:@"发现新数据" message:[NSString stringWithFormat:@"当前版本:%d，最新版本:%d，\r\n升级数据包容量:%.2fM",version,remoteDBVersion,[dbSize longValue]/1000.0f/1000.0f] cancelTitle:@"跳过该版本" otherTitle1:@"下载" otherTitle2:@"忽略" cancelAction:^{
                    [[NSUserDefaults standardUserDefaults] setInteger:remoteDBVersion forKey:@"JDO_Ignore_Version"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    [self enterMainStoryboard:false];
                } otherAction1:^{
                    hud.labelText = @"下载最新数据";
                    [self downloadSQLite_ifFailedUse:2];
                } otherAction2:^{
                    [self enterMainStoryboard:false];
                }];
            }else{  // 无法连接更新服务器则直接跳过
                [self enterMainStoryboard:true];
            }
        }else{
            [self enterMainStoryboard:true];
        }
    }
    [rs close];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError{
    hud.mode = MBProgressHUDModeText;
    hud.labelText = @"解析版本出错";
    hud.detailsLabelText = parseError.localizedDescription;
    
    [JDODatabase openDB:2 force:true];
    [self enterMainStoryboard:true];
}

- (void)zipArchiveDidUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo unzippedPath:(NSString *)unzippedPath{
    NSLog(@"解压完成，打开数据库:%@",[NSDate date]);
    [[NSUserDefaults standardUserDefaults] setBool:false forKey:@"JDO_GPS_Transformed"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [JDODatabase openDB:2 force:true];
//    [self checkGPSInfo];
    
    [self enterMainStoryboard:true];
}

- (void)zipArchiveProgressEvent:(NSInteger)loaded total:(NSInteger)total{
    NSLog(@"解压进度:%g",loaded*1.0/total);
}


- (void)checkGPSInfo{   // 检查坐标是否已经转换
    if ( ![[NSUserDefaults standardUserDefaults] boolForKey:@"JDO_GPS_Transformed"] ) {
        if ([self transfromGPS]) {
            [self enterMainStoryboard:false];
        }else{
            alert = [[JDOAlertTool alloc] init];
            [alert showAlertView:self title:@"坐标纠偏出错" message:[[JDODatabase sharedDB] lastErrorMessage] cancelTitle:@"跳过" otherTitle1:@"重试" otherTitle2:nil cancelAction:^{
                [hud hide:true];
                [self enterMainStoryboard:false];
            } otherAction1:^{
                [self transfromGPS];
            } otherAction2:nil];
        }
    }
}

- (BOOL) transfromGPS{  // 转换GPS坐标 地球坐标->百度坐标
    FMDatabase *db = [JDODatabase sharedDB];
    [db beginTransaction];
    FMResultSet *rs = [db executeQuery:@"select id,gpsx2,gpsy2 from station where gpsx2>1 and gpsy2>1"];
    while ([rs next]) {
        NSString *stationId = [NSString stringWithFormat:@"%d",[rs intForColumn:@"ID"]];
        NSNumber *gpsX = [NSNumber numberWithDouble:[rs doubleForColumn:@"GPSX2"]];
        NSNumber *gpsY = [NSNumber numberWithDouble:[rs doubleForColumn:@"GPSY2"]];
//        CLLocationCoordinate2D bdStation = BMKCoorDictionaryDecode(BMKConvertBaiduCoorFrom(CLLocationCoordinate2DMake(gpsY.doubleValue, gpsX.doubleValue),BMK_COORDTYPE_GPS));
//        BOOL success = [db executeUpdate:@"update station set GPSX2=?, GPSY2=? where id=?",@(bdStation.longitude),@(bdStation.latitude),stationId];
//        if (!success) {
//            [db rollback];
//            return false;
//        }
    }
    [rs close];
    [db commit];
    [[NSUserDefaults standardUserDefaults] setBool:true forKey:@"JDO_GPS_Transformed"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSLog(@"完成坐标转换:%@",[NSDate date]);
    return true;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
