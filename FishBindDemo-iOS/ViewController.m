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
                             [IIFish both:objA property:@"name"],
                             [IIFish both:objB property:@"bName"],
                             [IIFish observer:objC
                                     callBack:^(IIFishCallBack *callBack, id deadFish) {
                                         objC.fullName = [NSString stringWithFormat:@"\nTestA : name = %@\nTestB : bName = %@\nTestD : DK_Name = %@",objA.userName, objB.bName, objD.DK_Name];
                                     }],
                             [IIFish both:objD
                                 selector:@selector(setDK_Name:)
                                 callBack:^(IIFishCallBack *callBack, id deadFish) {
                                     [deadFish setDK_Name:[NSString stringWithFormat:@"DK_%@",callBack.args[0]]];
                                 }]
                             ]];
    
    
    objA.name = @"json";
    NSLog(@"%@", objC.fullName);
    
    objB.bName = @"GCD";
    NSLog(@"%@", objC.fullName);
    
    objD.DK_Name = @"apple";
    NSLog(@"%@", objC.fullName);
    
    
    
}



@end
