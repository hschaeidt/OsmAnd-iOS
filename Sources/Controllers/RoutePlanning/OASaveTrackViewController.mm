//
//  OASaveTrackViewController.mm
//  OsmAnd
//
//  Created by Anna Bibyk on 14.01.2021.
//  Copyright © 2021 OsmAnd. All rights reserved.
//

#import "OASaveTrackViewController.h"
#import "OARootViewController.h"
#import "Localization.h"
#import "OAColors.h"
#import "OATextMultilineTableViewCell.h"
#import "OASwitchTableViewCell.h"
#import "OASaveTrackBottomSheetViewController.h"
#import "OAMapLayers.h"
#import "OAMapRendererView.h"
#import "OAValueTableViewCell.h"
#import "OAFolderCardsCell.h"
#import "OASelectTrackFolderViewController.h"
#import "OAAddTrackFolderViewController.h"
#import "OACollectionViewCellState.h"

@interface OASaveTrackViewController() <UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, OASelectTrackFolderDelegate, OAFolderCardsCellDelegate, OAAddTrackFolderDelegate>

@end

@implementation OASaveTrackViewController
{
    NSArray<NSArray<NSDictionary *> *> *_data;
    OAAppSettings *_settings;
    
    NSString *_fileName;
    NSString *_sourceFileName;
    NSString *_filePath;
    NSString *_selectedFolderName;
    NSArray<NSString *> *_allFolders;
    BOOL _showSimplifiedButton;
    BOOL _rightButtonEnabled;
    
    BOOL _duplicate;
    BOOL _simplifiedTrack;
    BOOL _showOnMap;
    
    NSString *_inputFieldError;
    NSInteger _selectedFolderIndex;
    OACollectionViewCellState *_scrollCellsState;
}

- (instancetype) initWithFileName:(NSString *)fileName
                         filePath:(NSString *)filePath
                        showOnMap:(BOOL)showOnMap
                  simplifiedTrack:(BOOL)simplifiedTrack
                        duplicate:(BOOL)duplicate
{
    self = [super init];
    if (self)
    {
        _settings = [OAAppSettings sharedManager];
        _fileName = fileName;
        _filePath = filePath;
        _sourceFileName = fileName;
        _showSimplifiedButton = simplifiedTrack;
        _showOnMap = showOnMap;
        _duplicate = duplicate;

        _rightButtonEnabled = YES;
        _simplifiedTrack = NO;
        
        [self commonInit];
    }
    return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    self.cancelButton.layer.cornerRadius = 9.0;
    self.saveButton.layer.cornerRadius = 9.0;
    
    [self updateBottomButtons];
}

- (void) applyLocalization
{
    [super applyLocalization];
    self.titleLabel.text = OALocalizedString(@"save_as_new_track");
    [self.cancelButton setTitle:OALocalizedString(@"shared_string_cancel") forState:UIControlStateNormal];
    [self.saveButton setTitle:OALocalizedString(@"shared_string_save") forState:UIControlStateNormal];
}

- (NSString *) getDisplayingFolderName:(NSString *)filePath
{
    NSString *folderName = [filePath stringByDeletingLastPathComponent];
    if (folderName.length == 0)
        return OALocalizedString(@"shared_string_gpx_tracks");
    else
        return folderName;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void) commonInit
{
    [self updateAllFoldersList];
    _selectedFolderName = [self getDisplayingFolderName:_filePath];
    _selectedFolderIndex = (int)[_allFolders indexOfObject:_selectedFolderName];
    _scrollCellsState = [[OACollectionViewCellState alloc] init];

    if (_duplicate)
    {
        NSRange range = [_fileName rangeOfString:@"_copy\\s*\\d*$" options:NSRegularExpressionSearch];
        if (range.location == NSNotFound)
            _fileName = [_fileName stringByAppendingString:@"_copy"];

        NSString *path = [[OsmAndApp instance].gpxPath
                stringByAppendingPathComponent:[_filePath stringByDeletingLastPathComponent]];
        while ([[NSFileManager defaultManager] fileExistsAtPath:[[path stringByAppendingPathComponent:_fileName]
                stringByAppendingPathExtension:@"gpx"]])
        {
            if ([_fileName hasSuffix:@"_copy"])
                _fileName = [_fileName stringByAppendingString:@" 1"];

            _fileName = [OAUtilities createNewFileName:_fileName];
        }
    }

    [self generateData];
}

- (void) updateAllFoldersList
{
    _allFolders = [OAUtilities getGpxFoldersListSorted:YES shouldAddTracksFolder:YES];
}

- (void) generateData
{
    NSMutableArray *data = [NSMutableArray new];
    
    [data addObject:@[
        @{
            @"type" : [OATextMultilineTableViewCell getCellIdentifier],
            @"fileName" : _fileName,
            @"header" : OALocalizedString(@"shared_string_name"),
            @"key" : @"input_name",
        }
    ]];
    
    [data addObject:@[
        @{
            @"type" : [OAValueTableViewCell getCellIdentifier],
            @"header" : OALocalizedString(@"plan_route_folder"),
            @"title" : @"Select folder",
            @"value" : _selectedFolderName,
        },
        @{
            @"type" : [OAFolderCardsCell getCellIdentifier],
            @"selectedValue" : @(_selectedFolderIndex),
            @"values" : _allFolders,
            @"addButtonTitle" : OALocalizedString(@"add_folder")
        },
    ]];

    if (_showSimplifiedButton)
    {
        [data addObject:@[
            @{
                @"type" : [OASwitchTableViewCell getCellIdentifier],
                @"title" : OALocalizedString(@"simplified_track"),
                @"key" : @"simplified_track",
                @"footer" : OALocalizedString(@"simplified_track_description")
            }
        ]];
    }
    
    [data addObject:@[
        @{
            @"type" : [OASwitchTableViewCell getCellIdentifier],
            @"title" : OALocalizedString(@"shared_string_show_on_map"),
            @"key" : @"map_settings_show"
        }
    ]];
    
    _data = data;
}

- (void) updateBottomButtons
{
    self.saveButton.userInteractionEnabled = _rightButtonEnabled;
    [self.saveButton setBackgroundColor:_rightButtonEnabled ? UIColorFromRGB(color_primary_purple) : UIColorFromRGB(color_icon_inactive)];
}

- (BOOL) cellValueByKey:(NSString *)key
{
    if ([key isEqualToString:@"simplified_track"])
        return _simplifiedTrack;
    if ([key isEqualToString:@"map_settings_show"])
        return _showOnMap;
    return NO;
}

- (void) showSelectFolderScreen
{
    OASelectTrackFolderViewController *selectFolderView = [[OASelectTrackFolderViewController alloc] initWithSelectedFolderName:_selectedFolderName];
    selectFolderView.delegate = self;
    [self presentViewController:selectFolderView animated:YES completion:nil];
}

- (void) showAddFolderScreen
{
    OAAddTrackFolderViewController * addFolderVC = [[OAAddTrackFolderViewController alloc] init];
    addFolderVC.delegate = self;
    [self presentViewController:addFolderVC animated:YES completion:nil];
}

- (void) showEmptyNameAlert
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:OALocalizedString(@"empty_filename") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:OALocalizedString(@"shared_string_ok") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Actions

- (IBAction)cancelButtonPressed:(id)sender
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(onSaveTrackCancelled)])
        [self.delegate onSaveTrackCancelled];
    
    [self dismissViewController];
}

- (IBAction)saveButtonPressed:(id)sender
{
    if (_fileName.length == 0)
    {
        [self showEmptyNameAlert];
    }
    else
    {        
        [self dismissViewControllerAnimated:NO completion:nil];
        NSString *savingPath;
        if ([_selectedFolderName isEqualToString:OALocalizedString(@"shared_string_gpx_tracks")])
            savingPath = _fileName;
        else
            savingPath = [_selectedFolderName stringByAppendingPathComponent:_fileName];
        
        if (self.delegate)
        {
            [self.delegate onSaveAsNewTrack:savingPath
                                  showOnMap:_showOnMap
                            simplifiedTrack:_simplifiedTrack
                                  openTrack:YES];
        }
    }
}

#pragma mark - UITableViewDataSource

- (nonnull UITableViewCell *) tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    NSDictionary *item = _data[indexPath.section][indexPath.row];
    NSString *cellType = item[@"type"];
    if ([cellType isEqualToString:[OATextMultilineTableViewCell getCellIdentifier]])
    {
        OATextMultilineTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[OATextMultilineTableViewCell getCellIdentifier]];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OATextMultilineTableViewCell getCellIdentifier] owner:self options:nil];
            cell = (OATextMultilineTableViewCell *) nib[0];
            [cell leftIconVisibility:NO];
            cell.textView.userInteractionEnabled = YES;
            cell.textView.editable = YES;
            cell.textView.delegate = self;
            cell.textView.returnKeyType = UIReturnKeyDone;
            cell.textView.enablesReturnKeyAutomatically = YES;
        }
        if (cell)
        {
            cell.textView.text = item[@"fileName"];
            cell.textView.tag = indexPath.section << 10 | indexPath.row;
            cell.clearButton.tag = cell.textView.tag;
            [cell.clearButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
            [cell.clearButton addTarget:self action:@selector(clearButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        }
        return cell;
    }
    else if ([cellType isEqualToString:[OASwitchTableViewCell getCellIdentifier]])
    {
        OASwitchTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[OASwitchTableViewCell getCellIdentifier]];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OASwitchTableViewCell getCellIdentifier] owner:self options:nil];
            cell = (OASwitchTableViewCell *) nib[0];
            [cell leftIconVisibility:NO];
            [cell descriptionVisibility:NO];
        }
        if (cell)
        {
            cell.titleLabel.text = item[@"title"];

            NSString *itemKey = item[@"key"];
            BOOL value = [self cellValueByKey:itemKey];
            cell.switchView.on = value;
            cell.switchView.tag = indexPath.section << 10 | indexPath.row;
            [cell.switchView removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
            [cell.switchView addTarget:self action:@selector(applyParameter:) forControlEvents:UIControlEventValueChanged];
        }
        return cell;
    }
    else if ([cellType isEqualToString:[OAValueTableViewCell getCellIdentifier]])
    {
        OAValueTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:[OAValueTableViewCell getCellIdentifier]];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OAValueTableViewCell getCellIdentifier] owner:self options:nil];
            cell = (OAValueTableViewCell *)[nib objectAtIndex:0];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            [cell leftIconVisibility:NO];
            [cell descriptionVisibility:NO];
        }
        if (cell)
        {
            cell.titleLabel.text = item[@"title"];
            cell.titleLabel.textColor = UIColor.blackColor;
            cell.valueLabel.text = item[@"value"];
        }
        return cell;
    }
    else if ([cellType isEqualToString:[OAFolderCardsCell getCellIdentifier]])
    {
        OAFolderCardsCell* cell = [tableView dequeueReusableCellWithIdentifier:[OAFolderCardsCell getCellIdentifier]];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OAFolderCardsCell getCellIdentifier] owner:self options:nil];
            cell = (OAFolderCardsCell *)[nib objectAtIndex:0];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.delegate = self;
            cell.cellIndex = indexPath;
            cell.state = _scrollCellsState;
        }
        if (cell)
        {
            [cell setValues:item[@"values"] sizes:nil colors:nil addButtonTitle:item[@"addButtonTitle"] withSelectedIndex:(int)[item[@"selectedValue"] intValue]];
        }
        return cell;
    }
    
    return nil;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = _data[indexPath.section][indexPath.row];
    NSString *type = item[@"type"];
    if ([type isEqualToString:[OAFolderCardsCell getCellIdentifier]])
    {
        OAFolderCardsCell *folderCell = (OAFolderCardsCell *)cell;
        [folderCell updateContentOffset];
    }
}

- (NSInteger) tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _data[section].count;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return _data.count;
}

- (void) tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    if([view isKindOfClass:[UITableViewHeaderFooterView class]]){
        UITableViewHeaderFooterView *headerView = (UITableViewHeaderFooterView *) view;
        headerView.textLabel.textColor = UIColorFromRGB(color_text_footer);
    }
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section
{
    if([view isKindOfClass:[UITableViewHeaderFooterView class]]){
        UITableViewHeaderFooterView *headerView = (UITableViewHeaderFooterView *) view;
        headerView.textLabel.textColor = _inputFieldError != nil && section == 0 ? UIColorFromRGB(color_primary_red) : UIColorFromRGB(color_text_footer);
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSDictionary *item = _data[section].firstObject;
    
    return item[@"header"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 0)
        return _inputFieldError;
    NSDictionary *item = _data[section].firstObject;
    
    return item[@"footer"];
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = _data[indexPath.section][indexPath.row];
    NSString *cellType = item[@"type"];
    if ([cellType isEqualToString:[OAValueTableViewCell getCellIdentifier]])
    {
        [self showSelectFolderScreen];
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if([text isEqualToString:@"\n"])
    {
        [textView resignFirstResponder];
        return NO;
    }
    return YES;
}

- (void) textViewDidChange:(UITextView *)textView
{
    [self updateErrorMessage:textView.text];
    [textView sizeToFit];
}

#pragma mark - Selectors

- (void) clearButtonPressed:(UIButton *)sender
{
    _fileName = @"";
    
    UIButton *btn = (UIButton *)sender;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:btn.tag & 0x3FF inSection:btn.tag >> 10];
    
    [_tableView beginUpdates];
    UITableViewCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section]];
    if ([cell isKindOfClass:OATextMultilineTableViewCell.class])
        ((OATextMultilineTableViewCell *) cell).textView.text = @"";
    [_tableView endUpdates];
}

- (void) applyParameter:(id)sender
{
    UISwitch *sw = (UISwitch *)sender;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:sw.tag & 0x3FF inSection:sw.tag >> 10];
    NSDictionary *item = _data[indexPath.section][indexPath.row];
    NSString *key = item[@"key"];
    if ([key isEqualToString:@"simplified_track"])
    {
        _simplifiedTrack = !_simplifiedTrack;
        [_tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    if ([key isEqualToString:@"map_settings_show"])
    {
        _showOnMap = !_showOnMap;
        [_tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (void) updateErrorMessage:(NSString *)text
{
    [self updateFileNameFromEditText:text];
    
    [self.tableView beginUpdates];
    UITableViewHeaderFooterView *footer = [self.tableView footerViewForSection:0];
    footer.textLabel.textColor = _inputFieldError != nil ? UIColorFromRGB(color_primary_red) : UIColorFromRGB(color_text_footer);
    footer.textLabel.text = _inputFieldError;
    [footer sizeToFit];
    [self.tableView endUpdates];
}

- (void) updateFileNameFromEditText:(NSString *)name
{
    _rightButtonEnabled = NO;
    NSString *text = name.trim;
    _fileName = text;
    if (text.length == 0)
    {
        _inputFieldError = OALocalizedString(@"empty_filename");
    }
    else if ([self isIncorrectFileName:name])
    {
        _inputFieldError = OALocalizedString(@"incorrect_symbols");
    }
    else if ([self isFileExist:name])
    {
        _inputFieldError = OALocalizedString(@"gpx_already_exsists");
    }
    else
    {
        _inputFieldError = nil;
        _rightButtonEnabled = YES;
    }
    [self updateBottomButtons];
}

- (BOOL) isFileExist:(NSString *)name
{
    NSString *folderPath = OsmAndApp.instance.gpxPath;
    if (_selectedFolderName.length > 0 && ![_selectedFolderName isEqualToString:OALocalizedString(@"shared_string_gpx_tracks")])
        folderPath = [folderPath stringByAppendingPathComponent:_selectedFolderName];
        
    NSString *filePath = [[folderPath stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"gpx"];
    return [NSFileManager.defaultManager fileExistsAtPath:filePath];
}

- (BOOL) isIncorrectFileName:(NSString *)fileName
{
    BOOL isFileNameEmpty = [fileName trim].length == 0;

    NSCharacterSet* illegalFileNameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>:;.,"];
    BOOL hasIncorrectSymbols = [fileName rangeOfCharacterFromSet:illegalFileNameCharacters].length != 0;
    
    return isFileNameEmpty || hasIncorrectSymbols;
}

#pragma mark - Keyboard Notifications

- (CGFloat)getModalPresentationOffset:(BOOL)keyboardShown
{
    // accounts for additional top offset in modal presentation
    CGFloat modalOffset = modalOffset = keyboardShown ? 6. : 10.;;

    return modalOffset;
}

- (void) keyboardWillShow:(NSNotification *)notification;
{
    NSDictionary *userInfo = [notification userInfo];
    CGRect keyboardBounds;
    [[userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboardBounds];
    CGFloat duration = [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    NSInteger animationCurve = [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [UIView animateWithDuration:duration delay:0. options:animationCurve animations:^{
        self.view.frame = CGRectMake(0., 0., self.view.frame.size.width, DeviceScreenHeight - OAUtilities.getStatusBarHeight - keyboardBounds.size.height - [self getModalPresentationOffset:YES]);
    } completion:nil];
}

- (void) keyboardWillHide:(NSNotification *)notification;
{
    NSDictionary *userInfo = [notification userInfo];
    CGFloat duration = [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    NSInteger animationCurve = [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [UIView animateWithDuration:duration delay:0. options:animationCurve animations:^{
        self.view.frame = CGRectMake(0., 0., self.view.frame.size.width, DeviceScreenHeight - OAUtilities.getStatusBarHeight - [self getModalPresentationOffset:NO]);
    } completion:nil];
}

#pragma mark - OASelectTrackFolderDelegate

- (void) onFolderSelected:(NSString *)selectedFolderName
{
    _selectedFolderName = selectedFolderName;
    _selectedFolderIndex = [_allFolders indexOfObject:selectedFolderName];
    [self updateErrorMessage:_fileName];
    [self generateData];
    [_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:1], [NSIndexPath indexPathForRow:1 inSection:1]] withRowAnimation:UITableViewRowAnimationNone];
}

- (void) onFolderAdded:(NSString *)addedFolderName
{
    [self onTrackFolderAdded:addedFolderName];
}

- (void) onNewFolderAdded
{
    [self updateAllFoldersList];
    _selectedFolderIndex = [_allFolders indexOfObject:_selectedFolderName];
    [self generateData];
    [_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:1], [NSIndexPath indexPathForRow:1 inSection:1]] withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - OAAddTrackFolderDelegate

- (void) onTrackFolderAdded:(NSString *)folderName
{
    NSString *newFolderPath = [OsmAndApp.instance.gpxPath stringByAppendingPathComponent:folderName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:newFolderPath])
        [[NSFileManager defaultManager] createDirectoryAtPath:newFolderPath withIntermediateDirectories:NO attributes:nil error:nil];
    
    _selectedFolderName = folderName;
    [self onNewFolderAdded];
}

#pragma mark - OAFolderCardsCellDelegate

- (void) onItemSelected:(NSInteger)index
{
    _selectedFolderIndex = index;
    _selectedFolderName = _allFolders[index];
    [self updateErrorMessage:_fileName];
    [self generateData];
    [_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:1]] withRowAnimation:UITableViewRowAnimationNone];
}

- (void) onAddFolderButtonPressed
{
    [self showAddFolderScreen];
}

@end
