//
//  AppState.swift
//  Survale
//
//  Created by Sean Fillmore on 10/17/25.
//
import SwiftUI
import Combine

final class AppState: ObservableObject {
    // MARK: - Authentication
    
    @Published var isAuthenticated = false
    @Published var currentUserID: UUID?
    
    // MARK: - User Context
    
    @Published var currentUser: User?
    @Published var currentTeam: Team?
    @Published var currentAgency: Agency?
    
    // MARK: - Operation Context
    
    @Published var activeOperationID: UUID?
    @Published var activeOperation: Operation?
    
    // MARK: - Permissions
    
    @Published var locationPermissionGranted = false
    @Published var hasOnboarded = false
    
    // MARK: - Computed Properties
    
    /// Convenience computed property to check if we have a valid user ID
    var hasValidUser: Bool {
        return currentUserID != nil && !currentUserID!.uuidString.isEmpty
    }
    
    /// Check if current user is case agent of active operation
    var isCurrentUserCaseAgent: Bool {
        guard let userId = currentUserID,
              let operation = activeOperation else {
            return false
        }
        return operation.createdByUserId == userId
    }
    
    /// Check if user is in an active operation
    var isInActiveOperation: Bool {
        return activeOperationID != nil && activeOperation?.state == .active
    }
}



