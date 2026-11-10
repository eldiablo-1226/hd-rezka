import Foundation

/// URL of the film currently open in DetailsView; ShareButton reads it.
class SharedFilmId {
    static var id: String = ""
}

class SystemVersion {
    let os: OperatingSystemVersion
    let osString: String

    /// As inlined in UINavigationController.viewDidLoad (0x1000e006c): two fresh ProcessInfo instances.
    init() {
        os = ProcessInfo().operatingSystemVersion
        osString = ProcessInfo().operatingSystemVersionString
    }
}
