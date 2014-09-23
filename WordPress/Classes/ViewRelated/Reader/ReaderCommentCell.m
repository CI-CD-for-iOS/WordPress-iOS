#import "ReaderCommentCell.h"
#import "Comment.h"
#import "CommentContentView.h"
#import "ReaderPost.h"

static const NSInteger ReaderCommentCellMaxIndentationLevel = 4;
static const CGFloat ReaderCommentCellIndentationWidth = 16.0;
static const CGFloat ReaderCommentCellTopPadding = 12.0;
static const CGFloat ReaderCommentCellBottomPadding = 20.0;
static const CGFloat ReaderCommentCellSidePadding = 12.0;

@interface ReaderCommentCell()<CommentContentViewDelegate>

@property (nonatomic, strong) Comment *comment;
@property (nonatomic, strong) UIView *borderView;
@property (nonatomic, strong) UIView *nestingView;
@property (nonatomic, strong) CommentContentView *commentContentView;
@property (nonatomic, strong) NSLayoutConstraint *topMarginConstraint;
@property (nonatomic, strong) NSLayoutConstraint *leftIndentationConstraint;

@end


@implementation ReaderCommentCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // TODO: configure background
        self.backgroundColor = [WPStyleGuide itsEverywhereGrey];

        _nestingView = [[UIView alloc] initWithFrame:self.bounds];
        _nestingView.translatesAutoresizingMaskIntoConstraints = NO;
        _nestingView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"background-comment-nesting"]];
        [self.contentView addSubview:_nestingView];

        // configure top border
        _borderView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.bounds), 1)];
        _borderView.translatesAutoresizingMaskIntoConstraints = NO;
        _borderView.backgroundColor = [WPStyleGuide readGrey];
        [self.contentView addSubview:_borderView];

        _commentContentView = [[CommentContentView alloc] initWithFrame:self.bounds];
        _commentContentView.translatesAutoresizingMaskIntoConstraints = NO;
        _commentContentView.delegate = self;
        [self.contentView addSubview:_commentContentView];

        [self configureConstraints];
    }

    return self;
}

- (CGSize)sizeThatFits:(CGSize)size
{
    // Adjust width for indentation and padding
    CGFloat adjustedWidth = size.width - (ReaderCommentCellSidePadding * 2);
    adjustedWidth -= (self.indentationWidth * self.indentationLevel);

    CGSize commentContentViewSize = [self.commentContentView sizeThatFits:CGSizeMake(adjustedWidth, size.height)];
    CGFloat desiredHeight = commentContentViewSize.height + ReaderCommentCellBottomPadding;
    if (self.indentationLevel == 0 || self.needsTopPadding) {
        desiredHeight += ReaderCommentCellTopPadding;
    }
    return CGSizeMake(size.width, desiredHeight);
}

- (void)prepareForReuse
{
    [super prepareForReuse];

    self.needsTopPadding = NO;
    self.indentationLevel = 0;
    [self.commentContentView reset];
}

- (void)setAvatarImage:(UIImage *)avatarImage
{
    [self.commentContentView setAvatarImage:avatarImage];
}

- (void)configureCell:(Comment *)comment
{
    self.comment = comment;

    self.indentationWidth = ReaderCommentCellIndentationWidth;
    self.indentationLevel = MIN(ReaderCommentCellMaxIndentationLevel, [comment.depth integerValue]);

    self.borderView.hidden = self.indentationLevel != 0;
    self.leftIndentationConstraint.constant = ReaderCommentCellSidePadding + (self.indentationLevel * self.indentationWidth);
    self.topMarginConstraint.constant = (self.indentationLevel == 0 || self.needsTopPadding) ? ReaderCommentCellTopPadding : 0.0;

    self.commentContentView.contentProvider = comment;

    // Highlighting the author of the post
    NSString *authorUrl = comment.author_url;
    ReaderPost *post = (ReaderPost *)comment.post;
    if ([authorUrl isEqualToString:post.authorURL]) {
        [self.commentContentView highlightAuthor:YES];
    }
}


- (void)configureConstraints
{
    NSNumber *sidePadding = @(ReaderCommentCellSidePadding);
    NSNumber *bottomPadding = @(ReaderCommentCellBottomPadding);
    NSDictionary *metrics =  @{@"sidePadding":sidePadding,
                               @"bottomPadding":bottomPadding};

    UIView *contentView = self.contentView;
    NSDictionary *views = NSDictionaryOfVariableBindings(contentView, _commentContentView, _borderView, _nestingView);
    // Border View

    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[_nestingView][_commentContentView]"
                                                                             options:0
                                                                             metrics:metrics
                                                                               views:views]];
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_nestingView]|"
                                                                             options:0
                                                                             metrics:metrics
                                                                               views:views]];


    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(sidePadding)-[_borderView]-(sidePadding)-|"
                                                                             options:0
                                                                             metrics:metrics
                                                                               views:views]];
    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_borderView(1)]"
                                                                             options:0
                                                                             metrics:metrics
                                                                               views:views]];


    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[_commentContentView]-(sidePadding)-|"
                                                                             options:0
                                                                             metrics:metrics
                                                                               views:views]];

    [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[_commentContentView]-(bottomPadding)-|"
                                                                             options:0
                                                                             metrics:metrics
                                                                               views:views]];

    self.leftIndentationConstraint = [NSLayoutConstraint constraintWithItem:self.commentContentView
                                                                  attribute:NSLayoutAttributeLeft
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.contentView
                                                                  attribute:NSLayoutAttributeLeft
                                                                 multiplier:1.0
                                                                   constant:ReaderCommentCellSidePadding];
    [self.contentView addConstraint:self.leftIndentationConstraint];

    self.topMarginConstraint = [NSLayoutConstraint constraintWithItem:self.commentContentView
                                                            attribute:NSLayoutAttributeTop
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:self.contentView
                                                            attribute:NSLayoutAttributeTop
                                                           multiplier:1.0
                                                             constant:ReaderCommentCellTopPadding];
    [self.contentView addConstraint:self.topMarginConstraint];
}


#pragma mark - Actions

- (void)handleLinkTapped:(NSURL *)url
{
    if ([self.delegate respondsToSelector:@selector(commentCell:linkTapped:)]) {
        [self.delegate commentCell:self linkTapped:url];
    }
}

- (void)handleReplyTapped:(id<WPContentViewProvider>)contentProvider
{
    if ([self.delegate respondsToSelector:@selector(commentCell:replyToComment:)]) {
        [self.delegate commentCell:self replyToComment:self.comment];
    }
}

@end
