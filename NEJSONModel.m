//
//  NEJSONModel.m
//  NEJSONModel
//
//  Created by H-YXH on 7/31/15.
//  Copyright (c) 2015 NetEase (hangzhou) Network Co.,Ltd. All rights reserved.
//

#import "NEJSONModel.h"

#import <objc/runtime.h>
#import "NEJMClassProperty.h"
#import "JSONValueTransformer.h"

static NSArray* kClassPropertiesKey = nil;

static NSArray* __allowedJsonTypes = nil;
static NSArray* __allowedPrimitiveTypes = nil;
static NSDictionary* __primitiveDict = nil;
static JSONValueTransformer* __valueTransformer = nil;

@implementation NEJSONModel

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @autoreleasepool {
            __allowedJsonTypes = @[[NSNull class],
                                   [NSString class],
                                   [NSMutableString class],
                                   [NSNumber class],
                                   [NSDecimalNumber class],
                                   [NSArray class],
                                   [NSMutableArray class],
                                   [NSDictionary class],
                                   [NSMutableDictionary class]];
            
            __allowedPrimitiveTypes = @[@"BOOL",
                                        @"float",
                                        @"int",
                                        @"long",
                                        @"double",
                                        @"short",
                                        @"NSInteger",
                                        @"NSUInteger",
                                        @"Block"];
            
            __primitiveDict = @{@"f" : @"float",
                                @"i" : @"int",
                                @"d" : @"double",
                                @"l" : @"long",
                                @"c" : @"BOOL",
                                @"s" : @"short",
                                @"q" : @"long",
                                @"I" : @"NSInteger",
                                @"Q" : @"NSUInteger",
                                @"B" : @"BOOL",
                                @"@?": @"Block"};
            
            __valueTransformer = [[JSONValueTransformer alloc] init];
        }
    });
}

- (void)__setup__
{
    // inpect properties if not fount
    if (!objc_getAssociatedObject(self.class, &kClassPropertiesKey)) {
        [self __inspect_class_properties__];
    }
}

- (void)__inspect_class_properties__
{
    Class class = [self class];
    NSScanner* scanner = nil;
    NSString* type = nil;
    NSMutableDictionary* key2property = [NSMutableDictionary dictionary];
    
    while (class != [NEJSONModel class]) {
        unsigned int property_count;
        objc_property_t *properties = class_copyPropertyList(class, &property_count);
        for (unsigned int idx = 0; idx < property_count; idx ++) {
            NEJMClassProperty* property = [[NEJMClassProperty alloc] init];
            objc_property_t objc_property = properties[idx];
            const char* objc_property_name = property_getName(objc_property);
            
            // property name
            [property setName:[NSString stringWithUTF8String:objc_property_name]];
            
            // property attributes
            const char* objc_property_attributes = property_getAttributes(objc_property);
            NSString* propertyAttributes = [NSString stringWithUTF8String:objc_property_attributes];
            NSArray* attributeItems = [propertyAttributes componentsSeparatedByString:@","];
            
            // filter read_only property
            if ([attributeItems containsObject:@"R"]) {
                continue;
            }
            
            // filter 64b BOOLs
            if ([propertyAttributes hasPrefix:@"Tc"]) {
                continue;
            }
            
            scanner = [NSScanner scannerWithString:propertyAttributes];
            [scanner scanUpToString:@"T" intoString:nil];
            [scanner scanString:@"T" intoString:nil];
            
            // object
            if ([scanner scanString:@"@\"" intoString:nil]) {
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"<"]
                                        intoString:&type];
                
                // class
                [property setType:NSClassFromString(type)];
                
                // isMutable
                [property setIsMutable:([type rangeOfString:@"Mutable"].location != NSNotFound)];
                
                [property setIsStandardJSONType:[__allowedJsonTypes containsObject:property.type]];
                
                // protocol
                while ([scanner scanString:@"<" intoString:nil]) {
                    NSString* protocol_name = nil;
                    [scanner scanUpToString:@">" intoString:&protocol_name];
                    
                    if ([protocol_name isEqualToString:@"Ignore"]) {
                        property = nil;
                    }
                    else if (protocol_name.length > 0) {
                        [property setProtocol:protocol_name];
                    }
                    
                    [scanner scanString:@">" intoString:nil];
                }
            }
            // struct
            else if ([scanner scanString:@"{" intoString:nil]) {
                property = nil;
            }
            // primitive property
            else {
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@","]
                                        intoString:&type];
                type = __primitiveDict[type];
                if (![__allowedPrimitiveTypes containsObject:type]) {
                    @throw [NSException exceptionWithName:@"NEJM->Property type not allowed"
                                                   reason:[NSString stringWithFormat:@"Property type of %@.%@ is not supported by JSONModel.", self.class, property.name]
                                                 userInfo:nil];
                }
            }
            
            if ([type isEqualToString:@"Block"]) {
                property = nil;
            }
            
            if (property && ![key2property objectForKey:property.name]) {
                [key2property setObject:property forKey:property.name];
            }
        }
        
        
        class = [class superclass];
    }
    
    objc_setAssociatedObject(self.class, &kClassPropertiesKey, key2property, OBJC_ASSOCIATION_RETAIN);
}

- (NSArray *)__properties__
{
    NSDictionary* key2property = objc_getAssociatedObject(self.class, &kClassPropertiesKey);
    if (!key2property) [self __setup__];
    
    key2property = objc_getAssociatedObject(self.class, &kClassPropertiesKey);
    return [key2property allValues];
}

#pragma mark - public methods

- (NSString *)toJsonString
{
    NSData* json_data = [self toJSONDataWithKeys:nil];
    
    return [[NSString alloc] initWithData:json_data encoding:NSUTF8StringEncoding];
}

- (NSDictionary *)toDictionary
{
    return [self toDictionaryWithPropertyKey:nil];
}

- (instancetype)initWithJson:(NSString *)json error:(NSError *__autoreleasing *)error
{
    NSData* json_data = [json dataUsingEncoding:NSUTF8StringEncoding];
    id dict = [NSJSONSerialization JSONObjectWithData:json_data
                                              options:kNilOptions
                                                error:nil];
    return [self initWithDictionary:dict error:nil];
}

- (instancetype)initWithDictionary:(NSDictionary *)dict error:(NSError *__autoreleasing *)error
{
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    self = [super init];
    [self __importDictionary:dict];
    
    return self;
}

#pragma mark - private methods

- (NSDictionary *)toDictionaryWithPropertyKey:(NSArray *)propertyKeys
{
    id value;
    NSArray* properties = [self __properties__];
    NSMutableDictionary* ret_dict = [NSMutableDictionary dictionaryWithCapacity:properties.count];
    
    for (NEJMClassProperty* property in properties) {
        if (propertyKeys && ![propertyKeys containsObject:property.name]) {
            continue;
        }
        
        NSString* property_key = property.name;
        value = [self valueForKey:property_key];
        
        // filter nil
        if (isNull(value)) {
            [ret_dict setValue:[NSNull null] forKey:property_key];
            continue;
        }
        
        // check if value be of |NEJSONModel *| object
        if ([value isKindOfClass:[NEJSONModel class]]) {
            value = [(NEJSONModel *)value toDictionary];
            [ret_dict setValue:value forKeyPath:property_key];
            
            continue;
        }
        else {
            if (property.protocol.length) {
//                value = [self __reverseTransform:value forProperty:property];
                value = [self __substitutionReverseTransfor:value forProperty:property];
            }
            
            if (property.isStandardJSONType || property.type == nil) {
                [ret_dict setValue:value forKeyPath:property_key];
                continue;
            }
            
            NSString* selector_name = [NSString stringWithFormat:@"%@From%@:",
                                       @"JSONObject", property.type];
            SEL selector = NSSelectorFromString(selector_name);
            
            if ([__valueTransformer respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                value = [__valueTransformer performSelector:selector withObject:value];
#pragma clang diagnostic pop
                
                [ret_dict setValue:value forKeyPath:property_key];
            }
            else {
                assert(NO);
            }
        }
    }
    
    return [ret_dict copy];
}

- (id)__substitutionReverseTransfor:(id)value forProperty:(NEJMClassProperty *)property
{
    Class cls = NSClassFromString(property.protocol);
    if (!cls) return value;
    
    if ([cls isSubclassOfClass:[NSArray class]] && [property.type isSubclassOfClass:[NSArray class]]) {
        NSMutableArray* ret_array = [NSMutableArray arrayWithCapacity:[(NSArray *)value count]];
        
        for (id object in (NSArray*)value) {
            if ([object conformsToProtocol:@protocol(AbstractNEJMProtocol)]
                && [object respondsToSelector:@selector(toDictionary)])
            {
                NSMutableDictionary* dict = [[object toDictionary] mutableCopy];
                if (dict.count) {
                    [dict setValue:NSStringFromClass([object class]) forKey:@"__class__"];
                }
                
                [ret_array addObject:[dict copy]];
            }
            else {
                [ret_array addObject:object];
            }
        }
        
        return ret_array;
    }
    
    if ([cls isSubclassOfClass:[NSDictionary class]] && [property.type isSubclassOfClass:[NSDictionary class]]) {
        NSMutableDictionary* ret_dict = [NSMutableDictionary dictionary];
        
        for (NSString* key in [(NSDictionary*)value allKeys]) {
            id object = value[key];
            
            if ([object conformsToProtocol:@protocol(AbstractNEJMProtocol)]
                && [object respondsToSelector:@selector(toDictionary)])
            {
                NSDictionary* dict = [object toDictionary];
                if (dict.count) {
                    [dict setValue:NSStringFromClass([object class]) forKey:@"__class__"];
                }
                
                [ret_dict setValue:dict forKey:key];
            }
            else {
                [ret_dict setValue:object forKey:key];
            }
        }
        
        return ret_dict;
    }
    
    return value;
}

- (id)__reverseTransform:(id)value forProperty:(NEJMClassProperty *)property
{
    Class cls = NSClassFromString(property.protocol);
    if (!cls) return value;
    
    if ([cls isSubclassOfClass:[NEJSONModel class]]) {
        if (property.type == [NSArray class] || property.type == [NSMutableArray class]) {
            NSMutableArray* ret_array = [NSMutableArray arrayWithCapacity:[(NSArray *)value count]];
            
            for (NSObject<AbstractNEJMProtocol>* object in (NSArray*)value) {
                if ([object respondsToSelector:@selector(toDictionary)]) {
                    [ret_array addObject:[object toDictionary]];
                }
                else {
                    [ret_array addObject:object];
                }
            }
        
            return ret_array;
        }
        
        if (property.type == [NSDictionary class] || property.type == [NSMutableDictionary class]) {
            NSMutableDictionary* ret_dict = [NSMutableDictionary dictionary];
            
            for (NSString* key in [(NSDictionary*)value allKeys]) {
                id<AbstractNEJMProtocol> object = value[key];
                [ret_dict setValue:[object toDictionary] forKey:key];
            }
            
            return ret_dict;
        }
    }
    
    return value;
}

-(NSData*)toJSONDataWithKeys:(NSArray*)propertyKeys
{
    NSData* jsonData = nil;
    NSError* jsonError = nil;
    
    @try {
        NSDictionary* dict = [self toDictionaryWithPropertyKey:propertyKeys];
        jsonData = [NSJSONSerialization dataWithJSONObject:dict options:kNilOptions error:&jsonError];
    }
    @catch (NSException *exception) {
        //this should not happen in properly design JSONModel
        //usually means there was no reverse transformer for a custom property
        NSLog(@"EXCEPTION: %@", exception.description);
        return nil;
    }
    
    return jsonData;
}

- (BOOL)__importDictionary:(NSDictionary *)dict
{
    for (NEJMClassProperty* property in [self __properties__]) {
        NSString* property_key = property.name;
        assert(property_key);
        
        id value = dict[property_key];
        if (isNull(value)) {
            continue;
        }
        
        Class value_cls = [value class];
        BOOL isValueOfAllowedType = NO;
        
        for (Class cls in __allowedJsonTypes) {
            if (![value_cls isSubclassOfClass:cls]) {
                continue;
            }
            
            isValueOfAllowedType = YES;
            break;
        }
        
        if (!isValueOfAllowedType) {
            return NO;
        }
        
        if (!property) {
            continue;
        }
        
        // primitive value
        if (!property.type) {
            if (value != [self valueForKey:property_key]) {
                [self setValue:value forKey:property_key];
            }
            
            continue;
        }
        
        // nils
        if (isNull(value)) {
            if ([self valueForKey:property_key] != nil) {
                [self setValue:nil forKey:property_key];
            }
            
            continue;
        }
        
        // if value be of |NEJSONModel *| object
        if ([property.type isSubclassOfClass:[NEJSONModel class]]) {
            value = [[property.type alloc] initWithDictionary:value error:nil];
            
            if (!value) {
                return NO;
            }
            
            if (![value isEqual:[self valueForKey:property_key]]) {
                [self setValue:value forKey:property_key];
            }
            
            continue;
        }
        
        // protocol
        if (property.protocol) {
            value = [self __transform:value forProperty:property];
            
            if (!value) return NO;
        }
        
        // standard class type
        if (property.isStandardJSONType && [value isKindOfClass:property.type]) {
            if (property.isMutable) {
                value = [value mutableCopy];
            }
            
            if (![value isEqual:[self valueForKey:property_key]]) {
                [self setValue:value forKey:property_key];
            }
            
            continue;
        }
        
        if ((![value isKindOfClass:property.type] && !isNull(value))
            || property.isMutable
            ) {
            Class source_cls = [JSONValueTransformer classByResolvingClusterClasses:[value class]];
            NSString* selectorName = [NSString stringWithFormat:@"%@From%@:", property.type, source_cls];
            SEL selector = NSSelectorFromString(selectorName);
            
            BOOL foundCustomTransformer = NO;
            if ([__valueTransformer respondsToSelector:selector]) {
                foundCustomTransformer = YES;
            }
            
            if (!foundCustomTransformer) {
                return NO;
            }
            
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            //transform the value
            value = [__valueTransformer performSelector:selector withObject:value];
#pragma clang diagnostic pop
            
            if (![value isEqual:[self valueForKey:property.name]]) {
                [self setValue:value forKey: property.name];
            }
        }
        else {
            if (![value isEqual:[self valueForKey:property.name]]) {
                [self setValue:value forKey: property.name];
            }
        }
    }
    
    return YES;
}

- (id)__transform:(id)value forProperty:(NEJMClassProperty *)property
{
    Class value_cls = NSClassFromString(property.protocol);
    if (!value_cls) {
        if ([value isKindOfClass:[NSArray class]]) {
            assert(NO);
        }
        
        return value;
    }
    
    if (![value_cls isSubclassOfClass:[NSArray class]] && ![value_cls isSubclassOfClass:[NSDictionary class]]) {
        return value;
    }
    
    if ([property.type isSubclassOfClass:[NSArray class]]) {
        // expect an |NSArray *| object
        if (![value isKindOfClass:[NSArray class]]) {
            return nil;
        }
        
        value = [NEJSONModel arrayOfModelsFromDictionaries:value];
    }
    
    if ([property.type isSubclassOfClass:[NSDictionary class]]) {
        // expect an |NSDictionary *| object
        if (![value isKindOfClass:[NSDictionary class]]) {
            return nil;
        }
        
        NSMutableDictionary* ret_dict = [NSMutableDictionary dictionary];
        
        for (NSString* key in [value allKeys]) {
            id obj = [[[value_cls class] alloc] initWithDictionary:value[key] error:nil];
            if (obj == nil) return nil;
            
            [ret_dict setValue:obj forKey:key];
        }
        value = [ret_dict copy];
    }
    
    return value;
}

+ (NSMutableArray*)arrayOfModelsFromDictionaries:(NSArray*)array
{
    //bail early
    if (isNull(array)) return nil;
    
    //parse dictionaries to objects
    NSMutableArray* ret_array = [NSMutableArray arrayWithCapacity: [array count]];
    
    for (id dict in array) {
        Class cls = NSClassFromString([dict objectForKey:@"__class__"]);
        if (![cls isSubclassOfClass:[NEJSONModel class]]) {
            [ret_array addObject:dict];
            continue;
        }
        
        if ([dict isKindOfClass:NSDictionary.class]) {
            id obj = [[cls alloc] initWithDictionary:dict error:nil];
            if (obj == nil) continue;
            
            [ret_array addObject: obj];
        }
        else if ([dict isKindOfClass:NSArray.class]) {
            [ret_array addObjectsFromArray:[NEJSONModel arrayOfModelsFromDictionaries:dict]];
        }
        else {
            // This is very bad
        }
    }
    
    return ret_array;
}

#pragma mark - NSCopying, NSCoding
-(instancetype)copyWithZone:(NSZone *)zone
{
    return [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:self]];
}

-(instancetype)initWithCoder:(NSCoder *)decoder
{
    NSString* json = [decoder decodeObjectForKey:@"json"];
    
    NSError *error = nil;
    self = [self initWithJson:json error:&error];
    if (!self) {
        error = [NSError errorWithDomain:@"NEJM.CoderErrorDomain" code:-1 userInfo:nil];
    }
    
    return self;
}

-(void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.toJsonString forKey:@"json"];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end
