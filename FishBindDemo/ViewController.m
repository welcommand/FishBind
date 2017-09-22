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

//    [IIFishBind bindFishes:@[
//                             [IIFish fish:t1 key:@selector(setName:) callBack:nil],
//                             [IIFish fish:t2 key:@selector(setTabs:) callBack:nil],
//                             ]];

    NSLog(@"======");
    t1.name = @"hahahaha";
    NSLog(@"=====%@",t2.tabs);
    
    t2.tabs = @"aasdasdasds";
    NSLog(@"======%@",t1.name);
    
}


@end
