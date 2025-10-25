//
//  Secrets.swift
//  Survale
//
//  Created by Sean Fillmore on 10/17/25.
//
import Foundation

enum Secrets {
    static var supabaseURL: URL {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: raw) else { fatalError("Missing SUPABASE_URL") }
        return url
    }
    static var anonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        else { fatalError("Missing SUPABASE_ANON_KEY") }
        return key
    }
}

