//
//  OAPluginDetailsViewController.m
//  OsmAnd
//
//  Created by Alexey Kulish on 22/07/15.
//  Copyright (c) 2015 OsmAnd. All rights reserved.
//

#import "OAPluginDetailsViewController.h"
#import "OAUtilities.h"
#import "OAIAPHelper.h"
#import "Localization.h"
#import "OAPluginPopupViewController.h"
#import "OAPurchasesViewController.h"
#import <AFNetworking/AFNetworkReachabilityManager.h>
#import "OASizes.h"
#import "OARootViewController.h"
#import "OAChoosePlanHelper.h"
#import "OAPlugin.h"
#import "OAColors.h"
#import "OAOsmandDevelopmentViewController.h"
#import "OATripRecordingSettingsViewController.h"
#import "OAOsmEditingSettingsViewController.h"
#import "OAWeatherSettingsViewController.h"
#import "OAWikipediaSettingsViewController.h"
#import <SafariServices/SafariServices.h>

#define kPriceButtonTextInset 8.0
#define kPriceButtonMinTextWidth 80.0
#define kPriceButtonMinTextHeight 40.0
#define kPriceButtonRectBorder 15.0

typedef NS_ENUM(NSInteger, EOAPluginScreenType) {
    EOAPluginScreenTypeProduct = 0,
    EOAPluginScreenTypeCustomPlugin
};

@interface OAPluginDetailsViewController () <UITextViewDelegate, SFSafariViewControllerDelegate>

@end

@implementation OAPluginDetailsViewController
{
    OAIAPHelper *_iapHelper;
    OAPlugin *_plugin;
    EOAPluginScreenType _screenType;
    UIViewController *_settingsViewController;

    CALayer *_horizontalLineDesc;
}

#pragma mark - Initialization

- (instancetype) initWithProduct:(OAProduct *)product
{
    self = [super initWithNibName:@"OAPluginDetailsViewController" bundle:nil];
    if (self)
    {
        _product = product;
        _screenType = EOAPluginScreenTypeProduct;
        _settingsViewController = [self getSettingsViewController];
        [self commonInit];
    }
    return self;
}

- (instancetype) initWithCustomPlugin:(OAPlugin *)plugin
{
    self = [super initWithNibName:@"OAPluginDetailsViewController" bundle:nil];
    if (self)
    {
        _plugin = plugin;
        _screenType = EOAPluginScreenTypeCustomPlugin;
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    _iapHelper = [OAIAPHelper sharedInstance];
}

- (void)registerNotifications
{
    [self addNotification:OAIAPProductPurchasedNotification selector:@selector(productPurchased:)];
    [self addNotification:OAIAPProductsRequestSucceedNotification selector:@selector(productsRequested:)];
}

#pragma mark - Base UI

- (NSString *)getTitle
{
    return _plugin ? _plugin.getName : _product ? _product.localizedTitle : @"";
}

- (EOABaseNavbarColorScheme)getNavbarColorScheme;
{
    return EOABaseNavbarColorSchemeOrange;
}

- (NSArray<UIBarButtonItem *> *)getRightNavbarButtons
{
    if (_settingsViewController == nil)
    {
        return nil;
    }
    else
    {
        return @[[self createRightNavbarButton:nil
                                      iconName:@"ic_navbar_settings"
                                        action:@selector(onRightNavbarButtonPressed)
                                          menu:nil]];
    }
}

#pragma mark - UIViewController

- (void) viewDidLoad
{
    [super viewDidLoad];

    _horizontalLineDesc = [CALayer layer];
    _horizontalLineDesc.backgroundColor = [UIColorFromRGB(kBottomToolbarTopLineColor) CGColor];
    [self.detailsView.layer addSublayer:_horizontalLineDesc];
    
    self.priceButton.layer.cornerRadius = 4;
    self.priceButton.layer.masksToBounds = YES;
    
    self.buttonDeleteCustomPlugin.hidden = _screenType != EOAPluginScreenTypeCustomPlugin;
    self.buttonDeleteCustomPlugin.userInteractionEnabled = !self.buttonDeleteCustomPlugin.hidden;

    self.descTextView.delegate = self;
    self.descLabel.text = OALocalizedStringUp(@"shared_string_description");
    self.descLabel.font = [UIFont scaledSystemFontOfSize:13. weight:UIFontWeightSemibold];

    UIImage *screenshotImage;
    if (_screenType == EOAPluginScreenTypeProduct)
    {
        NSString *screenshotName = [_product productScreenshotName];
        if (screenshotName)
            screenshotImage = [UIImage imageNamed:screenshotName];
    }
    else if (_screenType == EOAPluginScreenTypeCustomPlugin)
    {
        screenshotImage = _plugin.getAssetResourceImage;
    }
    self.screenshot.image = screenshotImage;
    
    UIImage *logo;
    if (_screenType == EOAPluginScreenTypeProduct)
    {
        NSString *iconName = [_product productIconName];
        if (iconName)
        {
            logo = [UIImage templateImageNamed:iconName];
            self.icon.tintColor = UIColorFromRGB(plugin_icon_green);
        }
        self.icon.contentMode = UIViewContentModeCenter;
    }
    else if (_screenType == EOAPluginScreenTypeCustomPlugin)
    {
        logo = [_plugin getLogoResource];
        self.icon.contentMode = UIViewContentModeScaleAspectFit;
    }
    self.icon.image = logo;
    
    [self updatePurchaseButton];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [[OARootViewController instance] requestProductsWithProgress:YES reload:NO];
}

- (void) viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    CGFloat w;
    
    CGFloat navbarHeight = self.navigationController.navigationBar.frame.origin.y + self.navigationController.navigationBar.frame.size.height;
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
    {
        w = DeviceScreenWidth;
        _screenshot.frame = CGRectMake(0.0, navbarHeight, w, 220.0);
        
        _detailsView.frame = CGRectMake(0.0, navbarHeight + _screenshot.frame.size.height, w, DeviceScreenHeight - _screenshot.frame.size.height - navbarHeight);
    }
    else
    {
        w = DeviceScreenWidth / 2.0;
        
        _screenshot.frame = CGRectMake(0.0, navbarHeight, w, DeviceScreenHeight - navbarHeight);
        
        _detailsView.frame = CGRectMake(w, navbarHeight, DeviceScreenWidth - w, DeviceScreenHeight - navbarHeight);
        
    }

    _priceButton.frame = CGRectMake(_detailsView.frame.size.width - _priceButton.frame.size.width - 15.0, 15.0, _priceButton.frame.size.width, _priceButton.frame.size.height);

    _buttonDeleteCustomPlugin.frame = CGRectMake(CGRectGetMinX(_priceButton.frame) - 16. - 30., CGRectGetMinY(_priceButton.frame) + 5.0, 30., 30.);

    _descLabel.frame = CGRectMake(15.0, 85.0, w - 30.0, _descLabel.frame.size.height);
    _descTextView.frame = CGRectMake(10.0, 105.0, w - 20.0, _detailsView.frame.size.height - 105.0);

    _horizontalLineDesc.frame = CGRectMake(15.0, 70.0, _detailsView.frame.size.width - 30.0, 0.5);
}

- (void) updatePurchaseButton
{
    NSString *desc = nil;
    NSAttributedString *attrDesc = nil;
    NSString *price;
    
    if (_screenType == EOAPluginScreenTypeProduct)
    {
        desc = _product.localizedDescriptionExt;
        if (!_product.free)
            price = [OALocalizedString(@"buy") uppercaseStringWithLocale:[NSLocale currentLocale]];
    }
    else if (_screenType == EOAPluginScreenTypeCustomPlugin)
    {
        attrDesc = [OAUtilities attributedStringFromHtmlString:_plugin.getDescription fontSize:17];
    }

    [self applyLocalization];

    if (desc)
    {
        self.descTextView.text = desc;
    }
    else if (attrDesc)
    {
        self.descTextView.attributedText = attrDesc;
        self.descTextView.linkTextAttributes = @{NSForegroundColorAttributeName: UIColorFromRGB(color_primary_purple)};
    }
    
    BOOL purchased = NO;
    BOOL disabled = YES;
    
    if (_screenType == EOAPluginScreenTypeProduct)
    {
        purchased = [_product isPurchased];
        disabled = _product.disabled;
    }
    else if (_screenType == EOAPluginScreenTypeCustomPlugin)
    {
        purchased = YES;
        disabled = ![_plugin isEnabled];
    }
    
    if (purchased)
    {
        [self.priceButton setTitle:@"" forState:UIControlStateNormal];
        if (!disabled)
        {
            self.priceButton.layer.borderWidth = 0.0;
            self.priceButton.backgroundColor = UIColorFromRGB(0xff8f00);
            self.priceButton.tintColor = [UIColor whiteColor];
            [self.priceButton setImage:[UIImage imageNamed:@"ic_checkmark_big_enable"] forState:UIControlStateNormal];
        }
        else
        {
            self.priceButton.layer.borderWidth = 0.8;
            self.priceButton.layer.borderColor = UIColorFromRGB(0xff8f00).CGColor;
            self.priceButton.backgroundColor = [UIColor clearColor];
            self.priceButton.tintColor = UIColorFromRGB(0xff8f00);
            [self.priceButton setImage:[UIImage imageNamed:@"ic_checkmark_big_enable"] forState:UIControlStateNormal];
        }
    }
    else
    {
        self.priceButton.layer.borderWidth = 0.0;
        self.priceButton.backgroundColor = UIColorFromRGB(0xff8f00);
        self.priceButton.tintColor = [UIColor whiteColor];
        [self.priceButton setTitle:price forState:UIControlStateNormal];
    }
    
    [self.priceButton sizeToFit];
    CGSize priceSize = CGSizeMake(MAX(kPriceButtonMinTextWidth, self.priceButton.bounds.size.width + (!purchased ? kPriceButtonTextInset * 2.0 : 0.0)), kPriceButtonMinTextHeight);
    CGRect priceFrame = self.priceButton.frame;
    priceFrame.origin = CGPointMake(_detailsView.frame.size.width - priceSize.width - kPriceButtonRectBorder, 15.0);
    priceFrame.size = priceSize;
    self.priceButton.frame = priceFrame;
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange interaction:(UITextItemInteraction)interaction
{
    SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:URL];
    [self presentViewController:safariViewController animated:YES completion:nil];
    return NO;
}

#pragma mark - SFSafariViewControllerDelegate

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller
{
    [controller dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Selectors

- (void)onRightNavbarButtonPressed
{
    if (_settingsViewController)
        [self showViewController:_settingsViewController];
}

- (void)productPurchased:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updatePurchaseButton];
        [OAPluginPopupViewController showProductAlert:_product afterPurchase:YES];
    });
}

- (void)productsRequested:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updatePurchaseButton];
    });
}

- (IBAction)deleteButtonClicked:(id)sender
{
    [OAPlugin removeCustomPlugin:(OACustomPlugin *)_plugin];
    if (self.delegate)
        [self.delegate onCustomPluginDeleted];
    [self dismissViewController];
}

- (IBAction)priceButtonClicked:(id)sender
{
    if (_screenType == EOAPluginScreenTypeProduct)
    {
        BOOL purchased = [_product isPurchased];
        BOOL disabled = _product.disabled;
        if (purchased)
        {
            if (disabled)
            {
                [_iapHelper enableProduct:_product.productIdentifier];
                [OAPluginPopupViewController showProductAlert:_product afterPurchase:NO];
            }
            else
            {
                [_iapHelper disableProduct:_product.productIdentifier];
            }
            [self updatePurchaseButton];
            
            return;
        }
        
    //    [[OARootViewController instance] buyProduct:_product showProgress:YES];
        [OAChoosePlanHelper showChoosePlanScreenWithProduct:_product navController:self.navigationController];
    }
    else
    {
        [OAPlugin enablePlugin:_plugin enable:![_plugin isEnabled]];
        [self updatePurchaseButton];
    }
}

#pragma mark - Aditions

- (UIViewController *) getSettingsViewController
{
    if ([_product isKindOfClass:OATrackRecordingProduct.class])
        return [[OATripRecordingSettingsViewController alloc] initWithSettingsType:kTripRecordingSettingsScreenGeneral applicationMode:[OAAppSettings sharedManager].applicationMode.get];
    else if ([_product isKindOfClass:OAOsmEditingProduct.class])
        return [[OAOsmEditingSettingsViewController alloc] init];
    else if ([_product isKindOfClass:OAWeatherProduct.class])
        return [[OAWeatherSettingsViewController alloc] init];
    else if ([_product isKindOfClass:OAOsmandDevelopmentProduct.class])
        return [[OAOsmandDevelopmentViewController alloc] init];
    else if ([_product isKindOfClass:OAWikiProduct.class])
        return [[OAWikipediaSettingsViewController alloc] initWithAppMode:[OAAppSettings sharedManager].applicationMode.get];
    return nil;
}

@end
