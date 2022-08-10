//
//  OAWeatherToolbarHandlers.mm
//  OsmAnd
//
//  Created by Skalii on 17.06.2022.
//  Copyright (c) 2022 OsmAnd. All rights reserved.
//

#import "OAWeatherToolbarHandlers.h"
#import "OAMapStyleSettings.h"
#import "OsmAndApp.h"
#import "Localization.h"

#define kTempIndex 0
#define kPressureIndex 1
#define kWindIndex 2
#define kCloudIndex 3
#define kPrecipitationIndex 4
#define kContoursIndex 5

@implementation OAWeatherToolbarLayersHandler
{
    OAMapStyleSettings *_styleSettings;
    OsmAndAppInstance _app;

    NSMutableArray<NSMutableDictionary *> *_data;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    _styleSettings = [OAMapStyleSettings sharedInstance];
    _app = [OsmAndApp instance];

    [self updateData];
}

- (void)updateData
{
    NSMutableArray<NSMutableDictionary *> *layersData = [NSMutableArray array];
    [layersData addObject:[NSMutableDictionary dictionaryWithDictionary:@{
            @"img": @"ic_custom_thermometer",
            @"selected": @(_app.data.weatherTemp)
    }]];
    [layersData addObject:[NSMutableDictionary dictionaryWithDictionary:@{
            @"img": @"ic_custom_air_pressure",
            @"selected": @(_app.data.weatherPressure)
    }]];
    [layersData addObject:[NSMutableDictionary dictionaryWithDictionary:@{
            @"img": @"ic_custom_wind",
            @"selected": @(_app.data.weatherWind)
    }]];
    [layersData addObject:[NSMutableDictionary dictionaryWithDictionary:@{
            @"img": @"ic_custom_clouds",
            @"selected": @(_app.data.weatherCloud)
    }]];
    [layersData addObject:[NSMutableDictionary dictionaryWithDictionary:@{
            @"img": @"ic_custom_precipitation",
            @"selected": @(_app.data.weatherPrecip)
    }]];
    [layersData addObject:[NSMutableDictionary dictionaryWithDictionary:@{
            @"img": @"ic_custom_contour_lines",
            @"selected": @([[_styleSettings getParameter:WEATHER_TEMP_CONTOUR_LINES_ATTR].value isEqualToString:@"true"]
                    || [[_styleSettings getParameter:WEATHER_PRESSURE_CONTOURS_LINES_ATTR].value isEqualToString:@"true"])
    }]];

    _data = layersData;
}

- (NSArray *)getData
{
    return _data;
}

#pragma mark - OAFoldersCellDelegate

- (void)onItemSelected:(NSInteger)index
{
    if (index == kTempIndex)
    {
        BOOL selected = !_app.data.weatherTemp;
        _data[kTempIndex][@"selected"] = @(selected);
        _app.data.weatherTemp = selected;
    }
    else if (index == kPressureIndex)
    {
        BOOL selected = !_app.data.weatherPressure;
        _data[kPressureIndex][@"selected"] = @(selected);
        _app.data.weatherPressure = selected;
    }
    else if (index == kWindIndex)
    {
        BOOL selected = !_app.data.weatherWind;
        _data[kWindIndex][@"selected"] = @(selected);
        _app.data.weatherWind = selected;
    }
    else if (index == kCloudIndex)
    {
        BOOL selected = !_app.data.weatherCloud;
        _data[kCloudIndex][@"selected"] = @(selected);
        _app.data.weatherCloud = selected;
    }
    else if (index == kPrecipitationIndex)
    {
        BOOL selected = !_app.data.weatherPrecip;
        _data[kPrecipitationIndex][@"selected"] = @(selected);
        _app.data.weatherPrecip = selected;
    }
    else if (index == kContoursIndex)
    {
        BOOL selected = !([[_styleSettings getParameter:WEATHER_TEMP_CONTOUR_LINES_ATTR].value isEqualToString:@"true"]
                || [[_styleSettings getParameter:WEATHER_PRESSURE_CONTOURS_LINES_ATTR].value isEqualToString:@"true"]);
        _data[kContoursIndex][@"selected"] = @(selected);
        [OAMapStyleSettings weatherContoursParamChangedToValue:selected ? WEATHER_TEMP_CONTOUR_LINES_ATTR : WEATHER_NONE_CONTOURS_LINES_VALUE
                                                 styleSettings:_styleSettings];
    }

    if (self.delegate)
        [self.delegate updateData:_data type:EOAWeatherToolbarLayers];
}

@end

@implementation OAWeatherToolbarDatesHandler
{
    NSMutableArray<NSMutableDictionary *> *_data;
}

- (instancetype)initWithAvailable:(BOOL)available date:(NSDate *)date
{
    self = [super init];
    if (self)
    {
        [self commonInit:available date:date];
    }
    return self;
}

- (void)commonInit:(BOOL)available date:(NSDate *)date
{
    [self updateData:available date:date];
}

- (void)updateData:(BOOL)available date:(NSDate *)date
{
    NSCalendar *calendar = NSCalendar.autoupdatingCurrentCalendar;
    calendar.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
    NSDate *selectedDate = [calendar startOfDayForDate:date];

    NSMutableArray<NSMutableDictionary *> *layersData = [NSMutableArray array];
    [layersData addObject:[NSMutableDictionary dictionaryWithDictionary:@{
            @"title": OALocalizedString(@"today"),
            @"available": @(available),
            @"value": selectedDate
    }]];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.timeZone = calendar.timeZone;
    [formatter setDateFormat:@"dd.MM"];
    for (NSInteger i = 1; i <= 6; i++)
    {
        selectedDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:selectedDate options:0];
        [layersData addObject:[NSMutableDictionary dictionaryWithDictionary:@{
                @"title": [formatter stringFromDate:selectedDate],
                @"available": @(available),
                @"value": selectedDate
        }]];
    }

    _data = layersData;
}

- (NSArray<NSMutableDictionary *> *)getData
{
    return _data;
}

#pragma mark - OAFoldersCellDelegate

- (void)onItemSelected:(NSInteger)index
{
    if (self.delegate)
        [self.delegate updateData:_data type:EOAWeatherToolbarDates];
}

@end
