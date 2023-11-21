//
//  PolkaChatApp.swift
//  PolkaChat
//
//  Created by Daniel Leping on 15/02/2023.
//

import SwiftUI

@main
struct PolkaChatApp: App {
    private let model: ViewModel
    private let error: ErrorModel
    
    init() {
        let errorModel = ErrorModel()
        
        self.model = ViewModel(core: try! Core(errors: errorModel), error: errorModel)
        self.error = errorModel
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(model: model, error: error)
        }
    }
}
