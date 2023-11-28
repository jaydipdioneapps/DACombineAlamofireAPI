//
//  DAError.swift
//  DACombineAlamofireAPI
//

import Foundation


public struct ResponseModel: Codable {
    public let status : String
    public let message : String
    
    enum CodingKeys: String, CodingKey {
        case status = "status"
        case message = "message"
    }
}

public struct DAErrorModel: Codable {
    public let status : Int
    public let message : String
    
    init(status: Int, message: String) {
        self.status = status
        self.message = message
    }
    enum CodingKeys: String, CodingKey {
        case status = "status"
        case message = "message"
    }
}
