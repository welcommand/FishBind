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
#import <objc/message.h>


#pragma mark-
#pragma mark- base model

@implementation IIFish

+ (instancetype)fish:(id)object oKey:(NSString *)oKey pKey:(NSString *)pKey callBack:(IIFishMindine)callBack {
    IIFish *fish = [[IIFish alloc] init];
    fish.object = object;
    fish.oKey = oKey;
    fish.pKey = pKey;
    fish.callBack = callBack;
    return fish;
}
@end

@implementation IIPostFish
+ (instancetype)fish:(id)object pKey:(NSString *)pKey {
    return [super fish:object oKey:nil pKey:pKey callBack:nil];
}
+ (instancetype)fish:(id)blockObject {
    return [super fish:blockObject oKey:nil pKey:nil callBack:nil];
}
@end

@implementation IIObserverFish
+ (instancetype)fish:(id)object oKey:(NSString *)oKey {
    return [super fish:object oKey:oKey pKey:nil callBack:nil];
}
+ (instancetype)fish:(id)object callBack:(IIFishMindine)callBack {
    return [super fish:object oKey:nil pKey:nil callBack:callBack];
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

#pragma mark- opensource

//code from
//https://opensource.apple.com/source/libclosure/libclosure-67

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

#pragma mark-

typedef void (*IIFishBlockFunc) (void*, ...);

static BOOL IIFish_Block_TypeCheck(id object);
static id IIFish_Block_Get_TempBlock(IIFishBlock block);
static void * IIFish_Encoding_ReruenValue(const char *returnValueTypeCodeing, void *returnValue);

static  NSString const *IIFishBlockObserverKey = @"IIFishBlockObserverKey";

void* IIFishBlockFuncPtr(IIFishBlock block, ...) {
    
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
    
    void *returnValue = malloc([ms methodReturnLength]);
    [invo invokeWithTarget:tempBlock];
    [invo getReturnValue:returnValue];
    
    return IIFish_Encoding_ReruenValue([ms methodReturnType], returnValue);
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
    
    IIFishBlock block = (IIFishBlock)block_Layout;
    id tempBlock = IIFish_Block_Get_TempBlock(block);
    free((__bridge void *)tempBlock);
    
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
            case 'l': {
                long arg = va_arg(list, long);
                [invocation setArgument:(void *)&arg atIndex:i];
            } break;
            case 'q': {
                long long arg = va_arg(list, long long);
                [invocation setArgument:(void *)&arg atIndex:i];
            } break;
            case 'C': {
                unsigned char arg = va_arg(list, int);
                [invocation setArgument:(void *)&arg atIndex:i];
            } break;
            case 'I': {
                unsigned int arg = va_arg(list, unsigned int);
                [invocation setArgument:(void *)&arg atIndex:i];
            } break;
            case 'S': {
                unsigned short arg = va_arg(list, int);
                [invocation setArgument:(void *)&arg atIndex:i];
            } break;
            case 'L': {
                unsigned long arg = va_arg(list, unsigned long);
                [invocation setArgument:(void *)&arg atIndex:i];
            } break;
            case 'Q': {
                unsigned long long arg = va_arg(list, unsigned long long);
                [invocation setArgument:(void *)&arg atIndex:i];
            } break;
            case 'f': {
                float arg = va_arg(list, double);
                [invocation setArgument:(void *)&arg atIndex:i];
            } break;
            case 'd': {
                double arg = va_arg(list, double);
                [invocation setArgument:(void *)&arg atIndex:i];
            } break;
            case 'B': {
                BOOL arg = va_arg(list, int);
                [invocation setArgument:(void *)&arg atIndex:i];
            } break;
            case '*': {
                char *arg = va_arg(list, char *);
                [invocation setArgument:arg atIndex:i];
            } break;
            case '@': {
                id arg = va_arg(list, id);
                [invocation setArgument:(__bridge void *)arg atIndex:i];
            } break;
            case '#': {
                Class arg = va_arg(list, Class);
                [invocation setArgument:(void *)&arg atIndex:i];
            } break;
            case ':': {
                SEL arg = va_arg(list, SEL);
                [invocation setArgument:(void *)&arg atIndex:i];
            } break;
        }
    }
    
    return invocation;
}

static void* IIFish_Encoding_ReruenValue(const char *returnValueTypeCodeing, void *returnValue) {
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wint-conversion"
    
    switch (returnValueTypeCodeing[0]) {
        case 'c' : {
            char *arg = returnValue;
            return *arg;
        }
        case 'i': {
            int *arg = returnValue;
            return *arg;
        }
    }
    
#pragma clang diagnostic pop
    
    return nil;
}

#pragma mark- Method Hook
#pragma mark-

static NSString const* IIFish_Prefix = @"IIFish_";

@interface IIDeadFish : NSProxy
@property (nonatomic, weak) id orgObject;
@end
@implementation IIDeadFish

- (nullable NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return [_orgObject methodSignatureForSelector:sel];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    invocation.target = _orgObject;
    invocation.selector =NSSelectorFromString( [NSString stringWithFormat:@"%@%@",IIFish_Prefix,NSStringFromSelector(invocation.selector)]);
    [invocation invoke];
}
@end



@interface NSObject(IIFishBind)
@property (nonatomic, strong) id iiDeadFish;
@end

@implementation NSObject (IIFishBind)

- (id)iiDeadFish {
    IIDeadFish *deadFish = objc_getAssociatedObject(self, _cmd);
    if (!deadFish) {
         deadFish = [IIDeadFish alloc];
        deadFish.orgObject= self;
        self.iiDeadFish = deadFish;
    }
    return deadFish;
}

- (void)setIiDeadFish:(id)iiDeadFish {
    objc_setAssociatedObject(self, @selector(iiDeadFish), iiDeadFish, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end






void fakeForwardInvocation(id self, SEL _cmd, NSInvocation *anInvocation) {
    SEL fakeSel = anInvocation.selector;
    NSString *orgSelString = [NSString stringWithFormat:@"%@%@", IIFish_Prefix,NSStringFromSelector(fakeSel)];
    anInvocation.selector = NSSelectorFromString(orgSelString);
    [anInvocation invoke];
}

static BOOL IIFish_Class_IsSafeObject(id object) {
    return [object class] == object_getClass(object) ||
    [NSStringFromClass(object_getClass(object)) hasPrefix:[IIFish_Prefix copy]];
}

static Class IIFish_Class_CreateFakeSubClass(id object) {
    Class orgCls = object_getClass(object);
    NSString *newClsStr = [NSString stringWithFormat:@"%@%@",IIFish_Prefix,NSStringFromClass(orgCls)];
    
    Class newCls = objc_allocateClassPair(orgCls, [newClsStr UTF8String], 0);
    
    if (newCls == Nil) {
        return Nil;
    }
    
    IMP imp_class = imp_implementationWithBlock(^(){
        return orgCls;
    });
    IMP imp_superClass = imp_implementationWithBlock(^(){
        return class_getSuperclass(orgCls);
    });
    
#define IIFish_Method_Type(aSelector) method_getTypeEncoding( class_getInstanceMethod([NSObject class], (aSelector)))
    
    class_addMethod(newCls, @selector(class), imp_class, IIFish_Method_Type(@selector(class)));
    class_addMethod(newCls, @selector(superclass), imp_superClass, IIFish_Method_Type(@selector(superclass)));
    class_addMethod(newCls, @selector(forwardInvocation:), (IMP)fakeForwardInvocation, IIFish_Method_Type(@selector(forwardInvocation:)));
    class_addIvar(newCls, "_IIFish_Bind", sizeof(BOOL), log2(sizeof(BOOL)), @encode(BOOL));
    objc_registerClassPair(newCls);
    
    return newCls;
}

static void IIFish_Hook_Class(id object) {
    if (!IIFish_Class_IsSafeObject(object)) {
        //error
        return;
    }
    
    if (!IIFish_ClassTable_ContainClass([object class])) {
        Class newCls = IIFish_Class_CreateFakeSubClass(object);
        IIFish_ClassTable_AddClass([object class]);
        object_setClass(object, newCls);
    }
}

static void IIFish_Hook_Method(id object, SEL cmd) {
    
    Class cls = object_getClass(object);
    Method orgMethod = class_getInstanceMethod(cls, cmd);
    NSString *fakeSelStr = [NSString stringWithFormat:@"%@%@", IIFish_Prefix,NSStringFromSelector(cmd)];
    SEL fakeSel = NSSelectorFromString(fakeSelStr);
    class_addMethod(cls, fakeSel, (IMP)_objc_msgForward , method_getTypeEncoding(orgMethod));
    class_addMethod(cls, cmd, method_getImplementation(orgMethod), method_getTypeEncoding(orgMethod));
    
    
    orgMethod = class_getInstanceMethod(cls, cmd);
    Method fakeMethod = class_getInstanceMethod(cls, fakeSel);
    method_exchangeImplementations(orgMethod, fakeMethod);
    
}


#pragma mark-
@implementation IIFishBind
+ (void)bindFishes:(NSArray <IIFish*> *)fishes {

}

- (void)testMethod {
    NSLog(@"asdasdas");
}

#pragma mark-
#pragma mark- test

+ (void (^)(void))test:(id)obj {
    return ^() {
        NSLog(@"bbTest");
    };
}

+ (void)load {
    
    //===== block test ===
    int (^testBlock)(char c, id obj)  = ^(char c, id obj) {
        return 30;
    };
    IIFish_Hook_Block(testBlock);

    int i = testBlock('c',[NSArray new]);
    
    NSLog(@"block hook====== i = %@",@(i));
    
    //=====class test ======
    
    IIFishBind *fish = [[IIFishBind alloc] init];
    IIFishBind *fish1 = [[IIFishBind alloc] init];
    
    IIFish_Hook_Class(fish);
    IIFish_Hook_Method(fish, @selector(testMethod));
    
    [fish testMethod];
    [fish.iiDeadFish testMethod];
    [fish1 testMethod];
    
    NSLog(@"asdasdsa");
    
    //
    
    
}


@end
