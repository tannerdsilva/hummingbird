//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import HummingbirdCore
import NIOCore
import NIOSSL

extension HBHTTPChannelSetupBuilder {
    public static func http2<Responder: HBResponder<Channel>>(
        tlsConfiguration: TLSConfiguration,
        additionalChannelHandlers: @autoclosure @escaping @Sendable () -> [any RemovableChannelHandler] = []
    ) throws -> HBHTTPChannelSetupBuilder<HTTP2Channel<Responder>> {
        return .init { responder in
            return try HTTP2Channel(
                tlsConfiguration: tlsConfiguration,
                additionalChannelHandlers: additionalChannelHandlers,
                responder: responder
            )
        }
    }
}
