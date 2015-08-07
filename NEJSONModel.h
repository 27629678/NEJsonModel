//
//  NEJSONModel.h
//  NEJSONModel
//
//  Created by H-YXH on 7/31/15.
//  Copyright (c) 2015 NetEase (hangzhou) Network Co.,Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol Ignore @end

@protocol NSArray @end

@protocol NSDictionary @end

@protocol AbstractNEJMProtocol <NSCopying, NSCoding>

@required
-(NSDictionary*)toDictionary;

@end

@interface NEJSONModel : NSObject <AbstractNEJMProtocol, NSSecureCoding>

- (NSArray *)__properties__;

- (NSString *)toJsonString;

- (NSDictionary *)toDictionary;

- (instancetype)initWithJson:(NSString *)json error:(NSError **)error;

- (instancetype)initWithDictionary:(NSDictionary *)dict error:(NSError **)error;

@end
