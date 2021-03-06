//
//  PCUMessageCell.m
//  PonyChatUIV2
//
//  Created by 崔 明辉 on 15/7/7.
//  Copyright (c) 2015年 PonyCui. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <ReactiveCocoa/ReactiveCocoa.h>
#import "PCUCore.h"
#import "PCUImageManager.h"
#import "PCUMessageInteractor.h"
#import "PCUTextMessageItemInteractor.h"
#import "PCUSystemMessageItemInteractor.h"
#import "PCUImageMessageItemInteractor.h"
#import "PCUVoiceMessageItemInteractor.h"
#import "PCULinkMessageItemInteractor.h"
#import "PCUMessageCell.h"
#import "PCUTextMessageCell.h"
#import "PCUSystemMessageCell.h"
#import "PCUImageMessageCell.h"
#import "PCUVoiceMessageCell.h"
#import "PCULinkMessageCell.h"
#import "PCUMessageActivityIndicatorView.h"
#import "PCUSelectionShape.h"

@interface PCUMessageCell ()

@property (nonatomic, strong) ASTextNode *nicknameNode;

@property (nonatomic, strong) ASNetworkImageNode *avatarImageNode;

@property (nonatomic, strong) ASDisplayNode *sendingActivityNode;
@property (nonatomic, strong) PCUMessageActivityIndicatorView *sendingActivityIndicatorView;

@property (nonatomic, strong) ASImageNode *sendingErrorNode;

@property (nonatomic, strong) RACDisposable *sendingSingal;

@property (nonatomic, assign) BOOL isSelecting;
@property (nonatomic, strong) ASControlNode *selectionNode;
@property (nonatomic, strong) PCUSelectionShape *selectionShape;
@property (nonatomic, strong) ASControlNode *selectionGestureNode;

@end

@implementation PCUMessageCell

+ (PCUMessageCell *)cellForMessageInteractor:(PCUMessageItemInteractor *)messageInteractor {
    if ([messageInteractor isKindOfClass:[PCUTextMessageItemInteractor class]]) {
        return [[PCUTextMessageCell alloc] initWithMessageInteractor:messageInteractor];
    }
    else if ([messageInteractor isKindOfClass:[PCUSystemMessageItemInteractor class]]) {
        return [[PCUSystemMessageCell alloc] initWithMessageInteractor:messageInteractor];
    }
    else if ([messageInteractor isKindOfClass:[PCUImageMessageItemInteractor class]]) {
        return [[PCUImageMessageCell alloc] initWithMessageInteractor:messageInteractor];
    }
    else if ([messageInteractor isKindOfClass:[PCUVoiceMessageItemInteractor class]]) {
        return [[PCUVoiceMessageCell alloc] initWithMessageInteractor:messageInteractor];
    }
    else if ([messageInteractor isKindOfClass:[PCULinkMessageItemInteractor class]]) {
        return [[PCULinkMessageCell alloc] initWithMessageInteractor:messageInteractor];
    }
    else {
        return [[PCUMessageCell alloc] initWithMessageInteractor:messageInteractor];
    }
}

- (instancetype)initWithMessageInteractor:(PCUMessageItemInteractor *)messageInteractor
{
    self = [super init];
    if (self) {
        [super setSelectionStyle:UITableViewCellSelectionStyleNone];
        _messageInteractor = messageInteractor;
        [self addSubnode:self.contentNode];
        if (![self isKindOfClass:[PCUSystemMessageCell class]]) {
            [self.contentNode addSubnode:self.nicknameNode];
            [self.contentNode addSubnode:self.avatarImageNode];
            [self.contentNode addSubnode:self.upscriptTextNode];
            [self.contentNode addSubnode:self.subscriptTextNode];
            [self.contentNode addSubnode:self.sendingErrorNode];
            [self.contentNode addSubnode:self.sendingActivityNode];
            [self addSubnode:self.selectionNode];
            [self configureReacitiveCocoa];
            [self configureSendingStatus];
        }
    }
    return self;
}

- (void)configureReacitiveCocoa {
    @weakify(self);
    [RACObserve(self.messageInteractor, avatarURLString) subscribeNext:^(id x) {
        @strongify(self);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.avatarImageNode.URL = [NSURL URLWithString:self.messageInteractor.avatarURLString];
        });
    }];
    [RACObserve(self.messageInteractor.messageItem, senderNicknameString) subscribeNext:^(id x) {
        @strongify(self);
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *text = [[[self messageInteractor] messageItem] senderNicknameString];
            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.alignment = NSTextAlignmentRight;
            if (self.actionType == PCUMessageActionTypeReceive) {
                paragraphStyle.alignment = NSTextAlignmentLeft;
            }
            if (text != nil) {
                NSAttributedString *attributedString = [[NSAttributedString alloc]
                                                        initWithString:text
                                                        attributes:@{
                                                                     NSFontAttributeName: [UIFont systemFontOfSize:11.0],
                                                                     NSForegroundColorAttributeName: [UIColor lightGrayColor],
                                                                     NSParagraphStyleAttributeName: paragraphStyle
                                                                     }];
                [self.nicknameNode setAttributedString:attributedString];
            }
        });
    }];
}

#pragma mark - Events

- (void)handleErrorNodeTapped {
    if ([self.delegate respondsToSelector:@selector(PCUFailableMessageItemTapped:)]) {
        [self.delegate PCUFailableMessageItemTapped:[[self messageInteractor] messageItem]];
    }
}

- (void)handleAvatarTapped {
    if ([self.delegate respondsToSelector:@selector(PCUAvatarTappedWithMessageItem:)]) {
        [self.delegate PCUAvatarTappedWithMessageItem:[[self messageInteractor] messageItem]];
    }
}

- (void)handleAvatarLongPressed:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateRecognized) {
        if ([self.delegate respondsToSelector:@selector(PCUAvatarLongPressedWithMessageItem:)]) {
            [self.delegate PCUAvatarLongPressedWithMessageItem:[[self messageInteractor] messageItem]];
        }
    }
}

#pragma mark - Sending Status

- (void)configureSendingStatus {
    if (self.actionType == PCUMessageActionTypeSend) {
        if (self.messageInteractor.sendingStatus != PCUMessageItemSendingStatusSucceed) {
            [self.sendingActivityIndicatorView startAnimating];
            self.sendingErrorNode.hidden = YES;
            @weakify(self);
            self.sendingSingal = [RACObserve(self.messageInteractor, sendingStatus) subscribeNext:^(id x) {
                @strongify(self);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self updateSendingStatus];
                });
            }];
        }
        else if (self.messageInteractor.sendingStatus == PCUMessageItemSendingStatusFailure) {
            self.sendingErrorNode.hidden = NO;
            [self.sendingActivityIndicatorView stopAnimating];
        }
        else if (self.messageInteractor.sendingStatus == PCUMessageItemSendingStatusSucceed) {
            [self.sendingActivityIndicatorView stopAnimating];
        }
    }
}

- (void)updateSendingStatus {
    if (self.messageInteractor.sendingStatus == PCUMessageItemSendingStatusFailure) {
        self.sendingErrorNode.hidden = NO;
        [self.sendingActivityIndicatorView stopAnimating];
    }
    else if (self.messageInteractor.sendingStatus == PCUMessageItemSendingStatusProcessing) {
        [self.sendingActivityIndicatorView startAnimating];
        self.sendingErrorNode.hidden = YES;
    }
    else if (self.messageInteractor.sendingStatus == PCUMessageItemSendingStatusSucceed) {
        [self.sendingActivityIndicatorView stopAnimating];
        [self.sendingSingal dispose];
    }
}

#pragma mark - Node

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize {
    self.sendingActivityIndicatorView.frame = CGRectMake(0, 0, 44, 44);
    self.contentNode.frame = CGRectMake(0, 0, constrainedSize.width, kAvatarSize + kCellGaps);
    return CGSizeMake(constrainedSize.width, kAvatarSize + kCellGaps);
}

- (void)layout {
    if (self.actionType == PCUMessageActionTypeSend) {
        self.avatarImageNode.frame = CGRectMake(self.calculatedSize.width - 10 - kAvatarSize, 5, kAvatarSize, kAvatarSize);
        if (self.showNickname) {
            self.nicknameNode.frame = CGRectMake(0,
                                                 4.0,
                                                 self.avatarImageNode.frame.origin.x - 8.0,
                                                 14.0);
            self.nicknameNode.hidden = NO;
        }
    }
    else if (self.actionType == PCUMessageActionTypeReceive) {
        self.avatarImageNode.frame = CGRectMake(10, 5, kAvatarSize, kAvatarSize);
        if (self.showNickname) {
            self.nicknameNode.frame = CGRectMake(self.avatarImageNode.frame.origin.x + self.avatarImageNode.frame.size.width + 8.0,
                                                 4.0,
                                                 self.calculatedSize.width - (self.avatarImageNode.frame.origin.x + self.avatarImageNode.frame.size.width + 8.0),
                                                 14.0);
            self.nicknameNode.hidden = NO;
        }
    }
    else {
        self.avatarImageNode.frame = CGRectZero;
    }
}

- (void)updateLayoutWithContentFrame:(CGRect)frame {
    CGFloat topSpace = 0.0;
    if (self.showNickname) {
        topSpace = 18.0;
    }
    [self.upscriptTextNode measure:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
    [self.subscriptTextNode measure:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
    if (self.actionType == PCUMessageActionTypeSend) {
        self.upscriptTextNode.frame = CGRectMake(frame.origin.x - self.upscriptTextNode.calculatedSize.width,
                                                 8.0 + topSpace,
                                                 self.upscriptTextNode.calculatedSize.width,
                                                 self.upscriptTextNode.calculatedSize.height);
        self.subscriptTextNode.frame = CGRectMake(frame.origin.x - self.subscriptTextNode.calculatedSize.width,
                                                  frame.size.height - 26.0 + topSpace,
                                                  self.subscriptTextNode.calculatedSize.width,
                                                  self.subscriptTextNode.calculatedSize.height);
        self.sendingActivityNode.frame = CGRectMake(frame.origin.x - 44.0,
                                                             frame.size.height / 2.0 - 22.0 + topSpace,
                                                             44.0,
                                                             44.0);
        self.sendingErrorNode.frame = self.sendingActivityIndicatorView.frame;
        self.selectionNode.frame = CGRectMake(12.0,
                                              frame.size.height / 2.0 - 13.0 + topSpace,
                                              27.0,
                                              27.0);
    }
    else if (self.actionType == PCUMessageActionTypeReceive) {
        self.upscriptTextNode.frame = CGRectMake(frame.origin.x + frame.size.width,
                                                 8.0 + topSpace,
                                                 self.upscriptTextNode.calculatedSize.width,
                                                 self.upscriptTextNode.calculatedSize.height);
        self.subscriptTextNode.frame = CGRectMake(frame.origin.x + frame.size.width,
                                                  frame.size.height - 26.0 + topSpace,
                                                  self.subscriptTextNode.calculatedSize.width,
                                                  self.subscriptTextNode.calculatedSize.height);
        self.selectionNode.frame = CGRectMake(12.0,
                                              frame.size.height / 2.0 - 13.0 + topSpace,
                                              27.0,
                                              27.0);
    }
}

- (void)resume {
    if (self.messageInteractor.sendingStatus == PCUMessageItemSendingStatusFailure) {
        self.sendingErrorNode.hidden = NO;
        [self.sendingActivityIndicatorView stopAnimating];
    }
    else if (self.messageInteractor.sendingStatus == PCUMessageItemSendingStatusProcessing) {
        [self.sendingActivityIndicatorView startAnimating];
    }
    else {
        [self.sendingActivityIndicatorView stopAnimating];
    }
}

- (void)setSelecting:(BOOL)selecting animated:(BOOL)animated {
    if ([self isKindOfClass:[PCUSystemMessageCell class]]) {
        return;
    }
    if (self.isSelecting == selecting) {
        return;
    }
    self.isSelecting = selecting;
    if (selecting) {
        [self.selectionShape setSelected:NO];
        [self addSubnode:self.selectionGestureNode];
        self.selectionGestureNode.frame = self.bounds;
        self.selectionGestureNode.hidden = NO;
        if (self.actionType == PCUMessageActionTypeReceive) {
            CGRect frame = self.contentNode.frame;
            frame.origin.x = 44.0;
            if (animated) {
                [UIView animateWithDuration:0.25 animations:^{
                    self.contentNode.frame = frame;
                    self.selectionNode.alpha = 1.0;
                } completion:^(BOOL finished) {
                    self.contentNode.frame = frame;
                    self.selectionNode.alpha = 1.0;
                }];
            }
            else {
                self.contentNode.frame = frame;
                self.selectionNode.alpha = 1.0;
            }
        }
        else if (self.actionType == PCUMessageActionTypeSend) {
            if (animated) {
                [UIView animateWithDuration:0.25 animations:^{
                    self.selectionNode.alpha = 1.0;
                } completion:^(BOOL finished) {
                    self.selectionNode.alpha = 1.0;
                }];
            }
            else {
                self.selectionNode.alpha = 1.0;
            }
        }
    }
    else {
        self.selectionGestureNode.hidden = YES;
        if (self.actionType == PCUMessageActionTypeReceive) {
            CGRect frame = self.contentNode.frame;
            frame.origin.x = 0.0;
            if (animated) {
                [UIView animateWithDuration:0.25 animations:^{
                    self.contentNode.frame = frame;
                    self.selectionNode.alpha = 0.0;
                } completion:^(BOOL finished) {
                    self.contentNode.frame = frame;
                    self.selectionNode.alpha = 0.0;
                }];
            }
            else {
                self.contentNode.frame = frame;
                self.selectionNode.alpha = 0.0;
            }
        }
        else if (self.actionType == PCUMessageActionTypeSend) {
            if (animated) {
                [UIView animateWithDuration:0.25 animations:^{
                    self.selectionNode.alpha = 0.0;
                } completion:^(BOOL finished) {
                    self.selectionNode.alpha = 0.0;
                }];
            }
            else {
                self.selectionNode.alpha = 0.0;
            }
        }
    }
}

- (void)setSelected:(BOOL)selected {
    [self.selectionShape setSelected:selected];
}

- (void)handleSelectionNodeTapped {
    [self.cellDelegate messageCellShouldToggleSelection:self messageItem:self.messageInteractor.messageItem];
}

#pragma mark - Getter

- (ASDisplayNode *)contentNode {
    if (_contentNode == nil) {
        _contentNode = [[ASDisplayNode alloc] init];
    }
    return _contentNode;
}

- (ASTextNode *)nicknameNode {
    if (_nicknameNode == nil) {
        _nicknameNode = [[ASTextNode alloc] init];
        _nicknameNode.maximumLineCount = 1;
        _nicknameNode.hidden = YES;
    }
    return _nicknameNode;
}

- (ASNetworkImageNode *)avatarImageNode {
    if (_avatarImageNode == nil) {
        _avatarImageNode = [[ASNetworkImageNode alloc] initWithCache:[PCUImageManager sharedInstance]
                                                          downloader:[PCUImageManager sharedInstance]];
        _avatarImageNode.backgroundColor = ASDisplayNodeDefaultPlaceholderColor();
        _avatarImageNode.layer.cornerRadius = kAvatarSize / 2.0;
        _avatarImageNode.layer.masksToBounds = YES;
        [_avatarImageNode addTarget:self
                             action:@selector(handleAvatarTapped)
                   forControlEvents:ASControlNodeEventTouchUpInside];
        UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleAvatarLongPressed:)];
        longPressGestureRecognizer.minimumPressDuration = 0.25;
        [_avatarImageNode.view addGestureRecognizer:longPressGestureRecognizer];
    }
    return _avatarImageNode;
}

- (PCUMessageActionType)actionType {
    if (self.messageInteractor.ownSender) {
        return PCUMessageActionTypeSend;
    }
    else {
        return PCUMessageActionTypeReceive;
    }
}

- (ASTextNode *)upscriptTextNode {
    if (_upscriptTextNode == nil) {
        _upscriptTextNode = [[ASTextNode alloc] init];
    }
    return _upscriptTextNode;
}

- (ASTextNode *)subscriptTextNode {
    if (_subscriptTextNode == nil) {
        _subscriptTextNode = [[ASTextNode alloc] init];
    }
    return _subscriptTextNode;
}

- (ASImageNode *)sendingErrorNode {
    if (_sendingErrorNode == nil) {
        _sendingErrorNode = [[ASImageNode alloc] init];
        _sendingErrorNode.image = [UIImage imageNamed:@"SenderNodeError"];
        _sendingErrorNode.contentMode = UIViewContentModeCenter;
        _sendingErrorNode.hidden = YES;
        [_sendingErrorNode addTarget:self
                              action:@selector(handleErrorNodeTapped)
                    forControlEvents:ASControlNodeEventTouchUpInside];
    }
    return _sendingErrorNode;
}

- (ASControlNode *)selectionNode {
    if (_selectionNode == nil) {
        _selectionNode = [[ASControlNode alloc] initWithViewBlock:^UIView *{
            self.selectionShape = [[PCUSelectionShape alloc] initWithFrame:CGRectMake(0, 0, 27, 27)];
            self.selectionShape.userInteractionEnabled = YES;
            return self.selectionShape;
        }];
        _selectionNode.alpha = 0.0;
    }
    return _selectionNode;
}

- (ASControlNode *)selectionGestureNode {
    if (_selectionGestureNode == nil) {
        _selectionGestureNode = [[ASControlNode alloc] init];
        self.selectionGestureNode.hidden = YES;
        _selectionGestureNode.backgroundColor = [UIColor clearColor];
        [_selectionGestureNode addTarget:self
                                  action:@selector(handleSelectionNodeTapped)
                        forControlEvents:ASControlNodeEventTouchUpInside];
    }
    return _selectionGestureNode;
}

- (ASDisplayNode *)sendingActivityNode {
    if (_sendingActivityNode == nil) {
        _sendingActivityNode = [[ASDisplayNode alloc] initWithViewBlock:^UIView *{
            PCUMessageActivityIndicatorView *view = [[PCUMessageActivityIndicatorView alloc]
                                                     initWithFrame:CGRectMake(0, 0, 44, 44)];
            view.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
            view.hidesWhenStopped = YES;
            self.sendingActivityIndicatorView = view;
            return view;
        }];
    }
    return _sendingActivityNode;
}

@end
