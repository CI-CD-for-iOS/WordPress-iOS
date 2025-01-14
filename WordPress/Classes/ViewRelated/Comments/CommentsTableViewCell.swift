import Foundation
import WordPressShared.WPTableViewCell

open class CommentsTableViewCell: WPTableViewCell {

    // MARK: - IBOutlets

    @IBOutlet private weak var pendingIndicator: UIView!
    @IBOutlet private weak var pendingIndicatorWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var gravatarImageView: CircularImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var detailLabel: UILabel!

    @IBOutlet weak var timestampStackView: UIStackView!
    @IBOutlet private weak var timestampImageView: UIImageView!
    @IBOutlet private weak var timestampLabel: UILabel!

    // MARK: - Private Properties

    private var author = String()
    private var postTitle = String()
    private var content = String()
    private var timestamp: String?
    private var pending: Bool = false
    private var gravatarURL: URL?
    private typealias Style = WPStyleGuide.Comments
    private let placeholderImage = Style.gravatarPlaceholderImage

    private enum Labels {
        static let noTitle = NSLocalizedString("(No Title)", comment: "Empty Post Title")
        static let titleFormat = NSLocalizedString("%1$@ on %2$@", comment: "Label displaying the author and post title for a Comment. %1$@ is a placeholder for the author. %2$@ is a placeholder for the post title.")
    }

    // MARK: - Public Properties

    @objc static let reuseIdentifier = "CommentsTableViewCell"
    @objc static let estimatedRowHeight = 150

    // MARK: - Public Methods

    open override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = Style.backgroundColor
        pendingIndicator.layer.cornerRadius = pendingIndicatorWidthConstraint.constant / 2
    }

    @objc func configureWithComment(_ comment: Comment) {
        author = comment.authorForDisplay() ?? String()
        pending = (comment.status == CommentStatusPending)
        postTitle = comment.titleForDisplay() ?? Labels.noTitle
        content = comment.contentPreviewForDisplay() ?? String()
        timestamp = comment.dateCreated.mediumString()

        if let avatarURLForDisplay = comment.avatarURLForDisplay() {
            downloadGravatarWithURL(avatarURLForDisplay)
        } else {
            downloadGravatarWithGravatarEmail(comment.gravatarEmailForDisplay())
        }

        configurePendingIndicator()
        configureCommentLabels()
        configureTimestamp()
    }

}

private extension CommentsTableViewCell {

    // MARK: - Gravatar Downloading

    func downloadGravatarWithURL(_ url: URL?) {
        if url == gravatarURL {
            return
        }

        let gravatar = url.flatMap { Gravatar($0) }
        gravatarImageView.downloadGravatar(gravatar, placeholder: placeholderImage, animate: true)

        gravatarURL = url
    }

    func downloadGravatarWithGravatarEmail(_ email: String?) {
        guard let unwrappedEmail = email else {
            gravatarImageView.image = placeholderImage
            return
        }

        gravatarImageView.downloadGravatarWithEmail(unwrappedEmail, placeholderImage: placeholderImage)
    }

    // MARK: - Configure UI

    func configurePendingIndicator() {
        pendingIndicator.backgroundColor = pending ? Style.pendingIndicatorColor : .clear
    }

    func configureCommentLabels() {
        titleLabel.attributedText = attributedTitle()
        // Some Comment content has leading newlines. Let's nix that.
        detailLabel.text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        detailLabel.font = Style.detailFont
        detailLabel.textColor = Style.detailTextColor
    }

    func configureTimestamp() {

        // When FeatureFlag.commentFilters is removed,
        // all timestamp elements can be removed.
        timestampStackView.isHidden = FeatureFlag.commentFilters.enabled

        timestampLabel.text = timestamp
        timestampLabel.font = Style.timestampFont
        timestampLabel.textColor = Style.detailTextColor
        timestampImageView.image = Style.timestampImage
    }

    func attributedTitle() -> NSAttributedString {
        let replacementMap = [
            "%1$@": NSAttributedString(string: author, attributes: Style.titleBoldAttributes),
            "%2$@": NSAttributedString(string: postTitle, attributes: Style.titleBoldAttributes)
        ]

        // Replace Author + Title
        let attributedTitle = NSMutableAttributedString(string: Labels.titleFormat, attributes: Style.titleRegularAttributes)

        for (key, attributedString) in replacementMap {
            let range = (attributedTitle.string as NSString).range(of: key)
            if range.location != NSNotFound {
                attributedTitle.replaceCharacters(in: range, with: attributedString)
            }
        }

        return attributedTitle
    }

}
