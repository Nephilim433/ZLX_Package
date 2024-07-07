import Foundation
import Cache

public class CacheManager {
    // MARK: - Properties

    public static let shared = CacheManager()
    
    private let storage: Storage<String,Data>?
    private let defaultExpiry = Expiry.seconds(2 * 60)

    // MARK: - Init/deinit

    private init() {
        let diskConfig = DiskConfig(name: "ResponseCache")
        let memoryConfig = MemoryConfig(expiry: defaultExpiry, countLimit: 50, totalCostLimit: 50)
        let transformer = TransformerFactory.forCodable(ofType: Data.self)
        self.storage = try? Storage(diskConfig: diskConfig, memoryConfig: memoryConfig, transformer: transformer)
    }

    // MARK: - Public methods

    public func dataWith(key: String) -> Data? {
        guard let storage = storage else {
            return nil
        }
        return try? storage.object(forKey: key)
    }

    public func store(response: URLResponse?, data: Data?) {
        guard let data = data,
            let response = response,
            let path = response.url?.path else {
            return
        }
        let expiry = expiryFrom(response: response)
        store(data: data, path: path, expiry: expiry)
    }

    public func store(urlString: String, data: Data?) {
        guard let data = data else {
            return
        }
        store(data: data, path: urlString, expiry: nil)
    }

    public func removeExpiredObjects() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            try? self?.storage?.removeExpiredObjects()
        }
    }
    
    public func removeObjectsForKey(_ key: String, completion: (()->Void)? = nil) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            try? self?.storage?.removeObject(forKey: key)
            completion?()
        }
    }
    
    public func clear() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            try? self?.storage?.removeAll()
        }
    }

    // MARK: - Private methods

    private func expiryFrom(response: URLResponse) -> Expiry? {
        guard let httpResponse = response as? HTTPURLResponse,
            let headers = httpResponse.allHeaderFields as? [String : String] else {
                return nil
        }
        if let header = headers["Cache-Control"],
            let maxAgeString = header.components(separatedBy: ", max-age=").last,
            let maxAge = TimeInterval(maxAgeString) {
            return Expiry.seconds(maxAge)
        }
        return nil
    }

    private func store(data: Data, path: String, expiry: Expiry?) {
        guard CacheValidator.allowStorageFor(path) else {
            return
        }
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else {
                return
            }
            try? self.storage?.setObject(data, forKey: path, expiry: expiry ?? self.defaultExpiry)
        }
    }
}
