# FishBind

```
        IITestObjectA *objectA = [IITestObjectA new];
        IITestObjectB *objectB = [IITestObjectB new];
        IITestObjectA *objectA1 = [IITestObjectA new];
        
        objectA1.name = @"first name";
        
        [IIFishBind bindFishes:@[
                                 [IIFish both:objectA property:@"name"],
                                 [IIFish both:objectB property:@"nameData"]
                                 ]];
        objectA.name = @"dead fish";
        NSLog(@"===%@ ===%@===",objectA.name, objectB.nameData);
        // put ===dead fish ===dead fish===
        
        objectB.nameData = @"name data";
        NSLog(@"===%@ ===%@===",objectA.name, objectB.nameData);
        //put ===name data ===name data===
        
        [IIFishBind bindFishes:@[
                                 [IIFish post:objectA selector:@selector(loadDataWithName:age:)],
                                 [IIFish observer:objectB
                                         callBack:^(IIFishCallBack *callBack, id deadFish) {
                                             NSArray *args = callBack.args;
                                             NSString *name = [NSString stringWithFormat:@"NAME : %@",args[0]];
                                             // don`t call [objectB setNameData:args[0]]. will Dead loop
                                             [deadFish setNameData:name];
                                         }]
                                 ]];
        
        [objectA loadDataWithName:@"test" age:18];
        
        NSLog(@"===%@ ===%@===",objectA.name, objectB.nameData);
        //put ===test ===NAME : test===
        NSLog(@"====%@",objectA1.name);
        //put ====object1

        
        NSInteger (^testBlock)(NSInteger i, NSInteger j) = ^(NSInteger i, NSInteger j) {
            return i + j;
        };
        
        [IIFishBind bindFishes:@[
                                 [IIFish postBlock:testBlock],
                                 [IIFish observer:objectA1
                                         callBack:^(IIFishCallBack *callBack, id deadFish) {
                                             
                                             NSLog(@"test block called :  %@ + %@ = %@",callBack.args[0],callBack.args[1], callBack.resule);
                                             //put 3 + 4 = 7
                                         }]
                                 ]];
        
        testBlock(3,4);
 ```
 
 
