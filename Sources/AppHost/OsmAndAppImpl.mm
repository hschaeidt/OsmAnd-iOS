//
//  OsmAndAppImpl.m
//  OsmAnd
//
//  Created by Alexey Pelykh on 2/25/14.
//  Copyright (c) 2014 OsmAnd. All rights reserved.
//

#import "OsmAndAppImpl.h"

#import <UIKit/UIKit.h>

#import "OsmAndApp.h"
#import "OAResourcesInstaller.h"
#import "OADaytimeAppearance.h"
#import "OANighttimeAppearance.h"
#import "OAAutoObserverProxy.h"
#import "OAUtilities.h"
#import "OALog.h"
#import <AFNetworking/AFNetworkReachabilityManager.h>
#import "OAManageResourcesViewController.h"
#import "OAAppVersionDependentConstants.h"
#import "OAPOIHelper.h"
#import "OAIAPHelper.h"
#import "Localization.h"
#import "OASavingTrackHelper.h"
#import "OAMapStyleSettings.h"
#import "OATerrainLayer.h"
#import "OAMapCreatorHelper.h"
#import "OAOcbfHelper.h"
#import "OAQuickSearchHelper.h"
#import "OADiscountHelper.h"
#import "OARoutingHelper.h"
#import "OATargetPointsHelper.h"
#import "OAVoiceRouter.h"
#import "OAPlugin.h"
#import "OAPOIFiltersHelper.h"
#import "OATTSCommandPlayerImpl.h"
#import "OAOsmAndLiveHelper.h"
#import "OAAvoidSpecificRoads.h"
#import "OAIndexConstants.h"
#import "OALocationConvert.h"
#import "OAWeatherHelper.h"
#import "OAGPXDatabase.h"
#import "OAExternalTimeFormatter.h"
#import "OAFavoritesHelper.h"

#include <algorithm>

#include <QList>
#include <QHash>

#include <OsmAndCore.h>
#import "OAAppSettings.h"
#include <OsmAndCore/IFavoriteLocation.h>
#include <OsmAndCore/IWebClient.h>
#include "OAWebClient.h"
#include "OAWeatherWebClient.h"
#include "CoreResourcesFromBundleProvider.h"

#include <CommonCollections.h>
#include <binaryRead.h>
#include <routingContext.h>
#include <routingConfiguration.h>
#include <binaryRoutePlanner.h>
#include <routePlannerFrontEnd.h>
#include <OsmAndCore/Utilities.h>
#include <OsmAndCore/Map/IMapStylesCollection.h>
#include <OsmAndCore/Map/UnresolvedMapStyle.h>
#include <OsmAndCore/Map/ResolvedMapStyle.h>
#include <OsmAndCore/Map/MapPresentationEnvironment.h>
#include <OsmAndCore/Map/GeoCommonTypes.h>

#include <openingHoursParser.h>

#define k3MonthInSeconds 60 * 60 * 24 * 90

#define MILS_IN_DEGREE 17.777778f

#define VERSION_3_10 3.10
#define VERSION_3_14 3.14
#define VERSION_4_2 4.2
#define VERSION_4_4_1 4.41

#define kMaxLogFiles 3

#define kAppData @"app_data"
#define kInstallDate @"install_date"
#define kNumberOfStarts @"starts_num"
#define kSubfolderPlaceholder @"_%_"

#define _(name)
@implementation OsmAndAppImpl
{
    BOOL _initialized;
    BOOL _initializedCore;

    NSString* _worldMiniBasemapFilename;

    OAMapMode _mapMode;
    OAMapMode _prevMapMode;

    OAResourcesInstaller* _resourcesInstaller;
    std::shared_ptr<OsmAnd::IWebClient> _webClient;

    OAAutoObserverProxy* _downloadsManagerActiveTasksCollectionChangeObserver;

    BOOL _firstLaunch;
    UNORDERED_map<std::string, std::shared_ptr<RoutingConfigurationBuilder>> _customRoutingConfigs;

    BOOL _carPlayActive;
}

@synthesize dataPath = _dataPath;
@synthesize dataDir = _dataDir;
@synthesize documentsPath = _documentsPath;
@synthesize documentsDir = _documentsDir;
@synthesize gpxPath = _gpxPath;
@synthesize inboxPath = _inboxPath;
@synthesize cachePath = _cachePath;
@synthesize weatherForecastPath = _weatherForecastPath;
@synthesize favoritesPath = _favoritesPath;

@synthesize initialURLMapState = _initialURLMapState;

@synthesize defaultRenderer = _defaultRenderer;
@synthesize resourcesManager = _resourcesManager;
@synthesize localResourcesChangedObservable = _localResourcesChangedObservable;
@synthesize osmAndLiveUpdatedObservable = _osmAndLiveUpdatedObservable;
@synthesize resourcesRepositoryUpdatedObservable = _resourcesRepositoryUpdatedObservable;
@synthesize defaultRoutingConfig = _defaultRoutingConfig;

@synthesize favoritesCollection = _favoritesCollection;

@synthesize dayNightModeObservable = _dayNightModeObservable;
@synthesize mapSettingsChangeObservable = _mapSettingsChangeObservable;
@synthesize updateGpxTracksOnMapObservable = _updateGpxTracksOnMapObservable;
@synthesize updateRecTrackOnMapObservable = _updateRecTrackOnMapObservable;
@synthesize updateRouteTrackOnMapObservable = _updateRouteTrackOnMapObservable;
@synthesize trackStartStopRecObservable = _trackStartStopRecObservable;
@synthesize addonsSwitchObservable = _addonsSwitchObservable;
@synthesize availableAppModesChangedObservable = _availableAppModesChangedObservable;
@synthesize followTheRouteObservable = _followTheRouteObservable;
@synthesize osmEditsChangeObservable = _osmEditsChangeObservable;
@synthesize mapillaryImageChangedObservable = _mapillaryImageChangedObservable;
@synthesize simulateRoutingObservable = _simulateRoutingObservable;

@synthesize trackRecordingObservable = _trackRecordingObservable;
@synthesize isRepositoryUpdating = _isRepositoryUpdating;

@synthesize carPlayActive = _carPlayActive;

- (instancetype) init
{
    self = [super init];
    if (self)
    {
        _initializedCore = NO;
        _initialized = NO;

        // Get default paths
        _dataPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
        _dataDir = QDir(QString::fromNSString(_dataPath));
        _documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        _documentsDir = QDir(QString::fromNSString(_documentsPath));
        _gpxPath = [_documentsPath stringByAppendingPathComponent:@"GPX"];
        _inboxPath = [_documentsPath stringByAppendingPathComponent:@"Inbox"];
        _cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        _weatherForecastPath = [_cachePath stringByAppendingPathComponent:@"WeatherForecast"];
        _favoritesPath = [_documentsPath stringByAppendingPathComponent:FAVORITES_INDEX_DIR];
        _favoritesBackupPath = [_documentsPath stringByAppendingPathComponent:FAVORITES_BACKUP_DIR];

        _favoritesFilePrefix = @"favorites";
        _favoritesGroupNameSeparator = @"-";
        _legacyFavoritesFilePrefix = @"favourites";

        [self buildFolders];
        [self createLogFile];

        [self initOpeningHoursParser];

        // First of all, initialize user defaults
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        _firstLaunch = [defaults objectForKey:kAppData] == nil;
        [defaults registerDefaults:[self inflateInitialUserDefaults]];
        NSDictionary *defHideAllGPX = [NSDictionary dictionaryWithObject:@"NO" forKey:@"hide_all_gpx"];
        [defaults registerDefaults:defHideAllGPX];
        NSDictionary *defResetSettings = [NSDictionary dictionaryWithObject:@"NO" forKey:@"reset_settings"];
        [defaults registerDefaults:defResetSettings];
        NSDictionary *defResetRouting = [NSDictionary dictionaryWithObject:@"NO" forKey:@"reset_routing"];
        [defaults registerDefaults:defResetRouting];
        if (![defaults objectForKey:kInstallDate])
            [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kInstallDate];
        NSInteger ns = [defaults integerForKey:kNumberOfStarts];
        ns = ns < 0 ? 0 : ns;
        [defaults setInteger:++ns forKey:kNumberOfStarts];
    }
    return self;
}

- (void) dealloc
{
    _resourcesManager->localResourcesChangeObservable.detach(reinterpret_cast<OsmAnd::IObservable::Tag>((__bridge const void*)self));
    _resourcesManager->repositoryUpdateObservable.detach(reinterpret_cast<OsmAnd::IObservable::Tag>((__bridge const void*)self));

    _favoritesCollection->collectionChangeObservable.detach(reinterpret_cast<OsmAnd::IObservable::Tag>((__bridge const void*)self));
    _favoritesCollection->favoriteLocationChangeObservable.detach(reinterpret_cast<OsmAnd::IObservable::Tag>((__bridge const void*)self));
}

- (void) buildFolders
{
    NSError *error;

    if (![[NSFileManager defaultManager] fileExistsAtPath:_gpxPath])
    {
        BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:_gpxPath
                                                 withIntermediateDirectories:NO
                                                                  attributes:nil
                                                                       error:&error];
        if (!success)
            OALog(@"Error creating GPX folder: %@", error.localizedFailureReason);
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:_weatherForecastPath])
    {
        BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:_weatherForecastPath
                                                 withIntermediateDirectories:NO
                                                                  attributes:nil
                                                                       error:&error];
        if (!success)
            OALog(@"Error creating WeatherForecast folder: %@", error.localizedFailureReason);
    }
}

- (void) createLogFile
{
#if DEBUG
    return;
#else
    NSFileManager *manager = NSFileManager.defaultManager;
    NSString *logsPath = [_documentsPath stringByAppendingPathComponent:@"Logs"];
    if (![manager fileExistsAtPath:logsPath])
        [manager createDirectoryAtPath:logsPath withIntermediateDirectories:NO attributes:nil error:nil];
    NSArray<NSString *> *files = [manager contentsOfDirectoryAtPath:logsPath error:nil];
    for (NSInteger i = 0; i < files.count; i++)
    {
        if (i > kMaxLogFiles)
           [manager removeItemAtPath:[logsPath stringByAppendingPathComponent:files[i]] error:nil];
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MMM dd, yyyy HH:mm"];
    NSString *destPath = [[logsPath stringByAppendingPathComponent:[formatter stringFromDate:NSDate.date]] stringByAppendingPathExtension:@"log"];
    freopen([destPath fileSystemRepresentation], "a+", stderr);
#endif
}

- (void) initOpeningHoursParser
{
    [OAExternalTimeFormatter setLocale:[NSLocale currentLocale].localeIdentifier];
    OpeningHoursParser::setExternalTimeFormatterCallback([OAExternalTimeFormatter getExternalTimeFormatterCallback]);
    OpeningHoursParser::setTwelveHourFormattingEnabled([OAExternalTimeFormatter isCurrentRegionWith12HourTimeFormat]);
    OpeningHoursParser::setAmpmOnLeft([OAExternalTimeFormatter isCurrentRegionWithAmpmOnLeft]);
    OpeningHoursParser::setLocalizedDaysOfWeek([OAExternalTimeFormatter getLocalizedWeekdays]);
    OpeningHoursParser::setLocalizedMonths([OAExternalTimeFormatter getLocalizedMonths]);
    
    OpeningHoursParser::setAdditionalString("off", [OALocalizedString(@"day_off_label") UTF8String]);
    OpeningHoursParser::setAdditionalString("is_open", [OALocalizedString(@"shared_string_open") UTF8String]);
    OpeningHoursParser::setAdditionalString("is_open_24_7", [OALocalizedString(@"shared_string_is_open_24_7") UTF8String]);
    OpeningHoursParser::setAdditionalString("will_open_at", [OALocalizedString(@"will_open_at") UTF8String]);
    OpeningHoursParser::setAdditionalString("open_from", [OALocalizedString(@"open_from") UTF8String]);
    OpeningHoursParser::setAdditionalString("will_close_at", [OALocalizedString(@"will_close_at") UTF8String]);
    OpeningHoursParser::setAdditionalString("open_till", [OALocalizedString(@"open_till") UTF8String]);
    OpeningHoursParser::setAdditionalString("will_open_tomorrow_at", [OALocalizedString(@"will_open_tomorrow_at") UTF8String]);
    OpeningHoursParser::setAdditionalString("will_open_on", [OALocalizedString(@"will_open_on") UTF8String]);
    
    //[self runOpeningHoursParserTests];
}

- (void) runOpeningHoursParserTests
{
    [OAExternalTimeFormatter setLocale:@"en"];
    OpeningHoursParser::setAmpmOnLeft([OAExternalTimeFormatter isCurrentRegionWithAmpmOnLeft]);
    OpeningHoursParser::runTest();
    
    [OAExternalTimeFormatter setLocale:@"en"];
    OpeningHoursParser::setAmpmOnLeft([OAExternalTimeFormatter isCurrentRegionWithAmpmOnLeft]);
    OpeningHoursParser::runTestAmPmEnglish();
    
    [OAExternalTimeFormatter setLocale:@"zh"];
    OpeningHoursParser::setAmpmOnLeft([OAExternalTimeFormatter isCurrentRegionWithAmpmOnLeft]);
    OpeningHoursParser::runTestAmPmChinese();
    
    [OAExternalTimeFormatter setLocale:@"ar"];
    OpeningHoursParser::setAmpmOnLeft([OAExternalTimeFormatter isCurrentRegionWithAmpmOnLeft]);
    OpeningHoursParser::runTestAmPmArabic();
}

- (void) migrateResourcesToDocumentsIfNeeded
{
    BOOL movedRes = [self moveContentsOfDirectory:[_dataPath stringByAppendingPathComponent:RESOURCES_DIR] toDest:[_documentsPath stringByAppendingPathComponent:RESOURCES_DIR]];
    BOOL movedSqlite = [self moveContentsOfDirectory:[_dataPath stringByAppendingPathComponent:MAP_CREATOR_DIR] toDest:[_documentsPath stringByAppendingPathComponent:MAP_CREATOR_DIR]];
    if (movedRes)
        [self migrateMapNames:[_documentsPath stringByAppendingPathComponent:RESOURCES_DIR]];
    if (movedRes || movedSqlite)
        _resourcesManager->rescanUnmanagedStoragePaths(true);
}

- (BOOL) initializeCore
{
    @synchronized (self)
    {
        if (_initializedCore)
        {
            NSLog(@"OsmAndApp Core already initialized. Finish.");
            return YES;
        }

        @try
        {
            // Initialize OsmAnd Core
            NSLog(@"OsmAndApp InitializeCore start");
            const std::shared_ptr<CoreResourcesFromBundleProvider> coreResourcesFromBundleProvider(new CoreResourcesFromBundleProvider());
            OsmAnd::InitializeCore(coreResourcesFromBundleProvider);
            _initializedCore = YES;
            NSLog(@"OsmAndApp InitializeCore finish");
            return YES;
        }
        @catch (NSException *e)
        {
            NSLog(@"Failed to InitializeCore. Reason: %@", e.reason);
            return NO;
        }
    }
}

- (BOOL) initialize
{
    @synchronized (self)
    {
        @try
        {
            return [self initializeImpl];
        }
        @catch (NSException *e)
        {
            NSLog(@"Failed to initialize OsmAndApp. Reason: %@", e.reason);
            return NO;
        }
    }
}

- (BOOL) initializeImpl
{
    NSLog(@"OsmAndApp initialize start (%@)", [NSThread isMainThread] ? @"Main thread" : @"Background thread");
    if (_initialized)
    {
        NSLog(@"OsmAndApp already initialized. Finish.");
        return YES;
    }

    NSError* versionError = nil;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL hideAllGPX = [defaults boolForKey:@"hide_all_gpx"];
    BOOL resetSettings = [defaults boolForKey:@"reset_settings"];
    BOOL resetRouting = [defaults boolForKey:@"reset_routing"];
    OAAppSettings *settings = [OAAppSettings sharedManager];
    [settings setDisabledTypes:[settings.speedCamerasUninstalled get] ? [NSSet setWithObject:SPEED_CAMERA] : [NSSet set]];
    if (hideAllGPX)
    {
        [settings.mapSettingVisibleGpx set:@[]];
        [defaults setBool:NO forKey:@"hide_all_gpx"];
        [defaults synchronize];
    }
    if (resetRouting)
    {
        [settings clearImpassableRoads];
        [defaults setBool:NO forKey:@"reset_routing"];
        [defaults synchronize];
    }
    if (resetSettings)
    {
        int freeMaps = -1;
        if ([defaults objectForKey:@"freeMapsAvailable"]) {
            freeMaps = (int)[defaults integerForKey:@"freeMapsAvailable"];
        }

        NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
        [defaults removePersistentDomainForName:appDomain];
        [defaults synchronize];
        
        if (freeMaps != -1) {
            [defaults setInteger:freeMaps forKey:@"freeMapsAvailable"];
        }
        
        [defaults registerDefaults:[self inflateInitialUserDefaults]];
        NSDictionary *defHideAllGPX = [NSDictionary dictionaryWithObject:@"NO" forKey:@"hide_all_gpx"];
        [defaults registerDefaults:defHideAllGPX];
        NSDictionary *defResetSettings = [NSDictionary dictionaryWithObject:@"NO" forKey:@"reset_settings"];
        [defaults registerDefaults:defResetSettings];
        NSDictionary *defResetRouting = [NSDictionary dictionaryWithObject:@"NO" forKey:@"reset_routing"];
        [defaults registerDefaults:defResetRouting];

        _data = [OAAppData defaults];
        [defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:_data]
                         forKey:kAppData];
        [defaults setBool:NO forKey:@"hide_all_gpx"];
        [defaults setBool:NO forKey:@"reset_settings"];
        [defaults setBool:NO forKey:@"reset_routing"];
        [defaults synchronize];
    }

    OALog(@"Data path: %@", _dataPath);
    OALog(@"Documents path: %@", _documentsPath);
    OALog(@"GPX path: %@", _gpxPath);
    OALog(@"Cache path: %@", _cachePath);
    OALog(@"Weather Forecast path: %@", _weatherForecastPath);

    // Unpack app data
    _data = [NSKeyedUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:kAppData]];

    settings.simulateNavigation = NO;
    settings.simulateNavigationMode = [OASimulationMode toKey:EOASimulationModePreview];
    settings.simulateNavigationSpeed = kSimMinSpeed;
    
    [_data setLastMapSourceVariant:settings.applicationMode.get.variantKey];

    // Get location of a shipped world mini-basemap and it's version stamp
    _worldMiniBasemapFilename = [[NSBundle mainBundle] pathForResource:@"WorldMiniBasemap"
                                                                ofType:@"obf"
                                                           inDirectory:@"Shipped"];
    NSString* worldMiniBasemapStamp = [[NSBundle mainBundle] pathForResource:kWorldMiniBasemapKey
                                                                      ofType:@"stamp"
                                                                 inDirectory:@"Shipped"];
    NSString* worldMiniBasemapStampContents = [NSString stringWithContentsOfFile:worldMiniBasemapStamp
                                                                        encoding:NSASCIIStringEncoding
                                                                           error:&versionError];
    NSString* worldMiniBasemapVersion = [worldMiniBasemapStampContents stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    OALog(@"Located shipped world mini-basemap (version %@) at %@", worldMiniBasemapVersion, _worldMiniBasemapFilename);
    
    _webClient = std::make_shared<OAWebClient>();

    _localResourcesChangedObservable = [[OAObservable alloc] init];
    _resourcesRepositoryUpdatedObservable = [[OAObservable alloc] init];
    _osmAndLiveUpdatedObservable = [[OAObservable alloc] init];
    _resourcesManager.reset(new OsmAnd::ResourcesManager(_documentsDir.absoluteFilePath(QString::fromNSString(RESOURCES_DIR)),
                                                         _documentsDir.absolutePath(),
                                                         QList<QString>() << QString::fromNSString([[NSBundle mainBundle] resourcePath]),
                                                         _worldMiniBasemapFilename != nil ? QString::fromNSString(_worldMiniBasemapFilename) : QString(),
                                                         QString::fromNSString(NSTemporaryDirectory()),
                                                         QString::fromNSString(_cachePath),
                                                         QString::fromNSString([[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"]),
                                                         QString::fromNSString(@"https://download.osmand.net"),
                                                         QString::fromNSString([self generateIndexesUrl]),
                                                         _webClient));

    _resourcesManager->localResourcesChangeObservable.attach(reinterpret_cast<OsmAnd::IObservable::Tag>((__bridge const void*)self),
                                                             [self]
                                                             (const OsmAnd::ResourcesManager* const resourcesManager,
                                                              const QList< QString >& added,
                                                              const QList< QString >& removed,
                                                              const QList< QString >& updated)
                                                             {
                                                                 [_localResourcesChangedObservable notifyEventWithKey:self];
                                                                 [OAResourcesBaseViewController setDataInvalidated];
                                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                                     [[OAAvoidSpecificRoads instance] initRouteObjects:YES];
                                                                 });
                                                             });
    
    _resourcesManager->repositoryUpdateObservable.attach(reinterpret_cast<OsmAnd::IObservable::Tag>((__bridge const void*)self),
                                                         [self]
                                                         (const OsmAnd::ResourcesManager* const resourcesManager)
                                                         {
                                                             [_resourcesRepositoryUpdatedObservable notifyEventWithKey:self];
                                                         });

    [self instantiateWeatherResourcesManager];

    // Check for NSURLIsExcludedFromBackupKey and setup if needed
    const auto& localResources = _resourcesManager->getLocalResources();
    for (const auto& resource : localResources)
    {
        if (resource->origin == OsmAnd::ResourcesManager::ResourceOrigin::Installed)
        {
            NSString *localPath = resource->localPath.toNSString();
            [self applyExcludedFromBackup:localPath];
        }
    }
    
    for (NSString *filePath in [OAMapCreatorHelper sharedInstance].files.allValues)
    {
        [self applyExcludedFromBackup:filePath];
    }
    
    float currentVersion = [[[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"] floatValue];
    float prevVersion = [[NSUserDefaults standardUserDefaults] objectForKey:@"appVersion"] ? [[NSUserDefaults standardUserDefaults] floatForKey:@"appVersion"] : 0.;
    if (_firstLaunch)
    {
        [[NSUserDefaults standardUserDefaults] setObject:NSDate.date forKey:kInstallDate];
        [[NSUserDefaults standardUserDefaults] setFloat:currentVersion forKey:@"appVersion"];
        _resourcesManager->installBuiltInTileSources();
        [OAAppSettings sharedManager].shouldShowWhatsNewScreen = YES;
    }
    else if (currentVersion != prevVersion)
    {
        if (prevVersion < VERSION_3_10)
        {
            // Reset map sources
            _data.overlayMapSource = nil;
            _data.underlayMapSource = nil;
            _data.lastMapSource = [OAAppData defaultMapSource];
            _resourcesManager->installBuiltInTileSources();
            
            [self clearUnsupportedTilesCache];
        }
        if (prevVersion < VERSION_3_14)
        {
            [OAAppSettings.sharedManager.availableApplicationModes set:@"car,bicycle,pedestrian,public_transport,"];
        }
        if (prevVersion < VERSION_4_2)
        {
            [[NSUserDefaults standardUserDefaults] setObject:NSDate.date forKey:kInstallDate];
            
            [OAGPXDatabase.sharedDb save];
            [OAGPXDatabase.sharedDb load];

            NSError *error;
            NSArray *inboxFiles = [NSFileManager.defaultManager contentsOfDirectoryAtPath:_inboxPath error:&error];
            if (!error)
            {
                for (NSString *inboxFile in inboxFiles)
                {
                    [NSFileManager.defaultManager removeItemAtPath:[_inboxPath stringByAppendingPathComponent:inboxFile] error:nil];
                }
            }
        }
        if (prevVersion < VERSION_4_4_1)
        {
            OAAppSettings *app = [OAAppSettings sharedManager];
            for (OAApplicationMode *appMode in OAApplicationMode.values)
            {
                NSInteger value = [app.activeMarkers get:appMode];
                if (value == 0)
                    [app.activeMarkers set:ONE_ACTIVE_MARKER mode:appMode];
                else if (value == 1)
                    [app.activeMarkers set:TWO_ACTIVE_MARKERS mode:appMode];
            }
        }
        [[NSUserDefaults standardUserDefaults] setFloat:currentVersion forKey:@"appVersion"];
    }
    [self migrateResourcesToDocumentsIfNeeded];
    
    // Copy regions.ocbf to Documents/Resources if needed
    NSString *ocbfPathBundle = [[NSBundle mainBundle] pathForResource:@"regions" ofType:@"ocbf"];
    NSString *ocbfPathLib = [NSHomeDirectory() stringByAppendingString:@"/Documents/Resources/regions.ocbf"];
    
    if ([OAOcbfHelper isBundledOcbfNewer])
        [[NSFileManager defaultManager] removeItemAtPath:ocbfPathLib error:nil];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:ocbfPathLib])
    {
        NSError *error = nil;
        [[NSFileManager defaultManager] copyItemAtPath:ocbfPathBundle toPath:ocbfPathLib error:&error];
        if (error)
            NSLog(@"Error copying file: %@ to %@ - %@", ocbfPathBundle, ocbfPathLib, [error localizedDescription]);
    }
    [self applyExcludedFromBackup:ocbfPathLib];
    
    // Copy proj.db to Library/Application Support/proj
    NSString *projDbPathBundle = [[NSBundle mainBundle] pathForResource:@"proj" ofType:@"db"];
    NSString *projDbPathLib = [NSHomeDirectory() stringByAppendingString:@"/Library/Application Support/proj/proj.db"];
    [[NSFileManager defaultManager] removeItemAtPath:projDbPathLib error:nil];
    if (![[NSFileManager defaultManager] fileExistsAtPath:projDbPathLib])
    {
        NSError *errorDir = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:[NSHomeDirectory() stringByAppendingString:@"/Library/Application Support/proj"]
                                  withIntermediateDirectories:YES attributes:nil error:&errorDir];
        if (errorDir)
            NSLog(@"Error creating dir for proj: %@", [errorDir localizedDescription]);

        NSError *error = nil;
        [[NSFileManager defaultManager] copyItemAtPath:projDbPathBundle toPath:projDbPathLib error:&error];
        if (error)
            NSLog(@"Error copying file: %@ to %@ - %@", projDbPathBundle, projDbPathLib, [error localizedDescription]);

    }
    [self applyExcludedFromBackup:projDbPathLib];
    
    // Sync favorites filename with android version
    NSString *oldfFavoritesFilename = _documentsDir.filePath(QLatin1String("Favorites.gpx")).toNSString();
    _favoritesLegacyFilename = _documentsDir.filePath(QLatin1String("favourites.gpx")).toNSString();
    if ([[NSFileManager defaultManager] fileExistsAtPath:oldfFavoritesFilename] && ![[NSFileManager defaultManager] fileExistsAtPath:_favoritesLegacyFilename])
    {
        NSError *error = nil;
        [[NSFileManager defaultManager] moveItemAtPath:oldfFavoritesFilename toPath:_favoritesLegacyFilename error:&error];
        if (error)
            NSLog(@"Error moving file: %@ to %@ - %@", oldfFavoritesFilename, _favoritesLegacyFilename, [error localizedDescription]);
    }

    // Move legacy favorites backup folder to new location
    NSString *oldFavoritesBackupPath = [_documentsPath stringByAppendingPathComponent:@"favourites_backup"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:oldFavoritesBackupPath] && ![[NSFileManager defaultManager] fileExistsAtPath:_favoritesBackupPath])
    {
        NSError *error = nil;
        [[NSFileManager defaultManager] moveItemAtPath:oldFavoritesBackupPath toPath:_favoritesBackupPath error:&error];
        if (error)
            NSLog(@"Error moving dir: %@ to %@ - %@", oldFavoritesBackupPath, _favoritesBackupPath, [error localizedDescription]);
    }

    // Load favorites
    _favoritesCollectionChangedObservable = [[OAObservable alloc] init];
    _favoriteChangedObservable = [[OAObservable alloc] init];
    _favoritesCollection.reset(new OsmAnd::FavoriteLocationsGpxCollection());

    BOOL legacyFavoritesExists = [[NSFileManager defaultManager] fileExistsAtPath:_favoritesLegacyFilename];
    if (legacyFavoritesExists)
        _favoritesCollection->loadFrom(QString::fromNSString(_favoritesLegacyFilename));

    NSArray<NSString *> *favoritesGroupFiles = [OAFavoritesHelper getGroupFiles];
    for (NSString *groupFile in favoritesGroupFiles)
        _favoritesCollection->loadFrom(QString::fromNSString(groupFile), true);

    if (legacyFavoritesExists || ![[NSFileManager defaultManager] fileExistsAtPath:_favoritesPath])
    {
        [self saveFavoritesToPermanentStorage];
        [[NSFileManager defaultManager] removeItemAtPath:_favoritesLegacyFilename error:nil];
    }

    _favoritesCollection->collectionChangeObservable.attach(reinterpret_cast<OsmAnd::IObservable::Tag>((__bridge const void*)self),
                                                            [self]
                                                            (const OsmAnd::IFavoriteLocationsCollection* const collection)
                                                            {
                                                                [_favoritesCollectionChangedObservable notifyEventWithKey:self];
                                                            });
    _favoritesCollection->favoriteLocationChangeObservable.attach(reinterpret_cast<OsmAnd::IObservable::Tag>((__bridge const void*)self),
                                                                  [self]
                                                                  (const OsmAnd::IFavoriteLocationsCollection* const collection,
                                                                   const std::shared_ptr<const OsmAnd::IFavoriteLocation>& favoriteLocation)
                                                                  {
                                                                      [_favoriteChangedObservable notifyEventWithKey:self
                                                                                                            andValue:favoriteLocation->getTitle().toNSString()];
                                                                  });
    


    // Load resources list
    
    // If there's no repository available and there's internet connection, just update it
    if (!self.resourcesManager->isRepositoryAvailable() && AFNetworkReachabilityManager.sharedManager.isReachable)
    {
        [self startRepositoryUpdateAsync:YES];
    }

    // Load world regions
    [self loadWorldRegions];
    [OAManageResourcesViewController prepareData];
    [_worldRegion buildResourceGroupItem];

    [[OAWeatherHelper sharedInstance] clearOutdatedCache];

    _defaultRoutingConfig = [self getDefaultRoutingConfig];
    [[OAAvoidSpecificRoads instance] initRouteObjects:NO];
    [self loadRoutingFiles];
    
    _dayNightModeObservable = [[OAObservable alloc] init];
    _mapSettingsChangeObservable = [[OAObservable alloc] init];
    _updateGpxTracksOnMapObservable = [[OAObservable alloc] init];
    _updateRecTrackOnMapObservable = [[OAObservable alloc] init];
    _updateRouteTrackOnMapObservable = [[OAObservable alloc] init];
    _addonsSwitchObservable = [[OAObservable alloc] init];
    _availableAppModesChangedObservable = [[OAObservable alloc] init];
    _followTheRouteObservable = [[OAObservable alloc] init];
    _osmEditsChangeObservable = [[OAObservable alloc] init];
    _mapillaryImageChangedObservable = [[OAObservable alloc] init];
    _simulateRoutingObservable = [[OAObservable alloc] init];

    _trackRecordingObservable = [[OAObservable alloc] init];
    _trackStartStopRecObservable = [[OAObservable alloc] init];

    _mapMode = OAMapModeFree;
    _prevMapMode = OAMapModeFree;
    _mapModeObservable = [[OAObservable alloc] init];

    _downloadsManager = [[OADownloadsManager alloc] init];
    _downloadsManagerActiveTasksCollectionChangeObserver = [[OAAutoObserverProxy alloc] initWith:self
                                                                                     withHandler:@selector(onDownloadManagerActiveTasksCollectionChanged)
                                                                                      andObserve:_downloadsManager.activeTasksCollectionChangedObservable];
    
    _resourcesInstaller = [[OAResourcesInstaller alloc] init];

    _locationServices = [[OALocationServices alloc] initWith:self];
    if (_locationServices.available && _locationServices.allowed)
        [_locationServices start];

    [self updateScreenTurnOffSetting];

    _appearance = [[OADaytimeAppearance alloc] init];
    _appearanceChangeObservable = [[OAObservable alloc] init];
    
    [OAMapStyleSettings sharedInstance];

    [[OATargetPointsHelper sharedInstance] removeAllWayPoints:NO clearBackup:NO];
    
    // Init track recorder
    [OASavingTrackHelper sharedInstance];
    
    [OAMapCreatorHelper sharedInstance];
    [OATerrainLayer sharedInstanceHillshade];
    [OATerrainLayer sharedInstanceSlope];

    OAIAPHelper *iapHelper = [OAIAPHelper sharedInstance];
    [iapHelper resetTestPurchases];
    [iapHelper requestProductsWithCompletionHandler:nil];

    [OAApplicationMode onApplicationStart];
    OAApplicationMode *initialAppMode = [settings.useLastApplicationModeByDefault get] ?
        [OAApplicationMode valueOfStringKey:[settings.lastUsedApplicationMode get] def:OAApplicationMode.DEFAULT] :
                                                                                    settings.defaultApplicationMode.get;
    [settings setApplicationModePref:initialAppMode];
    
    [OAPlugin initPlugins];
    [OAPOIHelper sharedInstance];
    [OAQuickSearchHelper instance];
    OAPOIFiltersHelper *helper = [OAPOIFiltersHelper sharedInstance];
    [helper reloadAllPoiFilters];
    [helper loadSelectedPoiFilters];

    _initialized = YES;
    NSLog(@"OsmAndApp initialize finish");
    return YES;
}

- (BOOL) moveContentsOfDirectory:(NSString *)src toDest:(NSString *)dest
{
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:src])
        return NO;
    if (![fm fileExistsAtPath:dest])
        [fm createDirectoryAtPath:dest withIntermediateDirectories:YES attributes:nil error:nil];

    NSArray *files = [fm contentsOfDirectoryAtPath:src error:nil];
    BOOL tryAgain = NO;
    for (NSString *file in files)
    {
        if ([fm fileExistsAtPath:[dest stringByAppendingPathComponent:file]])
            continue;
        NSError *err = nil;
        [fm moveItemAtPath:[src stringByAppendingPathComponent:file]
                    toPath:[dest stringByAppendingPathComponent:file]
                     error:&err];
        if (err)
            tryAgain = YES;
    }
    if (!tryAgain)
        [fm removeItemAtPath:src error:nil];
    return YES;
}

- (void) migrateMapNames:(NSString *)path
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    [fm fileExistsAtPath:path isDirectory:&isDirectory];
    if (!isDirectory)
        return;

    NSArray *files = [fm contentsOfDirectoryAtPath:path error:nil];

    for (NSString *file in files)
    {
        NSString *oldPath = [path stringByAppendingPathComponent:file];
        BOOL isDir = NO;
        [fm fileExistsAtPath:oldPath isDirectory:&isDir];
        if (isDir)
            [self migrateMapNames:oldPath];
        else
        {
            NSString *newPath = [path stringByAppendingPathComponent:[self generateCorrectFileName:file]];
            if (![newPath isEqualToString:oldPath])
            {
                [fm moveItemAtPath:oldPath
                            toPath:newPath
                             error:nil];
            }
        }
    }
}

- (NSString *) generateCorrectFileName:(NSString *)path
{
    NSString *fileName = path.lastPathComponent;
    if ([fileName hasSuffix:@".map.obf"])
    {
        fileName = [OAUtilities capitalizeFirstLetter:[fileName stringByReplacingOccurrencesOfString:@".map.obf" withString:@".obf"]];
    }
    else if ([fileName.pathExtension isEqualToString:@"obf"])
    {
        fileName = [OAUtilities capitalizeFirstLetter:fileName];
    }
    else if ([fileName.pathExtension isEqualToString:@"sqlitedb"])
    {
        if ([fileName hasSuffix:@".hillshade.sqlitedb"])
        {
            fileName = [fileName stringByReplacingOccurrencesOfString:@".hillshade.sqlitedb" withString:@".sqlitedb"];
            fileName = [fileName stringByReplacingOccurrencesOfString:@"_" withString:@" "];
            fileName = [NSString stringWithFormat:@"Hillshade %@", [OAUtilities capitalizeFirstLetter:fileName]];
        }
        else if ([fileName hasSuffix:@".slope.sqlitedb"])
        {
            fileName = [fileName stringByReplacingOccurrencesOfString:@".slope.sqlitedb" withString:@".sqlitedb"];
            fileName = [fileName stringByReplacingOccurrencesOfString:@"_" withString:@" "];
            fileName = [NSString stringWithFormat:@"Slope %@", [OAUtilities capitalizeFirstLetter:fileName]];
        }
    }
    return [path.stringByDeletingLastPathComponent stringByAppendingPathComponent:fileName];
}

- (NSString *) generateIndexesUrl
{
    NSMutableString *res = [NSMutableString stringWithFormat:@"https://download.osmand.net/get_indexes?gzip&osmandver=%@", OAAppVersionDependentConstants.getAppVersionForUrl];
    NSDate *installDate = [[NSUserDefaults standardUserDefaults] objectForKey:kInstallDate];
    if (installDate)
    {
        NSInteger nd = [self daysBetween:installDate date2:NSDate.date];
        if (nd > 0)
            [res appendFormat:@"&nd=%ld", nd];
    }
    [res appendFormat:@"&ns=%ld", [[NSUserDefaults standardUserDefaults] integerForKey:kNumberOfStarts]];
    if (self.getUserIosId.length > 0)
        [res appendFormat:@"&aid=%@", [self getUserIosId]];
    return res;
}

- (NSInteger) daysBetween:(NSDate *)dt1 date2:(NSDate *)dt2
{
    NSUInteger unitFlags = NSCalendarUnitDay;
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *components = [calendar components:unitFlags fromDate:dt1 toDate:dt2 options:0];
    return [components day] + 1;
}

- (void) instantiateWeatherResourcesManager
{
    QHash<OsmAnd::BandIndex, std::shared_ptr<const OsmAnd::GeoBandSettings>> bandSettings; // init later
    _resourcesManager->instantiateWeatherResourcesManager(
        bandSettings,
        QString::fromNSString(_weatherForecastPath),
        QString::fromNSString([NSHomeDirectory() stringByAppendingString:@"/Library/Application Support/proj"]),
        256,
        [UIScreen mainScreen].scale,
        std::make_shared<OAWeatherWebClient>()
    );
}

- (std::shared_ptr<OsmAnd::MapPresentationEnvironment>)defaultRenderer
{
    if (!_defaultRenderer)
    {
        auto defSourceResource = _resourcesManager->getResource(QString::fromNSString([OAAppData defaultMapSource].resourceId));
        const auto name = std::static_pointer_cast<const OsmAnd::ResourcesManager::MapStyleMetadata>(defSourceResource->metadata)->mapStyle->name;
        
        const auto& resolvedMapStyle = _resourcesManager->mapStylesCollection->getResolvedStyleByName(name);
        _defaultRenderer = std::make_shared<OsmAnd::MapPresentationEnvironment>(resolvedMapStyle);
    }
    return _defaultRenderer;
}

- (void) clearUnsupportedTilesCache
{
    // Clear old cache
    NSArray<NSString *> *folders = @[@"osmand_hd", @"bing_earth", @"bing_maps", @"bing_hybrid", @"hike_bike", @"hike_hillshade"];
    NSFileManager *manager = [NSFileManager defaultManager];
    for (NSString *folderName in folders)
    {
        NSString *pathToCache = [self.cachePath stringByAppendingPathComponent:folderName];
        BOOL success = [manager removeItemAtPath:pathToCache error:nil];
        NSLog(@"Removing tiles at path: %@ %@", pathToCache, success ? @"successful" : @"failed - No such directory");
    }
}

- (std::vector<std::shared_ptr<RoutingConfigurationBuilder>>) getAllRoutingConfigs
{
    std::vector<std::shared_ptr<RoutingConfigurationBuilder>> values;
    for (auto it = _customRoutingConfigs.begin(); it != _customRoutingConfigs.end(); ++it)
        values.push_back(it->second);
    values.push_back(self.defaultRoutingConfig);
    return values;
}

- (std::shared_ptr<RoutingConfigurationBuilder>) getDefaultRoutingConfig
{
    float tm = [[NSDate date] timeIntervalSince1970];
    @try
    {
        return parseRoutingConfigurationFromXml([[[NSBundle mainBundle] pathForResource:@"routing" ofType:@"xml"] UTF8String], "");
    }
    @finally
    {
        float te = [[NSDate date] timeIntervalSince1970];
        if (te - tm > 30)
            NSLog(@"Defalt routing config init took %f ms", (te - tm));
    }
}

- (UNORDERED_map<std::string, std::shared_ptr<RoutingConfigurationBuilder>>) getCustomRoutingConfigs
{
    return _customRoutingConfigs;
}

- (std::shared_ptr<RoutingConfigurationBuilder>) getCustomRoutingConfig:(std::string &)key
{
    return _customRoutingConfigs[key];
}

- (std::shared_ptr<RoutingConfigurationBuilder>) getRoutingConfigForMode:(OAApplicationMode *)mode
{
    std::shared_ptr<RoutingConfigurationBuilder> builder = self.defaultRoutingConfig;
    NSString *routingProfileKey = [mode getRoutingProfile];
    if (routingProfileKey.length > 0)
    {
        int index = [routingProfileKey indexOf:@".xml"];
        if (index != -1)
        {
            NSString *configKey = [routingProfileKey substringToIndex:index + @".xml".length];
            if (_customRoutingConfigs.find(configKey.UTF8String) != _customRoutingConfigs.end())
                builder = _customRoutingConfigs[configKey.UTF8String];
        }
    }
    return builder;
}

- (void) loadRoutingFiles
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        const auto defaultAttributes = [self getDefaultAttributes];
        UNORDERED_map<std::string, std::shared_ptr<RoutingConfigurationBuilder>> customConfigs;
        
        NSFileManager *fileManager = NSFileManager.defaultManager;
        BOOL isDir = NO;
        NSString *routingPath = [self.documentsPath stringByAppendingPathComponent:ROUTING_PROFILES_DIR];
        BOOL exists = [fileManager fileExistsAtPath:routingPath isDirectory:&isDir];
        if (exists && isDir)
        {
            NSArray<NSString *> *files = [fileManager contentsOfDirectoryAtPath:routingPath error:nil];
            if (files != nil && files.count > 0)
            {
                for (NSString *f : files)
                {
                    NSString *fullPath = [routingPath stringByAppendingPathComponent:f];
                    [fileManager fileExistsAtPath:fullPath isDirectory:&isDir];
                    if (!isDir && [f.lastPathComponent hasSuffix:ROUTING_FILE_EXT])
                    {
                        NSString *fileName = fullPath.lastPathComponent;
                        auto builder = parseRoutingConfigurationFromXml(fullPath.UTF8String, fullPath.lastPathComponent.UTF8String);
                        if (builder)
                        {
                            for (auto it = defaultAttributes.begin(); it != defaultAttributes.end(); ++it)
                                builder->addAttribute(it->first, it->second);
                            
                            customConfigs[fileName.UTF8String] = builder;
                        }
                    }
                }
            }
        }
        _customRoutingConfigs = customConfigs;
    });
}

- (MAP_STR_STR) getDefaultAttributes
{
    MAP_STR_STR defaultAttributes;
    for (auto it = self.defaultRoutingConfig->attributes.begin(); it != self.defaultRoutingConfig->attributes.end(); ++it)
    {
        if ("routerName" != it->first)
            defaultAttributes[it->first] = it->second;
    }
    return defaultAttributes;
}

- (std::shared_ptr<GeneralRouter>) getRouter:(OAApplicationMode *)am
{
    auto builder = [OsmAndApp.instance getRoutingConfigForMode:am];
    return [self getRouter:builder mode:am];
}

- (std::shared_ptr<GeneralRouter>) getRouter:(std::shared_ptr<RoutingConfigurationBuilder> &)builder mode:(OAApplicationMode *)am
{
    auto router = builder->getRouter([am.getRoutingProfile UTF8String]);
    if (!router && am.parent)
        router = builder->getRouter([am.parent.stringKey UTF8String]);
    return router;
}

- (void) initVoiceCommandPlayer:(OAApplicationMode *)applicationMode warningNoneProvider:(BOOL)warningNoneProvider showDialog:(BOOL)showDialog force:(BOOL)force
{
    NSString *voiceProvider = [[OAAppSettings sharedManager].voiceProvider get:applicationMode];
    OAVoiceRouter *vrt = [OARoutingHelper sharedInstance].getVoiceRouter;
    [vrt setPlayer:[[OATTSCommandPlayerImpl alloc] initWithVoiceRouter:vrt voiceProvider:voiceProvider]];
}

- (void) showToastMessage:(NSString *)message
{
    // TODO toast
}

- (void) showShortToastMessage:(NSString *)message
{
    // TODO toast
}

- (void)startRepositoryUpdateAsync:(BOOL)async
{
    _isRepositoryUpdating = YES;
    
    if (async)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            
            self.resourcesManager->updateRepository();
            
            dispatch_async(dispatch_get_main_queue(), ^{
                _isRepositoryUpdating = NO;
            });
        });
    }
    else
    {
        self.resourcesManager->updateRepository();
        _isRepositoryUpdating = NO;
    }
}


- (void) checkAndDownloadOsmAndLiveUpdates
{
    if (!AFNetworkReachabilityManager.sharedManager.isReachable)
        return;

    @synchronized (self)
    {
        NSLog(@"Prepare checkAndDownloadOsmAndLiveUpdates start");
        QList<std::shared_ptr<const OsmAnd::IncrementalChangesManager::IncrementalUpdate> > updates;
        for (const auto& localResource : _resourcesManager->getLocalResources())
        {
            [OAOsmAndLiveHelper downloadUpdatesForRegion:QString(localResource->id).remove(QStringLiteral(".obf")) resourcesManager:_resourcesManager];
        }
        NSLog(@"Prepare checkAndDownloadOsmAndLiveUpdates finish");
    }
}

- (void) checkAndDownloadWeatherForecastsUpdates
{
    if (!AFNetworkReachabilityManager.sharedManager.isReachable)
        return;

    @synchronized (self)
    {
        NSLog(@"Prepare checkAndDownloadWeatherForecastsUpdates start");
        OAWeatherHelper *weatherHelper = [OAWeatherHelper sharedInstance];
        NSArray<NSString *> *regionIds = [weatherHelper getRegionIdsForDownloadedWeatherForecast];
        [weatherHelper checkAndDownloadForecastsByRegionIds:regionIds];
        NSLog(@"Prepare checkAndDownloadWeatherForecastsUpdates finish");
    }
}

- (BOOL) installTestResource:(NSString *)filePath
{
    if(_resourcesManager == nullptr)
    {
        _resourcesManager.reset(new OsmAnd::ResourcesManager(_documentsDir.absoluteFilePath(QString::fromNSString(RESOURCES_DIR)),
                                                             _documentsDir.absolutePath(),
                                                             QList<QString>() << QString::fromNSString([[NSBundle mainBundle] resourcePath]),
                                                             _worldMiniBasemapFilename != nil
                                                             ? QString::fromNSString(_worldMiniBasemapFilename)
                                                             : QString(),
                                                             QString::fromNSString(NSTemporaryDirectory()),
                                                             QString::fromNSString(_cachePath),
                                                             QString::fromNSString([[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"]),
                                                             QString::fromNSString(@"https://download.osmand.net"),
                                                             QString::fromNSString([self generateIndexesUrl]),
                                                             _webClient));
    }
    
    const auto filePathQ = QString::fromNSString(filePath);
    return _resourcesManager->addLocalResource(filePathQ);
}

- (BOOL) removeTestResource:(NSString *)filePath
{
    NSString *fileId = filePath.lastPathComponent.lowerCase;
    return _resourcesManager->uninstallResource(QString::fromNSString(fileId));
}

- (void) loadWorldRegions
{
    NSString *ocbfPathLib = [NSHomeDirectory() stringByAppendingString:@"/Documents/Resources/regions.ocbf"];
    _worldRegion = [OAWorldRegion loadFrom:ocbfPathLib];
}

- (void) applyExcludedFromBackup:(NSString *)localPath
{
    NSURL *url = [NSURL fileURLWithPath:localPath];
    
    id flag = nil;
    if ([url getResourceValue:&flag forKey:NSURLIsExcludedFromBackupKey error: nil])
    {
        OALog(@"NSURLIsExcludedFromBackupKey = %@ for %@", flag, localPath);
        if (!flag || [flag boolValue] == NO)
        {
            BOOL res = [url setResourceValue:@(YES) forKey:NSURLIsExcludedFromBackupKey error:nil];
            OALog(@"Set (%@) NSURLIsExcludedFromBackupKey for %@", (res ? @"OK" : @"FAILED"), localPath);
        }
    }
    else
    {
        OALog(@"NSURLIsExcludedFromBackupKey = %@ for %@", flag, localPath);
    }
}

- (void) shutdown
{
    [_locationServices stop];
    _locationServices = nil;

    _downloadsManager = nil;
}

- (NSDictionary*)inflateInitialUserDefaults
{
    NSMutableDictionary* initialUserDefaults = [[NSMutableDictionary alloc] init];

    [initialUserDefaults setValue:[NSKeyedArchiver archivedDataWithRootObject:[OAAppData defaults]]
                           forKey:kAppData];

    return initialUserDefaults;
}

@synthesize data = _data;
@synthesize worldRegion = _worldRegion;

@synthesize locationServices = _locationServices;
@synthesize downloadsManager = _downloadsManager;

- (OAMapMode) mapMode
{
    return _mapMode;
}

- (void) setMapMode:(OAMapMode)mapMode
{
    if (_mapMode == mapMode)
        return;
    _prevMapMode = _mapMode;
    _mapMode = mapMode;
    [[NSUserDefaults standardUserDefaults] setInteger:_mapMode forKey:kUDLastMapModePositionTrack];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [_mapModeObservable notifyEvent];
}

@synthesize mapModeObservable = _mapModeObservable;

@synthesize favoritesCollectionChangedObservable = _favoritesCollectionChangedObservable;
@synthesize favoriteChangedObservable = _favoriteChangedObservable;

@synthesize gpxCollectionChangedObservable = _gpxCollectionChangedObservable;
@synthesize gpxChangedObservable = _gpxChangedObservable;

@synthesize favoritesFilePrefix = _favoritesFilePrefix;
@synthesize favoritesGroupNameSeparator = _favoritesGroupNameSeparator;
@synthesize legacyFavoritesFilePrefix = _legacyFavoritesFilePrefix;
@synthesize favoritesLegacyStorageFilename = _favoritesLegacyFilename;
@synthesize favoritesBackupPath = _favoritesBackupPath;

- (void) saveDataToPermamentStorage
{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

    // App data
    [userDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:_data]
                                              forKey:kAppData];
    [userDefaults synchronize];
}

- (NSString *) favoritesBackupPath
{
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:_favoritesBackupPath])
        [manager createDirectoryAtPath:_favoritesBackupPath withIntermediateDirectories:NO attributes:nil error:nil];

    return _favoritesBackupPath;
}

- (NSString *) favoritesStorageFilename:(NSString *)groupName
{
    NSString *fileName = [groupName.length == 0
                          ? _favoritesFilePrefix
                          : [NSString stringWithFormat:@"%@%@%@", _favoritesFilePrefix, _favoritesGroupNameSeparator, [self getGroupFileName:groupName]] stringByAppendingString:GPX_FILE_EXT];
    return [_favoritesPath stringByAppendingPathComponent:fileName];
}

- (NSString *) getGroupFileName:(NSString *)groupName
{
    if ([groupName containsString:@"/"])
        return [groupName stringByReplacingOccurrencesOfString:@"/" withString:kSubfolderPlaceholder];

    return groupName;
}

- (NSString *) getGroupName:(NSString *)fileName
{
    if ([fileName containsString:kSubfolderPlaceholder])
        return [fileName stringByReplacingOccurrencesOfString:kSubfolderPlaceholder withString:@"/"];

    return fileName;
}

- (void) saveFavoritesToPermanentStorage
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:_favoritesPath])
        [[NSFileManager defaultManager] createDirectoryAtPath:_favoritesPath withIntermediateDirectories:NO attributes:nil error:nil];

    // Load collection from files
    auto favoritesCollection = std::make_shared<OsmAnd::FavoriteLocationsGpxCollection>();
    NSArray<NSString *> *favoritesGroupFiles = [OAFavoritesHelper getGroupFiles];
    for (NSString *groupFile in favoritesGroupFiles)
        favoritesCollection->loadFrom(QString::fromNSString(groupFile), true);

    // Get external and local groups with locations
    const auto& fileGroups = favoritesCollection->getGroupsLocations();
    const auto& localGroups = _favoritesCollection->getGroupsLocations();

    // Delete group files that are not in local groups
    for (const auto& fileGroup : fileGroups.keys())
        if (!localGroups.contains(fileGroup))
            [[NSFileManager defaultManager] removeItemAtPath:[self favoritesStorageFilename:fileGroup.toNSString()] error:nil];

    if (localGroups.isEmpty())
        return;

    // Save only groups that were changed
    for (const auto& localGroupEntry : rangeOf(localGroups))
    {
        const auto& localGroup = localGroupEntry.key();
        BOOL writeGroup = !fileGroups.contains(localGroup);
        if (!writeGroup)
        {
            const auto& fileLocations = fileGroups[localGroup];
            const auto& localLocations = localGroupEntry.value();
            if (fileLocations.size() != localLocations.size())
            {
                writeGroup = YES;
            }
            else
            {
                for (const auto& localLocation : localLocations)
                {
                    BOOL sameLocation = NO;
                    for (const auto& fileLocation : fileLocations)
                    {
                        if (fileLocation->isEqual(localLocation.get()))
                        {
                            sameLocation = YES;
                            break;
                        }
                    }
                    if (!sameLocation)
                    {
                        writeGroup = YES;
                        break;
                    }
                }
            }
        }
        if (writeGroup)
            _favoritesCollection->saveTo(QString::fromNSString([self favoritesStorageFilename:localGroup.toNSString()]), localGroup);
    }

    // Backup favorites
    [OAFavoritesHelper backup];
}

- (void) saveFavoritesToPermanentStorage:(NSArray<NSString *> *)groupNames
{
    QStringList namesList;
    for (NSString *name in groupNames)
        namesList.append(QString::fromNSString(name));

    const auto& groups = _favoritesCollection->getGroups();
    for (const auto& group : groups)
        if (namesList.contains(group))
        {
            _favoritesCollection->saveTo(QString::fromNSString([self favoritesStorageFilename:group.toNSString()]), group);
            break;
        }

    // Backup favorites
    [OAFavoritesHelper backup];
}

- (unsigned long long) freeSpaceAvailableOnDevice
{
    NSError* error = nil;
    unsigned long long deviceMemoryAvailable = 0;
    
    NSURL *home = [NSURL fileURLWithPath:NSHomeDirectory()];
    NSDictionary *results = [home resourceValuesForKeys:@[NSURLVolumeAvailableCapacityForImportantUsageKey] error:&error];
    if (results)
        deviceMemoryAvailable = [results[NSURLVolumeAvailableCapacityForImportantUsageKey] unsignedLongLongValue];
    
    if (deviceMemoryAvailable == 0)
    {
        NSDictionary* dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:_documentsPath error:&error];
        if (dictionary)
        {
            NSNumber *fileSystemFreeSizeInBytes = [dictionary objectForKey: NSFileSystemFreeSize];
            deviceMemoryAvailable = [fileSystemFreeSizeInBytes unsignedLongLongValue];
        }
    }
    return deviceMemoryAvailable;
}

- (BOOL) allowScreenTurnOff
{
    BOOL allowScreenTurnOff = NO;

    allowScreenTurnOff = allowScreenTurnOff && _downloadsManager.allowScreenTurnOff;

    return allowScreenTurnOff;
}

- (void) updateScreenTurnOffSetting
{
    BOOL allowScreenTurnOff = self.allowScreenTurnOff;

    if (allowScreenTurnOff)
        OALog(@"Going to enable screen turn-off");
    else
        OALog(@"Going to disable screen turn-off");

    dispatch_async(dispatch_get_main_queue(), ^{
        [UIApplication sharedApplication].idleTimerDisabled = !allowScreenTurnOff;
    });
}

@synthesize appearance = _appearance;
@synthesize appearanceChangeObservable = _appearanceChangeObservable;

- (void) onDownloadManagerActiveTasksCollectionChanged
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // In background, don't change screen turn-off setting
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground)
            return;
        
        [self updateScreenTurnOffSetting];
    });
}

- (void) onApplicationWillResignActive
{
}

- (void) onApplicationDidEnterBackground
{
    [self saveDataToPermamentStorage];

    // In background allow to turn off screen
    OALog(@"Going to enable screen turn-off");
    [UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (void) onApplicationWillEnterForeground
{
    [self updateScreenTurnOffSetting];
    [[OADiscountHelper instance] checkAndDisplay];
}

- (void) onApplicationDidBecomeActive
{
    [[OASavingTrackHelper sharedInstance] saveIfNeeded];
}

- (void) stopNavigation
{
    /* TODO
    if (locationProvider.getLocationSimulation().isRouteAnimating()) {
        locationProvider.getLocationSimulation().stop();
    }
     */
    
    OARoutingHelper *routingHelper = [OARoutingHelper sharedInstance];
    OATargetPointsHelper *targetPointsHelper = [OATargetPointsHelper sharedInstance];
    
    [[routingHelper getVoiceRouter] interruptRouteCommands];
    [routingHelper clearCurrentRoute:nil newIntermediatePoints:@[]];
    [routingHelper setRoutePlanningMode:false];
    OAAppSettings* settings = [OAAppSettings sharedManager];
    settings.lastRoutingApplicationMode = settings.applicationMode.get;
    [targetPointsHelper removeAllWayPoints:NO clearBackup:NO];
    dispatch_async(dispatch_get_main_queue(), ^{
        OAApplicationMode *carPlayMode = [settings.isCarPlayModeDefault get] ? OAApplicationMode.getFirstAvailableNavigationMode : [OAAppSettings.sharedManager.carPlayMode get];
        OAApplicationMode *defaultAppMode = [settings.useLastApplicationModeByDefault get] ?
            [OAApplicationMode valueOfStringKey:[settings.lastUsedApplicationMode get] def:OAApplicationMode.DEFAULT] :
            settings.defaultApplicationMode.get;
        [settings setApplicationModePref:_carPlayActive ? carPlayMode : defaultAppMode markAsLastUsed:NO];
    });
}

- (void) setupDrivingRegion:(OAWorldRegion *)reg
{
    OADrivingRegion *drg = nil;
    BOOL americanSigns = [@"american" isEqualToString:reg.regionRoadSigns];
    BOOL leftHand = [@"yes" isEqualToString:reg.regionLeftHandDriving];
    //EOAMetricsConstant::KILOMETERS_AND_METERS
    EOAMetricsConstant mc1 = [@"miles" isEqualToString:reg.regionMetric] ? EOAMetricsConstant::MILES_AND_FEET : EOAMetricsConstant::KILOMETERS_AND_METERS;
    EOAMetricsConstant mc2 = [@"miles" isEqualToString:reg.regionMetric] ? EOAMetricsConstant::MILES_AND_METERS : EOAMetricsConstant::KILOMETERS_AND_METERS;
    
    for (OADrivingRegion *r in [OADrivingRegion values])
    {
        if ([OADrivingRegion isAmericanSigns:r.region] == americanSigns && [OADrivingRegion isLeftHandDriving:r.region] == leftHand && ([OADrivingRegion getDefMetrics:r.region] == mc1 || [OADrivingRegion getDefMetrics:r.region] == mc2))
        {
            drg = r;
            break;
        }
    }
    
    if (drg)
        [[OAAppSettings sharedManager].drivingRegion set:drg.region];
}

- (NSString *) getUserIosId
{
    OAAppSettings *settings = [OAAppSettings sharedManager];
    if (![settings.sendAnonymousAppUsageData get])
        return @"";
    long lastRotation = [settings.lastUUIDChangeTimestamp get];
    BOOL needRotation = NSDate.date.timeIntervalSince1970 - lastRotation > k3MonthInSeconds;
    NSString *userIosId = needRotation ? settings.userIosId.get : @"";
    if (userIosId.length > 0)
        return userIosId;
    userIosId = [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
    [settings.userIosId set:userIosId];
    return userIosId;
}

@end
