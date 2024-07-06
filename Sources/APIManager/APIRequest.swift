import Foundation
import Alamofire
import AdSupport

public enum RequestType: String {
    case GET, POST, PUT, DELETE
    
    var httpMethod: HTTPMethod {
        switch self {
        case .GET: return .get
        case .POST: return .post
        case .PUT: return .put
        case .DELETE: return .delete
        }
    }
}

public enum APIError: Error {
    case unableCreateURL
    case dataCorrupted
}

public struct QueryField {
    public let key: String
    public let value: String
    
    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

public protocol APIRequest {
    
    var body: Data? { get }
    var path: String { get }
    var method: RequestType { get }
    var additionalHeaders: [String:String]? { get }
    var queryFields: [String: String]? { get }
    var queryFieldsArray: [QueryField]? { get }
}

@available(macOS 10.14, *)
public extension APIRequest {
    var encoding: ParameterEncoding { return URLEncoding.default }
   
    var baseURL: URL {
        let baseUrlString = APIClient.shared.baseUrlString
        return URL(string: baseUrlString)!
    }
    
    var url: URL {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        
        var queryDictionary = ["src":"mobileapp"]
        
        let u = APIClient.shared.uID
        if u.count > 0 {
            queryDictionary.merge(["_u": u], uniquingKeysWith: {$1})
        }
        
        let profileType = APIClient.shared.profileType
        if profileType.count > 0 {
            queryDictionary.merge(["profile_type": profileType], uniquingKeysWith: {$1})
        }

        if let query = queryFields {
            queryDictionary.merge(query, uniquingKeysWith: {$1})
        }

        let queryFromDictionary = (queryDictionary
            .sorted(by: { $0.key < $1.key } )
            .compactMap { (key, value) -> String in
                return "\(key)=\(value)"
            } as Array).joined(separator: "&")

        let queryFromArray = queryFieldsArray?.compactMap({ (field: QueryField) -> String in
            return "\(field.key)=\(field.value)"
        }).joined(separator: "&") ?? ""
        
        let query: String = [queryFromDictionary, queryFromArray].filter { $0.count > 0 }.joined(separator: "&")
        
        components.query = query

        return try! components.asURL()
    }
    var httpMethod: HTTPMethod { return method.httpMethod }
    var headers: HTTPHeaders {
        return HTTPHeaders(["Accept":"application/json",
                            "Accept-Charset":"UTF-8",
                            "Content-Type":"application/x-www-form-urlencoded",
                            "X-Device-Id": ASIdentifierManager.shared().advertisingIdentifier.uuidString]
            .merging(additionalHeaders ?? [:], uniquingKeysWith: { $1 })) }
    
    var queryFieldsArray: [QueryField]? {
        return []
    }
}
