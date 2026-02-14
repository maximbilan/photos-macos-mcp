import Foundation
import Logging
import MCP

@main
enum PhotosMCPMain {
    static func main() async throws {
        var logger = Logger(label: "com.photosmcp")
        #if DEBUG
        logger.logLevel = .debug
        #endif
        let server = PhotosServer(server: Server(
            name: "PhotosMCP",
            version: "1.0.0",
            instructions: "This server provides read-only access to the macOS Photos library. Use it to search photos, list albums, view metadata, and retrieve image thumbnails or full-size images.",
            capabilities: .init(tools: .init(listChanged: true))
        ))

        let transport = StdioTransport(logger: logger)
        try await server.start(transport: transport)

        // Keep running until shutdown
        await server.waitUntilCompleted()
    }
}
