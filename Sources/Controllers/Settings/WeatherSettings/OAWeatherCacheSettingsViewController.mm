//
//  OAWeatherCacheSettingsViewController.mm
//  OsmAnd
//
//  Created by Skalii on 01.07.2022.
//  Copyright (c) 2022 OsmAnd. All rights reserved.
//

#import "OAWeatherCacheSettingsViewController.h"
#import "MBProgressHUD.h"
#import "OAIconTitleValueCell.h"
#import "OATextLineViewCell.h"
#import "OATitleDescrRightIconTableViewCell.h"
#import "OsmAndApp.h"
#import "OAWeatherHelper.h"
#import "Localization.h"
#import "OAColors.h"

@interface OAWeatherCacheSettingsViewController () <UIViewControllerTransitioningDelegate, UITableViewDelegate, UITableViewDataSource>

@end

@implementation OAWeatherCacheSettingsViewController
{
    NSArray<NSDictionary *> *_data;
    NSIndexPath *_sizeIndexPath;
    NSIndexPath *_clearIndexPath;
    EOAWeatherCacheType _type;
    OAWorldRegion *_region;
    BOOL _clearButtonActive;
    MBProgressHUD *_progressHUD;
}

- (instancetype)initWithCacheType:(EOAWeatherCacheType)type
{
    self = [super initWithNibName:@"OABaseSettingsViewController" bundle:nil];
    if (self)
    {
        _type = type;
    }
    return self;
}

- (instancetype)initWithRegion:(OAWorldRegion *)region
{
    self = [super initWithNibName:@"OABaseSettingsViewController" bundle:nil];
    if (self)
    {
        _region = region;
    }
    return self;
}

- (void)applyLocalization
{
    [super applyLocalization];
    if (_region)
        self.titleLabel.text = OALocalizedString(@"shared_string_updates_size");
    else if (_type == EOAWeatherOnlineData)
        self.titleLabel.text = OALocalizedString(@"shared_string_online_cache");
    else if (_type == EOAWeatherOfflineData)
        self.titleLabel.text = OALocalizedString(@"weather_offline_forecast");
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.estimatedRowHeight = kEstimatedRowHeight;
    self.tableView.sectionHeaderHeight = 34.;
    self.tableView.sectionFooterHeight = 0.001;
    self.tableView.separatorInset = UIEdgeInsetsMake(0., 20., 0., 0.);
    [self setupView];

    _progressHUD = [[MBProgressHUD alloc] initWithView:self.view];
    [self.view addSubview:_progressHUD];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self updateCacheSize];
}

- (void)setupView
{
    NSMutableArray<NSDictionary *> *data = [NSMutableArray array];

    NSMutableArray<NSDictionary *> *infoCells = [NSMutableArray array];
    NSString *sizeString = [NSByteCountFormatter stringFromByteCount:0 countStyle:NSByteCountFormatterCountStyleFile];
    NSString *sizeTitle = @"";
    if (_region)
        sizeTitle = OALocalizedString(@"total");
    else if (_type == EOAWeatherOnlineData)
        sizeTitle = OALocalizedString(@"res_size");
    else if (_type == EOAWeatherOfflineData)
        sizeTitle = OALocalizedString(@"shared_string_total_size");
    [infoCells addObject:@{
            @"key": @"size",
            @"title": sizeTitle,
            @"value": sizeString,
            @"type": [OAIconTitleValueCell getCellIdentifier]
    }];
    [data addObject:@{ @"cells": infoCells }];
    _sizeIndexPath = [NSIndexPath indexPathForRow:infoCells.count - 1 inSection:data.count - 1];

    NSMutableArray<NSDictionary *> *clearCells = [NSMutableArray array];
    NSString *clearTitle = @"";
    if (_region)
        clearTitle = OALocalizedString(@"shared_string_delete");
    else if (_type == EOAWeatherOnlineData)
        clearTitle = OALocalizedString(@"poi_clear");
    else if (_type == EOAWeatherOfflineData)
        clearTitle = OALocalizedString(@"shared_string_delete_all");
    [_type == EOAWeatherOnlineData ? clearCells : infoCells addObject:@{
            @"key": @"clear",
            @"title": clearTitle,
            @"type": [OATextLineViewCell getCellIdentifier]
    }];

    if (clearCells.count > 0)
        [data addObject:@{ @"cells": clearCells }];

    _clearIndexPath = [NSIndexPath indexPathForRow:(clearCells.count > 0 ? clearCells.count : infoCells.count) - 1 inSection:data.count - 1];

    _data = data;
}

- (NSDictionary *)getItem:(NSIndexPath *)indexPath
{
    return _data[indexPath.section][@"cells"][indexPath.row];
}

- (void)updateCacheSize
{
    if (_region)
    {
        [[OAWeatherHelper sharedInstance] calculateCacheSize:_region onComplete:^() {
            if (_sizeIndexPath)
            {
                uint64_t size = [[OAWeatherHelper sharedInstance] getOfflineForecastSizeInfo:_region.regionId local:YES];
                NSMutableArray<NSDictionary *> *cells = _data[_sizeIndexPath.section][@"cells"];
                NSString *sizeString = [NSByteCountFormatter stringFromByteCount:size
                                                                      countStyle:NSByteCountFormatterCountStyleFile];
                cells[_sizeIndexPath.row] = @{
                        @"key": @"size",
                        @"title": OALocalizedString(@"total"),
                        @"value": sizeString,
                        @"type": [OAIconTitleValueCell getCellIdentifier]
                };
                _clearButtonActive = size > 0;

                [self.tableView reloadRowsAtIndexPaths:@[_sizeIndexPath, _clearIndexPath]
                                      withRowAnimation:UITableViewRowAnimationNone];
            }
        }];
    }
    else
    {
        [[OAWeatherHelper sharedInstance] calculateFullCacheSize:_type == EOAWeatherOfflineData onComplete:^(unsigned long long size)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (_sizeIndexPath)
                {
                    NSMutableArray<NSDictionary *> *cells = _data[_sizeIndexPath.section][@"cells"];
                    NSString *sizeString = [NSByteCountFormatter stringFromByteCount:size countStyle:NSByteCountFormatterCountStyleFile];
                    cells[_sizeIndexPath.row] = @{
                            @"key": @"size",
                            @"title": OALocalizedString(_type == EOAWeatherOnlineData ? @"res_size" : @"shared_string_total_size"),
                            @"value": sizeString,
                            @"type": [OAIconTitleValueCell getCellIdentifier]
                    };
                    _clearButtonActive = size > 0;

                    [self.tableView reloadRowsAtIndexPaths:@[_sizeIndexPath, _clearIndexPath]
                                          withRowAnimation:UITableViewRowAnimationNone];
                }
            });
        }];
    }
}

- (void)clearCache
{
    [_progressHUD showAnimated:YES whileExecutingBlock:^{
        if (_region)
            [[OAWeatherHelper sharedInstance] clearCache:YES regionIds:@[_region.regionId]];
        else
            [[OAWeatherHelper sharedInstance] clearCache:_type == EOAWeatherOfflineData regionIds:nil];
    } completionBlock:^{
        [self dismissViewController];
        if (self.cacheDelegate)
            [self.cacheDelegate onCacheClear];
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _data.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return ((NSArray *) _data[section][@"cells"]).count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self getItem:indexPath];
    UITableViewCell *outCell = nil;

    if ([item[@"type"] isEqualToString:[OAIconTitleValueCell getCellIdentifier]])
    {
        OAIconTitleValueCell *cell = [tableView dequeueReusableCellWithIdentifier:[OAIconTitleValueCell getCellIdentifier]];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OAIconTitleValueCell getCellIdentifier] owner:self options:nil];
            cell = (OAIconTitleValueCell *) nib[0];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            [cell showLeftIcon:NO];
            [cell showRightIcon:NO];
            cell.textView.font = [UIFont systemFontOfSize:17.];
        }
        if (cell)
        {
            cell.textView.text = item[@"title"];
            cell.descriptionView.text = item[@"value"];
        }
        outCell = cell;
    }
    else if ([item[@"type"] isEqualToString:[OATextLineViewCell getCellIdentifier]])
    {
        OATextLineViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[OATextLineViewCell getCellIdentifier]];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OATextLineViewCell getCellIdentifier] owner:self options:nil];
            cell = (OATextLineViewCell *) nib[0];
            cell.textView.font = [UIFont systemFontOfSize:17. weight:UIFontWeightMedium];
            cell.textView.textColor = UIColorFromRGB(color_primary_red);
        }
        if (cell)
        {
            if ([item[@"key"] isEqualToString:@"clear"])
            {
                cell.selectionStyle = _clearButtonActive ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
                cell.textView.textColor = _clearButtonActive ? UIColorFromRGB(color_primary_red) : UIColorFromRGB(color_text_footer);
            }
            else
            {
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                cell.textView.textColor = UIColor.blackColor;
            }
            cell.textView.text = item[@"title"];
            cell.textView.textAlignment = _type == EOAWeatherOnlineData ? NSTextAlignmentCenter : NSTextAlignmentNatural;
        }
        outCell = cell;
    }
    else if ([item[@"type"] isEqualToString:[OATitleDescrRightIconTableViewCell getCellIdentifier]])
    {
        OATitleDescrRightIconTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[OATitleDescrRightIconTableViewCell getCellIdentifier]];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OATitleDescrRightIconTableViewCell getCellIdentifier] owner:self options:nil];
            cell = (OATitleDescrRightIconTableViewCell *) nib[0];
            cell.iconView.tintColor = UIColorFromRGB(color_primary_red);
        }
        if (cell)
        {
            cell.titleLabel.text = item[@"title"];
            cell.descriptionLabel.text = item[@"description"];
            cell.iconView.image = [UIImage templateImageNamed:@"icon_remove"];
        }
        outCell = cell;
    }

    if ([outCell needsUpdateConstraints])
        [outCell updateConstraints];

    return outCell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self getItem:indexPath];
    if ([item[@"key"] isEqualToString:@"clear"] && _clearButtonActive)
    {
        NSString *title = @"";
        NSString *message = @"";
        if (_region)
        {
            title = OALocalizedString(@"shared_string_clear_offline_cache");
            message = [NSString stringWithFormat:OALocalizedString(@"weather_clear_offline_cache_for"), _region.name];
        }
        else if (_type == EOAWeatherOnlineData)
        {
            title = OALocalizedString(@"shared_string_clear_online_cache");
            message = OALocalizedString(@"weather_clear_online_cache");
        }
        else if (_type == EOAWeatherOfflineData)
        {
            title = OALocalizedString(@"shared_string_clear_offline_cache");
            message = OALocalizedString(@"weather_clear_offline_cache");
        }

        UIAlertController *alert =
                [UIAlertController alertControllerWithTitle:title
                                                    message:message
                                             preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:OALocalizedString(@"shared_string_cancel")
                                                               style:UIAlertActionStyleDefault
                                                             handler:nil];

        UIAlertAction *clearCacheAction = [UIAlertAction actionWithTitle:OALocalizedString(@"poi_clear")
                                                                   style:UIAlertActionStyleDefault
                                                                 handler:^(UIAlertAction * _Nonnull action)
                                                                 {
                                                                     [self clearCache];
                                                                 }
        ];

        [alert addAction:cancelAction];
        [alert addAction:clearCacheAction];

        alert.preferredAction = clearCacheAction;

        [self presentViewController:alert animated:YES completion:nil];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end