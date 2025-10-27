//
//  OperationDataCache.swift
//  Survale
//
//  Background data prefetching and caching service for smooth tab navigation
//

import Foundation
import MapKit
import Combine

@MainActor
final class OperationDataCache: ObservableObject {
    static let shared = OperationDataCache()
    
    // MARK: - Published State
    
    @Published private(set) var targets: [UUID: [OpTarget]] = [:]
    @Published private(set) var stagingPoints: [UUID: [StagingPoint]] = [:]
    @Published private(set) var teamMembers: [UUID: [User]] = [:]
    @Published private(set) var assignments: [UUID: [AssignedLocation]] = [:]
    
    // MARK: - Loading State
    
    @Published private(set) var isLoadingTargets = false
    @Published private(set) var isLoadingMembers = false
    @Published private(set) var isLoadingAssignments = false
    
    private var currentOperationId: UUID?
    private var prefetchTask: Task<Void, Never>?
    
    private init() {}
    
    // MARK: - Public API
    
    /// Prefetch all data for an operation in the background
    func prefetchOperationData(operationId: UUID) {
        // Cancel any existing prefetch
        prefetchTask?.cancel()
        
        // Skip if same operation and data already loaded
        if currentOperationId == operationId,
           targets[operationId] != nil,
           stagingPoints[operationId] != nil,
           teamMembers[operationId] != nil {
            print("✅ OperationDataCache: Data already cached for operation \(operationId)")
            return
        }
        
        currentOperationId = operationId
        
        // Start background prefetch
        prefetchTask = Task {
            print("🔄 OperationDataCache: Starting prefetch for operation \(operationId)")
            
            async let targetsResult = fetchTargets(for: operationId)
            async let stagingResult = fetchStaging(for: operationId)
            async let membersResult = fetchTeamMembers(for: operationId)
            async let assignmentsResult = fetchAssignments(for: operationId)
            
            // Load all in parallel
            let (targetsData, stagingData, membersData, assignmentsData) = await (
                targetsResult,
                stagingResult,
                membersResult,
                assignmentsResult
            )
            
            // Update cache if task wasn't cancelled
            guard !Task.isCancelled else {
                print("⚠️ OperationDataCache: Prefetch cancelled")
                return
            }
            
            self.targets[operationId] = targetsData
            self.stagingPoints[operationId] = stagingData
            self.teamMembers[operationId] = membersData
            self.assignments[operationId] = assignmentsData
            
            print("✅ OperationDataCache: Prefetch complete - \(targetsData.count) targets, \(stagingData.count) staging, \(membersData.count) members, \(assignmentsData.count) assignments")
        }
    }
    
    /// Get cached targets for an operation (returns immediately)
    func getTargets(for operationId: UUID) -> [OpTarget] {
        return targets[operationId] ?? []
    }
    
    /// Get cached staging points for an operation (returns immediately)
    func getStagingPoints(for operationId: UUID) -> [StagingPoint] {
        return stagingPoints[operationId] ?? []
    }
    
    /// Get cached team members for an operation (returns immediately)
    func getTeamMembers(for operationId: UUID) -> [User] {
        return teamMembers[operationId] ?? []
    }
    
    /// Get cached assignments for an operation (returns immediately)
    func getAssignments(for operationId: UUID) -> [AssignedLocation] {
        return assignments[operationId] ?? []
    }
    
    /// Clear cache for a specific operation
    func clearCache(for operationId: UUID) {
        targets.removeValue(forKey: operationId)
        stagingPoints.removeValue(forKey: operationId)
        teamMembers.removeValue(forKey: operationId)
        assignments.removeValue(forKey: operationId)
        
        if currentOperationId == operationId {
            currentOperationId = nil
            prefetchTask?.cancel()
            prefetchTask = nil
        }
    }
    
    /// Clear all cached data
    func clearAll() {
        targets.removeAll()
        stagingPoints.removeAll()
        teamMembers.removeAll()
        assignments.removeAll()
        currentOperationId = nil
        prefetchTask?.cancel()
        prefetchTask = nil
    }
    
    // MARK: - Private Fetch Methods
    
    private func fetchTargets(for operationId: UUID) async -> [OpTarget] {
        isLoadingTargets = true
        defer { isLoadingTargets = false }
        
        do {
            let result = try await SupabaseRPCService.shared.getOperationTargets(operationId: operationId)
            return result.targets
        } catch {
            print("❌ OperationDataCache: Failed to fetch targets: \(error)")
            return []
        }
    }
    
    private func fetchStaging(for operationId: UUID) async -> [StagingPoint] {
        do {
            let result = try await SupabaseRPCService.shared.getOperationTargets(operationId: operationId)
            return result.staging
        } catch {
            print("❌ OperationDataCache: Failed to fetch staging: \(error)")
            return []
        }
    }
    
    private func fetchTeamMembers(for operationId: UUID) async -> [User] {
        isLoadingMembers = true
        defer { isLoadingMembers = false }
        
        do {
            return try await SupabaseRPCService.shared.getOperationMembers(operationId: operationId)
        } catch {
            print("❌ OperationDataCache: Failed to fetch team members: \(error)")
            return []
        }
    }
    
    private func fetchAssignments(for operationId: UUID) async -> [AssignedLocation] {
        isLoadingAssignments = true
        defer { isLoadingAssignments = false }
        
        do {
            return try await SupabaseRPCService.shared.getOperationAssignments(operationId: operationId)
        } catch {
            print("❌ OperationDataCache: Failed to fetch assignments: \(error)")
            return []
        }
    }
}

