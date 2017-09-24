//
//  IITestObjectA.h
//  FishBindDemo
//
//  Created by WELCommand on 2017/9/24.
//  Copyright © 2017年 WELCommand. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IITestObjectA : NSObject

@property (nonatomic, strong, setter=setUserName:, getter=userName) NSString *name;
@property (nonatomic, assign) NSInteger age;

- (void)loadDataWithName:(NSString *)name age:(NSInteger)age;

@end
