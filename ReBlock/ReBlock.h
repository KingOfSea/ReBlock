//
//  ReBlock.h
//  ReBlock
//
//  Created by wangzhihai on 2018/11/9.
//  Copyright © 2018年 WangZhihai. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, ReBlockOptions) {
    ReBlockPositionAfter            = 0,        /// Called after the original block excution (default).
    ReBlockPositionInstead          = 1,        /// Will replace the block excution.
    ReBlockPositionBefore           = 2,        /// Called before the block excution.
    ReBlockPositionReImplementation = 4,        /// Will Re-Implement the block excution.
    ReBlockOptionAutomaticRemoval   = 1 << 3,   ///Will remove the hook after the first execution.
};

typedef NS_ENUM(NSUInteger, ReBlockErrorCode) {
    ReBlockErrorNoBlockOrUsingBlock,            /// The origin-block or using-block is nil;
    ReBlockErrorWillRecursiveCall,              /// The using-block and origin-block are the same object.
    ReBlockErrorMissingBlockSignature,          /// The block misses compile time signature info and can't be called.
    ReBlockErrorIncompatibleBlockSignature,     /// The using-block signature does not match the origin-block or is too large.
    ReBlockErrorRemoveBlockDeallocated = 100,   /// (for removing) The block hooked is already deallocated.
};

/// Opaque ReBlock Token that allows to deregister the hook.
@protocol ReblockToken <NSObject>

/// Deregisters an ReBlock.
/// @return YES if deregistration is successful, otherwise NO.
/// If block is ReBlockPositionReImplementation, it does't work.
- (BOOL)remove;

@end

@protocol ReBlockInfo <NSObject>

/// The block that is currently hooked.
- (id)instance;

/// The original invocation of the hooked block.
- (NSInvocation *)originalInvocation;

@end

/**
 ReBlock uses Objective-C message forwarding to hook into messages.
 If block is ‘NSGlobalBlock’ or ‘NSStackBlock’,not a  ‘NSMallocBlock’, only excute the last hooked when options is ‘ReBlockPositionInstead’.
 If used ‘ReBlockErrorIncompatibleBlockSignature’ ever,it means that origin-block never be excuted.You can use it to resolve block-retain-cycle.
 If used ‘ReBlockPositionInstead’ or ‘ReBlockPositionReImplementation’,the invoke of origin-block will return the value of replaced invoke when their returnValue are same type.
 */
@interface ReBlock : NSObject

+ (id<ReblockToken>)reblock:(id)block
    withOptions:(ReBlockOptions)options
     usingBlock:(id)usingBlock
          error:(NSError **)error;

@end
