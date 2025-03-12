//
//  LogsExporter.swift
//  Pulse
//
//  Created by Gleb Kovalenko on 12.03.2025.
//

import Pulse
import CoreData

// MARK: - LogsExporter

public class LogsExporter {
    
    // MARK: - Export
    
    public static func exportAllLogsAsText(store: LoggerStore) async throws -> String {
        let sessionsEntities = try await withUnsafeThrowingContinuation { continuation in
            store.backgroundContext.perform {
                let request = NSFetchRequest<LoggerSessionEntity>(entityName: "\(LoggerSessionEntity.self)")
                request.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerSessionEntity.createdAt, ascending: false)]

                let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: true)
                request.sortDescriptors = [sortDescriptor]

                let result = Result(catching: { try store.backgroundContext.fetch(request) })
                continuation.resume(with: result)
            }
        }
        let sessionsIDs = Set(sessionsEntities.map(\.id))
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            .init(format: "session IN %@", sessionsIDs)
        ])
        let options = LoggerStore.ExportOptions(predicate: predicate, sessions: sessionsIDs)
        return try await prepareForSharing(store: store, output: .plainText, options: options).items.first as? String ?? ""
    }
    
    // MARK: - Private
    
    private static func prepareForSharing(store: LoggerStore, output: ShareOutput, options: LoggerStore.ExportOptions) async throws -> ShareItems {
        let entities = try await withUnsafeThrowingContinuation { continuation in
            store.backgroundContext.perform {
                let request = NSFetchRequest<LoggerMessageEntity>(entityName: "\(LoggerMessageEntity.self)")
                request.predicate = options.predicate // important: contains sessions

                let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: true)
                request.sortDescriptors = [sortDescriptor]

                let result = Result(catching: { try store.backgroundContext.fetch(request) })
                continuation.resume(with: result)
            }
        }
        return try await ShareService.share(entities, store: store, as: output)
    }
}
