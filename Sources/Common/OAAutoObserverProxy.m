//
//  OAObserver.m
//  OsmAnd
//
//  Created by Alexey Pelykh on 2/25/14.
//  Copyright (c) 2014 OsmAnd. All rights reserved.
//

#import "OAAutoObserverProxy.h"

#include <objc/message.h>

@implementation OAAutoObserverProxy
{
}

@synthesize owner = _owner;
@synthesize handler = _handler;

- (instancetype)initWith:(id<OAObserverProtocol>)owner
{
    self = [super init];
    if (self) {
        [self ctor:owner
           handler:nil];
    }
    return self;
}

- (instancetype)initWith:(id<OAObserverProtocol>)owner andObserve:(id<OAObservableProtocol>)observable
{
    self = [super init];
    if (self) {
        [self ctor:owner
           handler:nil];
        [self observe:observable];
    }
    return self;
}

- (instancetype)initWith:(id)owner withHandler:(SEL)selector
{
    self = [super init];
    if (self) {
        [self ctor:owner
           handler:selector];
    }
    return self;
}

- (instancetype)initWith:(id)owner withHandler:(SEL)selector andObserve:(id<OAObservableProtocol>)observable;
{
    self = [super init];
    if (self) {
        [self ctor:owner
           handler:selector];
        [self observe:observable];
    }
    return self;
}

- (void)dealloc
{
    [self dtor];
}

- (void)ctor:(id)owner handler:(SEL)selector
{
    _owner = owner;
    _handler = selector;
    _observable = nil;
}

- (void)dtor
{
    [self detach];
}

@synthesize observable = _observable;

- (void)observe:(id<OAObservableProtocol>)observable
{
    @synchronized(self)
    {
        [self detach];

        _observable = observable;
        [_observable registerObserver:self];
    }
}

- (void)handleObservedEvent
{
    [self handleObservedEventFrom:nil];
}

- (void)handleObservedEventFrom:(id<OAObservableProtocol>)observer
{
    [self handleObservedEventFrom:observer
                          withKey:nil];
}

- (void)handleObservedEventFrom:(id<OAObservableProtocol>)observer withKey:(id)key
{
    [self handleObservedEventFrom:observer
                          withKey:key
                         andValue:nil];
}

- (void)handleObservedEventFrom:(id<OAObservableProtocol>)observer withKey:(id)key andValue:(id)value
{
    id owner = _owner;
    if (owner == nil)
        return;

    if (_handler != nil)
    {
        NSMethodSignature* handlerSignature = [owner methodSignatureForSelector:_handler];
        NSAssert(handlerSignature != nil, @"Whoa! Something is messed up with selector %@ in %@", NSStringFromSelector(_handler), owner);
        NSUInteger handlerArgsCount = [handlerSignature numberOfArguments] - 2; // Subtract "self" and "cmd_"

        if (handlerArgsCount == 3)
        {
            objc_msgSend(owner, _handler, observer, key, value);
            return;
        }
        
        if (handlerArgsCount == 2)
        {
            objc_msgSend(owner, _handler, observer, key);
            return;
        }
        
        if (handlerArgsCount == 1)
        {
            objc_msgSend(owner, _handler, observer);
            return;
        }
        
        objc_msgSend(owner, _handler);
        return;
    }
    
    if ([owner respondsToSelector:@selector(handleObservedEventFrom:withKey:andValue:)])
    {
        [owner handleObservedEventFrom:observer
                               withKey:key
                              andValue:value];
        return;
    }
    
    if ([owner respondsToSelector:@selector(handleObservedEventFrom:withKey:)])
    {
        [owner handleObservedEventFrom:observer
                               withKey:key];
        return;
    }
    
    if ([owner respondsToSelector:@selector(handleObservedEventFrom:)])
    {
        [owner handleObservedEventFrom:observer];
        return;
    }
    
    [owner handleObservedEvent];
}

- (BOOL)isAttached
{
    return (_observable != nil);
}

- (BOOL)detach
{
    @synchronized(self)
    {
        if (_observable == nil)
            return NO;

        [_observable unregisterObserver:self];
        _observable = nil;

        return YES;
    }
}

@end
