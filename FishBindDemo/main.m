//
//  main.m
//  FishBindDemo
//
//  Created by WELCommand on 2017/9/24.
//  Copyright © 2017年 WELCommand. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "IIFishBind.h"
#import "IITestObjectA.h"
#import "IITestObjectB.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        IITestObjectA *objectA = [IITestObjectA new];
        IITestObjectB *objectB = [IITestObjectB new];
        
        [IIFishBind bindFishes:@[
                                 [IIFish both:objectA property:@"name"],
                                 [IIFish both:objectB property:@"nameData"]
                                 ]];
        
        objectA.name = @"dead fish";
        // put ===dead fish ===dead fish===
        NSLog(@"===%@ ===%@===",objectA.name, objectB.nameData);
        
        
        objectB.nameData = @"name data";
        //put ===name data ===name data===
        NSLog(@"===%@ ===%@===",objectA.name, objectB.nameData);
        
    }
    return 0;
}






