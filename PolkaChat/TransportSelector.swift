//
//  TransportSelector.swift
//  PolkaChat
//
//  Created by Yehor Popovych on 21/11/2023.
//

import Foundation
import TesseractClient

final class TransportSelector: TesseractDelegate {
    private let errors: ErrorModel
    
    init(errors: ErrorModel) {
        self.errors = errors
    }
    
    func select(transports: Dictionary<String, Status>) async -> String? {
        assert(transports.count == 1, "How the heck do we have more than one transport here?")
        
        let tId = transports.first!.key
        let status = transports.first!.value
        
        switch status {
        case .ready: return tId
        case .unavailable(let reason):
            let m = "Transport '\(tId)' is not available because of the following reason: \(reason)"
            await errors.presentError(message: m)
            return nil
        case .error(let err):
            let m = "Transport '\(tId)' is not available because the transport produced an error: \(err)"
            await errors.presentError(message: m)
            return nil
        }
    }
}
