import Foundation

public class CacheValidator {

    private static let notCachingRequests: [String] = [
        "/account/profiles",
        "/account/profiles/set/",
        "/account/profiles/",
        "/account/api",
        "/api/swatched",
        "/api/site_settings",
        "/account/videoreq/search",
        "/account/videoreq/all",
        "/account/videoreq/add",
        "/account/movielists"
    ]

    static func allowStorageFor(_ path: String) -> Bool {
        return !notCachingRequests.contains(path)
    }
}
