//
//  OATripRecordingElevationWidget.m
//  OsmAnd Maps
//
//  Created by nnngrach on 04.04.2023.
//  Copyright © 2023 OsmAnd. All rights reserved.
//

#import "OATripRecordingElevationWidget.h"
#import "OASavingTrackHelper.h"
#import "OAOsmAndFormatter.h"
#import "OsmAndApp.h"
#import "OAAppSettings.h"
#import "Localization.h"
#import "OAGPXDatabase.h"
#import "OAGPXMutableDocument.h"
#import "OAGPXTrackAnalysis.h"
#import "OARootViewController.h"
#import "OATrackMenuHudViewController.h"
#import "OsmAnd_Maps-Swift.h"

@implementation OATripRecordingElevationWidget
{
    int _currentTrackIndex;
}

- (instancetype) initWithType:(OAWidgetType *)type
{
    self = [super initWithType:type];
    if (self)
    {
        __weak OATextInfoWidget *weakSelf = self;
        double __block cachedElevationDiff = -1;
        
        self.updateInfoFunction = ^BOOL {
            int currentTrackIndex = OASavingTrackHelper.sharedInstance.currentTrackIndex;
            double elevationDiff = [((OATripRecordingElevationWidget *)weakSelf) getElevationDiff:_currentTrackIndex != currentTrackIndex];
            _currentTrackIndex = currentTrackIndex;
            if (cachedElevationDiff != elevationDiff)
            {
                cachedElevationDiff = elevationDiff;
                EOAMetricsConstant metricsConstants = [[OAAppSettings sharedManager].metricSystem get];
                NSString *formattedUphill = [OAOsmAndFormatter getFormattedAlt:elevationDiff mc:metricsConstants];
                [weakSelf setText:formattedUphill subtext:nil];
            }
            return YES;
        };
        
        self.onClickFunction = ^(id sender) {
            OAGPXTrackAnalysis *analysis = [[[OASavingTrackHelper sharedInstance] currentTrack] getAnalysis:0];
            if (analysis.hasElevationData)
            {
                OAGPX *gpxFile = [[OASavingTrackHelper sharedInstance] getCurrentGPX];
                [[OARootViewController instance].mapPanel openTargetViewWithGPX:gpxFile selectedTab:EOATrackMenuHudSegmentsTab selectedStatisticsTab:EOATrackMenuHudSegmentsStatisticsAlititudeTab openedFromMap:YES];
            }
        };
        
        [self updateInfo];
    }
    return self;
}

//Override
- (double) getElevationDiff:(BOOL)reset
{
    return -1;
}

//Override
+ (NSString *) getName
{
    return @"";
}

@end


@implementation OATripRecordingUphillWidget
{
    double _diffElevationUp;
}

- (instancetype) init
{
    self = [super initWithType:OAWidgetType.tripRecordingUphill];
    if (self)
    {
        _diffElevationUp = 0.0;
        [self setIcons:@"widget_track_recording_uphill_day" widgetNightIcon:@"widget_track_recording_uphill_night"];
    }
    return self;
}

- (double) getElevationDiff:(BOOL)reset
{
    if (reset)
        _diffElevationUp = 0.0;

    OAGPXTrackAnalysis *analysis = [[[OASavingTrackHelper sharedInstance] currentTrack] getAnalysis:0];
    _diffElevationUp = MAX(analysis.diffElevationUp, _diffElevationUp);
    return _diffElevationUp;
}

+ (NSString *) getName
{
    return [NSString stringWithFormat:@"%@ - %@", OALocalizedString(@"record_plugin_name"), OALocalizedString(@"map_widget_trip_recording_uphill")];
}

@end


@implementation OATripRecordingDownhillWidget
{
    double _diffElevationDown;
}

- (instancetype) init
{
    self = [super initWithType:OAWidgetType.tripRecordingDownhill];
    if (self)
    {
        _diffElevationDown = 0.0;
        [self setIcons:@"widget_track_recording_downhill_day" widgetNightIcon:@"widget_track_recording_downhill_night"];
    }
    return self;
}

- (double) getElevationDiff:(BOOL)reset
{
    if (reset)
        _diffElevationDown = 0.0;

    OAGPXTrackAnalysis *analysis = [[[OASavingTrackHelper sharedInstance] currentTrack] getAnalysis:0];
    _diffElevationDown = MAX(analysis.diffElevationDown, _diffElevationDown);
    return _diffElevationDown;
}

+ (NSString *) getName
{
    return [NSString stringWithFormat:@"%@ - %@", OALocalizedString(@"record_plugin_name"), OALocalizedString(@"map_widget_trip_recording_downhill")];
}

@end
