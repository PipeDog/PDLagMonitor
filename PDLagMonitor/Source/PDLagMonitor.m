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
        | --- ping ---> |
        |               |
        | <-- pong ---- |
        |               |
 */

#define DUMP_CALLSTACK_SIGNAL SIGUSR1
static pthread_t tid; // Main thread id.

static void SignalHandler(int signal);
static void RegisterSignalHandler(void);
static void SignalDumpCallstack(void);

static NSString *const _PDLagMonitorPongNotification = @"_PDLagMonitorPongNotification";

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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pongFromMainThreadNotification:) name:_PDLagMonitorPongNotification object:nil];
    
    __weak typeof(self) weakSelf = self;
    _pingTimer = [self timerWithCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) callback:^{
        [weakSelf ping];
    }];
}

#pragma mark - Private Methods
- (void)pongFromMainThreadNotification:(NSNotification *)notification {
    [self cancelPongTimer];
}

- (void)ping {
    __weak typeof(self) weakSelf = self;
    _pongTimer = [self timerWithCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) callback:^{
        [weakSelf pongWhenTimeout];
    }];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:_PDLagMonitorPongNotification object:nil];
    });
}

- (void)pongWhenTimeout {
    [self cancelPongTimer];
    SignalDumpCallstack();
}

- (dispatch_source_t)timerWithCallbackQueue:(dispatch_queue_t)queue callback:(dispatch_block_t)callback {
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    if (timer) {
        // 1.f / 60 => 0.0167f
        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 0.0167f * NSEC_PER_SEC, 0.0167f / 10000 * NSEC_PER_SEC);
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
