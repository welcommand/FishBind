//
//  ViewController.m
//  FishBindDemo
//
//  Created by WELCommand on 2017/9/4.
//  Copyright © 2017年 WELCommand. All rights reserved.
//

#import "ViewController.h"
#import "TestA.h"
#import "TestB.h"

#import "IIFishBind.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    TestA *t1 = [[TestA alloc] init];
    TestB *t2 = [[TestB alloc] init];
    
    [IIFishBind bindFishes:@[
                             [IIFish fish:t1 oKey:@selector(age) pKey:@selector(setAge:) callBack:nil],
                             [IIFish fish:t2 oKey:@selector(testB) pKey:@selector(setTestB:) callBack:nil],
                             ]];
    
    NSLog(@"======");
    t1.age = 100;
    NSLog(@"=====%@",@(t2.testB));
    
    t2.testB = 200;
    NSLog(@"======%@",@(t1.age));
    
    
}


@end
