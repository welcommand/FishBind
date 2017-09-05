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

// TODO
// arg get
// block copy
//return?

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
#pragma mark - info

@interface IIFishInfo : NSObject
@property (nonatomic, copy) NSString *key;
@property (nonatomic, strong) NSHashTable *observers;
@end

@implementation IIFishInfo
- (instancetype)initWithKey:(NSString *)key {
    if (self = [super init]) {
        _key = [key copy];
        _observers = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory];
    }
    return self;
}
@end

#pragma mark-
#pragma mark- lock

static void IIFist_Lock(dispatch_block_t block) {
    static pthread_mutex_t mutex;
    pthread_mutex_init(&mutex, NULL);
    pthread_mutex_lock(&mutex);
    block();
    pthread_mutex_unlock(&mutex);
}

#pragma mark-
#pragma mark- class table

static dispatch_queue_t IIFish_ClassTable_Queue() {
    static dispatch_queue_t classTableQueue = nil;
    if (!classTableQueue) {
        classTableQueue = dispatch_queue_create("com.IIFishClassTableQueue.www", DISPATCH_QUEUE_CONCURRENT);
    }
    return classTableQueue;
}

static NSMutableSet* IIFish_ClassTable() {
    static NSMutableSet *classTable;
    if (!classTable) {
        classTable = [NSMutableSet new];
    }
    return classTable;
}

static BOOL IIFish_ClassTable_ContainClass(Class cls) {
    __block BOOL contain;
    dispatch_sync(IIFish_ClassTable_Queue(), ^{
        NSMutableSet *classTable = IIFish_ClassTable();
        contain = [classTable containsObject:cls];
    });
    return contain;
}

static void IIFish_ClassTable_AddClass(Class cls) {
    dispatch_barrier_async(IIFish_ClassTable_Queue(), ^{
        NSMutableSet *classTable = IIFish_ClassTable();
        [classTable addObject:cls];
    });
}

#pragma mark-
#pragma mark- GlobalTable

static NSMapTable* IIFish_GlobalTable() {
    static NSMapTable *globalTable;
    if (!globalTable) {
        globalTable = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory valueOptions:NSPointerFunctionsWeakMemory];
    }
    return globalTable;
}

#pragma mark-
#pragma mark- Block Hook

//code from
//https://opensource.apple.com/source/libclosure/libclosure-67


///////////////////
typedef NS_OPTIONS(int, IIFishBlockFlage) {
    IIFishBLOCK_HAS_COPY_DISPOSE =  (1 << 25),
    IIFishBLOCK_HAS_SIGNATURE  =    (1 << 30)
};

struct IIFishBlock_descriptor_1 {
    uintptr_t reserved;
    uintptr_t size;
};

struct IIFishBlock_descriptor_2 {
    void (*copy)(void *dst, const void *src);
    void (*dispose)(const void *);
};

struct IIFishBlock_descriptor_3 {
    const char *signature;
    const char *layout;
};

struct IIFishBlock_layout {
    void *isa;
    volatile int32_t flags;
    int32_t reserved;
    void (*invoke)(void *, ...);
    struct Block_descriptor_1 *descriptor;
};

typedef  struct IIFishBlock_layout  *IIFishBlock;

typedef void (*IIFishBlockIMP) (void*, ...);

static struct IIFishBlock_descriptor_2 * _IIFish_Block_descriptor_2(IIFishBlock aBlock)
{
    if (! (aBlock->flags & IIFishBLOCK_HAS_COPY_DISPOSE)) return NULL;
    uint8_t *desc = (uint8_t *)aBlock->descriptor;
    desc += sizeof(struct IIFishBlock_descriptor_1);
    return (struct IIFishBlock_descriptor_2 *)desc;
}

static struct IIFishBlock_descriptor_3 * _IIFish_Block_descriptor_3(IIFishBlock aBlock)
{
    if (! (aBlock->flags & IIFishBLOCK_HAS_SIGNATURE)) return NULL;
    uint8_t *desc = (uint8_t *)aBlock->descriptor;
    desc += sizeof(struct IIFishBlock_descriptor_1);
    if (aBlock->flags & IIFishBLOCK_HAS_COPY_DISPOSE) {
        desc += sizeof(struct IIFishBlock_descriptor_2);
    }
    return (struct IIFishBlock_descriptor_3 *)desc;
}

///////////////////


static const NSString *IIFishBlockObserverKey = @"IIFishBlockObserverKey";


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

static BOOL IIFish_Block_TypeCheck(id object) {
    return [object isKindOfClass:NSClassFromString(@"NSBlock")];
}

static void IIFish_Hook_Block(id obj) {
    if (IIFish_Block_Get_Org_Imp(obj) == 0) {
        IIFishBlock block = (__bridge IIFishBlock)(obj);
        IIFishBlockIMP orgImp = block->invoke;
        IIFish_Block_Set_Org_Imp(obj, orgImp);
        block->invoke = (IIFishBlockIMP)IIFishBlockFuncPtr;
    }
}


#pragma mark- Method Hook
static void IIFish_Hook_Class(id object) {
    if (!IIFish_ClassTable_ContainClass([object class])) {

        //objc_allocateClassPair([object class], const char * _Nonnull name, <#size_t extraBytes#>)

        IIFish_ClassTable_AddClass([object class]);
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
