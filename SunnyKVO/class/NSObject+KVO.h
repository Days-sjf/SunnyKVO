//
//  NSObject+KVO.h
//  SunnyKVO
//
//  Created by slyao on 15/11/26.
//  Copyright © 2015年 slyao. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^SunnyObservingBlock)(id obj, NSString *observedKey, id oldValue, id newValue);


@interface NSObject (KVO)

/***
 *
 *  注册监听
 *
 *********/
- (void)Sunny_addObserver:(NSObject *)obj
                   forKey:(NSString *)key
                withBlock:(SunnyObservingBlock)block;

/****
 *
 *  移除监听
 *
 *****/
- (void)Sunny_removeObserver:(NSObject *)obj
                      forKey:(NSString *)key;


@end
