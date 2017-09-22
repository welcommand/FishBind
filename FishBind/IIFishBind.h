//
//  IIFishBind.h
//  FishBindDemo
//
//  Created by WELCommand on 2017/9/4.
//  Copyright © 2017年 WELCommand. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^IIFishMindine) (id object, NSString *keyPatch,id resule,NSArray *args);

@interface IIFish : NSObject
@property (nonatomic, assign) NSInteger flag;
@property (nonatomic, assign) id object;
@property (nonatomic, copy) NSString *property;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, copy) id callBack;

// property bind
+ (instancetype)post:(id)object property:(NSString *)property;
+ (instancetype)observer:(id)object property:(NSString *)property;

// method bind
+ (instancetype)post:(id)object selector:(SEL)selector;
+ (instancetype)observer:(id)object callBack:(IIFishMindine)callBack;

// bind a block,  using observer:callBack: to observer
+ (instancetype)postBlock:(id)blockObject;

// bilateral bind
+ (instancetype)both:(id)object selector:(SEL)selector callBack:(IIFishMindine)callBack;
+ (instancetype)both:(id)object property:(NSString*)property;

@end

@interface IIFishBind : NSObject
+ (void)bindFishes:(NSArray <IIFish*> *)fishes;
+ (void)removeFish:(IIFish *)fishes;
@end
