//
//  OATrackMenuHeaderView.mm
//  OsmAnd
//
//  Created by Skalii on 15.09.2021.
//  Copyright (c) 2021 OsmAnd. All rights reserved.
//

#import "OATrackMenuHeaderView.h"
#import "OARootViewController.h"
#import "OARouteDetailsGraphViewController.h"
#import "OAGpxStatBlockCollectionViewCell.h"
#import "OAColors.h"

@implementation OATrackMenuHeaderView

- (instancetype)init
{
    NSArray *bundle = [[NSBundle mainBundle] loadNibNamed:NSStringFromClass([self class]) owner:nil options:nil];
    if ([bundle count])
    {
        self = [bundle firstObject];
        if (self)
        {
            [self commonInit];
        }
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    NSArray *bundle = [[NSBundle mainBundle] loadNibNamed:NSStringFromClass([self class]) owner:nil options:nil];
    if ([bundle count])
    {
        self = [bundle firstObject];
        if (self)
        {
            self.frame = frame;
            [self commonInit];
        }
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];

    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    [self.collectionView registerNib:[UINib nibWithNibName:[OAGpxStatBlockCollectionViewCell getCellIdentifier] bundle:nil] forCellWithReuseIdentifier:[OAGpxStatBlockCollectionViewCell getCellIdentifier]];
    ((UICollectionViewFlowLayout *) self.collectionView.collectionViewLayout).minimumInteritemSpacing = 12.;
}

- (void)commonInit
{

}

- (void)updateConstraints
{
    BOOL hasDescription = !self.descriptionView.hidden;
    BOOL hasCollection = !self.collectionView.hidden;
    BOOL isOnlyTitleAndDescription = hasDescription && !hasCollection && self.collectionView.hidden
            && self.locationContainerView.hidden && self.actionButtonsContainerView.hidden;

    self.onlyTitleAndDescriptionConstraint.active = isOnlyTitleAndDescription;

    self.titleBottomDescriptionConstraint.active = hasDescription;
    self.titleBottomNoDescriptionConstraint.active = !hasDescription;

    self.descriptionBottomCollectionConstraint.active = hasCollection;
    self.descriptionBottomNoCollectionConstraint.active = !hasCollection;

    [super updateConstraints];
}

- (BOOL)needsUpdateConstraints
{
    BOOL res = [super needsUpdateConstraints];
    if (!res)
    {
        BOOL hasDescription = !self.descriptionView.hidden;
        BOOL hasCollection = !self.collectionView.hidden;
        BOOL isOnlyTitleAndDescription = hasDescription && !hasCollection && self.collectionView.hidden
                && self.locationContainerView.hidden && self.actionButtonsContainerView.hidden;

        res = res || self.onlyTitleAndDescriptionConstraint.active != isOnlyTitleAndDescription;

        res = res || self.titleBottomDescriptionConstraint.active != hasDescription;
        res = res || self.titleBottomNoDescriptionConstraint.active != !hasDescription;

        res = res || self.descriptionBottomCollectionConstraint.active != hasCollection;
        res = res || self.descriptionBottomNoCollectionConstraint.active != !hasCollection;
    }
    return res;
}

- (void)setDescription:(NSString *)description
{
    BOOL hasDescription = description && description.length > 0;
    [self.descriptionView setText:description];
    self.descriptionView.hidden = !hasDescription;
}

- (void)setCollection:(NSArray *)data
{
    BOOL hasData = data && data.count > 0;

    self.collectionData = data;
    [self.collectionView reloadData];
    self.collectionView.hidden = !hasData;
}

- (void)makeOnlyHeaderAndDescription
{
    self.collectionView.hidden = YES;
    self.locationContainerView.hidden = YES;
    self.actionButtonsContainerView.hidden = YES;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger) collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.collectionData.count;
}

- (UICollectionViewCell *) collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = self.collectionData[indexPath.row];
    OAGpxStatBlockCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[OAGpxStatBlockCollectionViewCell getCellIdentifier] forIndexPath:indexPath];
    if (cell == nil)
    {
        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OAGpxStatBlockCollectionViewCell getCellIdentifier] owner:self options:nil];
        cell = nib[0];
    }
    if (cell)
    {
        [cell.valueView setText:item[@"value"]];
        cell.iconView.image = [UIImage templateImageNamed:item[@"icon"]];
        cell.iconView.tintColor = UIColorFromRGB(color_icon_inactive);
        [cell.titleView setText:item[@"title"]];

        cell.separatorView.hidden = indexPath.row == [self collectionView:collectionView numberOfItemsInSection:indexPath.section] - 1;

        if ([cell needsUpdateConstraints])
            [cell updateConstraints];
    }

    return cell;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = _collectionData[indexPath.row];
    return [self getSizeForItem:item[@"title"] value:item[@"value"]];
}

- (CGSize)getSizeForItem:(NSString *)title value:(NSString *)value
{
    CGSize sizeByTitle = [OAUtilities calculateTextBounds:title width:120. height:40. font:[UIFont systemFontOfSize:13. weight:UIFontWeightRegular]];
    CGSize sizeByValue = [OAUtilities calculateTextBounds:value width:100. height:40. font:[UIFont systemFontOfSize:13. weight:UIFontWeightMedium]];
    CGFloat widthByTitle = (sizeByTitle.width < 60. ? 60. : sizeByTitle.width > 120. ? 120. : sizeByTitle.width) + 13.;
    CGFloat widthByValue = (sizeByValue.width < 40. ? 40. : sizeByValue.width > 100. ? 100. : sizeByValue.width) + 20. + 13.;
    return CGSizeMake(MAX(widthByTitle, widthByValue), 40.);
}

#pragma mark - UICollectionViewDelegate

- (void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = _collectionData[indexPath.row];
    EOARouteStatisticsMode modeType = (EOARouteStatisticsMode) [item[@"type"] integerValue];
    if (self.delegate && [self.delegate respondsToSelector:@selector(openAnalysis:)])
        [self.delegate openAnalysis:modeType];
}

@end
