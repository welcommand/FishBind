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
@property (nonatomic, assign) id object;
@property (nonatomic, copy) NSString *property;
@property (nonatomic, copy) NSString *selector;
@property (nonatomic, copy) id callBack;

+ (instancetype)fish:(id)object selector:(SEL)selector callBack:(IIFishMindine)callBack;
+ (instancetype)fish:(id)object property:(NSString*)property;


@end

@interface IIPostFish : IIFish

+ (instancetype)postBlock:(id)blockObject;
+ (instancetype)post:(id)object property:(NSString *)property;
+ (instancetype)post:(id)object selector:(SEL)selector;

@end

@interface IIObserverFish : IIFish
+ (instancetype)observer:(id)object property:(NSString *)property;
+ (instancetype)observer:(id)object callBack:(IIFishMindine)callBack;
@end


@interface IIFishBind : NSObject
+ (void)bindFishes:(NSArray <IIFish*> *)fishes;
+ (void)removeFish:(NSArray <IIFish *> *)fishes;
@end
