//
//  OAAppVersionDependentConstants.h
//  OsmAnd
//
//  Created by nnngrach on 28.11.2020.
//  Copyright © 2020 OsmAnd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OAAppVersionDependentConstants : NSObject

+ (NSString *) getShortAppVersion;
+ (NSString *) getShortAppVersionWithSeparator:(NSString *)separator;
+ (NSString *)getAppVersionWithBundle;
+ (NSString *) getAppVersionForUrl;
+ (NSString *) getVersion;

@end
