//
//  OAFavoriteViewController.m
//  OsmAnd
//
//  Created by Alexey Kulish on 01/06/15.
//  Copyright (c) 2015 OsmAnd. All rights reserved.
//

#import "OAFavoriteViewController.h"
#import "OsmAndApp.h"
#import "OAAppData.h"
#import "OAAppSettings.h"
#import "OALog.h"
#import "OADefaultFavorite.h"
#import "OANativeUtilities.h"
#import "OAFavoritesHelper.h"
#import "OAUtilities.h"
#import "OACollapsableView.h"
#import "OACollapsableWaypointsView.h"
#import <UIAlertView+Blocks.h>
#import "OAPOI.h"
#import "OAPOIViewController.h"
#import "OAColors.h"
#import "OACollapsableCoordinatesView.h"
#import "OATextMultilineTableViewCell.h"
#import "OAPOIHelper.h"

#include <OsmAndCore.h>
#include <OsmAndCore/IFavoriteLocation.h>
#include <OsmAndCore/Utilities.h>
#include "Localization.h"

@implementation OAFavoriteViewController
{
    OsmAndAppInstance _app;
    OAPOI *_originObject;
    OAFavoriteGroup *_favoriteGroup;
    std::vector<std::shared_ptr<OpeningHoursParser::OpeningHours::Info>> _openingHoursInfo;
}

- (id) initWithItem:(OAFavoriteItem *)favorite headerOnly:(BOOL)headerOnly
{
    self = [super init];
    if (self)
    {
        _app = [OsmAndApp instance];
        _favorite = favorite;
        _favoriteGroup = [OAFavoritesHelper getGroupByName:[self.favorite getCategory]];
        _openingHoursInfo = OpeningHoursParser::getInfo(self.favorite.favorite->getExtension(QString::fromNSString([PRIVATE_PREFIX stringByAppendingString:OPENING_HOURS])).toStdString());

        if (!OAFavoritesHelper.isFavoritesLoaded)
            [OAFavoritesHelper loadFavorites];
        
        [self acquireOriginObject];
        self.topToolbarType = ETopToolbarTypeMiddleFixed;
    }
    return self;
}

- (id) initWithLocation:(CLLocationCoordinate2D)location andTitle:(NSString*)formattedLocation headerOnly:(BOOL)headerOnly
{
    self = [super init];
    if (self)
    {
        _app = [OsmAndApp instance];
        
        // Create favorite
        OsmAnd::LatLon locationPoint(location.latitude, location.longitude);
        
        QString elevation = QString();
        QString time = QString::fromNSString([OAFavoriteItem toStringDate:[NSDate date]]);
        QString pickupTime = QString::fromNSString([OAFavoriteItem toStringDate:[NSDate date]]);
        
        QString title = QString::fromNSString(formattedLocation);
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *groupName = [userDefaults objectForKey:kFavoriteDefaultGroupKey] ? [userDefaults stringForKey:kFavoriteDefaultGroupKey] : @"";
        QString group = QString::fromNSString(groupName);

        NSInteger defaultColor = [[userDefaults objectForKey:kFavoriteDefaultColorKey] integerValue];
        OAFavoriteColor *favCol = [OADefaultFavorite builtinColors][[OADefaultFavorite getValidBuiltInColorNumber:defaultColor]];
        
        UIColor* color_ = favCol.color;
        CGFloat r,g,b,a;
        [color_ getRed:&r
                 green:&g
                  blue:&b
                 alpha:&a];

        QString description = QString();
        QString address = QString();
        QString icon = QString();
        QString background = QString();

        auto favorite = _app.favoritesCollection->createFavoriteLocation(locationPoint,
                                                                        elevation,
                                                                        time,
                                                                        pickupTime,
                                                                        title,
                                                                        description,
                                                                        address,
                                                                        group,
                                                                        icon,
                                                                        background,
                                                                        OsmAnd::FColorARGB(a,r,g,b));
        
        OAFavoriteItem* fav = [[OAFavoriteItem alloc] initWithFavorite:favorite];
        _favorite = fav;
        [_app saveFavoritesToPermanentStorage:@[self.favorite.getCategory]];
        if (!OAFavoritesHelper.isFavoritesLoaded)
            [OAFavoritesHelper loadFavorites];
        
        _favoriteGroup = [OAFavoritesHelper getGroupByName:self.favorite.getCategory];
        [self acquireOriginObject];
        self.topToolbarType = ETopToolbarTypeMiddleFixed;
    }
    return self;
}

- (void) acquireOriginObject
{
    _originObject = [OAPOIHelper findPOIByOriginName:_favorite.getAmenityOriginName lat:_favorite.getLatitude lon:_favorite.getLongitude];
    if (!_originObject)
        _originObject = [_favorite getAmenity];
}

- (void) buildTopRows:(NSMutableArray<OARowInfo *> *)rows
{
    [super buildTopRows:rows];
    [self buildGroupFavouritesView:rows];
}

- (void) buildRowsInternal:(NSMutableArray<OARowInfo *> *)rows
{
    [self buildTopRows:rows];
    
    if (_favorite && [_favorite.getTimestamp timeIntervalSince1970] > 0)
    {
        [self buildDateRow:rows timestamp:[_favorite getTimestamp]];
    }
    if ( _originObject && [ _originObject isKindOfClass:OAPOI.class])
    {
        OAPOIViewController *builder = [[OAPOIViewController alloc] initWithPOI: _originObject];
        builder.location = CLLocationCoordinate2DMake([_favorite getLatitude], [_favorite getLongitude]);
        NSMutableArray<OARowInfo *> *internalRows = [NSMutableArray array];
        [builder buildRowsInternal:internalRows];
        [rows addObjectsFromArray:internalRows];
    }
    else
    {
        [self buildCoordinateRows:rows];
    }

    [self setRows:rows];
}

- (void) buildDescription:(NSMutableArray<OARowInfo *> *)rows
{
    NSString *desc = [_favorite getDescription];
    if (desc && desc.length > 0)
    {
        OARowInfo *descriptionRow = [[OARowInfo alloc] initWithKey:nil icon:nil textPrefix:OALocalizedString(@"enter_description") text:desc textColor:nil isText:NO needLinks:NO order:0 typeName:kDescriptionRowType isPhoneNumber:NO isUrl:NO];
        [rows addObject:descriptionRow];
    }
}

- (void) buildGroupFavouritesView:(NSMutableArray<OARowInfo *> *)rows
{
    OAFavoriteGroup *favoriteGroup = _favoriteGroup;
    if (favoriteGroup && favoriteGroup.points.count > 0)
    {
        UIColor *color = favoriteGroup.color ? favoriteGroup.color : [OADefaultFavorite getDefaultColor];
        UIColor *disabledColor = UIColorFromRGB(color_text_footer);
        color = favoriteGroup.isVisible ? color : disabledColor;
        UIImage *icon = [UIImage templateImageNamed:@"ic_custom_folder"];
        NSString *name = [self.favorite getCategoryDisplayName];
        NSString *description = OALocalizedString(@"context_menu_points_of_group");

        OARowInfo *rowInfo = [[OARowInfo alloc] initWithKey:nil icon:icon textPrefix:description text:name textColor:color isText:NO needLinks:NO order:1 typeName:kGroupRowType isPhoneNumber:NO isUrl:NO];
        rowInfo.collapsed = YES;
        rowInfo.collapsable = YES;
        rowInfo.height = 64;
        rowInfo.collapsableView = [self getCollapsableFavouritesView:self.favorite];

        [rows addObject:rowInfo];
    }
}

- (OACollapsableWaypointsView *) getCollapsableFavouritesView:(OAFavoriteItem *)favorite
{
    OACollapsableWaypointsView *collapsableGroupView = [[OACollapsableWaypointsView alloc] init];
    [collapsableGroupView setData:favorite];
    collapsableGroupView.collapsed = YES;
    return collapsableGroupView;
}

- (BOOL) showNearestWiki;
{
    return YES;
}

- (BOOL) showNearestPoi
{
    return YES;
}

- (NSString *)getTypeStr
{
    NSString *group = [self getItemGroup];
    if (group.length > 0)
        return group;
    else
        return [self getCommonTypeStr];
}

- (NSString *) getCommonTypeStr
{
    return OALocalizedString(@"favorites_item");
}

- (NSAttributedString *) getAttributedTypeStr
{
    return [self getAttributedTypeStr:[self getTypeStr]];
}

- (NSAttributedString *) getAttributedTypeStr:(NSString *)group
{
    NSAttributedString *attributedTypeStr = [self getAttributedTypeStr:group color:[_favoriteGroup color]];
    NSMutableAttributedString *mutAttributedTypeStr = [[NSMutableAttributedString alloc] init];
    [mutAttributedTypeStr appendAttributedString:attributedTypeStr];
    if ([self.favorite getAddress] && [self.favorite getAddress].length > 0)
    {
        NSString *address = [@"\n\n" stringByAppendingString:[self.favorite getAddress]];
        [mutAttributedTypeStr appendAttributedString:[[NSAttributedString alloc] initWithString:address]];
    }
    [mutAttributedTypeStr addAttributes:@{ NSFontAttributeName : [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline],
                                           NSForegroundColorAttributeName : UIColorFromRGB(color_dialog_text_description_color_night) }
                                  range:NSMakeRange(0, mutAttributedTypeStr.length)];
    return mutAttributedTypeStr;
}

- (UIColor *) getAdditionalInfoColor
{
    return [OANativeUtilities getOpeningHoursColor:_openingHoursInfo];
}

- (NSAttributedString *) getAdditionalInfoStr
{
    return [OANativeUtilities getOpeningHoursDescr:_openingHoursInfo];
}

- (NSString *) getItemName
{
    return [self.favorite getDisplayName];
}

- (NSString *) getItemGroup
{
    return [self.favorite getCategoryDisplayName];
}

- (NSString *) getItemDesc
{
    return [self.favorite getDescription];
}

- (UIImage *) getIcon
{
    return [self.favorite getCompositeIcon];
}

- (NSDate *) getTimestamp
{
    return [self.favorite getTimestamp];
}

@end
