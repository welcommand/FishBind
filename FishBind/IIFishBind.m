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

//todo
//type coding
//pro sup  & name find
//kvo

#pragma mark-
#pragma mark- base model

typedef NS_OPTIONS(NSInteger, IIFishFlage) {
    IIFish_IsBlock = (1 << 2),
    IIFish_Post =  (1 << 10),
    IIFish_Observer  =    (1 << 11),
    IIFish_Property = (1 << 20),
    IIFish_Seletor = (1 << 21)
};


@implementation IIFish

+ (instancetype)fish:(id)object property:(NSString*)property selector:(SEL)selector callBack:(IIFishMindine)callBack flag:(NSInteger)flag {
    IIFish *fish = [[self alloc] init];
    fish.object = object;
    fish.selector = selector;
    fish.property = property;
    fish.callBack = callBack;
    fish.flag = flag;
    return fish;
}


+ (instancetype)both:(id)object selector:(SEL)selector callBack:(IIFishMindine)callBack {
    return [self  fish:object property:nil selector:selector callBack:callBack flag:IIFish_Seletor];
}
+ (instancetype)both:(id)object property:(NSString*)property {
    return [self fish:object property:property selector:nil callBack:nil flag:IIFish_Property];
}

+ (instancetype)postBlock:(id)blockObject {
    return [self fish:blockObject property:nil selector:nil callBack:nil flag:IIFish_Post | IIFish_IsBlock];
}

+ (instancetype)post:(id)object property:(NSString *)property {
    return [self fish:object property:property selector:nil callBack:nil flag:IIFish_Post | IIFish_Property];
}
+ (instancetype)post:(id)object selector:(SEL)selector {
    return [self fish:object property:nil selector:selector callBack:nil flag:IIFish_Post | IIFish_Seletor];
}

+ (instancetype)observer:(id)object property:(NSString *)property {
    return [self fish:object property:property selector:nil callBack:nil flag:IIFish_Observer | IIFish_Property];
}
+ (instancetype)observer:(id)object callBack:(IIFishMindine)callBack {
    return [self fish:object property:nil selector:nil callBack:callBack flag:IIFish_Observer | IIFish_Seletor];
}

@end


static NSInvocation * IIFish_Encoding(NSMethodSignature *methodSignature, NSInteger firstArgIndex, va_list list);


#pragma mark-
#pragma mark- lock

static void IIFish_Lock(dispatch_block_t block) {
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
    
    SEL orgSel =NSSelectorFromString( [NSString stringWithFormat:@"%@%@",IIFish_Prefix,NSStringFromSelector(invocation.selector)]);
    Method method = class_getInstanceMethod(object_getClass(_orgObject), orgSel);
    if (method) {
        invocation.selector = orgSel;
    }
    
    [invocation invoke];
}
@end


#pragma mark-
#pragma mark- deadfish

@interface NSObject(IIFishBind_DeadFish)
@property (nonatomic, strong) id iiDeadFish;
@end

@implementation NSObject (IIFishBind_DeadFish)

- (id)iiDeadFish {
    Class cls = object_getClass(self);
    if (![NSStringFromClass(cls) hasPrefix:[IIFish_Prefix copy]]) {
        return self;
    }
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

#pragma mark-
#pragma mark- observer Fish info


#pragma mark-
#pragma mark- methodAsset

@interface IIFishMethodAsset : NSObject

@property (nonatomic, strong) NSMutableDictionary *methodAsset;

- (void)methodAsset:(void (^)(NSMutableDictionary *methodAsset))asset;
- (void)observerFishesWithKey:(NSString *)key asset:(void (^)(NSMutableSet <IIFish *>*observerFishes))asset;

@end

@implementation IIFishMethodAsset

- (id)init {
    if (self  = [super init]) {
        _methodAsset = [NSMutableDictionary new];
    }
    return self;
}

- (void)methodAsset:(void (^)(NSMutableDictionary *methodAsset))asset {
    IIFish_Lock(^{
        asset(_methodAsset);
    });
}

- (void)observerFishesWithKey:(NSString *)key asset:(void (^)(NSMutableSet <IIFish *>*observerFishes))asset {
    [self methodAsset:^(NSMutableDictionary *methodAsset) {
        
        NSMutableSet *fishesSet = [methodAsset objectForKey:key];
        if (!fishesSet) {
            fishesSet = [NSMutableSet new];
            [methodAsset addEntriesFromDictionary:@{key : fishesSet}];
        }
        asset(fishesSet);
    }];
}

@end


static IIFishMethodAsset *IIFish_Class_Get_Asset(id object) {
    IIFishMethodAsset *asset = objc_getAssociatedObject(object, "IIFish_Class_Get_Asset");
    if (!asset) {
        asset = [[IIFishMethodAsset alloc] init];
        objc_setAssociatedObject(object, "IIFish_Class_Get_Asset", asset, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return asset;
}



void fakeForwardInvocation(id self, SEL _cmd, NSInvocation *anInvocation) {
    SEL fakeSel = anInvocation.selector;
    NSString *orgSelString = [NSString stringWithFormat:@"%@%@", IIFish_Prefix,NSStringFromSelector(fakeSel)];
    anInvocation.selector = NSSelectorFromString(orgSelString);
    [anInvocation invoke];
    
    // fake code
    
    NSString *returnValue;
    [anInvocation getArgument:&returnValue atIndex:2];
    
    
    IIFishMethodAsset *asseet = IIFish_Class_Get_Asset(self);
    __block NSArray *observers;
    [asseet observerFishesWithKey:NSStringFromSelector(fakeSel) asset:^(NSMutableSet<IIFish *> *observerFishes) {
        observers = [[observerFishes allObjects] copy];
    }];
    
//    for(IIFish *fish in observers) {
//        SEL sel = fish.oKey;
//        [[fish.object iiDeadFish] performSelector:sel withObject:returnValue];
//    }
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

#pragma mark- Property helper



static SEL IIFish_Property_GetSelector(Class cls, const char *propertyName) {
    objc_property_t property = class_getProperty(cls, propertyName);
    if (!property) return 0;
    
    unsigned int count;
    objc_property_attribute_t *attributes = property_copyAttributeList(property, &count);
    
    char *selector = NULL;
    for (unsigned i = 0; i < count; i++) {
        objc_property_attribute_t att = attributes[i];
        if (strcmp(att.name, "S")) {
            strcpy(selector, att.name);
        }
    }
    
    if (!selector) {
        char c = toupper(propertyName[0]);
        strcpy(selector, "set");
        strcat(selector, &c);
        strcat(selector, propertyName + 1);
    }
    
    free(property);
    free(attributes);
    return NSSelectorFromString([NSString stringWithCString:selector encoding:NSUTF8StringEncoding]);
}

//typedef struct {
//    char * getSelector;
//    char * setSelector;
//} IIFishPropertySelector;
//
//static IIFishPropertySelector * IIFish_Property_selector(Class cls, const char *propertyName) {
//
//    objc_property_t property = class_getProperty(cls, propertyName);
//    if (!property) return nil;
//
//    unsigned int count;
//    objc_property_attribute_t *attributes = property_copyAttributeList(property, &count);
//
//    IIFishPropertySelector *propertySelector = malloc(sizeof(IIFishPropertySelector));
//    for (unsigned i = 0; i < count; i++) {
//        objc_property_attribute_t att = attributes[i];
//        if (strcmp(att.name, "G")) {
//             strcpy(propertySelector->getSelector, att.name);
//        } else if (strcmp(att.name, "S")) {
//            strcpy(propertySelector->setSelector, att.name);
//        }
//    }
//
//    if (!propertySelector->getSelector) {
//        strcpy(propertySelector->getSelector, propertyName);
//    } else if (!propertySelector->setSelector) {
//        char c = toupper(propertyName[0]);
//        strcpy(propertySelector->setSelector, "set");
//        strcat(propertySelector->setSelector, &c);
//        strcat(propertySelector->setSelector, propertyName + 1);
//    }
//
//    free(property);
//    free(attributes);
//    return propertySelector;
//}


#pragma mark-

@implementation IIFishBind

+ (void)bindFishes:(NSArray <IIFish*> *)fishes {
    
    for (IIFish *fish in fishes) {
        if (fish.flag & IIFish_Observer) continue;
        
        // property
        if (fish.flag & IIFish_Property) {
            SEL selector = IIFish_Property_GetSelector(fish.object,[fish.property UTF8String]);
            if (!selector) continue;
            fish.selector = selector;
            IIFish_Hook_Class(fish.object);
            IIFish_Hook_Method(fish.object, selector);
            continue;
        }
        
        //method
        if (fish.flag & IIFish_Seletor) {
            IIFish_Hook_Class(fish.object);
            IIFish_Hook_Method(fish.object, fish.selector);
            continue;
        }
        
        // block
        if (fish.flag & IIFish_IsBlock) {
            IIFish_Hook_Block(fish.object);
            continue;
        }
        
        NSString *key = fish.flag & IIFish_IsBlock ? IIFishBlockObserverKey : NSStringFromSelector(fish.selector);

        IIFishMethodAsset *asset = IIFish_Class_Get_Asset(fish.object);
        [asset observerFishesWithKey:key asset:^(NSMutableSet<IIFish *> *observerFishes) {
            for (IIFish *f in fishes) {
                if (f.flag & IIFish_Post ||  f == fish) continue;
                [observerFishes addObject:f];
            }
        }];
    }
}

+ (void)removeFish:(NSArray <IIFish *> *)fishes {
    
}





#pragma mark-
#pragma mark- test

- (void)testMethod {
    NSLog(@"asdasdas");
}

+ (void (^)(void))test:(id)obj {
    return ^() {
        NSLog(@"bbTest");
    };
}

+ (void)load {
    
    //===== block test ===
//    int (^testBlock)(char c, id obj)  = ^(char c, id obj) {
//        return 30;
//    };
//    IIFish_Hook_Block(testBlock);
//
//    int i = testBlock('c',[NSArray new]);
//
//    NSLog(@"block hook====== i = %@",@(i));
    
    //=====class test ======
    
//    IIFishBind *fish = [[IIFishBind alloc] init];
//    IIFishBind *fish1 = [[IIFishBind alloc] init];
//
//    IIFish_Hook_Class(fish);
//    IIFish_Hook_Method(fish, @selector(testMethod));
//
//    [fish testMethod]; // hook
//    [fish.iiDeadFish testMethod]; // not hook
//    [fish1 testMethod]; // not hook
//
//    NSLog(@"asdasdsa");
    
    //=======  bind test ====
    
}
@end



