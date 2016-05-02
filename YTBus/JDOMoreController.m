//
//  JDOMoreController.m
//  YTBus
//
//  Created by zhang yi on 14-12-22.
//  Copyright (c) 2014年 胶东在线. All rights reserved.
//

#import "JDOMoreController.h"
#import "JDOConstants.h"
#import "UIViewController+MJPopupViewController.h"
#import "UMFeedback.h"
#import "JDOShareController.h"
#import "JDOMainTabController.h"
#import "iVersion.h"
#import "AppDelegate.h"
#import <ShareSDK/ShareSDK.h>
#import <ShareSDKUI/ShareSDK+SSUI.h>

typedef enum{
    JDOSettingTypeSystem = 0,
    JDOSettingTypeShare
}JDOSettingType;

@interface JDOUmengAdvController : UIViewController <UIWebViewDelegate>

@property (nonatomic,strong) UIWebView *webView;

@end

@implementation JDOUmengAdvController

- (void)loadView{
    [super loadView];

    self.webView = [[UIWebView alloc] initWithFrame:CGRectInset([UIScreen mainScreen].bounds, 20, 80)];
    self.webView.delegate = self;
    self.webView.scalesPageToFit = true;
    self.view = self.webView;
}

- (void) viewDidLoad{
    NSString *advURL = [[MobClick getAdURL] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self.webView loadRequest:[[NSURLRequest alloc] initWithURL:[NSURL URLWithString:advURL] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:5]];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView{
    
}

@end

@interface JDOMoreCell : UITableViewCell

@end

@implementation JDOMoreCell

- (id)initWithCoder:(NSCoder *)aDecoder{
    if (self = [super initWithCoder:aDecoder]){
        self.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"表格圆角中"]];
        return self;
    }
    return nil;
}

@end

@interface JDOMoreController () <UMFeedbackDataDelegate>

@property (strong, nonatomic) UMFeedback *feedback;

@end

@implementation JDOMoreController{
    BOOL needGetFeedback;
    NSUInteger unreadNumber;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.bounces = false;
    self.tableView.backgroundColor = [UIColor colorWithHex:@"dfded9"];
    
    // 友盟IDFA广告
    // 因为友盟的获取广告url是同步方法，最好是在本地后台获取开关
    AppDelegate *delegate = [UIApplication sharedApplication].delegate;
    if ([delegate.systemParam[@"openUmengAdv"] isEqualToString:@"1"]) {
        UIButton *advBtn = [UIButton buttonWithType:UIButtonTypeInfoLight];
//        advBtn.frame = CGRectMake(10, 0, 120, 30);
        [advBtn setTitle:@"广告" forState:UIControlStateNormal];
        [advBtn addTarget:self action:@selector(showAdvView) forControlEvents:UIControlEventTouchUpInside];
        self.tableView.tableHeaderView = advBtn;
    }
    
    // 注册UMFeedback的时候就会获取一遍数据，若已经有新反馈，则直接显示提示。如果没有新反馈，还有可能在应用启动到切换到“更多”tab页这段时间有新的反馈，则再重新获取一遍
    unreadNumber= 0;
    self.feedback = [UMFeedback sharedInstance];
    if (self.feedback.theNewReplies.count>0) {
        unreadNumber = self.feedback.theNewReplies.count;
        needGetFeedback = false;
    }else{
        needGetFeedback = true;
    }
}

- (void)viewWillAppear:(BOOL)animated{
    self.feedback.delegate = self;
    if (needGetFeedback) {
        [self.feedback get];
    }else{
        needGetFeedback = true;
    }
}

- (void)viewWillDisappear:(BOOL)animated{
    self.feedback.delegate = nil;
}

- (void)getFinishedWithError: (NSError *)error{
    [self performSelectorOnMainThread:@selector(onGetFinished:) withObject:error waitUntilDone:false];
}

- (void)onGetFinished:(NSError *)error{
}

- (void)showAdvView {
    JDOUmengAdvController *advController = [[JDOUmengAdvController alloc] init];
    [self presentPopupViewController:advController animationType:MJPopupViewAnimationFade];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    if(indexPath.row == JDOSettingTypeShare){
        //NSArray* imageArray = @[[UIImage imageNamed:@"shareImg.png"]];
        //(注意：图片必须要在Xcode左边目录里面，名称必须要传正确，如果要分享网络图片，可以这样传iamge参数 images:@[@"http://mob.com/Assets/images/logo.png?v=20150320"]）
//        if (imageArray) {
        
            NSMutableDictionary *shareParams = [NSMutableDictionary dictionary];
            [shareParams SSDKSetupShareParamsByText:@"我正在使用 “掌上公交”。"
                                             images:nil
                                                url:nil
                                              title:@"掌上公交"
                                               type:SSDKContentTypeAuto];
            //2、分享（可以弹出我们的分享菜单和编辑界面）
            [ShareSDK showShareActionSheet:self.view //要显示菜单的视图, iPad版中此参数作为弹出菜单的参照视图，只有传这个才可以弹出我们的分享菜单，可以传分享的按钮对象或者自己创建小的view 对象，iPhone可以传nil不会影响
                                     items:@[@(SSDKPlatformTypeSinaWeibo),@(SSDKPlatformSubTypeWechatTimeline),@(SSDKPlatformSubTypeQQFriend)]
                               shareParams:shareParams
                       onShareStateChanged:^(SSDKResponseState state, SSDKPlatformType platformType, NSDictionary *userData, SSDKContentEntity *contentEntity, NSError *error, BOOL end) {
                           
                           switch (state) {
                               case SSDKResponseStateSuccess:
                               {
                                   UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"分享成功"
                                                                                       message:nil
                                                                                      delegate:nil
                                                                             cancelButtonTitle:@"确定"
                                                                             otherButtonTitles:nil];
                                   [alertView show];
                                   break;
                               }
                               case SSDKResponseStateFail:
                               {
                                   UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"分享失败"
                                                                                   message:[NSString stringWithFormat:@"%@",error]
                                                                                  delegate:nil
                                                                         cancelButtonTitle:@"OK"
                                                                         otherButtonTitles:nil, nil];
                                   [alert show];
                                   break;
                               }
                               default:
                                   break;
                           }
                       }  
             ];}
    //}
}

//- (id<ISSShareActionSheetItem>) getShareItem:(ShareType) type content:(NSString *)content{
//    return [ShareSDK shareActionSheetItemWithTitle:[ShareSDK getClientNameWithType:type] icon:[ShareSDK getClientIconWithType:type] clickHandler:^{
//        JDOShareController *vc = [[JDOShareController alloc] initWithImage:nil content:content type:type];
//        UINavigationController *naVC = [[UINavigationController alloc] initWithRootViewController:vc];
//        [self presentViewController:naVC animated:true completion:nil];
//    }];
//}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section{
    return 15;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section{
    return 15;
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

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath{
}


//- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
//    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MoreCell" forIndexPath:indexPath];
//    cell.backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"表格圆角中"]];
//    return cell;
//}


@end
