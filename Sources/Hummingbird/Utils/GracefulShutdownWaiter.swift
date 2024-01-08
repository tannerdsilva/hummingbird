//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import ServiceLifecycle

/// An actor that provides a function to wait on cancellation/graceful shutdown.
public actor CancellationWaiter {
    private var taskContinuation: CheckedContinuation<Void, Error>?

    public init() {}

    public func wait() async throws {
        try await withTaskCancellationHandler {
            try await withGracefulShutdownHandler {
                try await withCheckedThrowingContinuation { continuation in
                    self.taskContinuation = continuation
                }
            } onGracefulShutdown: {
                Task {
                    await self.finish()
                }
            }
        } onCancel: {
            Task {
                await self.finish(throwing: CancellationError())
            }
        }
    }

    public func finish(throwing error: Error? = nil) {
        if let error {
            self.taskContinuation?.resume(throwing: error)
        } else {
            self.taskContinuation?.resume()
        }
        self.taskContinuation = nil
    }
}
