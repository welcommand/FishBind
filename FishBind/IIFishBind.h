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
@property (nonatomic, copy) NSString *oKey;
@property (nonatomic, copy) NSString *pKey;
@property (nonatomic, copy) id callBack;

+ (instancetype)fish:(id)object oKey:(NSString *)oKey pKey:(NSString *)pKey callBack:(IIFishMindine)callBack;
@end

@interface IIPostFish : IIFish
+ (instancetype)fish:(id)object pKey:(NSString *)pKey;
+ (instancetype)fish:(id)blockObject;
@end

@interface IIObserverFish : IIFish
+ (instancetype)fish:(id)object oKey:(NSString *)oKey;
+ (instancetype)fish:(id)object callBack:(IIFishMindine)callBack;
@end

//@interface NSObject (IIFishBind)
//@property (nonatomic, strong) id _iiDeadFish;
//@end

@interface IIFishBind : NSObject
+ (void)bindFishes:(NSArray <IIFish*> *)fishes;
@end
