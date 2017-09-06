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
    struct Block_descriptor_1 *descriptor;
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

static long long IIFish_Block_Get_Org_Address(id block);

static  NSString const *IIFishBlockObserverKey = @"IIFishBlockObserverKey";
//static NSString const *IIFishBlockOrgSelector = @"";

void IIFishBlockFuncPtr(IIFishBlock block, ...) {
    
    long long funcAddress =  IIFish_Block_Get_Org_Address((__bridge id)block);
    SEL orgSel = NSSelectorFromString([NSString stringWithFormat:@"IIFishBlock_%@:",@(funcAddress)]);
    
    NSMethodSignature *ms = [IIFishBlockFuncHolder methodSignatureForSelector:orgSel];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:ms];
    inv.target = [IIFishBlockFuncHolder class];
    inv.selector = orgSel;
    [inv setArgument:block atIndex:2];
    [inv invoke];

    return;
}

static long long IIFish_Block_Get_Org_Address(id block) {
    return  [objc_getAssociatedObject(block, @"IIFish_Block_Org_Imp") longLongValue];
}

static void IIFish_Block_Set_Org_Address(id block, long  long orgFuncAddress) {
    objc_setAssociatedObject(block, @"IIFish_Block_Org_Imp", @(orgFuncAddress), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL IIFish_Block_TypeCheck(id object) {
    return [object isKindOfClass:NSClassFromString(@"NSBlock")];
}

static const char *IIFish_Block_ConvertBlockSignature(const char * signature) {
    NSString *tString = [NSString stringWithUTF8String:signature];
//    return [[tString stringByReplacingOccurrencesOfString:@"@?0" withString:[NSString stringWithFormat:@"@0:%@",@(sizeof(id))] options:2 range:[tString rangeOfString:@"@?0"]] UTF8String];
//    //v8@?0
//    //v24@0:8@16
    
    return [@"v24@0:8@?16" UTF8String];
}

static void IIFish_Hook_Block(id obj) {
    if (IIFish_Block_Get_Org_Address(obj) == 0) {
        IIFishBlock block = (__bridge IIFishBlock)(obj);
        long long blockOrgFuncAddress = (long long)block->invoke;
        
        NSString *fakeSelString = [NSString stringWithFormat:@"IIFishBlock_%@:",@(blockOrgFuncAddress)];
        
        SEL fakeSel = NSSelectorFromString(fakeSelString);
        if (!class_getClassMethod([IIFishBlockFuncHolder class], fakeSel)) {
            
            //deep copy

            struct IIFishBlock_layout newBlock;
            newBlock.isa = (__bridge void *)[obj class];
            newBlock.flags = block->flags;
            newBlock.invoke = block->invoke;
            newBlock.reserved = block->reserved;
            newBlock.descriptor = block->descriptor;
            
            
            IIFishBlock p = &newBlock;
            IMP fakeImp = imp_implementationWithBlock((__bridge id)p);
            struct IIFishBlock_descriptor_3 *des3 =  _IIFish_Block_descriptor_3(block);
            
            const char *c = IIFish_Block_ConvertBlockSignature (des3->signature);
            
            NSMethodSignature *ms = [NSMethodSignature signatureWithObjCTypes:c];
            
            class_addMethod(objc_getMetaClass(object_getClassName([IIFishBlockFuncHolder class])), fakeSel, fakeImp, c);
            
            NSLog(@"asdasd");
        }
        IIFish_Block_Set_Org_Address(obj, blockOrgFuncAddress);
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

    
    
    
    
    
    
    void (^testBlock)() = ^() {
        NSLog(@"bbTest");
    };
    
    
    IIFish_Hook_Block(testBlock);
    testBlock();
    
    NSLog(@"asdasdasdsa");
    
}



@end
