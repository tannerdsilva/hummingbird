//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HummingbirdCore

/// Group of middleware that can be used to create a responder chain. Each middleware calls the next one
public final class HBMiddlewareGroup<Context> {
    var middlewares: [any HBMiddlewareProtocol<Context>]

    /// Initialize `HBMiddlewareGroup`
    ///
    /// Set middleware array to be empty
    public init() {
        // this is set by WebSocketRouterGroup so this needs to be kept public
        self.middlewares = []
    }

    init(middlewares: [any HBMiddlewareProtocol<Context>]) {
        self.middlewares = middlewares
    }

    /// Add middleware to group
    public func add(_ middleware: any HBMiddlewareProtocol<Context>) {
        self.middlewares.append(middleware)
    }

    /// Construct responder chain from this middleware group
    /// - Parameter finalResponder: The responder the last middleware calls
    /// - Returns: Responder chain
    public func constructResponder(finalResponder: any HBResponder<Context>) -> any HBResponder<Context> {
        var currentResponser = finalResponder
        for i in (0..<self.middlewares.count).reversed() {
            let responder = MiddlewareResponder(middleware: middlewares[i], next: currentResponser.respond(to:context:))
            currentResponser = responder
        }
        return currentResponser
    }
}
