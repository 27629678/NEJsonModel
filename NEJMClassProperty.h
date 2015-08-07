//
//  NEJMClassProperty.h
//  NEJSONModel
//
//  Created by H-YXH on 7/31/15.
//  Copyright (c) 2015 NetEase (hangzhou) Network Co.,Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NEJMClassProperty : NSObject

@property (assign, nonatomic) Class type;

@property (copy, nonatomic) NSString* name;

@property (copy, nonatomic) NSString* protocol;

@property (assign, nonatomic) BOOL isMutable;

@property (assign, nonatomic) BOOL isStandardJSONType;

@end
