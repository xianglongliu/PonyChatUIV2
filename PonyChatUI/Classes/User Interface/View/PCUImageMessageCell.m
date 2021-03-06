//
//  PCUImageMessageCell.m
//  PonyChatUIV2
//
//  Created by 崔 明辉 on 15/7/7.
//  Copyright (c) 2015年 PonyCui. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <FLAnimatedImage/FLAnimatedImageView.h>
#import <FLAnimatedImage/FLAnimatedImage.h>
#import "PCUImageMessageCell.h"
#import "PCUImageMessageItemInteractor.h"
#import "PCUCore.h"
#import "PCUImageManager.h"
#import "PCUPopMenuViewController.h"

@interface PCUImageMessageCell ()<PCUPopMenuViewControllerDelegate>

@property (nonatomic, strong) ASNetworkImageNode *imageNode;

@property (nonatomic, strong) ASDisplayNode *animatingImageNode;

@property (nonatomic, strong) PCUPopMenuViewController *popMenuViewController;

@end

@implementation PCUImageMessageCell

- (instancetype)initWithMessageInteractor:(PCUMessageItemInteractor *)messageInteractor
{
    self = [super initWithMessageInteractor:messageInteractor];
    if (self) {
        if ([[self imageMessageInteractor] isGIF]) {
            [self.contentNode addSubnode:self.animatingImageNode];
        }
        else {
            [self.contentNode addSubnode:self.imageNode];
        }
    }
    return self;
}

#pragma mark - Event

- (void)handleImageNodeTapped {
    if ([self.delegate respondsToSelector:@selector(PCUImageMessageItemTapped:)]) {
        [self.delegate PCUImageMessageItemTapped:(id)self.messageInteractor.messageItem];
    }
    if ([self.delegate respondsToSelector:@selector(PCUImageMessageItemTapped:imageView:)]) {
        [self.delegate PCUImageMessageItemTapped:(id)self.messageInteractor.messageItem imageView:self.imageNode];
    }
}

#pragma mark - Node

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize {
    CGFloat topSpace = 0.0;
    if (self.showNickname) {
        topSpace = 18.0;
    }
    CGSize superSize = [super calculateSizeThatFits:constrainedSize];
    CGSize imageSize = CGSizeMake([[self imageMessageInteractor] imageWidth], [[self imageMessageInteractor] imageHeight]);
    self.contentNode.frame = CGRectMake(0, 0, constrainedSize.width, MAX(superSize.height, imageSize.height) + kCellGaps + topSpace);
    return CGSizeMake(constrainedSize.width, MAX(superSize.height, imageSize.height) + kCellGaps + topSpace);
}

- (void)layout {
    CGFloat topSpace = 0.0;
    if (self.showNickname) {
        topSpace = 18.0;
    }
    [super layout];
    if ([super actionType] == PCUMessageActionTypeSend) {
        self.imageNode.frame = CGRectMake(self.calculatedSize.width - kAvatarSize - 4.0 - [self imageMessageInteractor].imageWidth, 0.0 + topSpace, [self imageMessageInteractor].imageWidth, [self imageMessageInteractor].imageHeight);
        self.animatingImageNode.frame = CGRectMake(self.calculatedSize.width - kAvatarSize - 20.0 - [self imageMessageInteractor].imageWidth, 0.0 + topSpace, [self imageMessageInteractor].imageWidth, [self imageMessageInteractor].imageHeight);
    }
    else if ([super actionType] == PCUMessageActionTypeReceive) {
        self.imageNode.frame = CGRectMake(kAvatarSize + 4.0, 0.0 + topSpace, [self imageMessageInteractor].imageWidth, [self imageMessageInteractor].imageHeight);
        self.animatingImageNode.frame = CGRectMake(kAvatarSize + 20.0, 0.0 + topSpace, [self imageMessageInteractor].imageWidth, [self imageMessageInteractor].imageHeight);
    }
    else {
        self.imageNode.hidden = YES;
    }
    if ([super actionType] == PCUMessageActionTypeSend) {
        self.imageNode.layer.mask = [self senderShapeLayerWithSize:self.imageNode.frame.size];
        self.imageNode.layer.masksToBounds = YES;
    }
    else if ([super actionType] == PCUMessageActionTypeReceive) {
        self.imageNode.layer.mask = [self receiverShapeLayerWithSize:self.imageNode.frame.size];
        self.imageNode.layer.masksToBounds = YES;
    }
    [self updateLayoutWithContentFrame:self.imageNode.frame];
}

- (void)resume {
    [super resume];
    if ([[[self imageMessageInteractor] imageURLString] hasPrefix:@"/"]) {
        UIImage *image = [UIImage imageWithContentsOfFile:[[self imageMessageInteractor] imageURLString]];
        _imageNode.image = image;
    }
}

#pragma mark - PCUPopMenuViewControllerDelegate

- (void)handleBackgroundImageNodeTapped:(UILongPressGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        self.imageNode.alpha = 0.5;
        CGPoint thePoint = [sender.view.superview convertPoint:sender.view.frame.origin toView:[[UIApplication sharedApplication] keyWindow]];
        thePoint.x += CGRectGetWidth(sender.view.frame) / 2.0;
        [self.popMenuViewController presentMenuViewControllerWithReferencePoint:thePoint];
    }
    else if (sender.state == UIGestureRecognizerStateEnded) {
        self.imageNode.alpha = 1.0;
    }
}

- (void)menuItemDidPressed:(PCUPopMenuViewController *)menuViewController itemIndex:(NSUInteger)itemIndex {
    if (itemIndex == 0) {
        if ([self.delegate respondsToSelector:@selector(PCURequireDeleteMessageItem:)]) {
            [self.delegate PCURequireDeleteMessageItem:self.messageInteractor.messageItem];
        }
    }
    else if (itemIndex == 1) {
        if ([self.delegate respondsToSelector:@selector(PCURequireForwardMessageItem:)]) {
            [self.delegate PCURequireForwardMessageItem:self.messageInteractor.messageItem];
        }
    }
    else if (itemIndex == 2) {
        [self.cellDelegate mainViewShouldEnteringSeletionMode];
    }
}

#pragma mark - Getter

- (PCUImageMessageItemInteractor *)imageMessageInteractor {
    return (id)[super messageInteractor];
}

- (ASDisplayNode *)animatingImageNode {
    if (_animatingImageNode == nil) {
        _animatingImageNode = [[ASDisplayNode alloc] initWithViewBlock:^UIView *{
            FLAnimatedImageView *imageView = [[FLAnimatedImageView alloc] init];
            if ([[self imageMessageInteractor] isGIF] &&
                [[self imageMessageInteractor] imageURLString] != nil) {
                NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[[self imageMessageInteractor] imageURLString]] cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:60.0];
                [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
                    if (connectionError == nil && data != nil) {
                        FLAnimatedImage *image = [FLAnimatedImage animatedImageWithGIFData:data];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [imageView setAnimatedImage:image];
                        });
                    }
                }];
                imageView.frame = CGRectMake(0, 0, [[self imageMessageInteractor] imageWidth], [[self imageMessageInteractor] imageHeight]);
            }
            return imageView;
        }];
    }
    return _animatingImageNode;
}

- (ASNetworkImageNode *)imageNode {
    if (_imageNode == nil) {
        _imageNode = [[ASNetworkImageNode alloc] initWithCache:[PCUImageManager sharedInstance]
                                                    downloader:[PCUImageManager sharedInstance]];
        if ([[self imageMessageInteractor] isGIF]) {
            return _imageNode;
        }
        [_imageNode addTarget:self action:@selector(handleImageNodeTapped) forControlEvents:ASControlNodeEventTouchUpInside];
        _imageNode.contentMode = UIViewContentModeScaleAspectFill;
        if ([[[self imageMessageInteractor] imageURLString] hasPrefix:@"/"]) {
            UIImage *image = [UIImage imageWithContentsOfFile:[[self imageMessageInteractor] imageURLString]];
            _imageNode.image = image;
        }
        else if ([[self imageMessageInteractor] thumbURLString] != nil) {
            _imageNode.URL = [NSURL URLWithString:[[self imageMessageInteractor] thumbURLString]];
        }
        else {
            _imageNode.URL = [NSURL URLWithString:[[self imageMessageInteractor] imageURLString]];
        }
        _imageNode.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
        UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackgroundImageNodeTapped:)];
        gesture.minimumPressDuration = 0.35;
        [_imageNode.view addGestureRecognizer:gesture];
    }
    return _imageNode;
}

- (CAShapeLayer *)senderShapeLayerWithSize:(CGSize)size {
    
    //// Bezier Drawing
    UIBezierPath* bezierPath = [[UIBezierPath alloc] init];
    
    UIBezierPath* rectanglePath = [UIBezierPath bezierPathWithRoundedRect: CGRectMake(19,
                                                                                      2,
                                                                                      size.width - 36,
                                                                                      size.height - 4)
                                                             cornerRadius: 4];
    [bezierPath appendPath:rectanglePath];
    
    UIBezierPath* drawPath = [[UIBezierPath alloc] init];
    [drawPath moveToPoint: CGPointMake(size.width - 17.0, 22.5)];
    [drawPath addLineToPoint: CGPointMake(size.width - 11.0, 28.15)];
    [drawPath addLineToPoint: CGPointMake(size.width - 17.0, 34.5)];
    [drawPath addLineToPoint: CGPointMake(size.width - 17.0, 22.5)];
    
    [bezierPath appendPath:drawPath];
    [bezierPath closePath];
    
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.path = bezierPath.CGPath;
    return maskLayer;
}

- (CAShapeLayer *)receiverShapeLayerWithSize:(CGSize)size {
    
    //// Bezier Drawing
    UIBezierPath* bezierPath = [[UIBezierPath alloc] init];
    
    UIBezierPath* rectanglePath = [UIBezierPath bezierPathWithRoundedRect: CGRectMake(19,
                                                                                      2,
                                                                                      size.width - 28,
                                                                                      size.height - 4)
                                                             cornerRadius: 4];
    [bezierPath appendPath:rectanglePath];
    
    UIBezierPath* drawPath = [[UIBezierPath alloc] init];
    [drawPath moveToPoint: CGPointMake(19, 22.5)];
    [drawPath addLineToPoint: CGPointMake(13, 28.15)];
    [drawPath addLineToPoint: CGPointMake(19, 34.5)];
    [drawPath addLineToPoint: CGPointMake(19, 22.5)];
    [drawPath closePath];
    
    [bezierPath appendPath:drawPath];
    [bezierPath closePath];
    
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.path = bezierPath.CGPath;
    return maskLayer;
}

- (PCUPopMenuViewController *)popMenuViewController {
    if (_popMenuViewController == nil) {
        _popMenuViewController = [[PCUPopMenuViewController alloc] init];
        _popMenuViewController.titles = @[@"删除", @"转发", @"更多..."];
        _popMenuViewController.delegate = self;
    }
    return _popMenuViewController;
}

@end
