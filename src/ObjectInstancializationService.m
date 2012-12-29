//
//  ObjectInstancializationService.m
//  TrainSampleProject
//
//  Created by Tomer Shiri on 12/19/12.
//  Copyright (c) 2012 Tomer Shiri. All rights reserved.
//

#import "ObjectInstancializationService.h"
#import "IOCDefines.h"
#import "ProtocolLocator.h"

#import <objc/runtime.h>

@implementation ObjectInstancializationService


+(NSString*) getIvarName:(Ivar) iVar {
    return [NSString stringWithUTF8String:ivar_getName(iVar)];
}

+(BOOL) isIOCIvar:(Ivar) iVar {
    NSString* ivarName = [ObjectInstancializationService getIvarName:iVar];
    return [ivarName hasPrefix:STABABLE_PROPERTY_PREFIX];
}

+(BOOL) isArray:(NSString*) iVarType {
    return iVarType && [iVarType isEqualToString:@"NSArray"];
}

+(BOOL) isProtocol:(NSString*) iVarType {
    return iVarType && [iVarType hasPrefix:@"<"] && [iVarType hasSuffix:@">"];
}

+(NSString*) protocolNameFromType:(NSString*) iVarType {
    //<xxx>
    return [[iVarType substringFromIndex:1] substringToIndex:[iVarType length] - 2];
}

+(NSString*) classNameFromType:(NSString*) iVarType {
    //@"xxx"
    return [[iVarType substringFromIndex:2] substringToIndex:[iVarType length] - 3];
}

+(id) iVarDefaultValueForType:(NSString*) iVarType {
    if ([iVarType length] > 2) {
        return nil;
    }
    return [NSNumber numberWithFloat:0.0];
}

+(void) setValueForIvar:(Ivar)ivar inObjectInstance:(id) instance {

    NSString* ivarType = [NSString stringWithUTF8String:ivar_getTypeEncoding(ivar)];
    NSString* className = [ObjectInstancializationService classNameFromType:ivarType];
    NSString* ivarName = [ObjectInstancializationService getIvarName:ivar];
    
    id ivarValue;
    
    if ([ObjectInstancializationService isProtocol:className]) {
        NSString* protocolName = [ObjectInstancializationService protocolNameFromType:className];
        ivarValue = [ObjectInstancializationService instantializeWithProtocol:NSProtocolFromString(protocolName)];
    }
    else if ([ObjectInstancializationService isArray:className]) {
        NSString* protocolNameFromIvarName = [ivarName substringFromIndex:[STABABLE_PROPERTY_PREFIX length]];
        ivarValue = [ObjectInstancializationService instantializeAllWithProtocol:NSProtocolFromString(protocolNameFromIvarName)];
    }
    else {
        ivarValue = [ObjectInstancializationService instantialize:NSClassFromString(className)];
    }

    if (ivarValue == nil) {
        ivarValue = [ObjectInstancializationService iVarDefaultValueForType:ivarType];
    }
    [instance setValue:ivarValue forKey:ivarName];
}

+(NSArray*) instantializeAllWithProtocol:(Protocol*) protocol {
    NSArray* classesForProtocol = [ProtocolLocator getAllClassesByProtocolType:protocol];
    if (!classesForProtocol) return nil;
    NSMutableArray* instances = [[NSMutableArray alloc] initWithCapacity:[classesForProtocol count]];
    
    for (Class clazz in classesForProtocol) {
        id instance = [ObjectInstancializationService instantialize:clazz];
        
        if (!instance) continue;
        
        [instances addObject:instance];
    }
    return [instances autorelease];
}

+(id) instantializeWithProtocol:(Protocol*) protocol {
    NSArray* classesForProtocol = [ProtocolLocator getAllClassesByProtocolType:protocol];
    if (!classesForProtocol) return nil;
    Class clazz = [classesForProtocol objectAtIndex:0];
    id instance = [[ObjectInstancializationService instantialize:clazz] retain];
    return [instance autorelease];
}

+(id) instantialize:(Class) clazz {
    id classInstance = [[clazz alloc] init];
    if (!classInstance) return classInstance;
    unsigned int numberOfIvars = 0;
    Ivar* iVars = class_copyIvarList(clazz, &numberOfIvars);
    for (int i = 0; i < numberOfIvars; ++i) {
        Ivar ivar = iVars[i];

        if (![ObjectInstancializationService isIOCIvar:ivar]) continue;

        [ObjectInstancializationService setValueForIvar:ivar inObjectInstance:classInstance];
    }
    return classInstance;
}


@end
