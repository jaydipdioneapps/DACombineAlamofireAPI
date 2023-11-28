//
//  DAError.swift
//  DACombineAlamofireAPI
//

import Foundation

public struct DAErrorModel: Codable {
    let status : Int
    let message : String
    
    init(status: Int, message: String) {
        self.status = status
        self.message = message
    }
    enum CodingKeys: String, CodingKey {
        case status = "status"
        case message = "message"
    }
}
