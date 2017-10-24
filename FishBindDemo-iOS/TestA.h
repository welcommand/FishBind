//
//  TestA.h
//  FishBindDemo
//
//  Created by WELCommand on 2017/10/23.
//  Copyright © 2017年 WELCommand. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TestA : NSObject

@property (nonatomic, strong, setter=setUserName:, getter=userName) NSString *name;

@property (nonatomic, assign) double ageA;

@end
