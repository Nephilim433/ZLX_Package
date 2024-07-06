import Foundation
import RxSwift

public enum HTTPCodes {
    public static let tooManyRequests = 429
    public static let unauthorized = 401
    public static let forbidden = 403
}

public protocol BaseResponse {}

public protocol APIResponse: BaseResponse {
    
    associatedtype Success: Codable
    
    var success: Success? { get }
    var failure: String? { get }
    var statusCode: Int? { get }

    init(success: Success?, failure: String?, statusCode: Int?)
}

public struct APIDataResponse: BaseResponse {
    
    public var data: Data?
    public var failure: String?
    public var statusCode: Int?

}

public struct APICodeResponse: BaseResponse {
    
    public var code: Int?
    public var failure: String?
}

public struct ServerResponse: Codable {
    
    public let status: Int
    public let message: String?
}

public struct ServerError: Codable {
    
    public let error: Int?
    public let message: String?
}

public class APIClient {

    // MARK:- Variables
    
    public var uID = ""
    public var profileID = ""
    public var profileType = ""

    public let logoutAction = PublishSubject<Void>()
    public let cookiesKey = "Cookie"
    
    private let setCookiesKey = "Set-Cookie"
    private let isNeedUseDevDomainKey = "is_dev_domain"
    
    private var cookiesString: String?


    private var session: URLSession {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.httpCookieAcceptPolicy = .never
        //sessionConfiguration.httpShouldSetCookies = true
        sessionConfiguration.httpCookieStorage?.removeCookies(since: Date())
        if let url = URL(string: baseUrlString), cookies.count > 0 {
            sessionConfiguration.httpCookieStorage?.setCookies(cookies, for: url, mainDocumentURL: url)
        }
        //sessionConfiguration.httpCookieStorage?.setCookie(cookies)
        let session = URLSession(configuration: sessionConfiguration)
        return session
    }

    private var cookies: [HTTPCookie] {
        set {
            var cookieDict = [String : AnyObject]()

            newValue.forEach { (cookie) in
                cookieDict[cookie.name] = cookie.properties as AnyObject?
            }
            //print("\(cookieDict)")
            UserDefaults.standard.set(cookieDict , forKey: cookiesKey)
        }
        get {
            
            var storedCookies: [HTTPCookie] = []
            if let cookieDictionary = UserDefaults.standard.dictionary(forKey: cookiesKey) {

                for (_, cookieProperties) in cookieDictionary {
                    if let cookie = HTTPCookie(properties: cookieProperties as! [HTTPCookiePropertyKey : Any] ) {
                        storedCookies.append(cookie)
                    }
                }
                
                if storedCookies.count != 0 && profileID != "" {
                    
                    if  let url = URL(string: baseUrlString.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "/", with: "")){
                        let profileCookie = HTTPCookie(properties: [HTTPCookiePropertyKey.name : "profile_id",
                                                                    HTTPCookiePropertyKey.value: profileID,
                                                                    HTTPCookiePropertyKey.domain: url.absoluteString,
                                                                    HTTPCookiePropertyKey.path : "/",
                                                                    HTTPCookiePropertyKey.secure: "FALSE",
                                                                    HTTPCookiePropertyKey.expires: Date(timeIntervalSinceNow: 60*60*24*30*360)])
                        
                        if let profileCookie = profileCookie {
                            storedCookies.append(profileCookie)
                        }
                    }
                }
            }
            return storedCookies
        }
    }
    
    

    /*
     public var minimalCookiesRequired: [String:String] {
        guard let components = self.cookies[cookiesKey]?.components(separatedBy: "; "),
            let profileString = (components.filter { $0.contains("profile_id=") }.first),
            let sessionString = (components.filter({ $0.contains("session=") }).first),
            let index = sessionString.range(of: "session=")?.lowerBound else {
                return [:]
        }
        let filteredCookie = [profileString, String(sessionString.suffix(from: index))].joined(separator: "; ")
        return [cookiesKey : filteredCookie]
    }
     */
    
    public var isLoggedIn: Bool {
        return !cookies.first!.value.isEmpty
    }
    
    
    // MARK: - Dev domain logic
    public var baseUrlString: String {
        !isNeedUseDevDomain ? standardURL : self.standardURL.transformToDevDomainString()
    }
    private let standardURL =  "https://flx-m.com/"
    
    /* new logic for dev domain logic. **/
    public var isNeedUseDevDomainStatic: Bool?
    
    
    public var isNeedUseDevDomain: Bool {
        set {
            isNeedUseDevDomainStatic = newValue
            
            UserDefaults.standard.set(newValue, forKey: isNeedUseDevDomainKey)
            UserDefaults.standard.synchronize()
        }
        get {
            if let isNeedUseDevDomainStatic = isNeedUseDevDomainStatic {
                return isNeedUseDevDomainStatic
            } else {
                let isNeedUseDevDomain = UserDefaults.standard.bool(forKey: isNeedUseDevDomainKey)
                return isNeedUseDevDomain
            }
        }
    }
    
    
    // MARK:- Init and Deinit
    
    private init() {}
    static public let shared = APIClient()

    // MARK:- Private
    
    private func setCookies(response: URLResponse) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                let httpResponse = response as? HTTPURLResponse,
                let headers = httpResponse.allHeaderFields as? [String: String],
                let url = response.url else {
                    return
            }
            
            if let setCookie = headers["Set-Cookie"], setCookie.contains("session=") {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
                self.cookies = cookies
            }
        }
    }
    
    public func removeCookies() {
        cookies = []
        UserDefaults.standard.set(nil, forKey: cookiesKey)
    }
    
    public func clearProfileID() {
        profileID = ""
    }
    
    private func prepareRequest(_ request: APIRequest) -> URLRequest {
        var urlRequest = URLRequest(url: request.url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30.0)
        urlRequest.httpMethod = request.httpMethod.rawValue
        let headers = request.headers/*.dictionary.merging(cookies, uniquingKeysWith: { (base, other) -> String in
            return base
        })*/
        urlRequest.allHTTPHeaderFields = headers.dictionary
        urlRequest.httpBody = request.body
        logRequest(URL: urlRequest.urlRequest?.url)
        return urlRequest
    }

    private func logRequest(URL: URL?) {
        guard let url = URL, var urlString = URL?.absoluteString else {
            return
        }
        let shouldCropWatched = (url.path == "/api/watched" || url.path == "/api/swatched")
        if let index = url.absoluteString.range(of: "?")?.upperBound, shouldCropWatched {
           urlString = String(url.absoluteString.prefix(upTo: index))
        }
        print("📤", urlString)
    }

    private func logHeaders(_ headers: [String : String]?) {
        print("headers: " , headers ?? "No headers")
    }

    private func checkAuthorizationWith(statusCode: Int?) {
        let notAuthorized = [HTTPCodes.unauthorized].contains(statusCode)
        guard notAuthorized else {
            return
        }
        logoutAction.onNext(())
    }

    // MARK:- Public

    /// Request with retrieving data from server and decoding to resulting type
    public func execute<T, R: APIResponse>(_ request: APIRequest) -> Observable<R> where R.Success == T {
        return Observable<R>.create { [weak self] observer in
            let unknownErrorString = "Unknown Error"

            CacheManager.shared.removeExpiredObjects()
            
            if let data = CacheManager.shared.dataWith(key: request.url.absoluteString),
                let success = try? JSONDecoder().decode(T.self, from: data) {
                let result = R(success: success, failure: nil, statusCode: 200)
                DispatchQueue.main.async {
                    observer.onNext(result)
                }
                return Disposables.create()
            }

            guard let self = self else {
                observer.onNext(R(success: nil, failure: unknownErrorString, statusCode: nil))
                
                return Disposables.create()
            }
            
            let urlRequest = self.prepareRequest(request)
            
            let task = self.session.dataTask(with: urlRequest, completionHandler: { [weak self] (data, response, error) in
                response.map {
                    self?.setCookies(response: $0)
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == HTTPCodes.tooManyRequests {
                    let tooManyRequestError = "The list is too huge. Please try to change the filter or use a search"
                    let result = R(success: nil, failure: tooManyRequestError, statusCode: HTTPCodes.tooManyRequests)
                    DispatchQueue.main.async {
                        observer.onNext(result)
                    }
                    
                    return
                }
                let statusCode = (response as? HTTPURLResponse)?.statusCode
                self?.checkAuthorizationWith(statusCode: statusCode)
                if let value = data {
                    
                    do {
                        if let jsonArray = try? JSONSerialization.jsonObject(with: value, options : .allowFragments)
                        {
                           print(jsonArray) // use the json here
                        } else {
                            print("bad json")
                        }
                    } catch let error as NSError {
                        print(error)
                    }
                    
                    let decoder = JSONDecoder()
                    do {
                        let _ = try decoder.decode(T.self, from: value)
                    } catch let error {
                        print("⚠️ Decoding error:", error)
                        if let JSONString = String(data: value, encoding: String.Encoding.utf8) {
                            print(JSONString)
                        }
                        print(urlRequest.curlString)
                    }
                    if let success = try? decoder.decode(T.self, from: value) {
                        let result = R(success: success, failure: nil, statusCode: statusCode)
                        CacheManager.shared.store(response: response, data: data)
                        DispatchQueue.main.async {
                            observer.onNext(result)
                        }
                    } else {
                        let decoder = JSONDecoder()
                        let failure = try? decoder.decode(ServerError.self, from: value)
                        let result = R(success: nil, failure: failure?.message ?? unknownErrorString, statusCode: statusCode)
                        DispatchQueue.main.async {
                            observer.onNext(result)
                        }
                    }
                } else if let err = error {
                    let result = R(success: nil, failure: err.localizedDescription, statusCode: statusCode)
                    DispatchQueue.main.async {
                        observer.onNext(result)
                    }
                }
            })
            
            task.resume()
            
            return Disposables.create {}
        }
    }

    /// Request with that return data task
    public func execute(_ request: APIRequest, compeltion: @escaping (Data?, URLResponse?, Error?) -> ()) -> URLSessionDataTask? {
        let urlRequest = self.prepareRequest(request)

        CacheManager.shared.removeExpiredObjects()
        
        if let data = CacheManager.shared.dataWith(key: request.url.absoluteString) {
            compeltion(data, nil, nil)
            return nil
        }

        let task = self.session.dataTask(with: urlRequest, completionHandler: { [weak self] (data, response, error) in
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            self?.checkAuthorizationWith(statusCode: statusCode)
            response.map { self?.setCookies(response: $0) }
            CacheManager.shared.store(response: response, data: data)
            compeltion(data, response, error)
        })
        task.resume()
        return task
    }

    
    /// Request with retrieving data and returning it as raw Data
    /// Be careful: data is getting without switching to main thread
    public func execute(_ request: APIRequest) -> Observable<APIDataResponse> {
        return Observable<APIDataResponse>.create { [weak self] observer in
            let unknownErrorString = "Unknown Error"
            guard let self = self else {
                let result = APIDataResponse(data: nil, failure: unknownErrorString, statusCode: nil)
                observer.onNext(result)
                return Disposables.create()
            }

            CacheManager.shared.removeExpiredObjects()
            
            if let data = CacheManager.shared.dataWith(key: request.url.absoluteString) {
                let result = APIDataResponse(data: data, failure: nil, statusCode: nil)
                observer.onNext(result)
                return Disposables.create()
            }

            let urlRequest = self.prepareRequest(request)
            let task = self.session.dataTask(with: urlRequest, completionHandler:  { [weak self] (data, response, error) in
                response.map { self?.setCookies(response: $0) }
                
                let statusCode = (response as? HTTPURLResponse)?.statusCode
                //print(":=-> \(urlRequest.urlRequest), response with status code:\(statusCode)")

                self?.checkAuthorizationWith(statusCode: statusCode)
                if let value = data {
                    
//                    if let json = try? JSONSerialization.jsonObject(with: value, options : .allowFragments) {
//                        print(":=-> json data= \(json)") // use the json here
//                    } else {
//                        print(":=-> bad json")
//                    }
                    
                    CacheManager.shared.store(response: response, data: data)
                    let result = APIDataResponse(data: value, failure: nil, statusCode: statusCode)
                    observer.onNext(result)
                } else if let err = error {
                    let result = APIDataResponse(data: nil, failure: err.localizedDescription, statusCode: statusCode)
                    observer.onNext(result)
                }
            })
            
            task.resume()
            
            return Disposables.create()
        }
    }

    public func execute(_ request: APIRequest) -> Observable<Bool> {
        return Observable<Bool>.create { [weak self] observer in
            guard let self = self else {
                observer.onNext(false)
                return Disposables.create()
            }
            let urlRequest = self.prepareRequest(request)
            let task = self.session.dataTask(with: urlRequest, completionHandler:  { [weak self] (data, response, error) in
                let statusCode = (response as? HTTPURLResponse)?.statusCode
                print("🔰 Status code: ", statusCode ?? 0)
                if statusCode != 200 {
                    print(urlRequest.curlString)
                }
                self?.checkAuthorizationWith(statusCode: statusCode)
                observer.onNext(statusCode == 200)
            })
            task.resume()
            return Disposables.create()
        }
    }

    // MARK: - Request without retrieving data from server

    public func execute(_ request: APIRequest) -> Observable<APICodeResponse> {
        return Observable<APICodeResponse>.create { [weak self] (observer) in
            let unknownErrorString = "Unknown Error"
            
            guard let self = self else {
                observer.onNext(APICodeResponse(code: nil, failure: unknownErrorString))
                
                return Disposables.create()
            }
            
            let urlRequest = self.prepareRequest(request)
            
            let task = self.session.dataTask(with: urlRequest, completionHandler: { [weak self] (data, response, error) in
                response.map { self?.setCookies(response: $0) }
                let statusCode = (response as? HTTPURLResponse)?.statusCode
                self?.checkAuthorizationWith(statusCode: statusCode)

                if let _ = data, let httpResponse = response as? HTTPURLResponse {
                    let result = APICodeResponse(code: httpResponse.statusCode, failure: nil)
                    DispatchQueue.main.async {
                        observer.onNext(result)
                    }
                } else if let err = error, let httpResponse = response as? HTTPURLResponse {
                    let result = APICodeResponse(code: httpResponse.statusCode, failure: err.localizedDescription)
                    DispatchQueue.main.async {
                        observer.onNext(result)
                    }
                }
            })
            
            task.resume()
            
            return Disposables.create {}
        }
    }
}

// MARK: - CURL string

extension URLRequest {

    public var curlString: String {
        // Logging URL requests in whole may expose sensitive data,
        // or open up possibility for getting access to your user data,
        // so make sure to disable this feature for production builds!
        #if !DEBUG
        return ""
        #else
        guard let url = url else {
            return ""
        }

        var baseCommand = "curl"

        if httpMethod == "HEAD" {
            baseCommand += " --head"
        }

        var command = [baseCommand]

        if let method = httpMethod, method != "HEAD" {
            command.append("-X \(method)")
        }

        command.append("'" + url.absoluteString + "'")

        if let headers = allHTTPHeaderFields {
            for (key, value) in headers {
                command.append("-H '\(key): \(value)'")
            }
        }

        if let data = httpBody, let body = String(data: data, encoding: .utf8) {
            command.append("-d '\(body)'")
        }

        return command.joined(separator: " \\\n\t")
        #endif
    }
}


extension String {
    func transformToDevDomainString() -> String {
        let dev = self.replacingOccurrences(of: "//", with: ("//" + "dev."))
        
        return dev
    }
}

