# FishBind

```

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
        //pub ===name data ===name data===
        NSLog(@"===%@ ===%@===",objectA.name, objectB.nameData);
 ```
 
 
