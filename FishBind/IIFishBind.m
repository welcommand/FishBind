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

static NSInvocation * IIFish_Encoding(NSMethodSignature *methodSignature, NSInteger firstArgIndex, va_list list);


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
typedef void (*IIFishBlockFunc) (void*, ...);

static id IIFish_Block_Get_TempBlock(IIFishBlock block);
static BOOL IIFish_Block_TypeCheck(id object);

static  NSString const *IIFishBlockObserverKey = @"IIFishBlockObserverKey";

void IIFishBlockFuncPtr(IIFishBlock block, ...) {
    
    struct IIFishBlock_descriptor_3 *descriptor_3 =  _IIFish_Block_descriptor_3(block);
    NSMethodSignature *ms = [NSMethodSignature signatureWithObjCTypes:descriptor_3->signature];
    
    va_list ap;
    va_start(ap, block);
    NSInvocation *invo = IIFish_Encoding(ms, 1, ap);
    va_end(ap);
    
    id tempBlock = IIFish_Block_Get_TempBlock(block);
    
    if (!IIFish_Block_TypeCheck(tempBlock)) {
        struct IIFishBlock_layout tb;
        [(NSValue *)tempBlock getValue:&tb];
        tempBlock = (__bridge id)&tb;
    }
    
    invo.target = tempBlock;
    [invo invoke];
}

static id IIFish_Block_Get_TempBlock(IIFishBlock block) {
     return objc_getAssociatedObject((__bridge id)block, @"IIFish_Block_TempBlock");
}

static void IIFish_Block_Set_TempGlobalBlock(IIFishBlock block, struct IIFishBlock_layout tempBlockLayout) {
    NSValue *blockValue = [NSValue value:&tempBlockLayout withObjCType:@encode(struct IIFishBlock_layout)];
    objc_setAssociatedObject((__bridge id)block, @"IIFish_Block_TempBlock", blockValue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void IIFish_Block_Set_TempMallocBlock(IIFishBlock block, IIFishBlock tempBlock) {
    objc_setAssociatedObject((__bridge id)block, @"IIFish_Block_TempBlock", (__bridge id)tempBlock, OBJC_ASSOCIATION_ASSIGN);
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
    
    IIFishBlock newBlock = NULL;
    struct IIFishBlock_descriptor_2 *descriptor_2 = _IIFish_Block_descriptor_2(block);
    if (descriptor_2) {
        // size == block + ref objects ? need test
        newBlock = malloc(block->descriptor->size);
        if (!newBlock) return nil;
        memmove(newBlock, block, block->descriptor->size);
        descriptor_2->copy(newBlock, block);
        IIFish_Block_Set_TempMallocBlock(block, newBlock);
        IIFish_Block_HookDisposeFuncOnces(block);
    } else {
        struct IIFishBlock_layout block_layout;
        block_layout.isa = block->isa;
        block_layout.flags = block->flags;
        block_layout.invoke = block->invoke;
        block_layout.reserved = block->reserved;
        block_layout.descriptor = block->descriptor;
        IIFish_Block_Set_TempGlobalBlock(block, block_layout);
    }
    
    return newBlock;
}

static void IIFish_Hook_Block(id obj) {
    IIFishBlock block = (__bridge IIFishBlock)(obj);
    
    if (!IIFish_Block_Get_TempBlock(block)) {
        IIFish_Block_DeepCopy(block);
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

#pragma mark- Type Encodings
// https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html


static NSInvocation * IIFish_Encoding(NSMethodSignature *methodSignature, NSInteger firstArgIndex, va_list list) {
    
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
    
    for (NSInteger i = firstArgIndex; i < [methodSignature numberOfArguments]; i ++) {
        const char *argType = [methodSignature getArgumentTypeAtIndex:i];
        
        switch (argType[0]) {
            case 'c' : {
                char arg = va_arg(list, int);
                [invocation setArgument:(void *)&arg atIndex:i];
            } break;
            case 'i': {
                int arg = va_arg(list, int);
                [invocation setArgument:(void *)&arg atIndex:i];
            } break;
            case 's': {
                short arg = va_arg(list, int);
                [invocation setArgument:(void *)&arg atIndex:i];
            } break;
                //....
            case '@': {
                id arg = va_arg(list, id);
                [invocation setArgument:(__bridge void *)arg atIndex:i];
            } break;
            
           
        }
        
        
    }
    
    return invocation;
}





#pragma mark-
@implementation IIFishBind
+ (void)bindFishes:(NSArray <IIFish*> *)fishes {
    
}

#pragma mark-
#pragma mark- test


+ (void (^)(void))test:(id)obj {
    return ^() {
        NSLog(@"bbTest");
    };
}

+ (void)load {
    
    void (^testBlock)(char c)  = ^(char c) {
        NSLog(@"bbTest");
    };
    IIFish_Hook_Block(testBlock);

    
    testBlock('c');
    
    NSLog(@"asdasdasdsa");
    
}



@end
