//
//  OAConfigureProfileViewController.h
//  OsmAnd
//
//  Created by Paul on 01.08.2020.
//  Copyright © 2020 OsmAnd. All rights reserved.
//

#import "OABaseNavbarViewController.h"

#define kGeneralSettings @"general_settings"
#define kNavigationSettings @"nav_settings"
#define kProfileAppearanceSettings @"profile_appearance"
#define kExportProfileSettings @"export_profile"
#define kTrackRecordingSettings @"trip_rec"
#define kOsmEditsSettings @"osm_edits"
#define kOsmandDevelopmentSettings @"osmand_development"
#define kWeatherSettings @"weather"
#define kWikipediaSettings @"wikipedia"

@class OAApplicationMode;

@interface OAConfigureProfileViewController : OABaseNavbarViewController

- (instancetype) initWithAppMode:(OAApplicationMode *)mode targetScreenKey:(NSString *)targetScreenKey;

@end
