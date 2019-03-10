//
//  RBTestObj.h
//  RBTestKit
//
//  Created by 王志海 on 2019/3/10.
//  Copyright © 2019年 C.King. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RBTestObj : NSObject

- (void)run;

@end

//@implementation RBTestObj
//
//- (void)run{
//    [self runWithBlock:^(NSString *str1, NSString *str2){
//        NSLog(@"Param is %@,%@",str1, str2);
//    }];
//}
//
//- (void)runWithBlock:(void (^)(NSString *str1, NSString *str2))block{
//    if (block) {
//        NSString *str1 = @"RBTest1";
//        NSString *str2 = @"RBTest2";
//        block(str1, str2);
//    }
//}
//
//@end
