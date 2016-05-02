//
//  BusLineSearchViewController.h
//  BaiduMapApiDemoSrc
//
//  Created by baidu on 12-6-20.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <BaiduMapAPI_Map/BMKMapComponent.h>
#import <BaiduMapAPI_Search/BMKSearchComponent.h>

@interface BusLineSearchViewController : UIViewController<BMKMapViewDelegate, BMKBusLineSearchDelegate,BMKPoiSearchDelegate> {
	IBOutlet BMKMapView* _mapView;
	IBOutlet UITextField* _cityText;
	IBOutlet UITextField* _busLineText;
	
    NSMutableArray* _busPoiArray;
    int currentIndex;
    BMKPoiSearch* _poisearch;
	BMKBusLineSearch* _buslinesearch;
    BMKPointAnnotation* _annotation;
}

@property (nonatomic,copy) NSString *lineId;
@property (nonatomic) NSInteger direction;//0表示上行，1表示下行

-(void)onClickBusLineSearch;
-(void)onClickNextSearch;

- (void)textFiledReturnEditing:(id)sender;
@end
