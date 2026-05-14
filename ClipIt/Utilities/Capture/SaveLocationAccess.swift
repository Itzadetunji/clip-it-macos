//
//  SaveLocationAccess.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 14/05/2026.
//

import Foundation

enum SaveLocationAccess {
    static func bookmarkData(for directory: URL) throws -> Data {
        try directory.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    static func withWritableAccess<T>(
        to directory: URL,
        bookmarkData: Data?,
        operation: (URL) async throws -> T
    ) async throws -> T {
        let resolvedDirectory = try resolveDirectory(
            directory,
            bookmarkData: bookmarkData
        )
        let didStartAccessing = resolvedDirectory.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                resolvedDirectory.stopAccessingSecurityScopedResource()
            }
        }

        try validateWritableDirectory(resolvedDirectory)
        return try await operation(resolvedDirectory)
    }

    static func validateWritableDirectory(_ directory: URL) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw SaveLocationAccessError.notDirectory(directory)
            }
        } else {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }

        let probeURL = directory.appendingPathComponent(
            ".clipit-permission-check-\(UUID().uuidString)"
        )
        do {
            try Data().write(to: probeURL, options: .atomic)
            try? fileManager.removeItem(at: probeURL)
        } catch {
            throw SaveLocationAccessError.notWritable(directory, error)
        }
    }

    private static func resolveDirectory(
        _ directory: URL,
        bookmarkData: Data?
    ) throws -> URL {
        guard let bookmarkData else {
            return directory
        }

        var isStale = false
        let resolvedDirectory = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        return resolvedDirectory
    }
}

enum SaveLocationAccessError: LocalizedError {
    case notDirectory(URL)
    case notWritable(URL, Error)

    var errorDescription: String? {
        switch self {
        case .notDirectory(let url):
            return "\(url.path) is not a folder."
        case .notWritable(let url, let error):
            return "ClipIt does not have permission to save clips in \(url.path). Choose the folder again or pick another location. \(error.localizedDescription)"
        }
    }
}
