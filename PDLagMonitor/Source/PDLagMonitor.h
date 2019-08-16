//
//  PDLagMonitor.h
//  PDLagMonitor
//
//  Created by liang on 2019/8/16.
//  Copyright © 2019 liang. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol PDLagMonitorDelegate <NSObject>

- (void)dumpCallstackSymbolsWhenMainThreadLag:(NSArray<NSString *> *)callstackSymbols;

@end

@interface PDLagMonitor : NSObject

@property (class, strong, readonly) PDLagMonitor *globalMonitor;

@property (nonatomic, weak) id<PDLagMonitorDelegate> delegate;

- (void)startMonitoring; // Must be called on main thread.

@end

NS_ASSUME_NONNULL_END
