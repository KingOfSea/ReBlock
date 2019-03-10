//
//  ViewController1.m
//  ReBlock
//
//  Created by wangzhihai on 2018/11/29.
//  Copyright © 2018年 WangZhihai. All rights reserved.
//

#import "ViewController1.h"
#import "ReBlock.h"

typedef NSInteger (^TestBlk)(NSInteger,NSInteger);


@interface ViewController1 ()
@property (nonatomic, copy) TestBlk test;
@end

@implementation ViewController1

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"Test ReBlock";
    
    UIButton *button = [[UIButton alloc] initWithFrame:self.view.bounds];
    [button setTitle:@"Click Anywhere" forState:UIControlStateNormal];
    [button setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    [button addTarget:self action:@selector(click) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    [self unsafeBlock];
    [self safeBlock];
}

- (void)unsafeBlock{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    self.test = ^(NSInteger num1, NSInteger num2){
        self.view.backgroundColor = [UIColor redColor];
        NSLog(@"retain-cycle");
        return num1*num2;
    };
#pragma clang diagnostic push
}

- (void)safeBlock{
    __weak typeof(self) weakSelf = self;
    [ReBlock reblock:self.test withOptions:ReBlockPositionReImplementation usingBlock:^(id<ReBlockInfo> info,NSInteger num1, NSInteger num2){
        weakSelf.view.backgroundColor = [UIColor redColor];
        NSLog(@"not-retain-cycle");
        return num1+num2;
    } error:nil];
}

- (void)click{
    [self tryToGetData:self.test];
}

- (void)tryToGetData:(TestBlk)comp{
    NSInteger r = comp(2,6);
    NSLog(@"res = %ld",r);
}

- (void)dealloc{
    NSLog(@"ViewController1 dealloc");
}

@end
