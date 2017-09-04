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
@property (nonatomic, copy) NSString *keyPatch;
@property (nonatomic, copy) id block;
+ (instancetype)fishWithObject:(id)object keyPatch:(NSString *)keypPatch block:(IIFishMindine)block;
@end

@interface IIObserverFish : IIFish
+ (instancetype)fishWithObject:(id)object block:(IIFishMindine)block;
@end

@interface IIPostFish : IIFish
+ (instancetype)fishWithObject:(id)object keyPatch:(NSString *)keypPatch;
@end


@interface IIFishBind : NSObject

+ (void)bind:(IIFish *)fish, ...;

@end
