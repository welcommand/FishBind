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
//kvo
// lock
// remove
// type codeing

static NSString const* IIFish_Prefix = @"IIFish_";

typedef NS_OPTIONS(NSInteger, IIFishFlage) {
    IIFish_IsBlock = (1 << 2),
    IIFish_Post =  (1 << 10),
    IIFish_Observer  =    (1 << 11),
    IIFish_Property = (1 << 20),
    IIFish_Seletor = (1 << 21)
};


@implementation IIFishCallBack
@end

#pragma mark-
#pragma mark- IIFish

@implementation IIFish

+ (instancetype)fish:(id)object property:(NSString*)property selector:(SEL)selector callBack:(IIFishCallBackBlock)callBack flag:(NSInteger)flag {
    IIFish *fish = [[self alloc] init];
    fish.object = object;
    fish.selector = selector;
    fish.property = property;
    fish.callBack = callBack;
    fish.flag = flag;
    return fish;
}

+ (instancetype)both:(id)object selector:(SEL)selector callBack:(IIFishCallBackBlock)callBack {
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
+ (instancetype)observer:(id)object callBack:(IIFishCallBackBlock)callBack {
    return [self fish:object property:nil selector:nil callBack:callBack flag:IIFish_Observer | IIFish_Seletor];
}
@end


#pragma mark-
#pragma mark- Dead Fish

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


@interface NSObject(IIFishBind_DeadFish)
@property (nonatomic, readonly) id iiDeadFish;
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
        objc_setAssociatedObject(self, _cmd, deadFish, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return deadFish;
}
@end

#pragma mark-
#pragma mark- ObserverAsset

@interface IIObserverAsset : NSObject

// key : orgSelector value : info
@property (nonatomic, strong) NSMutableDictionary <NSString *, NSString*>*methodAsset;
//key : orgSelector value : observer
@property (nonatomic, strong) NSMutableDictionary <NSString *, NSSet<IIFish *>*>*observerAsset;
@property (nonatomic, strong) dispatch_queue_t rwQueue;

- (void)asset:(void (^)(NSMutableDictionary <NSString *, NSString*> * methodAsset, NSMutableDictionary <NSString *, NSSet<IIFish *>*>*observerAsset))asset;

@end

@implementation IIObserverAsset

- (id)init {
    if (self  = [super init]) {
        _methodAsset = [NSMutableDictionary new];
        _observerAsset = [NSMutableDictionary new];
        _rwQueue = dispatch_queue_create("com.IIFishAsset.FishBind", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)asset:(void (^)(NSMutableDictionary <NSString *, NSString*> * methodAsset, NSMutableDictionary <NSString *, NSSet<IIFish *>*>*observerAsset))asset {
    dispatch_barrier_sync(_rwQueue, ^{
        asset(_methodAsset, _observerAsset);
    });
}
@end


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
#pragma mark- Type Encodings
// https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html



#define IIFishGetArgFromVAList(type1, type2) {type1 arg = va_arg(list, type2); return (void *)&arg;}
static char* testFunc(char *s,va_list list);


static void *test(char *type, va_list list) {;
    switch (type[0]) {
        case 'c' :
            IIFishGetArgFromVAList(char, int);
        case 'i':
            IIFishGetArgFromVAList(int, int);
        case 's':
            IIFishGetArgFromVAList(short, int);
        case 'l':
            IIFishGetArgFromVAList(long, long);
        case 'q': {
            void *v = NULL;
            char c[sizeof(long long)];
            
            long long arg = va_arg(list, long long);
            
            memcpy(c, (char *)&arg, 8);
            
            return c;
        }
            //IIFishGetArgFromVAList(long long, long long);
        case 'C':
            IIFishGetArgFromVAList(unsigned char, int);
        case 'I':
            IIFishGetArgFromVAList(unsigned int, unsigned int);
        case 'S':
            IIFishGetArgFromVAList(unsigned short, int);
        case 'L':
            IIFishGetArgFromVAList(unsigned long, unsigned long);
        case 'Q':
            IIFishGetArgFromVAList(unsigned long long, unsigned long long);
        case 'f':
            IIFishGetArgFromVAList(float, double);
        case 'd':{
            
        }
            //IIFishGetArgFromVAList(double, double);
        case 'B':
            IIFishGetArgFromVAList(BOOL, int);
        case '*':
            IIFishGetArgFromVAList(char *, char *);
        case '@':
            IIFishGetArgFromVAList(id, id);
        case '#':
            IIFishGetArgFromVAList(Class, Class);
        case ':':
            IIFishGetArgFromVAList(SEL, SEL);
        case '?' :
        case '^' :
            IIFishGetArgFromVAList(void *, void *);
        case '{' : {
            return  testFunc(type, list);
        }
    }
    
    return NULL;
}

static char* testFunc(char *s, va_list list) {
    NSUInteger valueSize = 0;
    NSGetSizeAndAlignment(s, &valueSize, NULL);
    char data[valueSize];
    int dataP = 0;
    
    for (int i = 0; i < strlen(s); i++) {
        if (s[i] == '{') {
            while (s[++i] != '=') {}
        } else if (s[i] == '[') {
            i++;
            int count = 0;
            while (isnumber(s[i])) {
                count = count * 10 + (s[i] - '0');
                i++;
            }
            if (count != 0) {
                //copy
            }
            i++;
        } else if (s[i] == '}' || s[i] == ']') {
        } else {
            char *t = test(s + i ,list);
            NSUInteger valueSize = 0;
            NSGetSizeAndAlignment(&s[i], &valueSize, NULL);
            
            for (int j = 0 ; j < valueSize;) {
                data[dataP++] = t[j++];
            }
            if (s[i] == '^') {
                while (s[++i] == '^') {}
                if (s[i] == '{' || s[i] == '[' || s[i] == '(') {
                    i+=2;
                } else {
                    i++;
                }
            }
        }
    }
    
    return data;
}


static void IIFish_TypeEncoding_Set_MethodArgs(NSInvocation *invocation, NSInteger firstArgIndex, va_list list) {
    
    for (NSInteger i = firstArgIndex; i < [invocation.methodSignature numberOfArguments]; i ++) {
        const char *argType = [invocation.methodSignature getArgumentTypeAtIndex:i];
        char *v = test(argType, list);
        long long  vv = atoll(v);
        
        CGFloat f1 = 321;
        CGFloat f2 = 222;
        char c [sizeof(CGFloat) * 2];
        
        for (int i = 0; i < sizeof(CGFloat); i++) {
            c[i] = ((char *)&f1)[i];
        }
        for (int i = sizeof(CGFloat); i < sizeof(CGFloat) * 2; i++) {
            c[i] = ((char *)&f2)[i];
        }
        
        
        NSInteger app = 445;
        char cf[sizeof(NSInteger)];
        for (int i = 0; i < sizeof(NSInteger); i++) {
            cf[i] = ((char *)&app)[i];
        }
        
        
        void *p = (void *)c;
        void *p1 = (void *)cf;
        
        [invocation setArgument:p atIndex:3];
        [invocation setArgument:p1 atIndex:2];
        continue;
        
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
            case '{' : {
                NSUInteger valueSize = 0;
                NSGetSizeAndAlignment(argType, &valueSize, NULL);
                CGFloat arg = va_arg(list, CGFloat);
                [invocation setArgument:&arg atIndex:i];
            }
        }
    }
}

static void *IIFish_TypeEncoding_Get_ReturnValue(const char *returnValueTypeCodeing, void *returnValue) {
    
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

static id IIFish_TypeEncoding_Get_ReturnValueInBox(NSInvocation *invocation) {
    const char *argType = [invocation.methodSignature methodReturnType];
    id argBox;
    switch (argType[0]) {
        case 'c' : {
            char arg;
            [invocation getReturnValue:&arg];
            argBox = [NSNumber numberWithChar:arg];
        } break;
        case 'i': {
            int arg;
            [invocation getReturnValue:&arg];
            argBox = [NSNumber numberWithInt:arg];
        } break;
        case 's': {
            short arg;
            [invocation getReturnValue:&arg];
            argBox = [NSNumber numberWithShort:arg];
        } break;
        case 'l': {
            long arg;
           [invocation getReturnValue:&arg];
            argBox = [NSNumber numberWithLong:arg];
        } break;
        case 'q': {
            long long arg;
            [invocation getReturnValue:&arg];
            argBox = [NSNumber numberWithLongLong:arg];
        } break;
        case 'C': {
            unsigned char arg;
            [invocation getReturnValue:&arg];
            argBox = [NSNumber numberWithUnsignedChar:arg];
        } break;
        case 'I': {
            unsigned int arg;
            [invocation getReturnValue:&arg];
            argBox = [NSNumber numberWithUnsignedInteger:arg];
        } break;
        case 'S': {
            unsigned short arg;
            [invocation getReturnValue:&arg];
            argBox = [NSNumber numberWithUnsignedShort:arg];
        } break;
        case 'L': {
            unsigned long arg;
            [invocation getReturnValue:&arg];
            argBox = [NSNumber numberWithUnsignedLong:arg];
        } break;
        case 'Q': {
            unsigned long long arg;
           [invocation getReturnValue:&arg];
            argBox = [NSNumber numberWithUnsignedLongLong:arg];
        } break;
        case 'f': {
            float arg;
            [invocation getReturnValue:&arg];
            argBox = [NSNumber numberWithFloat:arg];
        } break;
        case 'd': {
            double arg;
            [invocation getReturnValue:&arg];
            argBox = [NSNumber numberWithDouble:arg];
        } break;
        case 'B': {
            BOOL arg;
            [invocation getReturnValue:&arg];
            argBox = [NSNumber numberWithBool:arg];
        } break;
        case '*': {
            char *arg;
            [invocation getReturnValue:&arg];
            argBox = [[NSString alloc] initWithUTF8String:arg];
        } break;
        case '@': {
            id arg;
            [invocation getReturnValue:&arg];
            argBox = arg;
        } break;
        case '#': {
            Class arg;
            [invocation getReturnValue:&arg];
            argBox = NSStringFromClass(arg);
        } break;
        case ':': {
            SEL arg;
            [invocation getReturnValue:&arg];
            argBox = NSStringFromSelector(arg);
        } break;
    }

    return argBox;
}

static NSArray *IIFish_TypeEncoding_Get_MethodArgs(NSInvocation *invocation, NSInteger beginIndex) {
    
    NSMutableArray *args = [NSMutableArray new];
    for (NSInteger i = beginIndex; i < [invocation.methodSignature numberOfArguments]; i ++) {
        const char *argType = [invocation.methodSignature getArgumentTypeAtIndex:i];
        id argBox;
        switch (argType[0]) {
            case 'c' : {
                char arg;
                [invocation getArgument:&arg atIndex:i];
                argBox = [NSNumber numberWithChar:arg];
            } break;
            case 'i': {
                int arg;
                [invocation getArgument:&arg atIndex:i];
                argBox = [NSNumber numberWithInt:arg];
            } break;
            case 's': {
                short arg;
                [invocation getArgument:&arg atIndex:i];
                argBox = [NSNumber numberWithShort:arg];
            } break;
            case 'l': {
                long arg;
                [invocation getArgument:&arg atIndex:i];
                argBox = [NSNumber numberWithLong:arg];
            } break;
            case 'q': {
                long long arg;
                [invocation getArgument:&arg atIndex:i];
                argBox = [NSNumber numberWithLongLong:arg];
            } break;
            case 'C': {
                unsigned char arg;
                [invocation getArgument:&arg atIndex:i];
                argBox = [NSNumber numberWithUnsignedChar:arg];
            } break;
            case 'I': {
                unsigned int arg;
                [invocation getArgument:&arg atIndex:i];
                argBox = [NSNumber numberWithUnsignedInteger:arg];
            } break;
            case 'S': {
                unsigned short arg;
                [invocation getArgument:&arg atIndex:i];
                argBox = [NSNumber numberWithUnsignedShort:arg];
            } break;
            case 'L': {
                unsigned long arg;
                [invocation getArgument:&arg atIndex:i];
                argBox = [NSNumber numberWithUnsignedLong:arg];
            } break;
            case 'Q': {
                unsigned long long arg;
                [invocation getArgument:&arg atIndex:i];
                argBox = [NSNumber numberWithUnsignedLongLong:arg];
            } break;
            case 'f': {
                float arg;
                [invocation getArgument:&arg atIndex:i];
                argBox = [NSNumber numberWithFloat:arg];
            } break;
            case 'd': {
                double arg;
                [invocation getArgument:&arg atIndex:i];
                argBox = [NSNumber numberWithDouble:arg];
            } break;
            case 'B': {
                BOOL arg;
                [invocation getArgument:&arg atIndex:i];
                argBox = [NSNumber numberWithBool:arg];
            } break;
            case '*': {
                char *arg;
                [invocation getArgument:&arg atIndex:i];
                argBox = [[NSString alloc] initWithUTF8String:arg];
            } break;
            case '@': {
                id arg;
                [invocation getArgument:&arg atIndex:i];
                argBox = arg;
            } break;
            case '#': {
                Class arg;
                [invocation getArgument:&arg atIndex:i];
                argBox = NSStringFromClass(arg);
            } break;
            case ':': {
                SEL arg;
                [invocation getArgument:&arg atIndex:i];
                argBox = NSStringFromSelector(arg);
            } break;
        }
        
        if (argBox) {
            [args addObject:argBox];
        }
        
    }
    
    return args;
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
static IIObserverAsset *IIFish_Class_Get_Asset(id object);

static  NSString const *IIFishBlockObserverKey = @"IIFishBlockObserverKey";

void* IIFishBlockFuncPtr(IIFishBlock block, ...) {
    
    struct IIFishBlock_descriptor_3 *descriptor_3 =  _IIFish_Block_descriptor_3(block);
    NSMethodSignature *ms = [NSMethodSignature signatureWithObjCTypes:descriptor_3->signature];
    va_list ap;
    va_start(ap, block);
    NSInvocation *invo = [NSInvocation invocationWithMethodSignature:ms];
    IIFish_TypeEncoding_Set_MethodArgs(invo,1,ap);
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
    
    
    IIObserverAsset *asseet = IIFish_Class_Get_Asset((__bridge id)block);
    __block NSArray *observers;
    NSString *key = [IIFishBlockObserverKey copy];
    [asseet asset:^(NSMutableDictionary<NSString *,NSString *> *methodAsset, NSMutableDictionary<NSString *,NSSet<IIFish *> *> *observerAsset) {
        observers = [[observerAsset objectForKey:key] allObjects];
    }];
    
    
    IIFishCallBack *callBack = [[IIFishCallBack alloc] init];
    callBack.tager = (__bridge id)block;
    callBack.args = IIFish_TypeEncoding_Get_MethodArgs(invo,1);
    callBack.resule = IIFish_TypeEncoding_Get_ReturnValueInBox(invo);
    
    for (IIFish *fish in observers) {
        if (fish.callBack) {
            fish.callBack(callBack, [fish.object iiDeadFish]);
        }
    }
    
    return IIFish_TypeEncoding_Get_ReturnValue([ms methodReturnType], returnValue);
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


#pragma mark- Method Hook
#pragma mark-

static SEL IIFish_Property_GetSelector(Class cls, const char *propertyName);
static SEL IIFish_Property_SetSelector(Class cls, const char *propertyName);


static IIObserverAsset *IIFish_Class_Get_Asset(id object) {
    IIObserverAsset *asset = objc_getAssociatedObject(object, "IIFish_Class_Get_Asset");
    if (!asset) {
        asset = [[IIObserverAsset alloc] init];
        objc_setAssociatedObject(object, "IIFish_Class_Get_Asset", asset, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return asset;
}



void fakeForwardInvocation(id self, SEL _cmd, NSInvocation *anInvocation) {
    Class cls = object_getClass(self);
    SEL fakeSel = anInvocation.selector;
    NSString *orgSelString = [NSString stringWithFormat:@"%@%@", IIFish_Prefix,NSStringFromSelector(fakeSel)];
    anInvocation.selector = NSSelectorFromString(orgSelString);
    [anInvocation invoke];
    

    // asset
    IIObserverAsset *asseet = IIFish_Class_Get_Asset(self);
    __block NSArray *observers;
    __block NSString *info;
    NSString *key = NSStringFromSelector(fakeSel);
    [asseet asset:^(NSMutableDictionary<NSString *,NSString *> *methodAsset, NSMutableDictionary<NSString *,NSSet<IIFish *> *> *observerAsset) {
        info = [methodAsset objectForKey:key];
        observers = [[observerAsset objectForKey:key] allObjects];
    }];
    
    //
    IIFishCallBack * (^CallBackBlock)() = ^() {
        IIFishCallBack *callBack = [[IIFishCallBack alloc] init];
        callBack.tager = self;
        callBack.selector = NSStringFromSelector(anInvocation.selector);
        callBack.args = IIFish_TypeEncoding_Get_MethodArgs(anInvocation,2);
        callBack.resule = IIFish_TypeEncoding_Get_ReturnValueInBox(anInvocation);
        return callBack;
    };
    
    void *propertyValue = NULL;
    if (info.length > 0) {
        SEL postGetSel = IIFish_Property_GetSelector([self class], [info UTF8String]);
        
        Method m = class_getInstanceMethod(cls, postGetSel);
        NSMethodSignature *ms  = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(m)];
        NSInvocation *invo = [NSInvocation invocationWithMethodSignature:ms];
        
        invo.selector = postGetSel;
        [invo invokeWithTarget:[self iiDeadFish]];
        propertyValue = malloc([ms methodReturnLength]);
        
        [invo getReturnValue:propertyValue];
    }
    
    for (IIFish *fish in observers) {
        if (fish.flag & IIFish_Property && propertyValue != NULL) {
            SEL observerSetSel = IIFish_Property_SetSelector([fish.object class], [fish.property UTF8String]);
            NSMethodSignature *ms = [fish.object methodSignatureForSelector:observerSetSel];
            NSInvocation *invo = [NSInvocation invocationWithMethodSignature:ms];
            invo.selector = observerSetSel;
            [invo setArgument:propertyValue atIndex:2];
            [invo invokeWithTarget:[fish.object iiDeadFish]];
        } else if (fish.callBack) {
            IIFishCallBack *callBack = CallBackBlock();
            fish.callBack(callBack, [fish.object iiDeadFish]);
        }
    }
    
    free(propertyValue);
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

static SEL IIFish_Property_SetSelector(Class cls, const char *propertyName) {
    objc_property_t property = class_getProperty(cls, propertyName);
    if (!property) return 0;
    
    unsigned int count;
    objc_property_attribute_t *attributes = property_copyAttributeList(property, &count);
    
    for (unsigned i = 0; i < count; i++) {
        objc_property_attribute_t att = attributes[i];
        if (!strcmp(att.name, "S")) {
            char *s = malloc(strlen(att.value));
            strcpy(s, att.value);
            
            SEL sel = sel_getUid(s);
            free(attributes);
            free(s);
            return sel;
        }
    }
    
    char *s = malloc(strlen(propertyName) + 5);
    strcpy(s, "set");
    
    char firstC = propertyName[0];
    if (isalpha(firstC)) {
        s[3] = toupper(firstC);
        strcat(s, propertyName + 1);
    } else {
        strcat(s, propertyName);
    }
    strcat(s, ":");
    
    SEL sel = sel_getUid(s);
    free(attributes);
    free(s);
    return sel;
    
}

static SEL IIFish_Property_GetSelector(Class cls, const char *propertyName) {
    objc_property_t property = class_getProperty(cls, propertyName);
    if (!property) return 0;
    
    unsigned int count;
    objc_property_attribute_t *attributes = property_copyAttributeList(property, &count);
    
    for (unsigned i = 0; i < count; i++) {
        objc_property_attribute_t att = attributes[i];
        if (!strcmp(att.name, "G")) {
            char *s = malloc(strlen(att.value));
            strcpy(s, att.value);
            SEL sel = sel_getUid(s);
            free(attributes);
            free(s);
            return sel;

        }
    }
    char *s = malloc(strlen(propertyName));
    strcpy(s, propertyName);
    SEL sel = sel_getUid(s);
    free(attributes);
    free(s);
    return sel;
}

#pragma mark-

@implementation IIFishBind

+ (void)bindFishes:(NSArray <IIFish*> *)fishes {
    
    IIFish_Lock(^{
        for (IIFish *fish in fishes) {
            if (fish.flag & IIFish_Observer) continue;
            
            if (fish.flag & IIFish_Property) {// property
                SEL selector = IIFish_Property_SetSelector([fish.object class],[fish.property UTF8String]);
                if (!selector) continue;
                fish.selector = selector;
                IIFish_Hook_Class(fish.object);
                IIFish_Hook_Method(fish.object, selector);
            } else if (fish.flag & IIFish_Seletor) {// method
                IIFish_Hook_Class(fish.object);
                IIFish_Hook_Method(fish.object, fish.selector);
            } else if (fish.flag & IIFish_IsBlock) { // block
                IIFish_Hook_Block(fish.object);
            }
            
            NSString *key = fish.flag & IIFish_IsBlock ? IIFishBlockObserverKey : NSStringFromSelector(fish.selector);
            NSString *info =  fish.flag & IIFish_Property ? fish.property : @"";
            
            IIObserverAsset *asset = IIFish_Class_Get_Asset(fish.object);
            
            [asset asset:^(NSMutableDictionary<NSString *,NSString *> *methodAsset, NSMutableDictionary<NSString *,NSSet<IIFish *> *> *observerAsset) {
                [methodAsset addEntriesFromDictionary:@{key : info}];
                
                NSMutableSet *observerFishes = [NSMutableSet new];
                for (IIFish *f in fishes) {
                    if (f.flag & IIFish_Post ||  f == fish) continue;
                    [observerFishes addObject:f];
                }
                [observerAsset addEntriesFromDictionary:@{key : observerFishes}];
            }];
        }
    });
}

+ (void)removeFish:(NSArray <IIFish *> *)fishes {
    
}

@end
