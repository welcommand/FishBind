//
//  IIFishBind.m
//  FishBindDemo
//
//  Created by WELCommand on 2017/9/4.
//  Copyright © 2017年 WELCommand. All rights reserved.
//

#import "IIFishBind.h"

@implementation IIFish
+ (instancetype)fishWithObject:(id)object keyPatch:(NSString *)keypPatch block:(IIFishMindine)block {
    IIFish *fish = [[IIFish alloc] init];
    fish.object = object;
    fish.keyPatch = keypPatch;
    fish.block = block;
    return fish;
}
@end

@implementation IIObserverFish
+ (instancetype)fishWithObject:(id)object block:(IIFishMindine)block {
    return [super fishWithObject:object keyPatch:nil block:block];
}
@end

@implementation IIPostFish
+ (instancetype)fishWithObject:(id)object keyPatch:(NSString *)keypPatch {
    return [super fishWithObject:object keyPatch:keypPatch block:nil];
}
@end


@implementation IIFishBind
+ (void)bind:(IIFish *)fish, ... {
}
@end
