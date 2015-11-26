//
//  NSObject+KVO.m
//  SunnyKVO
//
//  Created by slyao on 15/11/26.
//  Copyright © 2015年 slyao. All rights reserved.
//

#import "NSObject+KVO.h"
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *SunnyKVOClassPrefix = @"SunnyKVOPrefix_";
static NSString *SunnyKVOAssociatedObservers = @"SunnyKVOAssociatedObservers";

@interface SunnyKVOInfo : NSObject

@property(nonatomic, strong) NSObject *obj;
@property(nonatomic, strong) NSString *key;
@property(nonatomic, copy) SunnyObservingBlock block;

@end

@implementation SunnyKVOInfo

- (instancetype)initWithObserver:(NSObject *)obj key:(NSString *)key block:(SunnyObservingBlock)block
{
    self = [super init];
    if(self)
    {
        _obj = obj;
        _key = key;
        _block = block;
    }
    return self;
}

@end

@implementation NSObject (KVO)


- (void)Sunny_addObserver:(NSObject *)obj forKey:(NSString *)key withBlock:(SunnyObservingBlock)block
{
    SEL setterMethod = NSSelectorFromString([self setterMethod:key]);
    Method setMethod = class_getInstanceMethod([self class], setterMethod);
    
    //判断是否有set方法，没有set方法抛出异常
    if (!setMethod) {
        NSString *reason = [NSString stringWithFormat:@"Object %@ does not have a setter for key %@", self, key];
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:reason
                                     userInfo:nil];
        
        return;
    }
    
    //存在set方法，则动态创建一个类
    
    Class currentClass = object_getClass(self);
    NSString *className = NSStringFromClass(currentClass);
    
    if (![className hasPrefix:SunnyKVOClassPrefix]) {
        currentClass = [self creatClassWithSunnyPrefix:className];
    }
    
    // 判断新增的class是否有set方法
    if (![self hasSelector:setterMethod]) {
        
        //没有set方法则新增一个set方法
        const char *types = method_getTypeEncoding(setMethod);
        IMP imp = method_getImplementation(class_getInstanceMethod([self class], @selector(Sunny_setMethod:)));
        class_addMethod(currentClass, setterMethod, imp, types);
    }
    
    //将info信息和SunnyKVOAssociatedObservers进行关联
    SunnyKVOInfo *info = [[SunnyKVOInfo alloc] initWithObserver:obj key:key block:block];
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(SunnyKVOAssociatedObservers));
    //如果没有关联则新建一个关联
    if (!observers) {
        observers = [NSMutableArray array];
        objc_setAssociatedObject(self, (__bridge const void *)(SunnyKVOAssociatedObservers), observers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [observers addObject:info];
    
}

- (void)Sunny_removeObserver:(NSObject *)obj forKey:(NSString *)key
{
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(SunnyKVOAssociatedObservers));
    
    for (SunnyKVOInfo *info in observers) {
        if ([info.obj isEqual:obj] && [info.key isEqualToString:key]) {
            [observers removeObject:info];
            break;
        }
    }
}

/****
 *
 * 复写set方法
 *
 *****/
- (void)Sunny_setMethod:(id)newValue
{
    NSString *setterName = NSStringFromSelector(_cmd);
    NSString *getterName = [self getterMethod:setterName];
    
    //判断是否存在get方法，不存在抛出异常
    if (!getterName) {
        NSString *reason = [NSString stringWithFormat:@"Object %@ does not have setter %@", self, setterName];
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:reason
                                     userInfo:nil];
        return;
    }
    //存在则获取旧的值
    id oldValue = [self valueForKey:getterName];
    
    //创建一个父类的结构体   接受者为消息接受者为当前类
    struct objc_super superclass = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self))
    };
    
    //创建一个父类对象消息传递的指针
    void (*sunny_msgSendSuper)(void *, SEL, id) = (void *)objc_msgSendSuper;
    //调用父类的set方法
    //相当于[super setXXX];
    sunny_msgSendSuper(&superclass, _cmd, newValue);
    
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(SunnyKVOAssociatedObservers));
    for (SunnyKVOInfo *info in observers) {
        if ([info.key isEqualToString:getterName]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                info.block(self, getterName, oldValue, newValue);
            });
        }
    }
}

/****
 *
 * 复写class 方法
 *
 *****/
- (Class)Sunny_Class
{
    return class_getSuperclass(object_getClass(self));
}


#pragma mark-  Tool Method
/****
 *
 * 根据set方法获取get方法名
 *
 *****/
- (NSString *)getterMethod:(NSString *)setter
{
    if (setter.length <=0 || ![setter hasPrefix:@"set"] || ![setter hasSuffix:@":"]) {
        return nil;
    }
    
    // 去除头部的set 和尾部的:
    NSRange range = NSMakeRange(3, setter.length - 4);
    NSString *key = [setter substringWithRange:range];
    
    // 首字符小写
    NSString *firstLetter = [[key substringToIndex:1] lowercaseString];
    key = [key stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                       withString:firstLetter];
    
    return key;
}

/****
 *
 * 根据get方法获取set方法名
 *
 *****/
- (NSString *)setterMethod:(NSString *)getter
{
    if (getter.length <= 0) {
        return nil;
    }
    // 首字符大写
    NSString *firstLetter = [[getter substringToIndex:1] uppercaseString];
    NSString *remainingLetters = [getter substringFromIndex:1];
    
    // 头部添加set
    NSString *setter = [NSString stringWithFormat:@"set%@%@:", firstLetter, remainingLetters];
    
    return setter;
}

- (BOOL)hasSelector:(SEL)selector
{
    Class clazz = object_getClass(self);
    unsigned int methodCount = 0;
    Method* methodList = class_copyMethodList(clazz, &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL thisSelector = method_getName(methodList[i]);
        if (thisSelector == selector) {
            free(methodList);
            return YES;
        }
    }
    free(methodList);
    return NO;
}

- (Class)creatClassWithSunnyPrefix:(NSString *)className
{
    NSString *sunnyClassName = [SunnyKVOClassPrefix stringByAppendingString:className];
    Class sunnyClass = NSClassFromString(sunnyClassName);
    
    if (sunnyClass) {
        object_setClass(self, sunnyClass);
        return sunnyClass;
    }
    
    //如果带前缀的类不存在，则新建一个类
    Class originalClass = object_getClass(self);
    Class kvoClass = objc_allocateClassPair(originalClass, sunnyClassName.UTF8String, 0);
    
    //新建的类复写class方法
    Method clazzMethod = class_getInstanceMethod(originalClass, @selector(class));
    const char *types = method_getTypeEncoding(clazzMethod);

    IMP imp = method_getImplementation(class_getInstanceMethod([self class], @selector(Sunny_Class)));
    class_addMethod(kvoClass, @selector(class), imp, types);
    
    //向runtime注册新建的类
    objc_registerClassPair(kvoClass);
    //将当前类的指针指向新建的类
    object_setClass(self, kvoClass);
    
    return kvoClass;
}
@end
