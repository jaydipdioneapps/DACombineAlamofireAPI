//
//  DAError.swift
//  DACombineAlamofireAPI
//

import Foundation

public enum DAError: LocalizedError {
    case unauthorized
    case noInternetConnection

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Access is denied. User is unauthorized."
        case .noInternetConnection:
            return "Please check your internet connection and try again later."
        }
    }
}
