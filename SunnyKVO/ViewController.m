//
//  ViewController.m
//  SunnyKVO
//
//  Created by slyao on 15/11/26.
//  Copyright © 2015年 slyao. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+KVO.h"

@interface Message : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *age;

@end

@implementation Message

@end


@interface ViewController ()

@property (nonatomic, strong) Message *message;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.message = [[Message alloc] init];
    
    [self.message Sunny_addObserver:self forKey:@"name" withBlock:^(id obj, NSString *observedKey, id oldValue, id newValue) {
        NSLog(@"%@.%@ is now: %@", obj, observedKey, newValue);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.textField.text = newValue;
        });
    }];
    
    [self.message Sunny_addObserver:self forKey:@"age" withBlock:^(id obj, NSString *observedKey, id oldValue, id newValue) {
        NSLog(@"%@.%@ is now: %@", obj, observedKey, newValue);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.textfiled.text = newValue;
        });
    }];
    
    [self buttonClick:nil];
}
- (IBAction)buttonClick:(id)sender {
    NSArray *msgs = @[@"Hello World!", @"Objective C", @"Swift", @"Peng Gu", @"peng.gu@me.com", @"www.gupeng.me", @"glowing.com"];
    NSUInteger index = arc4random_uniform((u_int32_t)msgs.count);
    self.message.name = msgs[index];
    NSUInteger index1 = arc4random_uniform((u_int32_t)msgs.count);

    self.message.age = msgs[index1];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
