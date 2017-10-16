//
//  ViewController.m
//  FishBindDemo-iOS
//
//  Created by WELCommand on 2017/10/16.
//  Copyright © 2017年 WELCommand. All rights reserved.
//

#import "ViewController.h"
#import "IIFishBind.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    void (^testBlock)(id f, NSInteger i, NSInteger j) = ^(id f, NSInteger i, NSInteger j) {
        NSLog(@"asdasd");
    };

    [IIFishBind bindFishes:@[[IIFish postBlock:testBlock],
                             [IIFish observer:self callBack:^(IIFishCallBack *callBack, id deadFish) {
    }]]];
    testBlock(self,3,5);
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    
}


- (void)test:(NSInteger)i {
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
