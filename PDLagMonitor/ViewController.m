//
//  ViewController.m
//  PDLagMonitor
//
//  Created by liang on 2019/8/16.
//  Copyright © 2019 liang. All rights reserved.
//

#import "ViewController.h"
#import "PDLagMonitor.h"

@interface ViewController () <PDLagMonitorDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self commitInit];
    [self doBusyJob];
}

- (void)commitInit {
    [PDLagMonitor globalMonitor].delegate = self;
    [[PDLagMonitor globalMonitor] startMonitoring];
}

- (void)doBusyJob {
    while (YES) {
        NSLog(@"Do job...");
    }
}

#pragma mark - PDLagMonitorDelegate
- (void)dumpCallstackSymbolsWhenMainThreadLag:(NSArray<NSString *> *)callstackSymbols {
    // Report lag callstack here ...
}

@end
