//
//  ViewController2.m
//  ReBlockDemo
//
//  Created by 王志海 on 2019/3/10.
//  Copyright © 2019年 KingOfSea. All rights reserved.
//

#import "ViewController2.h"
#import <RBTestKit/RBTestKit.h>
#import <objc/runtime.h>
#import "ReBlock.h"

@interface RBTestObj (Hook)
@end

@implementation RBTestObj (Hook)

+ (void)load{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL sel_old = @selector(runWithBlock:);
        SEL sel_new = @selector(rb_runWithBlock:);
        Method methd_old = class_getInstanceMethod(self, sel_old);
        Method methd_new = class_getInstanceMethod(self, sel_new);
        BOOL result = class_addMethod(self, sel_new, method_getImplementation(methd_new), method_getTypeEncoding(methd_new));
        if (result == NO) {
            method_exchangeImplementations(methd_old, methd_new);
        }
    });
}

- (void)rb_runWithBlock:(void (^)(NSString *str1, NSString *str2))block{
    [ReBlock reblock:block withOptions:ReBlockPositionBefore usingBlock:^(id<ReBlockInfo> info, NSString *str1, NSString *str2){
        str1 = @"hook_str1";
        str2 = @"hook_str2";
        [info.originalInvocation setArgument:&str1 atIndex:1];
        [info.originalInvocation setArgument:&str2 atIndex:2];
    } error:nil];
    [self rb_runWithBlock:block];
}

@end

@interface ViewController2 ()

@end

@implementation ViewController2


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];

    RBTestObj *rbObj = [RBTestObj new];
    [rbObj run];
    
    UILabel *label = [[UILabel alloc] initWithFrame:self.view.bounds];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = @"Look At The Log Of Control";
    [self.view addSubview:label];
}


@end
