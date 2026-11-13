import UIKit
import Nuke
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // The original also called FirebaseApp.configure(); Firebase is intentionally removed.
        DefaultSettings.register()  // improvement: one default per settings key (DefaultSettings.values)
        UNUserNotificationCenter.current().delegate = self
        // improvement (critique r1): a poster gives up after `siteTimeout` without data, like the site's pages. Nuke waited
        // 60 s, and its six loading slots held a stalled poster, so the page's poster stayed a grey fill.
        let images = DataLoader.defaultConfiguration
        images.timeoutIntervalForRequest = siteTimeout
        ImagePipeline.shared = ImagePipeline(configuration: .init(dataLoader: DataLoader(configuration: images)))
        return true
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        DownloadManager.shared.backgroundCompletionHandler = completionHandler
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound, .badge])
    }
}
