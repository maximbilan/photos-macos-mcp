import MCP

/// Tool schema definitions for MCP registration.
enum ToolDefinitions {

    static func schema(
        properties: [String: Value],
        required: [String]? = nil
    ) -> Value {
        var obj: [String: Value] = [
            "type": .string("object"),
            "properties": .object(properties)
        ]
        if let required = required, !required.isEmpty {
            obj["required"] = .array(required.map { .string($0) })
        }
        return .object(obj)
    }

    static func prop(_ type: String, description: String, enumValues: [String]? = nil) -> Value {
        var p: [String: Value] = [
            "type": .string(type),
            "description": .string(description)
        ]
        if let enumValues = enumValues {
            p["enum"] = .array(enumValues.map { .string($0) })
        }
        return .object(p)
    }

    static var all: [Tool] {
        [
            Tool(
                name: "list_albums",
                description: "Return all user albums and smart albums with name, identifier, asset count, and type.",
                inputSchema: schema(properties: [
                    "limit": prop("integer", description: "Maximum number of albums to return (default 50, max 200)"),
                    "offset": prop("integer", description: "Number of albums to skip for pagination (default 0)")
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "get_library_stats",
                description: "Return total counts of photos, videos, albums, and date range of the library.",
                inputSchema: schema(properties: [:]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "search_photos",
                description: "Search the Photos library by date range, media type, favorite status, or keyword.",
                inputSchema: schema(properties: [
                    "start_date": prop("string", description: "Start of date range (ISO 8601)"),
                    "end_date": prop("string", description: "End of date range (ISO 8601)"),
                    "media_type": prop("string", description: "Filter by media type", enumValues: ["photo", "video", "live_photo", "any"]),
                    "is_favorite": prop("boolean", description: "Filter to favorites only"),
                    "keyword": prop("string", description: "Filter by visual content (pizza, food, car, city, dog, beach, etc.). Uses Vision ML. Combine with date range for large libraries."),
                    "limit": prop("integer", description: "Maximum results (default 50, max 200)"),
                    "offset": prop("integer", description: "Offset for pagination (default 0)")
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "get_album_contents",
                description: "Return asset metadata for all items in a given album by album identifier.",
                inputSchema: schema(properties: [
                    "album_identifier": prop("string", description: "The album's local identifier"),
                    "limit": prop("integer", description: "Maximum results (default 50, max 200)"),
                    "offset": prop("integer", description: "Offset for pagination (default 0)")
                ], required: ["album_identifier"]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "get_asset_details",
                description: "Return full metadata for an asset: EXIF, dates, GPS, dimensions, media subtypes, duration (video), resource sizes.",
                inputSchema: schema(properties: [
                    "asset_identifier": prop("string", description: "The asset's local identifier")
                ], required: ["asset_identifier"]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "get_asset_classifications",
                description: "Return Vision image classification labels and confidence scores for a photo. Useful when keyword search misses an expected object.",
                inputSchema: schema(properties: [
                    "asset_identifier": prop("string", description: "The asset's local identifier"),
                    "max_results": prop("integer", description: "Maximum classification labels to return (default 10, max 30)")
                ], required: ["asset_identifier"]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "get_photo_thumbnail",
                description: "Small preview (default 512px). For full resolution use get_photo_full. Saves to temp file; tell user `open /path` to view.",
                inputSchema: schema(properties: [
                    "asset_identifier": prop("string", description: "The asset's local identifier"),
                    "max_dimension": prop("integer", description: "Maximum width or height in pixels (default 512)"),
                    "quality": prop("number", description: "JPEG quality 0.0-1.0 (default 0.8)")
                ], required: ["asset_identifier"]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "get_photo_full",
                description: "Full-resolution image (use this when user wants full size, not thumbnails). Saves to temp file; tell user `open /path` to view. Use max_dimension (e.g. 2048) to limit size.",
                inputSchema: schema(properties: [
                    "asset_identifier": prop("string", description: "The asset's local identifier"),
                    "max_dimension": prop("integer", description: "Optional max width/height to downscale (avoids huge payloads)"),
                    "quality": prop("number", description: "JPEG quality 0.0-1.0 (default 0.8)")
                ], required: ["asset_identifier"]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "get_photos_by_place",
                description: "Find photos by place name (city, country). Geocodes the name and finds photos taken nearby. Use for 'photos from Valencia', 'pictures in Paris', etc.",
                inputSchema: schema(properties: [
                    "place": prop("string", description: "Place name (e.g. 'Valencia', 'New York', 'Paris, France')"),
                    "radius_km": prop("number", description: "Search radius in km (default 25)"),
                    "limit": prop("integer", description: "Maximum results (default 50, max 200)"),
                    "offset": prop("integer", description: "Offset for pagination (default 0)")
                ], required: ["place"]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "get_photos_by_location",
                description: "Find photos within a radius (km) of given latitude and longitude coordinates.",
                inputSchema: schema(properties: [
                    "latitude": prop("number", description: "Center latitude"),
                    "longitude": prop("number", description: "Center longitude"),
                    "radius_km": prop("number", description: "Search radius in kilometers (default 10)"),
                    "limit": prop("integer", description: "Maximum results (default 50, max 200)"),
                    "offset": prop("integer", description: "Offset for pagination (default 0)")
                ], required: ["latitude", "longitude"]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "get_photos_by_date",
                description: "Find photos taken on a specific date or within a date range.",
                inputSchema: schema(properties: [
                    "date": prop("string", description: "Specific date (ISO 8601) for photos on that day"),
                    "start_date": prop("string", description: "Start of date range (ISO 8601)"),
                    "end_date": prop("string", description: "End of date range (ISO 8601)"),
                    "limit": prop("integer", description: "Maximum results (default 50, max 200)"),
                    "offset": prop("integer", description: "Offset for pagination (default 0)")
                ]),
                annotations: .init(readOnlyHint: true)
            ),
            Tool(
                name: "list_moments",
                description: "Return photo moments/collections grouped by time and location.",
                inputSchema: schema(properties: [
                    "limit": prop("integer", description: "Maximum moments to return (default 50, max 200)"),
                    "offset": prop("integer", description: "Offset for pagination (default 0)")
                ]),
                annotations: .init(readOnlyHint: true)
            )
        ]
    }
}
