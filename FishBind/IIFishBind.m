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
        classTableQueue = dispatch_queue_create("com.IIFishClassTableQueue.FishBind", DISPATCH_QUEUE_CONCURRENT);
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
    struct IIFishBlock_descriptor_1 *descriptor;
};
typedef  struct IIFishBlock_layout  *IIFishBlock;

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

#pragma mark-
#pragma mark- block imp holder

@interface IIFishBlockFuncHolder : NSObject
@end
@implementation IIFishBlockFuncHolder
@end


#pragma mark-
typedef void (*IIFishBlockFunc) (void*, ...);

static IIFishBlock IIFish_Block_Get_TempBlock(id block);

static  NSString const *IIFishBlockObserverKey = @"IIFishBlockObserverKey";
//static NSString const *IIFishBlockOrgSelector = @"";

void IIFishBlockFuncPtr(IIFishBlock block, ...) {
    
    long long funcAddress =  IIFish_Block_Get_Org_Address((__bridge id)block);
    SEL orgSel = NSSelectorFromString([NSString stringWithFormat:@"IIFishBlock_%@:",@(funcAddress)]);
    
    NSMethodSignature *ms = [IIFishBlockFuncHolder methodSignatureForSelector:orgSel];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:ms];
    inv.target = [IIFishBlockFuncHolder class];
    inv.selector = orgSel;
    [inv invoke];

    return;
}

static IIFishBlock IIFish_Block_Get_TempBlock(id block) {
    return (__bridge void *)objc_getAssociatedObject(block, @"IIFish_Block_TempBlock");
}

static void IIFish_Block_Set_TempGlobalBlock(id block, IIFishBlock tempBlock) {
    objc_setAssociatedObject(block, @"IIFish_Block_TempBlock", (__bridge id)tempBlock, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void IIFish_Block_Set_TempMallocBlock(id block, IIFishBlock tempBlock) {
    objc_setAssociatedObject(block, @"IIFish_Block_TempBlock", (__bridge id)tempBlock, OBJC_ASSOCIATION_ASSIGN);
}

static void * IIFish_Block_Get_DisposeFunc(id block) {
    return (__bridge void *)objc_getAssociatedObject(block, @"IIFish_Block_DisposeFunc");
}

static void IIFish_Block_Set_DisposeFunc(id block, void * disposeFunc) {
    objc_setAssociatedObject(block, @"IIFish_Block_DisposeFunc", (__bridge id)disposeFunc, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void IIFish_Block_disposeFunc(const void * block_Layout) {
    // clear Temp Block
    
    void (*disposeFunc)(const void *) = IIFish_Block_Get_DisposeFunc((__bridge id)(block_Layout));
    if (disposeFunc) {
        disposeFunc(block_Layout);
    }
}

static void IIFish_Block_HookDisposeFuncOnces(IIFishBlock block) {
    if (block->flags & IIFishBLOCK_HAS_COPY_DISPOSE) {
        struct IIFishBlock_descriptor_2 *descriptor_2  = _IIFish_Block_descriptor_2(block);
        if (descriptor_2->dispose != IIFish_Block_disposeFunc) {
            void *disposeFunc = descriptor_2->dispose;
            IIFish_Block_Set_DisposeFunc((__bridge id)(block), disposeFunc);
            descriptor_2->dispose = IIFish_Block_disposeFunc;
        }
    }
}


static BOOL IIFish_Block_TypeCheck(id object) {
    return [object isKindOfClass:NSClassFromString(@"NSBlock")];
}

static IIFishBlock IIFish_Block_DeepCopy(IIFishBlock block) {
    
    IIFishBlock newBlock;
    struct IIFishBlock_descriptor_2 *descriptor_2 = _IIFish_Block_descriptor_2(block);
    if (descriptor_2) {
        // size == block + ref objects ? need test
        newBlock = malloc(block->descriptor->size);
        if (!newBlock) return nil;
        memmove(newBlock, block, block->descriptor->size);
        descriptor_2->copy(newBlock, block);
        IIFish_Block_Set_TempMallocBlock((__bridge id)block, newBlock);
        IIFish_Block_HookDisposeFuncOnces(block);
    } else {
        newBlock->isa = block->isa;
        newBlock->flags = block->flags;
        newBlock->invoke = block->invoke;
        newBlock->reserved = block->reserved;
        newBlock->descriptor = block->descriptor;
        IIFish_Block_Set_TempGlobalBlock((__bridge id)block, newBlock);
    }
    
    return newBlock;
}

static const char *IIFish_Block_ConvertBlockSignature(const char * signature) {
    NSString *tString = [NSString stringWithUTF8String:signature];
//    return [[tString stringByReplacingOccurrencesOfString:@"@?0" withString:[NSString stringWithFormat:@"@0:%@",@(sizeof(id))] options:2 range:[tString rangeOfString:@"@?0"]] UTF8String];
//    //v8@?0
//    //v24@0:8@16
    
    return [@"v24@0:8" UTF8String];
}

static void IIFish_Hook_Block(id obj) {
    if (!IIFish_Block_Get_TempBlock(obj)) {
        IIFishBlock block = (__bridge IIFishBlock)(obj);
        long long blockOrgFuncAddress = (long long)block->invoke;
        
        NSString *fakeSelString = [NSString stringWithFormat:@"IIFishBlock_%@:",@(blockOrgFuncAddress)];
        
        SEL fakeSel = NSSelectorFromString(fakeSelString);
        if (!class_getClassMethod([IIFishBlockFuncHolder class], fakeSel)) {
            
            IIFishBlock newBlock = IIFish_Block_DeepCopy(block);
            IMP fakeImp = imp_implementationWithBlock((__bridge id)newBlock);
            struct IIFishBlock_descriptor_3 *des3 =  _IIFish_Block_descriptor_3(block);
            const char *c = IIFish_Block_ConvertBlockSignature (des3->signature);
            
            class_addMethod(objc_getMetaClass(object_getClassName([IIFishBlockFuncHolder class])), fakeSel, fakeImp, c);
            
        }
        block->invoke = (IIFishBlockFunc)IIFishBlockFuncPtr;
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


+ (void)test:(id)obj {
    
}

+ (void)load {
    
    //v16@0:8
    //v8@?0
    //v24@0:8@16

    
    NSMethodSignature *ms = [NSMethodSignature signatureWithObjCTypes:"v24@0:8@?16"];
    
    
    Method m = class_getClassMethod(self, @selector(test:));
    
    
    void (^testBlock)() = ^() {
        NSLog(@"bbTest");
    };
    
    
    IIFish_Hook_Block(testBlock);
    testBlock();
    
    NSLog(@"asdasdasdsa");
    
}



@end
