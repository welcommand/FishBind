//
//  IIFishBind.h
//  FishBindDemo
//
//  Created by WELCommand on 2017/9/4.
//  Copyright © 2017年 WELCommand. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IIFishCallBack : NSObject
@property (nonatomic, weak) id tager;
@property (nonatomic, copy) NSString *selector;
@property (nonatomic, strong) NSArray *args;
@property (nonatomic, assign) id resule;
@end

typedef void(^IIFishCallBackBlock) (IIFishCallBack *callBack, id deadFish);

@interface IIFish : NSObject
// property bind
+ (instancetype)post:(id)object property:(NSString *)property;
+ (instancetype)observer:(id)object property:(NSString *)property;

// method bind
+ (instancetype)post:(id)object selector:(SEL)selector;
+ (instancetype)observer:(id)object callBack:(IIFishCallBackBlock)callBack;

// bind a block,  using observer:callBack: to observe
+ (instancetype)postBlock:(id)blockObject;

// bilateral bind
+ (instancetype)both:(id)object property:(NSString *)property callBack:(IIFishCallBackBlock)callBack;
+ (instancetype)both:(id)object selector:(SEL)selector callBack:(IIFishCallBackBlock)callBack;

@end

@interface IIFishBind : NSObject

+ (void)bindFishes:(NSArray <IIFish*> *)fishes;

@end

@interface NSObject (IIFishBind)

- (NSArray *)iifish_allKeys;
- (NSArray *)iifish_observersWithKey:(NSString *)key;
- (NSArray *)iifish_observersWithProperty:(NSString *)property;

- (void)iifish_removeObserverWithKey:(NSString *)key;
- (void)iifish_removeObserverWithkey:(NSString *)key andObject:(id)object;

- (void)iifish_removeObserverWithProperty:(NSString *)property;
- (void)iifish_removeObserverWithProperty:(NSString *)property andObject:(id)object;

- (void)iifish_removeObserverWithObject:(id)object;

- (void)iifish_removeAllObserver;

@end


//#####
//##### hook all methods
//#####


typedef NS_OPTIONS(NSUInteger, IIFishWatchOptions) {
    IIFishWatchOptionsInstanceMethod = (1 << 0),
    IIFishWatchOptionsClassMethod = (1 << 1),
    IIFishWatchOptionsWithoutNSObject = (1 << 2)
};



typedef void(^IIFishWatchCallBackBlock) (IIFishCallBack *callBack);

@interface NSObject (IIFishWatch)
+ (void)iifish_watchMethodsOptions:(IIFishWatchOptions)options callback:(IIFishWatchCallBackBlock)callback;
- (void)iifish_watchMethodsOptions:(IIFishWatchOptions)options callback:(IIFishWatchCallBackBlock)callback;
@end

