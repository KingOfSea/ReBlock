//
//  ReBlock.m
//  ReBlock
//
//  Created by wangzhihai on 2018/11/9.
//  Copyright © 2018年 WangZhihai. All rights reserved.
//

#import "ReBlock.h"
#import <libkern/OSAtomic.h>
#import <objc/runtime.h>
#import <objc/message.h>

#define ReBlockPositionFilter 0x07

#define ReblockLog(...)
#define ReblockLogError(...) do { NSLog(__VA_ARGS__); }while(0)

#define ReblockError(errorCode, errorDescription) \
do { \
    ReblockLogError(@"ReBlock: %@", errorDescription); \
    if (error) {\
        *error = [NSError errorWithDomain:ReblockErrorDomain code:errorCode userInfo:@{NSLocalizedDescriptionKey: errorDescription}];\
    }\
}while(0)

#define ReblockStrongError(errorCode, errorDescription)\
do { \
    ReblockLogError(@"ReBlock: %@", errorDescription); \
    strongError = [NSError errorWithDomain:ReblockErrorDomain code:errorCode userInfo:@{NSLocalizedDescriptionKey: errorDescription}];\
}while(0)

NSString *const ReblockErrorDomain = @"ReblockErrorDomain";

struct RB_Block_Impl;
typedef struct RB_Block_Impl *RB_Block;

@interface ReBlockIdentifier : NSObject

@property (nonatomic, weak, readonly) id originBlock;
@property (nonatomic, assign) ReBlockOptions options;
@property (nonatomic, copy) id usingBlock;

+ (instancetype)identifierWithBlockObject:(id)blockObject
                                  options:(ReBlockOptions)options
                               usingBlock:(id)usingBlock
                                    error:(NSError **)error;
- (BOOL)invokeWithInfo:(id<ReBlockInfo>)info;

- (BOOL)remove;

@end


@interface ReBlockContainer : NSObject

@property (nonatomic, strong) NSValue *blockValue;
@property (nonatomic, weak) id originBlock;
@property (nonatomic, assign, readonly) id copyedBlock;

@property (atomic, copy) NSArray *beforeReBlocks;
@property (atomic, copy) NSArray *insteadReBlocks;
@property (atomic, copy) NSArray *afterReBlocks;
@property (atomic, strong) ReBlockIdentifier *lastIdentifierReImp;

@property (nonatomic, assign) BOOL hasBeenReImplemented;

+ (instancetype)containerWithBlockObject:(id)blockObj;
- (void)addIdentifier:(ReBlockIdentifier *)reblockIdentifier;
- (BOOL)removeIdentifier:(id)identifier;

@end


@interface ReBlockInfo : NSObject<ReBlockInfo>

@property (nonatomic, readonly, weak) id instance;
@property (nonatomic, readonly, strong) NSInvocation *originalInvocation;

- (id)initWithInstance:(id)instance invocation:(NSInvocation *)invocation;
@end

@interface ReBlock()

@property (nonatomic, strong) NSValue *blockValue;
@property (nonatomic, assign, readonly) RB_Block origin_block;
@property (nonatomic, assign) ReBlockOptions options;
@property (nonatomic, copy) id usingBlock;

@end

typedef NS_OPTIONS(int, ReBlockFlag) {
    RE_BLOCK_HAS_COPY_DISPOSE   =   (1 << 25),
    RE_BLOCK_HAS_SIGNATURE      =   (1 << 30)
};

#pragma mark -

struct rb_block_desc {
    size_t reserved;
    size_t Block_size;
    void (*copy)(void *dst, const void *src);
    void (*dispose)(const void *);
    const char *signature;
    const char *layout;
};

struct rb_block_desc_0 {
    size_t reserved;
    size_t Block_size;
};

struct rb_block_desc_1 {
    void (*copy)(void *dst, const void *src);
    void (*dispose)(const void *);
};

struct rb_block_desc_2 {
    const char *signature;
    const char *layout;
};

struct RB_Block_Impl {
    void *isa;
    int Flags;
    int Reserved;
    void *FuncPtr;
    struct rb_block_desc *Desc;
};

@implementation ReBlock

+ (id<ReblockToken>)reblock:(id)block withOptions:(ReBlockOptions)options usingBlock:(id)usingBlock error:(NSError **)error{
    if (!usingBlock || !block) {
        ReblockError(ReBlockErrorNoBlockOrUsingBlock, @"There is no block or using-block can be used.");
        return nil;
    }
    if (usingBlock == block) {
        ReblockError(ReBlockErrorWillRecursiveCall, @"The hook will recursive call Because the Block and the Using-block are the same object.");
        return nil;
    }
    return reblock_add(block, options, usingBlock, error);
}


#pragma mark -
static id NSBlockFromRBBlock(RB_Block rb_block){
    return (__bridge id)(rb_block);
}

static RB_Block RBBlockFromNSBlock(id block){
    return (__bridge RB_Block)(block);
}

static id reblock_add(id self, ReBlockOptions options, id usingBlock, NSError **error){
    NSCParameterAssert(self);
    NSCParameterAssert(usingBlock);
    __block ReBlockIdentifier *identifier = nil;
    __block NSError *strongError = nil;
    
    reblock_performLocked(^{
        if (self) {
            reblock_NSBlock_hookOnces();
            
            RB_Block block = RBBlockFromNSBlock(self);
            
            ReBlockContainer *container = reblock_getContainerForObject(self);
            identifier = [ReBlockIdentifier identifierWithBlockObject:self options:options usingBlock:usingBlock error:&strongError];
            if (identifier) {
                [container addIdentifier:identifier];
                struct rb_block_desc_2 *descriptor_2 =  reblock_desc_2(block);
                block->FuncPtr = (void *)reblock_forward(descriptor_2->signature);
            }
        }
        
    });
    if (strongError) {
        *error = strongError;
    }
    return identifier;
}

static BOOL reblock_remove(ReBlockIdentifier *identifier, NSError **error){
    NSCAssert([identifier isKindOfClass:ReBlockIdentifier.class], @"Must have correct type.");
    
    __block BOOL success = NO;
    __block NSError *strongError = nil;
    reblock_performLocked(^{
        id self = identifier.originBlock; // strongify
        if (self) {
            ReBlockContainer *reblockContainer = reblock_getContainerForObject(self);
            success = [reblockContainer removeIdentifier:identifier];
            if (success) {
                identifier.usingBlock = nil;
            }
        }else {
            NSString *errrorDesc = [NSString stringWithFormat:@"Unable to deregister hook. Object already deallocated: %@", identifier];
            ReblockStrongError(ReBlockErrorRemoveBlockDeallocated, errrorDesc);
        }
    });
    if (strongError) {
        *error = strongError;
    }
    return success;
}

static void reblock_performLocked(dispatch_block_t block) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    static OSSpinLock reblock_lock = OS_SPINLOCK_INIT;
    OSSpinLockLock(&reblock_lock);
    block();
    OSSpinLockUnlock(&reblock_lock);
#pragma clang diagnostic pop
}

static ReBlockContainer *reblock_getContainerForObject(id self) {
    NSCParameterAssert(self);
    ReBlockContainer *reblockContainer = objc_getAssociatedObject(self, @"reblock_container");
    if (!reblockContainer) {
        reblockContainer = [ReBlockContainer containerWithBlockObject:self];
        objc_setAssociatedObject(self, @"reblock_container", reblockContainer, OBJC_ASSOCIATION_RETAIN);
    }
    return reblockContainer;
}

static BOOL reblock_isCompatibleBlockSignature(NSMethodSignature *blockSig, NSMethodSignature *usingblkSig, NSError **error) {
    NSCParameterAssert(blockSig);
    NSCParameterAssert(usingblkSig);
    
    BOOL signaturesMatch = YES;
    if (usingblkSig.numberOfArguments > blockSig.numberOfArguments+1) {
        signaturesMatch = NO;
    }else {
        if (usingblkSig.numberOfArguments > 1) {
            const char *blockType = [usingblkSig getArgumentTypeAtIndex:1];
            if (blockType[0] != '@') {
                signaturesMatch = NO;
            }
        }
        // Argument 0 is origin-block/using-block, argument 1 is param or id<ReBlockInfo>. We start comparing at argument 2.
        // The block can have less arguments than the method, that's ok.
        if (signaturesMatch) {
            for (NSUInteger idx = 2; idx < usingblkSig.numberOfArguments-1; idx++) {
                const char *methodType = [blockSig getArgumentTypeAtIndex:idx-1];
                const char *blockType = [usingblkSig getArgumentTypeAtIndex:idx];
                // Only compare parameter, not the optional type data.
                if (!methodType || !blockType || methodType[0] != blockType[0]) {
                    signaturesMatch = NO; break;
                }
            }
        }
    }
    
    if (!signaturesMatch) {
        NSString *description = [NSString stringWithFormat:@"Using-block signature %@ doesn't match Origin-block signature %@.", usingblkSig, blockSig];
        ReblockError(ReBlockErrorIncompatibleBlockSignature, description);
        return NO;
    }
    return YES;
}

static IMP reblock_forward(const char *methodTypes) {
    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    if (methodTypes[0] == '{') {
        NSMethodSignature *methodSignature = [NSMethodSignature signatureWithObjCTypes:methodTypes];
        if ([methodSignature.debugDescription rangeOfString:@"is special struct return? YES"].location != NSNotFound) {
            msgForwardIMP = (IMP)_objc_msgForward_stret;
        }
    }
#endif
    return msgForwardIMP;
}

void reblock_strongHookMethod(Class cls, SEL selector, IMP func){
    Method method = class_getInstanceMethod([NSObject class], selector);
    BOOL success = class_addMethod(cls, selector, func, method_getTypeEncoding(method));
    if (!success) {
        class_replaceMethod(cls, selector, func, method_getTypeEncoding(method));
    }
}

static struct rb_block_desc_1 * reblock_desc_1(RB_Block aBlock)
{
    if (! (aBlock->Flags & RE_BLOCK_HAS_COPY_DISPOSE)) return NULL;
    uint8_t *desc = (uint8_t *)aBlock->Desc;
    desc += sizeof(struct rb_block_desc_0);
    return (struct rb_block_desc_1 *)desc;
}

static struct rb_block_desc_2 * reblock_desc_2(RB_Block aBlock)
{
    if (! (aBlock->Flags & RE_BLOCK_HAS_SIGNATURE)) return NULL;
    uint8_t *desc = (uint8_t *)aBlock->Desc;
    desc += sizeof(struct rb_block_desc_0);
    if (aBlock->Flags & RE_BLOCK_HAS_COPY_DISPOSE) {
        desc += sizeof(struct rb_block_desc_1);
    }
    return (struct rb_block_desc_2 *)desc;
}

static RB_Block reblock_copyBlock(id block){
    RB_Block rb_block = RBBlockFromNSBlock(block);
    RB_Block newBlock = NULL;
    newBlock = malloc(rb_block->Desc->Block_size);
    if (!newBlock) {
        return NULL;
    }
    memmove(newBlock, rb_block, rb_block->Desc->Block_size);
    
    struct rb_block_desc_1 *desc_1 = reblock_desc_1(rb_block);
    if (desc_1) {
        desc_1->copy(newBlock, rb_block);
    }
    
    return newBlock;
}

static NSMethodSignature *relock_methodSignature(id block, NSError **error){
    RB_Block rb_block = RBBlockFromNSBlock(block);
    if (!(rb_block->Flags & RE_BLOCK_HAS_SIGNATURE)) {
        NSString *description = [NSString stringWithFormat:@"The block %@ doesn't contain a type signature.", block];
        ReblockError(ReBlockErrorMissingBlockSignature, description);
        return nil;
    }
    void *desc = rb_block->Desc;
    desc += 2 * sizeof(unsigned long int);
    if (rb_block->Flags & RE_BLOCK_HAS_COPY_DISPOSE) {
        desc += 2 * sizeof(void *);
    }
    if (!desc) {
        NSString *description = [NSString stringWithFormat:@"The block %@ doesn't has a type signature.", block];
        ReblockError(ReBlockErrorMissingBlockSignature, description);
        return nil;
    }
    const char *signature = (*(const char **)desc);
    return [NSMethodSignature signatureWithObjCTypes:signature];
}

NSMethodSignature *reblock_methodSignatureForSelector(id self, SEL _cmd, SEL aSelector) {
    struct rb_block_desc_2 *descriptor_2 =  reblock_desc_2((__bridge  void *)self);
    return [NSMethodSignature signatureWithObjCTypes:descriptor_2->signature];
}

#define reblock_invoke(reblocks, info) \
for (ReBlockIdentifier *reblockIdentifier in reblocks) {\
    [reblockIdentifier invokeWithInfo:info];\
    if (reblockIdentifier.options & ReBlockOptionAutomaticRemoval) { \
        reblocksToRemove = [reblocksToRemove?:@[] arrayByAddingObject:reblockIdentifier]; \
    } \
}

static void reblock_forwardInvocation(id self, SEL _cmd, NSInvocation *invo) {
    
    id block = invo.target;
    
    ReBlockContainer *container = reblock_getContainerForObject(block);
    NSArray *reblocksToRemove = nil;
    
    ReBlockInfo *info = [[ReBlockInfo alloc] initWithInstance:container.originBlock invocation:invo];
    
    reblock_invoke(container.beforeReBlocks, info);
    if (container.insteadReBlocks.count) {
        reblock_invoke(container.insteadReBlocks, info);
    }else if (container.lastIdentifierReImp) {
        [container.lastIdentifierReImp invokeWithInfo:info];
    }else{
        [invo invokeWithTarget:container.copyedBlock];
    }
    
    reblock_invoke(container.afterReBlocks, info);
    
    // Remove any hooks that are queued for deregistration.
    [reblocksToRemove makeObjectsPerformSelector:@selector(remove)];
}

static void reblock_NSBlock_hookOnces() {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = NSClassFromString(@"NSBlock");
        reblock_strongHookMethod(cls, @selector(methodSignatureForSelector:), (IMP)reblock_methodSignatureForSelector);
        reblock_strongHookMethod(cls,@selector(forwardInvocation:), (IMP)reblock_forwardInvocation);
    });
}

static void reblock_dispose(id obj) {
    RB_Block rb_block = RBBlockFromNSBlock(obj);
    if (rb_block->Desc && rb_block->Desc->dispose) {
        rb_block->Desc->dispose(rb_block);
    }
}

static BOOL reblock_isMollocBlock(id obj){
    RB_Block rb_block = RBBlockFromNSBlock(obj);
    struct rb_block_desc_1 *desc_1 = reblock_desc_1(rb_block);
    if (desc_1) {
        return YES;
    }
    return NO;
}

@end

@implementation ReBlockIdentifier

+ (instancetype)identifierWithBlockObject:(id)blockObject options:(ReBlockOptions)options usingBlock:(id)usingBlock error:(NSError **)error{
    return [[ReBlockIdentifier alloc] initWithBlockObject:blockObject options:options usingBlock:usingBlock error:error];
}

- (instancetype)initWithBlockObject:(id)blockObj
                            options:(ReBlockOptions)options
                         usingBlock:(id)usingBlock
                              error:(NSError **)error{
    if (!usingBlock || !blockObj) {
        ReblockError(ReBlockErrorNoBlockOrUsingBlock, @"There is no block or using-block can be used.");
        return nil;
    }
    if (usingBlock == blockObj) {
        ReblockError(ReBlockErrorWillRecursiveCall, @"The hook will recursive call Because the Block and the Using-block are the same object.");
        return nil;
    }
    NSMethodSignature *blockSig = relock_methodSignature(blockObj, NULL);
    NSMethodSignature *usingBlockSig = relock_methodSignature(usingBlock, NULL);
    if (!reblock_isCompatibleBlockSignature(blockSig, usingBlockSig, NULL)) {
        return nil;
    }
    if (self = [super init]) {
        _originBlock = blockObj;
        _options = options;
        _usingBlock = usingBlock;
    }
    return self;
}

- (BOOL)invokeWithInfo:(id<ReBlockInfo>)info{
    
    NSMethodSignature *signature = relock_methodSignature(self.usingBlock, nil);
    NSInvocation *blockInvocation = [NSInvocation invocationWithMethodSignature:signature];
    NSInvocation *originalInvocation = info.originalInvocation;
    NSUInteger numberOfArguments = signature.numberOfArguments;
    NSUInteger numberOfArguments_origin = originalInvocation.methodSignature.numberOfArguments;

    
    // Be extra paranoid. We already check that on hook registration.
    if (numberOfArguments > numberOfArguments_origin + 1) {
        ReblockLogError(@"Using-block has too many arguments. Not calling %@",info);
        return NO;
    }
    
    // The first argument of the using-block will be the ReBlockInfo. Optional.
    void *argBuf = NULL;

    if (numberOfArguments > 1) {
        [blockInvocation setArgument:&info atIndex:1];
        
        for (NSUInteger idx = 2; idx < numberOfArguments; idx++) {
            const char *type = [originalInvocation.methodSignature getArgumentTypeAtIndex:idx-1];
            NSUInteger argSize;
            NSGetSizeAndAlignment(type, &argSize, NULL);
            
            if (!(argBuf = reallocf(argBuf, argSize))) {
                ReblockLogError(@"Failed to allocate memory for block invocation.");
                return NO;
            }
            
            [originalInvocation getArgument:argBuf atIndex:idx-1];
            [blockInvocation setArgument:argBuf atIndex:idx];
        }
    }
    
    [blockInvocation invokeWithTarget:self.usingBlock];
    
    ReBlockOptions options = self.options&ReBlockPositionFilter;
    if (options == ReBlockPositionInstead || options == ReBlockPositionReImplementation) {
        const char *usingBlkType = [signature methodReturnType];
        const char *blockType = [originalInvocation.methodSignature methodReturnType];
        if (strcmp(usingBlkType, blockType) == 0 && strcmp(blockType, "v") != 0) {
            void *returnValue = NULL;
            [blockInvocation getReturnValue:&returnValue];
            [originalInvocation setReturnValue:&returnValue];
        }
    }
    
    if (argBuf != NULL) {
        free(argBuf);
    }
    return YES;
}

- (BOOL)remove {
    return reblock_remove(self, NULL);
}

@end

@implementation ReBlockContainer

+ (instancetype)containerWithBlockObject:(id)blockObj{
    return [[self alloc] initWithBlockObject:blockObj];
}

- (instancetype)initWithBlockObject:(id)blockObj{
    self = [super init];
    if (self) {
        _originBlock = blockObj;
        RB_Block block_copy = reblock_copyBlock(blockObj);
        _blockValue = [NSValue value:&block_copy withObjCType:@encode(RB_Block)];
    }
    return self;
}

- (id)copyedBlock{
    NSValue *blockValue = self.blockValue;
    if (blockValue == nil) {
        return nil;
    }
    RB_Block copy_block;
    [blockValue getValue:&copy_block];
    id copyedBlock = NSBlockFromRBBlock(copy_block);
    if (![copyedBlock isKindOfClass:NSClassFromString(@"NSBlock")]) {
        return nil;
    }
    return copyedBlock;
}

#define addIdentifier(array) ((array && reblock_isMollocBlock(self.originBlock))?array:@[])
- (void)addIdentifier:(ReBlockIdentifier *)reblockIdentifier{
    NSUInteger position = reblockIdentifier.options&ReBlockPositionFilter;
    
    if (position == ReBlockPositionReImplementation) {
        //release the values copyed by block
        if (self.hasBeenReImplemented == NO) {
            reblock_dispose(self.originBlock);
            reblock_dispose(self.copyedBlock);
            self.hasBeenReImplemented = YES;
        }
        self.lastIdentifierReImp = reblockIdentifier;
        return;
    }
    
    switch (position) {
        case ReBlockPositionBefore:     self.beforeReBlocks     = [addIdentifier(self.beforeReBlocks)   arrayByAddingObject:reblockIdentifier]; break;
        case ReBlockPositionInstead:    self.insteadReBlocks    = [addIdentifier(self.insteadReBlocks)  arrayByAddingObject:reblockIdentifier]; break;
        case ReBlockPositionAfter:      self.afterReBlocks      = [addIdentifier(self.afterReBlocks)    arrayByAddingObject:reblockIdentifier]; break;
    }
}

- (BOOL)removeIdentifier:(id)identifier{
    for (NSString *reblockArrayName in @[NSStringFromSelector(@selector(beforeReBlocks)),
                                        NSStringFromSelector(@selector(insteadReBlocks)),
                                        NSStringFromSelector(@selector(afterReBlocks)),
                                        ]) {
        NSArray *array = [self valueForKey:reblockArrayName];
        NSUInteger index = [array indexOfObjectIdenticalTo:identifier];
        if (array && index != NSNotFound) {
            NSMutableArray *newArray = [NSMutableArray arrayWithArray:array];
            [newArray removeObjectAtIndex:index];
            [self setValue:newArray forKey:reblockArrayName];
            return YES;
        }
    }
    return NO;
}

@end

@implementation ReBlockInfo

- (id)initWithInstance:(id)instance invocation:(NSInvocation *)invocation {
    NSCParameterAssert(instance);
    NSCParameterAssert(invocation);
    if (self = [super init]) {
        _instance = instance;
        _originalInvocation = invocation;
    }
    return self;
}

@end
