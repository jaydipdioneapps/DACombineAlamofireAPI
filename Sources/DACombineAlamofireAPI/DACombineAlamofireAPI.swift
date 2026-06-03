import Foundation
import Combine
import Alamofire

final public class DACombineAlamofireAPI: Publisher {

    public static let shared = DACombineAlamofireAPI()
    init() {}

    public typealias Output = Data
    public typealias Failure = Error

    private(set) var sessionManager: Session = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 1200.0
        return Alamofire.Session(configuration: configuration)
    }()

    private(set) var headers: HTTPHeaders = ["Content-Type": "application/json"]
    private(set) var url: String = ""
    private(set) var httpMethod: HTTPMethod = .get
    private(set) var param: [String: Any]?

    private let requestLock = NSLock()
    private var _currentRequest: DataRequest?
    var currentRequest: DataRequest? {
        get { requestLock.lock(); defer { requestLock.unlock() }; return _currentRequest }
        set { requestLock.lock(); defer { requestLock.unlock() }; _currentRequest = newValue }
    }

    public func setSessionManager(_ sessionManager: Session) -> Self {
        self.sessionManager = sessionManager
        return self
    }

    public func setHeaders(_ headers: [String: String]) -> Self {
        self.headers = HTTPHeaders()
        for param in headers { self.headers[param.key] = param.value }
        return self
    }

    public func setURL(_ url: String) -> Self {
        self.url = url
        return self
    }

    public func setHttpMethod(_ httpMethod: HTTPMethod) -> Self {
        self.httpMethod = httpMethod
        return self
    }

    public func setParameter(_ param: [String: Any]) -> Self {
        self.param = param
        return self
    }

    private func encoding(_ httpMethod: HTTPMethod) -> ParameterEncoding {
        return httpMethod == .get ? URLEncoding.default : JSONEncoding.default
    }

    public func receive<S>(subscriber: S)
        where S: Subscriber, Failure == S.Failure, Output == S.Input {

        let localURL = self.url
        let localMethod = self.httpMethod
        let localParam = self.param
        let localHeaders = self.headers
        let localSession = self.sessionManager

        guard let urlQuery = localURL.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) else {
            subscriber.receive(completion: .failure(URLError(.badURL)))
            return
        }

        let encoding: ParameterEncoding = localMethod == .get
            ? URLEncoding.default
            : JSONEncoding.default

        let dataRequest = localSession.request(
            urlQuery,
            method: localMethod,
            parameters: localParam,
            encoding: encoding,
            headers: localHeaders
        )

        self.currentRequest = dataRequest

        let subscription = Subscription(request: dataRequest, target: subscriber)
        subscriber.receive(subscription: subscription)
    }

    public func cancelRequest() {
        currentRequest?.cancel()
    }
}

extension DACombineAlamofireAPI {

    private final class Subscription<Target: Subscriber>: Combine.Subscription
        where Target.Input == Output, Target.Failure == Failure {

        private let lock = NSLock()
        private var target: Target?
        private let request: DataRequest
        private var isCancelled = false

        init(request: DataRequest, target: Target) {
            self.request = request
            self.target = target
        }

        func request(_ demand: Subscribers.Demand) {
            assert(demand > 0)

            lock.lock()
            let capturedTarget = target
            lock.unlock()

            guard let target = capturedTarget else { return }

            request.responseData { [weak self] response in
                guard let self = self else { return }

                self.lock.lock()
                let cancelled = self.isCancelled
                self.lock.unlock()
                guard !cancelled else { return }

                if let error = response.error {
                    if case .sessionTaskFailed(let sessionError) = error,
                       let urlError = sessionError as? URLError {
                        let codes: [Int] = [
                            DAHTTPStatusCode.networkConnectionLost.rawValue,
                            DAHTTPStatusCode.noInternetConnection.rawValue,
                            DAHTTPStatusCode.networkRequestTimeout.rawValue,
                            DAHTTPStatusCode.serverError.rawValue
                        ]
                        if codes.contains(urlError.code.rawValue) {
                            self.deliver(
                                errorStatus: urlError.code.rawValue,
                                message: error.localizedDescription,
                                to: target
                            )
                            return
                        }
                    }
                }

                switch response.result {
                case .success:
                    let result = self.checkResponse(response: response)
                    if result.success, let value = response.value {
                        _ = target.receive(value)
                        target.receive(completion: .finished)
                    } else {
                        self.deliver(
                            errorStatus: result.statusCode,
                            message: result.message,
                            to: target
                        )
                    }

                case .failure:
                    let statusCode = response.response?.statusCode ?? 404
                    let errorCodes = [
                        DAHTTPStatusCode.unauthorized.rawValue,
                        DAHTTPStatusCode.internalServerError.rawValue,
                        DAHTTPStatusCode.badRequest.rawValue,
                        DAHTTPStatusCode.forbidden.rawValue,
                        DAHTTPStatusCode.notFound.rawValue,
                        DAHTTPStatusCode.badGateway.rawValue,
                        DAHTTPStatusCode.serviceUnavailable.rawValue,
                        DAHTTPStatusCode.gatewayTimeout.rawValue,
                        DAHTTPStatusCode.serverError.rawValue
                    ]
                    if errorCodes.contains(statusCode) {
                        self.deliver(
                            errorStatus: statusCode,
                            message: response.error?.localizedDescription ?? "",
                            to: target
                        )
                    }
                }

                self.lock.lock()
                self.target = nil
                self.lock.unlock()
            }
            .resume()
        }

        private func deliver(errorStatus: Int, message: String, to target: Target) {
            let errorModel = DAErrorModel(status: errorStatus, message: message)
            if let encoded = try? JSONEncoder().encode(errorModel) {
                _ = target.receive(encoded)
            }
            target.receive(completion: .finished)
        }

        private func checkResponse(
            response: AFDataResponse<Data>
        ) -> (statusCode: Int, message: String, success: Bool) {
            let errorCodes = [
                DAHTTPStatusCode.unauthorized.rawValue,
                DAHTTPStatusCode.internalServerError.rawValue,
                DAHTTPStatusCode.badRequest.rawValue,
                DAHTTPStatusCode.forbidden.rawValue,
                DAHTTPStatusCode.notFound.rawValue,
                DAHTTPStatusCode.badGateway.rawValue,
                DAHTTPStatusCode.serviceUnavailable.rawValue,
                DAHTTPStatusCode.gatewayTimeout.rawValue
            ]
            guard let statusCode = response.response?.statusCode,
                  errorCodes.contains(statusCode) else {
                return (DAHTTPStatusCode.accepted.rawValue, "Success", true)
            }
            if let data = response.value,
               let eModel = try? JSONDecoder().decode(ResponseModel.self, from: data) {
                return (statusCode, eModel.message, false)
            }
            return (statusCode, response.error?.localizedDescription ?? "", false)
        }

        func cancel() {
            lock.lock()
            isCancelled = true
            target = nil
            lock.unlock()
            request.cancel()
        }
    }
}
