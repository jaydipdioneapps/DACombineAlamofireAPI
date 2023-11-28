//
//  DAError.swift
//  DACombineAlamofireAPI
//

import Foundation

public enum DAError: LocalizedError {
    case unauthorized
    case noInternetConnection
    case internalServerError
    case badRequest
    case forbidden
    case notFound
    case badGateway
    case serviceUnavailable
    case gatewayTimeout
    case other

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Access is denied. User is unauthorized."
        case .badRequest:
            return "Bad request."
        case .forbidden:
            return "Forbidden."
        case .notFound:
            return "Page not found."
        case .badGateway:
            return "Bad gateway."
        case .serviceUnavailable:
            return "Service unavailable."
        case .gatewayTimeout:
            return "Gateway timeout."
        case .internalServerError:
            return "Internal server error."
        case .noInternetConnection:
            return "Please check your internet connection and try again later."
        case .other:
            return ""
        }
    }
}

public struct DAErrorModel {
    let status : DAError
    let message : String
    
    init(status: DAError, message: String) {
        self.status = status
        self.message = message
    }
}
