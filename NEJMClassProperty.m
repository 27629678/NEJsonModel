//
//  NEJMClassProperty.m
//  NEJSONModel
//
//  Created by H-YXH on 7/31/15.
//  Copyright (c) 2015 NetEase (hangzhou) Network Co.,Ltd. All rights reserved.
//

#import "NEJMClassProperty.h"

@implementation NEJMClassProperty

- (NSString *)description
{
    NSMutableArray* properties = [NSMutableArray arrayWithCapacity:8];
    
    if (self.isMutable) [properties addObject:@"Mutable"];
    if (self.isStandardJSONType) [properties addObject:@"Standard JSON type"];
    
    NSString* propertiesString = @"";
    if (properties.count > 0) {
        propertiesString = [NSString stringWithFormat:@"(%@)", [properties componentsJoinedByString:@", "]];
    }
    
    return [NSString stringWithFormat:@"@property %@%@ %@ %@",
            [NSString stringWithFormat:@"%@*",self.type],
            self.protocol?[NSString stringWithFormat:@"<%@>", self.protocol]:@"",
            self.name,
            propertiesString
            ];
}

@end
