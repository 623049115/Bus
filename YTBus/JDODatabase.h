//
//  JDODatabase.h
//  YTBus
//
//  Created by zhang yi on 14-10-31.
//  Copyright (c) 2014年 胶东在线. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FMDB.h"
#import "SSZipArchive.h"

// 某个站点通过的所有线路，在“我的附近”中使用
#define GetLinesByStation @"select t0.ATTACH as ATTACH, t0.STATIONNAME as STATIONNAME,t0.GEOGRAPHICALDIRECTION as DIRECTION,t1.BUSLINEID as LINEID ,t1.buslinedetail as LINEDETAILID,t3.buslinename as LINENAME,t2.buslinename as LINEDETAIL,t2.DIRECTION as LINEDIRECTION,t3.runtime as RUNTIME, t3.ZHIXIAN as ZHIXIAN from station t0 inner join LINESTATION t1 on t0.id = t1.stationid and t0.ATTACH = t1.ATTACH inner join BUSLINEDETAIL t2 on t1.buslinedetail = t2.id and t1.ATTACH = t2.ATTACH  inner join BUSLINE t3 on t1.buslineid = t3.id and t1.ATTACH = t3.ATTACH where t0.id = ? and t0.attach = ? and t3.appshow = 1 order by (case when cast(t3.buslinename as int)=0 then 999 else cast(t3.buslinename as int) end)"

// 某条线路的所有站点(单向)，在“线路实时”的地图界面中使用
#define GetStationsByLineDetail @"select t0.buslinename as LINEDETAIL,t1.BUSLINEID as LINEID ,t1.buslinedetail as LINEDETAILID,t2.ID as STATIONID, t2.STATIONNAME as STATIONNAME,t2.GEOGRAPHICALDIRECTION as DIRECTION,t2.MAPX as GPSX,t2.MAPY as GPSY from BUSLINEDETAIL t0 inner join LINESTATION t1 on t0.id = t1.buslinedetail and t0.attach = t1.attach inner join STATION t2 on t1.stationid = t2.id and t1.attach = t2.attach where t0.id = ? and t0.attach = ? order by t1.SEQUENCE"

// 某条线路名称及其起点站和终点站，在“线路查询”的收藏中使用
//#define GetLineById @"select ID,BUSLINENAME,(select stationname from STATION where id=t0.STATIONA) as STATIONANAME,(select stationname from STATION where id=t0.STATIONB) as STATIONBNAME from BusLine t0 where ID in (?)"
// 收藏的基本单元从线路改为线路详情
#define GetLineById @"select t0.ID as LINEID, t1.ID as DETAILID, t0.BUSLINENAME as BUSLINENAME, t0.ZHIXIAN as ZHIXIAN,  t1.BUSLINENAME as LINEDETAILNAME, t1.DIRECTION as DIRECTION, t0.ATTACH as ATTACH from BusLine t0 inner join BusLineDetail t1 on t0.ID = t1.BUSLINEID and t0.ATTACH = t1.ATTACH where (t1.ID in (%@) and t1.ATTACH = 1) or (t1.ID in (%@) and t1.ATTACH = 2)"

// 所有线路名称及其起点站和终点站，在“线路查询”的所有线路中使用
#define GetAllLines @"select ID,BUSLINENAME, ZHIXIAN, ATTACH, (select stationname from STATION where id=t0.STATIONA and attach=t0.attach) as STATIONANAME,(select stationname from STATION where id=t0.STATIONB and attach=t0.attach) as STATIONBNAME from BusLine t0 where t0.appshow = 1 order by ID"

// 所有站点名称，及站点通过的线路数[******暂时不用******]
#define GetAllStations  @"select t0.ID, STATIONNAME, sum(1) as NUM from STATION t0 inner join LINESTATION t1 on t0.ID = t1.STATIONID inner join BusLineDetail t2 on t1.BUSLINEDETAIL = t2.ID where t0.MAPX<>0 and t0.MAPY<>0 group by t0.ID order by STATIONNAME"

// 所有站点名称，及站点通过的线路名称
#define GetAllStationsWithLine @"select t0.ATTACH as ATTACH, t0.ID as STATIONID, t0.stationname as STATIONNAME,t3.BUSLINENAME as BUSLINENAME,t3.ID as BUSLINEID from STATION t0 inner join LINESTATION t1 on t0.ID = t1.STATIONID and t0.ATTACH = t1.ATTACH inner join BusLineDetail t2 on t1.BUSLINEDETAIL = t2.ID and t1.ATTACH = t2.ATTACH inner join BusLine t3 on t2.BUSLINEID = t3.ID and t2.ATTACH = t3.ATTACH where t0.MAPX<>0 and t0.MAPY<>0 and t3.appshow = 1 order by STATIONNAME,t0.ID,(case when cast(t3.buslinename as int)=0 then 999 else cast(t3.buslinename as int) end)"

// 根据站点名称，查询是否有同名的对向站点
#define GetConverseStation @"select t0.ATTACH as ATTACH, t2.ID as STATIONID,t2.STATIONNAME as STATIONNAME,t2.GEOGRAPHICALDIRECTION as DIRECTION,t2.MAPX as GPSX,t2.MAPY as GPSY from BusLineDetail t0 inner join LINESTATION t1 on t0.ID = t1.BUSLINEDETAIL and t0.ATTACH = t1.ATTACH inner join STATION t2 on t1.STATIONID = t2.ID and t1.ATTACH = t2.ATTACH where t2.STATIONNAME = ? and t0.ID = ? and t0.ATTACH = ?"

// 根据站点名称，查询所有同名站点及通过的所有线路[******暂时不用******]
#define GetStationsWithLinesByName @"select t0.ID as STATIONID, (CASE WHEN SUBSTR(STATIONNAME,-1,1)='2' and SUBSTR(STATIONNAME,-2,1) not in ('1','2','3','4','5','6','7','8','9','0') THEN SUBSTR(STATIONNAME,1,LENGTH(STATIONNAME)-1) ELSE STATIONNAME END) as STATIONNAME,t0.MAPX as GPSX, t0.MAPY as GPSY, t3.ID as BUSLINEID, t3.BUSLINENAME as BUSLINENAME,t2.ID as LINEDETAILID, t2.BUSLINENAME as BUSLINEDETAIL, t2.DIRECTION as DIRECTION from STATION t0 inner join LINESTATION t1 on t0.ID = t1.STATIONID inner join BusLineDetail t2 on t1.BUSLINEDETAIL = t2.ID inner join BusLine t3 on t2.BUSLINEID = t3.ID where STATIONNAME=? and t0.MAPX<>0 and t0.MAPY<>0 and t3.appshow = 1 order by t0.ID, (case when cast(t3.buslinename as int)=0 then 999 else cast(t3.buslinename as int) end)"

// 查询所有的站点，用来填充四叉树
#define GetAllStationsInfo @"SELECT DISTINCT t0.ATTACH as ATTACH,t0.ID AS STATIONID,t0.stationname as STATIONNAME,t0.GEOGRAPHICALDIRECTION as DIRECTION,t0.MAPX as GPSX,t0.MAPY as GPSY FROM STATION t0 INNER JOIN LINESTATION t1 ON t0.ID = t1.STATIONID and t0.ATTACH = t1.ATTACH INNER JOIN BusLineDetail t2 ON t1.BUSLINEDETAIL = t2.ID and t1.ATTACH = t2.ATTACH INNER JOIN BusLine t3 ON t2.BUSLINEID = t3.ID and t2.ATTACH = t3.ATTACH WHERE t0.MAPX <> 0 AND t0.MAPY <> 0 and t3.appshow = 1 and t0.stationname not like 't_%'"

// 附近的站点，跟上面的只有where条件不同
#define GetNearbyStations @"SELECT DISTINCT t0.ATTACH as ATTACH,t0.ID AS ID,t0.stationname as STATIONNAME,t0.GEOGRAPHICALDIRECTION as DIRECTION,t0.MAPX as GPSX,t0.MAPY as GPSY FROM STATION t0 INNER JOIN LINESTATION t1 ON t0.ID = t1.STATIONID and t0.ATTACH = t1.ATTACH INNER JOIN BusLineDetail t2 ON t1.BUSLINEDETAIL = t2.ID and t1.ATTACH = t2.ATTACH INNER JOIN BusLine t3 ON t2.BUSLINEID = t3.ID and t2.ATTACH = t3.ATTACH WHERE t0.MAPX>? and t0.MAPX<? and t0.MAPY>? and t0.MAPY<? and t3.appshow = 1 and t0.stationname not like 't_%' order by t0.attach"

// 根据站点id查找站点
#define GetStationById @"select STATIONNAME,GEOGRAPHICALDIRECTION,MAPX,MAPY FROM STATION where ID = ? and ATTACH = ?"

// 根据线路id查询双向线路详情
#define GetDetailIdByLineId @"select ID,DIRECTION,ATTACH from BusLineDetail where BUSLINEID = ? and ATTACH = ?"

// 查询线路详情id查询
#define GetDetailById @"select BUSLINENAME,PRICE,FIRSTTIME,LASTTIME from BusLineDetail where ID = ? and ATTACH = ?"


// 芝罘区、开发区id相同的站点，共369个，其中站名相同的212个，站名不同的大部分是同一位置的站点市公交修改了站名(通常是为了广告)，但也有小部分不是同一个站点(这种的相隔距离都很远)
// 最后的where条件用A.attach<B.attach，这样同名站点的选名顺序就是市公交>开发区公交>其他
// 有以下五种可能：1、同名且位置相同。2、同名但位置不同。3、不同名但位置相同。4、不同名但位置差距不大。5、不同名且位置差距很大。不论哪种情况，只要位置距离小于100米都认为是相同站点，名字采用A.stationname
#define GetStationsSameId @"select A.ID as id,A.ATTACH as attach1,B.ATTACH as attach2,A.STATIONNAME as name1,B.STATIONNAME as name2,A.DIRECTION as direction1,B.direction as direction2, A.gpsx2 as gpsx1,A.gpsy2 as gpsy1,B.GPSX2 as gpsx2,B.GPSY2 as gpsy2,A.mapx as mapx1,A.mapy as mapy1,B.mapx as mapx2,B.mapy as mapy2 from (SELECT DISTINCT t0.ATTACH as ATTACH,t0.ID AS ID,t0.stationname as STATIONNAME,t0.GEOGRAPHICALDIRECTION as DIRECTION,t0.gpsx2 as GPSX2,t0.gpsy2 as GPSY2,t0.mapx as mapx,t0.mapy as mapy FROM STATION t0 INNER JOIN LINESTATION t1 ON t0.ID = t1.STATIONID and t0.ATTACH = t1.ATTACH INNER JOIN BusLineDetail t2 ON t1.BUSLINEDETAIL = t2.ID and t1.ATTACH = t2.ATTACH INNER JOIN BusLine t3 ON t2.BUSLINEID = t3.ID and t2.ATTACH = t3.ATTACH WHERE t3.appshow = 1 and t0.stationname not like 't_%' and t0.mapx>0 and t0.mapy>0) A inner join (SELECT DISTINCT t0.ATTACH as ATTACH,t0.ID AS ID,t0.stationname as STATIONNAME,t0.GEOGRAPHICALDIRECTION as DIRECTION,t0.gpsx2 as GPSX2,t0.gpsy2 as GPSY2,t0.mapx as mapx,t0.mapy as mapy FROM STATION t0 INNER JOIN LINESTATION t1 ON t0.ID = t1.STATIONID and t0.ATTACH = t1.ATTACH INNER JOIN BusLineDetail t2 ON t1.BUSLINEDETAIL = t2.ID and t1.ATTACH = t2.ATTACH INNER JOIN BusLine t3 ON t2.BUSLINEID = t3.ID and t2.ATTACH = t3.ATTACH WHERE t3.appshow = 1 and t0.stationname not like 't_%' and t0.mapx>0 and t0.mapy>0) B on A.id = B.id and A.attach < B.attach order by A.attach,B.attach"
// 测试有attach = 3的情况下合并站点
// union select A.ID as id,A.ATTACH as attach1,B.ATTACH as attach2,A.STATIONNAME as name1,B.STATIONNAME as name2,A.DIRECTION as direction1,B.direction as direction2, A.gpsx2 as gpsx1,A.gpsy2 as gpsy1,B.GPSX2 as gpsx2,B.GPSY2 as gpsy2,A.mapx as mapx1,A.mapy as mapy1,B.mapx as mapx2,B.mapy as mapy2 from (SELECT DISTINCT t0.ATTACH as ATTACH,t0.ID AS ID,t0.stationname as STATIONNAME,t0.GEOGRAPHICALDIRECTION as DIRECTION,t0.gpsx2 as GPSX2,t0.gpsy2 as GPSY2,t0.mapx as mapx,t0.mapy as mapy FROM STATION t0) A inner join (SELECT DISTINCT t0.ATTACH as ATTACH,t0.ID AS ID,t0.stationname as STATIONNAME,t0.GEOGRAPHICALDIRECTION as DIRECTION,t0.gpsx2 as GPSX2,t0.gpsy2 as GPSY2,t0.mapx as mapx,t0.mapy as mapy FROM STATION t0) B on A.id = B.id and A.id = 745 and A.attach < B.attach
// and (A.GPSX2<>B.GPSX2 or A.GPSY2<>B.GPSY2) and A.stationname = B.stationname

// 芝罘区、开发区站名相同、方向相同，但id不同的站点，共107个，其中78个坐标不同
#define GetStationsSameName @"select A.ID as id1,B.ID as id2,A.ATTACH as attach1,B.ATTACH as attach2,A.STATIONNAME as name,A.DIRECTION as direction, A.mapx as mapx1,A.mapy as mapy1,B.mapx as mapx2,B.mapy as mapy2 from (SELECT DISTINCT t0.ATTACH as ATTACH,t0.ID AS ID,t0.stationname as STATIONNAME,t0.GEOGRAPHICALDIRECTION as DIRECTION,t0.mapx as mapx,t0.mapy as mapy  FROM STATION t0 INNER JOIN LINESTATION t1 ON t0.ID = t1.STATIONID and t0.ATTACH = t1.ATTACH INNER JOIN BusLineDetail t2 ON t1.BUSLINEDETAIL = t2.ID and t1.ATTACH = t2.ATTACH INNER JOIN BusLine t3 ON t2.BUSLINEID = t3.ID and t2.ATTACH = t3.ATTACH WHERE t3.appshow = 1 and t0.stationname not like 't_%' and t0.mapx>0 and t0.mapy>0) A inner join (SELECT DISTINCT t0.ATTACH as ATTACH,t0.ID AS ID,t0.stationname as STATIONNAME,t0.GEOGRAPHICALDIRECTION as DIRECTION,t0.mapx as mapx,t0.mapy as mapy FROM STATION t0 INNER JOIN LINESTATION t1 ON t0.ID = t1.STATIONID and t0.ATTACH = t1.ATTACH INNER JOIN BusLineDetail t2 ON t1.BUSLINEDETAIL = t2.ID and t1.ATTACH = t2.ATTACH INNER JOIN BusLine t3 ON t2.BUSLINEID = t3.ID and t2.ATTACH = t3.ATTACH WHERE t3.appshow = 1 and t0.stationname not like 't_%' and t0.mapx>0 and t0.mapy>0) B on A.ATTACH < B.ATTACH and A.id != B.id and A.DIRECTION = B.DIRECTION and A.stationname = B.stationname"

// 排查同一线路上重复的站点
// select * from (select BUSLINEDETAIL,STATIONID,attach,count(1) as num from LINESTATION GROUP BY BUSLINEDETAIL,STATIONID,attach) where num>1


@interface JDODatabase : NSObject

+ (BOOL) deleteOldDbInDocument;
+ (BOOL) isDBExistInDocument;
+ (BOOL) saveZipFile:(NSData *)zipData;
+ (BOOL) unzipDBFile:(id<SSZipArchiveDelegate>) delegate;
+ (void) openDB:(int) which;
+ (void) openDB:(int) which force:(BOOL) force;
+ (FMDatabase *) sharedDB;

@end
