//
//  ViewController.m
//  FishBindDemo-iOS
//
//  Created by WELCommand on 2017/10/16.
//  Copyright © 2017年 WELCommand. All rights reserved.
//

#import "ViewController.h"
#import "IIFishBind.h"
#import "TestA.h"
#import "TestB.h"
#import "TestC.h"
#import "TestD.h"

@interface ViewController ()

@end


@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    //双向绑定

    TestA *objA = [TestA new];
    TestB *objB = [TestB new];
    TestC *objC = [TestC new];
    TestD *objD = [TestD new];
    
    [IIFishBind bindFishes:@[
                             [IIFish both:objA property:@"name"
                                 callBack:^(IIFishCallBack *callBack, id deadFish) {
                                     [deadFish setUserName:callBack.args[0]];
                                 }],
                             [IIFish both:objB property:@"bName"
                                 callBack:^(IIFishCallBack *callBack, id deadFish) {
                                     [deadFish setBName:callBack.args[0]];
                                 }],
                             [IIFish both:objD
                                 selector:@selector(setDK_Name:)
                                 callBack:^(IIFishCallBack *callBack, id deadFish) {
                                     [deadFish setDK_Name:[NSString stringWithFormat:@"DK_%@",callBack.args[0]]];
                                 }]
                             ]];
    
    [objA setValue:@"json" forKey:@"name"];
    NSLog(@"%@", [NSString stringWithFormat:@"\nTestA : name = %@\nTestB : bName = %@\nTestD : DK_Name = %@",objA.userName, objB.bName, objD.DK_Name]);
    /*
     TestA : name = json
     TestB : bName = json
     TestD : DK_Name = DK_json
     */
    
    objB.bName = @"GCD";
    NSLog(@"%@", [NSString stringWithFormat:@"\nTestA : name = %@\nTestB : bName = %@\nTestD : DK_Name = %@",objA.userName, objB.bName, objD.DK_Name]);
    /*
    TestA : name = GCD
    TestB : bName = GCD
    TestD : DK_Name = DK_GCD
     */
    
    objD.DK_Name = @"apple";
    NSLog(@"%@", [NSString stringWithFormat:@"\nTestA : name = %@\nTestB : bName = %@\nTestD : DK_Name = %@",objA.userName, objB.bName, objD.DK_Name]);
    /*
    TestA : name = apple
    TestB : bName = apple
    TestD : DK_Name = apple
     */
    
    
    //类型自动转换 基于KVC
    //
    [IIFishBind bindFishes:@[
                             [IIFish both:objA property:@"ageA" callBack:nil],
                             [IIFish both:objB property:@"ageB" callBack:nil],
                             ]];
    //
    objA.ageA = 3.3;
    
    NSLog(@"a = %@ b = %@ ", @(objA.ageA),@( objB.ageB));
    
    NSLog(@"%@",[objA iifish_allKeys]);
    NSLog(@"%@",[objA iifish_observersWithKey:@"setAgeA:"]);
    
    // 绑定block
//    
//    CGFloat (^testBlock)(CGFloat i, CGFloat j) = ^(CGFloat i, CGFloat j) {
//        return i + j;
//    };
//    
//    [IIFishBind bindFishes:@[
//                             [IIFish postBlock:testBlock],
//                             [IIFish observer:self
//                                     callBack:^(IIFishCallBack *callBack, id deadFish) {
//                                         NSLog(@"%@ + %@ = %@", callBack.args[0], callBack.args[1], callBack.resule);
//                                         // 3.1 + 4.1 = 7.199999999999999
//                                     }]
//                             ]];
//    
//    
//    CGFloat value = testBlock (3.1, 4.1);
//    
//    NSLog(@"value = %@", @(value));
    // value = 7.199999999999999
    
    // 单向绑定
    
//    [IIFishBind bindFishes:@[
//                             [IIFish post:self selector:@selector(viewDidAppear:)],
//                             [IIFish observer:self
//                                     callBack:^(IIFishCallBack *callBack, id deadFish) {
//                                          NSLog(@"======== 4 ===========");
//                                     }]
//                             ]];
//
//    [IIFishBind bindFishes:@[
//                             [IIFish post:self selector:@selector(viewWillAppear:)],
//                             [IIFish observer:self
//                                     callBack:^(IIFishCallBack *callBack, id deadFish) {
//                                         NSLog(@"======== 2 ===========");
//                                     }]
//                             ]];
    
    //方法调用观察

    
    __unused NSString *s = [objC fullName];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    NSLog(@"\n\n======== 1 ===========");
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSLog(@"======== 3 ===========");
}


@end
