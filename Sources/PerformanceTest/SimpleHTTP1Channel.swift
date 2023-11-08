import Hummingbird
import HummingbirdCore
import Logging
import NIOCore
import NIOHTTP1

public struct SimpleHTTP1Channel: HBChannelSetup, HTTPChannelHandler {
    public typealias In = HTTPServerRequestPart
    public typealias Out = SendableHTTPServerResponsePart

    public init(
        additionalChannelHandlers: @autoclosure @escaping @Sendable () -> [any RemovableChannelHandler] = [],
        responder: @escaping @Sendable (HBHTTPRequest, Channel) async throws -> HBHTTPResponse = { _, _ in throw HBHTTPError(.notImplemented) }
    ) {
        self.additionalChannelHandlers = additionalChannelHandlers
        self.responder = responder
    }

    public func initialize(channel: Channel, configuration: HBServerConfiguration, logger: Logger) -> EventLoopFuture<Void> {
        let childChannelHandlers: [RemovableChannelHandler] = self.additionalChannelHandlers() + [
            HBHTTPUserEventHandler(logger: logger),
            HBHTTPSendableResponseChannelHandler(),
        ]
        return channel.eventLoop.makeCompletedFuture {
            try channel.pipeline.syncOperations.configureHTTPServerPipeline(
                withPipeliningAssistance: configuration.withPipeliningAssistance,
                withErrorHandling: true
            )
            try channel.pipeline.syncOperations.addHandlers(childChannelHandlers)
        }
    }

    public func handle(asyncChannel: NIOCore.NIOAsyncChannel<NIOHTTP1.HTTPServerRequestPart, HummingbirdCore.SendableHTTPServerResponsePart>, logger: Logging.Logger) async {
        do {
            var iterator = asyncChannel.inbound.makeAsyncIterator()
            let responseBodyWriter = HBHTTPServerBodyWriter(outbound: asyncChannel.outbound)
            while let part = try await iterator.next() {
                guard case .head(let head) = part else {
                    fatalError()
                }
                let body: ByteBuffer
                if case .body(var buffer) = try await iterator.next() {
                    while case .body(var part) = try await iterator.next() {
                        buffer.writeBuffer(&part)
                    }
                    body = buffer
                } else {
                    body = ByteBuffer()
                }

                let request = HBHTTPRequest(head: head, body: .byteBuffer(body))
                let response: HBHTTPResponse
                do {
                    response = try await self.responder(request, asyncChannel.channel)
                } catch {
                    response = HBHTTPResponse(status: .internalServerError)
                }

                let responseHead = HTTPResponseHead(version: request.head.version, status: response.status, headers: response.headers)
                try await asyncChannel.outbound.write(.head(responseHead))
                try await response.body.write(responseBodyWriter)
                try await asyncChannel.outbound.write(.end(nil))
            }
        } catch {
            print(error)
        }
    }

    public var responder: @Sendable (HBHTTPRequest, Channel) async throws -> HBHTTPResponse
    let additionalChannelHandlers: @Sendable () -> [any RemovableChannelHandler]
}

/// Writes ByteBuffers to AsyncChannel outbound writer
struct HBHTTPServerBodyWriter: Sendable, HBResponseBodyWriter {
    typealias Out = SendableHTTPServerResponsePart
    /// The components of a HTTP response from the view of a HTTP server.
    public typealias OutboundWriter = NIOAsyncChannelOutboundWriter<Out>

    let outbound: OutboundWriter

    func write(_ buffer: ByteBuffer) async throws {
        try await self.outbound.write(.body(buffer))
    }
}
