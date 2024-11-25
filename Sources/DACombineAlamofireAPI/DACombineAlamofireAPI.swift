import Foundation
import Combine
import Alamofire


final public class DACombineAlamofireAPI: Publisher {
    
    /// `Singleton` variable of API class
    public static let shared = DACombineAlamofireAPI()
    
    /// It's private for subclassing
    private init() {}
    
    // MARK: Types
    
    /// The response of data type.
    public typealias Output = Data
    public typealias Failure = Error
    
    // MARK: - Properties
    
    /// `Session` creates and manages Alamofire's `Request` types during their lifetimes. It also provides common
    /// functionality for all `Request`s, including queuing, interception, trust management, redirect handling, and response
    /// cache handling.
    private(set) var sessionManager: Session = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 1200.0
        return Alamofire.Session(configuration: configuration)
    }()
    
    /// `HTTPHeaders` value to be added to the `URLRequest`. Set `["Content-Type": "application/json"]` by default..
    private(set) var headers: HTTPHeaders = ["Content-Type": "application/json"]
        
    /// `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    private(set) var url: String = ""
    
    /// `HTTPMethod` for the `URLRequest`. `.get` by default..
    private(set) var httpMethod: HTTPMethod = .get
    
    /// `Param` (a.k.a. `[String: Any]`) value to be encoded into the `URLRequest`. `nil` by default..
    private(set) var param: [String: Any]?
    
         
    // MARK: - Initializer
    
    /// Set param
    ///
    /// - Parameter sessionManager: `Session` creates and manages Alamofire's `Request` types during their lifetimes.
    /// - Returns: Self
    public func setSessionManager(_ sessionManager: Session) -> Self {
        self.sessionManager = sessionManager
        return self
    }
    
    /// Set param
    ///
    /// - Parameter headers: a dictionary of parameters to apply to a `HTTPHeaders`.
    /// - Returns: Self
    public func setHeaders(_ headers: [String: String]) -> Self {
        self.headers = HTTPHeaders()
        for param in headers {
            self.headers[param.key] = param.value
        }
        return self
    }
    
    /// Set url
    ///
    /// - Parameter apiUrl: URL to set for api request
    /// - Returns: Self
    public func setURL(_ url: String) -> Self {
        self.url = url
        return self
    }
    
    /// Set httpMethod
    ///
    /// - Parameter httpMethod: to change as get, post, put, delete etc..
    /// - Returns: Self
    public func setHttpMethod(_ httpMethod: HTTPMethod) -> Self {
        self.httpMethod = httpMethod
        return self
    }
    
    /// Set param
    ///
    /// - Parameter param: a dictionary of parameters to apply to a `URLRequest`.
    /// - Returns: Self
    public func setParameter(_ param: [String:Any]) -> Self {
        self.param = param
        return self
    }
    
    
    /// The parameter encoding. `URLEncoding.default` by default.
    private func encoding(_ httpMethod: HTTPMethod) -> ParameterEncoding {
        var encoding : ParameterEncoding = JSONEncoding.default
        if httpMethod == .get {
            encoding = URLEncoding.default
        }
        return encoding
    }
    
    /// Subscriber for `observer` that can be used to cancel production of sequence elements and free resources.
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        
        guard let urlQuery = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            // Handle the error, such as by throwing an exception or logging it
            debugPrint("Error: Invalid URL or unable to percent encode")
            subscriber.receive(completion: .failure(URLError(.badURL)))
            return
        }
        
        /// Creates a `DataRequest` from a `URLRequest`.
        /// Responsible for creating and managing `Request` objects, as well as their underlying `NSURLSession`.
        let request = sessionManager.request(urlQuery,
                                             method: httpMethod,
                                             parameters: param,
                                             encoding: self.encoding(httpMethod),
                                             headers: self.headers)
            /*.cURLDescription { description in
                debugPrint(" cURL Request ")
                debugPrint(description)
                debugPrint("")
            }*/
            
        subscriber.receive(subscription: Subscription(request: request, target: subscriber))
    }
}

extension DACombineAlamofireAPI {
    // MARK: - Subscription -
    private final class Subscription<Target: Subscriber>: Combine.Subscription where Target.Input == Output, Target.Failure == Failure {
        private var target: Target?
        private let request: DataRequest
        
        init(request: DataRequest, target: Target) {
            self.request = request
            self.target = target
        }
        
        func request(_ demand: Subscribers.Demand) {
            assert(demand > 0)

            guard let target = target else { return }
            
            self.target = nil
            request.responseData { response in
                
                if let error = response.error {
                    switch error {
                    case .sessionTaskFailed(let sessionError):
                        // Handle specific session errors here
                        if let urlError = sessionError as? URLError {
                            if urlError.code.rawValue == DAHTTPStatusCode.networkConnectionLost.rawValue || urlError.code.rawValue == DAHTTPStatusCode.noInternetConnection.rawValue || urlError.code.rawValue == DAHTTPStatusCode.networkRequestTimeout.rawValue || urlError.code.rawValue == DAHTTPStatusCode.serverError.rawValue {
                                let errorModel = DAErrorModel(status: urlError.code.rawValue, message: error.localizedDescription)
                                _ = target.receive(try! JSONEncoder().encode(errorModel))
                                target.receive(completion: .finished)
                                return
                            }
                        }
                    default:
                        break
                    }
                }

                switch response.result {
                case .success :
                    let result = self.checkResponse(response: response)
                    if result.success {
                        _ = target.receive(response.value!)
                        target.receive(completion: .finished)
                    } else {
                        let errorModel = DAErrorModel(status: result.statusCode, message: result.message)
                        _ = target.receive(try! JSONEncoder().encode(errorModel))
                        target.receive(completion: .finished)
                    }
                case .failure(let error):
                    switch response.response?.statusCode {
                    case DAHTTPStatusCode.unauthorized.rawValue,DAHTTPStatusCode.internalServerError.rawValue,DAHTTPStatusCode.badRequest.rawValue,DAHTTPStatusCode.forbidden.rawValue,DAHTTPStatusCode.notFound.rawValue,DAHTTPStatusCode.badGateway.rawValue,DAHTTPStatusCode.serviceUnavailable.rawValue,DAHTTPStatusCode.gatewayTimeout.rawValue, DAHTTPStatusCode.serverError.rawValue:
                        let errorModel = DAErrorModel(status: response.response?.statusCode ?? 404, message: response.error?.localizedDescription ?? "")
                        _ = target.receive(try! JSONEncoder().encode(errorModel))
                        target.receive(completion: .finished)
                        return
                    default:
                        return

                    }
                }
            }
            .resume()
        }
        
        func checkResponse(response: AFDataResponse<Data>) -> (statusCode: Int, message: String, success: Bool) {
            switch response.response?.statusCode {
            case DAHTTPStatusCode.unauthorized.rawValue,DAHTTPStatusCode.internalServerError.rawValue,DAHTTPStatusCode.badRequest.rawValue,DAHTTPStatusCode.forbidden.rawValue,DAHTTPStatusCode.notFound.rawValue,DAHTTPStatusCode.badGateway.rawValue,DAHTTPStatusCode.serviceUnavailable.rawValue,DAHTTPStatusCode.gatewayTimeout.rawValue:
                do {
                    let eModel = try JSONDecoder().decode(ResponseModel.self, from: response.value!)
                    return (response.response?.statusCode ?? 404, eModel.message, false)
                } catch {
                    return (response.response?.statusCode ?? 404, response.error?.localizedDescription ?? "", false)
                }
            default:
                return (DAHTTPStatusCode.accepted.rawValue, "Success", true)

            }
        }
        
        func cancel() {
            request.cancel()
            target = nil
        }
    }
}

