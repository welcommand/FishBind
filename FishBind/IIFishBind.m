//
//  IIFishBind.m
//  FishBindDemo
//
//  Created by WELCommand on 2017/9/4.
//  Copyright © 2017年 WELCommand. All rights reserved.
//

#import "IIFishBind.h"
#import <pthread.h>
#import <objc/runtime.h>

#pragma mark-


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

#pragma mark-
#pragma mark- Block Hook

typedef NS_OPTIONS(int, IIFishBlockFlage) {
    IIFishBLOCK_HAS_COPY_DISPOSE =  (1 << 25),
    IIFishBLOCK_HAS_SIGNATURE  =    (1 << 30)
};

struct IIFishBlock_descriptor_2 {
    void (*copy)(void *dst, const void *src);
    void (*dispose)(const void *);
};

struct IIFishBlock_descriptor_3 {
    const char *signature;
    const char *layout;
};

struct _IIFish_Block_Impl {
    Class isa;
    int flags;
    int reserved;
    void (*invoke)(struct _IIFish_Block_Impl *block, ...);
    struct {
        unsigned long int reserved;
        unsigned long int size;
    } *IIFishBlock_descriptor_1;
};
typedef  struct _IIFish_Block_Impl  *IIFishBlock;

typedef void (*IIFishBlockIMP) (struct _IIFish_Block_Impl *block, ...);

//https://opensource.apple.com/source/libclosure/libclosure-59/Block_private.h.auto.html

void IIFishBlockFuncPtr(struct _IIFish_Block_Impl *block, ...) {
    
    
    
}



static IIFishBlockIMP IIFish_Block_Get_Org_Imp(id block) {
    id orgImp = objc_getAssociatedObject(block, @"IIFish_Block_Org_Imp");
    return orgImp ? (IIFishBlockIMP)(__bridge void *)orgImp : 0;
}

static void IIFish_Block_Set_Org_Imp(id block, IIFishBlockIMP orgImp) {
    id oImp = (__bridge id)((void *)orgImp);
    objc_setAssociatedObject(block, @"IIFish_Block_Org_Imp", oImp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL IIFish_IsBlock(id object) {
    return [object isKindOfClass:NSClassFromString(@"NSBlock")];
}

static void IIFish_Check_Block(id obj) {
    if (IIFish_Block_Get_Org_Imp(obj) == 0) {
        
    }
    
}


#pragma mark- Method Hook
static void IIFist_Lock(dispatch_block_t block) {
    static pthread_mutex_t mutex;
    pthread_mutex_init(&mutex, NULL);
    pthread_mutex_lock(&mutex);
    block();
    pthread_mutex_unlock(&mutex);
}

static NSMutableSet* IIFish_Class_Table() {
    static NSMutableSet *classTable;
    if (!classTable) {
        classTable = [NSMutableSet new];
    }
    return classTable;
}

static void IIFish_Check_Class(id object) {
    NSMutableSet *classTable = IIFish_Class_Table();
    if (![classTable containsObject:[object class]]) {
        
        //objc_allocateClassPair([object class], const char * _Nonnull name, <#size_t extraBytes#>)
        
        [classTable addObject:[object class]];
    }
}


@implementation IIFishBind
+ (void)bindFishes:(NSArray <IIFish*> *)fishes {
    
}

#pragma mark-
#pragma mark- test

+ (void)load {
    
}


@end
