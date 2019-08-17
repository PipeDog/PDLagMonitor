//
//  PDLagMonitor.m
//  PDLagMonitor
//
//  Created by liang on 2019/8/16.
//  Copyright © 2019 liang. All rights reserved.
//

#import "PDLagMonitor.h"
#include <signal.h>
#include <pthread.h>

/*
    WorkerThread    MainThread
        |               |
        | --- ping ---> | -----
        |               |   |
        |               |   | => Threshold time length is 0.0167s.
        |               |   |
        | <-- pong ---- | -----
        |               |
 */

#define DUMP_CALLSTACK_SIGNAL SIGUSR1
static pthread_t tid; // Main thread id.

static void SignalHandler(int signal);
static void RegisterSignalHandler(void);
static void SignalDumpCallstack(void);

@implementation PDLagMonitor {
    dispatch_source_t _pingTimer;
    dispatch_source_t _pongTimer;
}

+ (PDLagMonitor *)globalMonitor {
    static PDLagMonitor *_globalMonitor;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _globalMonitor = [[PDLagMonitor alloc] init];
    });
    return _globalMonitor;
}

- (void)startMonitoring {
    if (![NSThread isMainThread]) {
        NSAssert(NO, @"Error: Method `startMonitoring` must be called on main thread.");
        return;
    }
    
    tid = pthread_self();
    RegisterSignalHandler();
    
    __weak typeof(self) weakSelf = self;
    // 60 times 1s => 0.0167s
    _pingTimer = [self timerWithTimeInterval:0.0167f queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) callback:^{
        [weakSelf ping];
    }];
}

#pragma mark - Private Methods
- (void)ping {
    __weak typeof(self) weakSelf = self;
    // 50 times 1s => 0.0200s
    _pongTimer = [self timerWithTimeInterval:0.0200f queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) callback:^{
        [weakSelf pongBeyondThreshold];
    }];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self pong];
    });
}

- (void)pong {
    [self cancelPongTimer];
}

- (void)pongBeyondThreshold {
    [self cancelPongTimer];
    SignalDumpCallstack();
}

- (dispatch_source_t)timerWithTimeInterval:(NSTimeInterval)secs queue:(dispatch_queue_t)queue callback:(dispatch_block_t)callback {
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    if (timer) {
        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, secs * NSEC_PER_SEC, 0.00001f * NSEC_PER_SEC);
        dispatch_source_set_event_handler(timer, callback);
        dispatch_resume(timer);
    }
    return timer;
}

- (void)cancelPongTimer {
    if (_pongTimer) {
        dispatch_source_cancel(_pongTimer);
        _pongTimer = nil;
    }
}

@end

static void SignalHandler(int signal) {
    NSLog(@"Main thread catch signal %d", signal);
    
    if (signal != DUMP_CALLSTACK_SIGNAL) {
        return;
    }
    
    NSArray *callStackSymbols = [NSThread callStackSymbols];
    id<PDLagMonitorDelegate> delegate = [PDLagMonitor globalMonitor].delegate;
    
    if ([delegate respondsToSelector:@selector(dumpCallstackSymbolsWhenMainThreadLag:)]) {
        [delegate dumpCallstackSymbolsWhenMainThreadLag:callStackSymbols];
    }
    
    NSLog(@"Dump callstack : %@", callStackSymbols);
}

static void RegisterSignalHandler(void) {
    signal(DUMP_CALLSTACK_SIGNAL, SignalHandler);
}

static void SignalDumpCallstack(void) {
    NSLog(@"Sending signal %d to main thread.", DUMP_CALLSTACK_SIGNAL);
    pthread_kill(tid, DUMP_CALLSTACK_SIGNAL);
}
