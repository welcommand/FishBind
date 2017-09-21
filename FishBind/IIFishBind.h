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
@property (nonatomic, assign) SEL oKey;
@property (nonatomic, assign) SEL pKey;
@property (nonatomic, copy) id callBack;

+ (instancetype)fish:(id)object oKey:(SEL)oKey pKey:(SEL)pKey callBack:(IIFishMindine)callBack;
@end

@interface IIPostFish : IIFish
+ (instancetype)fish:(id)object pKey:(SEL)pKey;
+ (instancetype)fish:(id)blockObject;
@end

@interface IIObserverFish : IIFish
+ (instancetype)fish:(id)object oKey:(SEL)oKey;
+ (instancetype)fish:(id)object callBack:(IIFishMindine)callBack;
@end


@interface IIFishBind : NSObject
+ (void)bindFishes:(NSArray <IIFish*> *)fishes;
+ (void)removeFish:(NSArray <IIFish *> *)fishes;
@end
