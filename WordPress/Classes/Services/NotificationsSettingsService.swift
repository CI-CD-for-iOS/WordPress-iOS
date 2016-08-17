import Foundation


/// This service encapsulates the Restful API related to WordPress Notifications.
///
public class NotificationsSettingsService: LocalCoreDataService
{
    // MARK: - Aliases
    public typealias Channel    = NotificationSettings.Channel
    public typealias Stream     = NotificationSettings.Stream


    /// Designated Initializer
    ///
    /// - Parameter managedObjectContext: A Reference to the MOC that should be used to interact with the Core Data Stack.
    ///
    public override init(managedObjectContext context: NSManagedObjectContext) {
        super.init(managedObjectContext: context)

        if let restApi = AccountService(managedObjectContext: context).defaultWordPressComAccount()?.wordPressComRestApi {
            remoteApi = restApi.hasCredentials() ? restApi : nil
        }
    }

    /// Convenience Initializer. Useful for Unit Testing
    ///
    /// - Parameters:
    ///     - managedObjectContext: A Reference to the MOC that should be used to interact with the Core Data Stack.
    ///     - wordPressComRestApi: The WordPressComRestApi that should be used.
    ///
    public convenience init(managedObjectContext context: NSManagedObjectContext, wordPressComRestApi: WordPressComRestApi) {
        self.init(managedObjectContext: context)
        self.remoteApi = wordPressComRestApi
    }


    /// This method will retrieve all of the Notification Settings for the default WordPress.com account
    ///
    /// - Parameters:
    ///     - success: Closure to be called on success.
    ///     - failure: Closure to be called on failure, with the associated error.
    ///
    public func getAllSettings(success: ([NotificationSettings] -> Void)?, failure: (NSError! -> Void)?) {
        notificationsServiceRemote?.getAllSettings(deviceId,
            success: {
                (remote: [RemoteNotificationSettings]) in
                let parsed = self.settingsFromRemote(remote)
                success?(parsed)
            },
            failure: { (error: NSError!) in
                failure?(error)
            })
    }


    /// Updates the specified NotificationSettings's Stream, with a collection of new values.
    ///
    /// - Parameters:
    ///     - settings: The NotificationSettings to be updated.
    ///     - stream: Reference to the specific Settings Stream to update.
    ///     - newValues: The collection of new values to be submited.
    ///     - success: Closure to be called on success.
    ///     - failure: Closure to be called on failure, with the associated error.
    ///
    public func updateSettings(settings: NotificationSettings, stream: Stream, newValues: [String: Bool], success: (() -> ())?, failure: (NSError! -> Void)?) {
        let remote = remoteFromSettings(newValues, channel: settings.channel, stream: stream)
        let pristine = stream.preferences

        // Preemptively Update the new settings
        for (key, value) in newValues {
            stream.preferences?[key] = value
        }

        notificationsServiceRemote?.updateSettings(remote,
            success: {
                success?()
            },
            failure: { (error: NSError!) in
                // Fall back to Pristine Settings
                stream.preferences = pristine
                failure?(error)
            })
    }


    /// Registers a given Push Notifications Token against the WordPress.com backend.
    ///
    /// - Parameters:
    ///     - token: Apple's Push Notifications Device Token
    ///     - success: Closure to be called on success.
    ///     - failure: Closure to be called on failure, with the associated error.
    ///
    public func registerDeviceForPushNotifications(token: String, success: ((deviceId: String) -> ())?, failure: (NSError -> Void)?) {
        if token.isEmpty {
            DDLogSwift.logWarn("Error: registerDeviceForPushNotifications called with an empty token!")
            return
        }

        notificationsServiceRemote?.registerDeviceForPushNotifications(token, success: success, failure: failure)
    }


    /// Unregisters the given deviceID for Push Notification Events.
    ///
    /// - Parameters:
    ///     - deviceId: Identifier of the device to be unregistered
    ///     - success: Closure to be called on success.
    ///     - failure: Closure to be called on failure, with the associated error.
    ///
    public func unregisterDeviceForPushNotifications(deviceId: String, success: (() -> ())?, failure: (NSError -> Void)?) {
        if deviceId.isEmpty {
            DDLogSwift.logWarn("Error: unregisterDeviceForPushNotifications called with an empty deviceId!")
            return
        }

        notificationsServiceRemote?.unregisterDeviceForPushNotifications(deviceId, success: success, failure: failure)
    }


    /// Static Helper that will parse RemoteNotificationSettings instances into a collection of
    /// NotificationSettings instances.
    ///
    /// - Parameters:
    ///     - remoteSettings: Array of RemoteNotificationSettings
    ///
    /// - Returns: An array of NotificationSettings objects
    ///
    private func settingsFromRemote(remoteSettings: [RemoteNotificationSettings]) -> [NotificationSettings] {
        var parsed       = [NotificationSettings]()
        let blogMap      = blogService.blogsForAllAccountsById() as? [Int: Blog]

        for remoteSetting in remoteSettings {
            let channel  = channelFromRemote(remoteSetting.channel)
            let streams  = streamsFromRemote(remoteSetting.streams)
            let blog     = blogForChannel(channel, blogMap: blogMap)
            let settings = NotificationSettings(channel: channel, streams: streams, blog: blog)

            parsed.append(settings)
        }

        return parsed
    }


    /// Helper method to convert RemoteNotificationSettings.Channel into a NotificationSettings.Channel enum.
    ///
    /// - Parameter remote: An instance of the RemoteNotificationSettings.Channel enum
    ///
    /// - Returns: Instance of NotificationSettings.Channel Enum
    ///
    private func channelFromRemote(remote: RemoteNotificationSettings.Channel) -> NotificationSettings.Channel {
        switch remote {
        case let .Blog(blogId):
            return .Blog(blogId: blogId)
        case .Other:
            return .Other
        case .WordPressCom:
            return .WordPressCom
        }
    }


    /// Helper method that will parse RemoteNotificationSettings.Stream instances into a collection of
    /// NotificationSettings.Stream instances.
    ///
    /// - Parameter remote: Array of RemoteNotificationSettings.Stream
    ///
    /// - Returns: An array of NotificationSettings.Stream
    ///
    private func streamsFromRemote(remote: [RemoteNotificationSettings.Stream]) -> [NotificationSettings.Stream] {
        var parsed = Array<NotificationSettings.Stream>()

        for remoteStream in remote {
            let kind    = remoteStream.kind.rawValue
            let stream  = NotificationSettings.Stream(kind: kind, preferences: remoteStream.preferences)
            parsed.append(stream)
        }

        return parsed
    }


    /// Helper method that filters the Blog associated with a specific Channel, if any.
    ///
    /// - Parameters:
    ///     - channel: An instance of the RemoteNotificationSettings.Channel enum
    ///     - blogMap: A Map of Blog entities, with their BlogID's as keys
    ///
    /// - Returns: Instance of the associated Blog, if any
    ///
    private func blogForChannel(channel: NotificationSettings.Channel, blogMap: [Int : Blog]?) -> Blog? {
        // We reuse a Blog Map by ID, since it's actually one order of magnitude faster than fetching
        // each time.
        switch channel {
        case let .Blog(blogId):
            return blogMap?[blogId]
        default:
            return nil
        }
    }


    /// Transforms a collection of Settings into a format that's the one expected by the backend,
    /// depending on whether the channel is a Site (will post the Site ID), Other or WordPress.com
    ///
    /// - Parameters:
    ///     - settings: A collection of the settings that need to be updated
    ///     - channel: A reference to the Chanel that must be updated
    ///     - stream: A reference to the Stream that must be updated
    ///
    /// - Returns: Dictionary of values, as expected by the Backend, for the specified Channel and Stream.
    ///
    private func remoteFromSettings(settings: [String: Bool], channel: Channel, stream: Stream) -> [String: AnyObject] {
        var wrappedSettings : AnyObject     = settings
        var streamKey                       = stream.kind.rawValue

        switch stream.kind {
        case .Device:
            // Devices require a special structure:
            // The backend actually expects an array of dictionaries of devices, each one with its own
            // device_id set.
            //
            var updatedSettings             = settings as [String: AnyObject]
            updatedSettings["device_id"]    = deviceId

            // Done!
            streamKey                       = "devices"
            wrappedSettings                 = [updatedSettings]
        default:
            break
        }

        // Prepare the Remote Settings Dictionary
        switch channel {
        case let .Blog(blogId):
            return [
                "blogs": [
                    [   "blog_id" : blogId,
                        streamKey : wrappedSettings
                    ]
                ]
            ]
        case .Other:
            return [
                "other": [
                    streamKey : wrappedSettings
                ]
            ]
        case .WordPressCom:
            return [ "wpcom": wrappedSettings ]
        }
    }


    // MARK: - Private Properties
    private var remoteApi : WordPressComRestApi?


    // MARK: - Private Computed Properties
    private var notificationsServiceRemote : NotificationsSettingsServiceRemote? {
        return NotificationsSettingsServiceRemote(wordPressComRestApi: remoteApi)
    }

    private var blogService : BlogService {
        return BlogService(managedObjectContext: managedObjectContext)
    }

    private var deviceId : String {
        return PushNotificationsManager.sharedInstance.deviceId ?? String()
    }
}
