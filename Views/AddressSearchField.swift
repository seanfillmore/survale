//
//  AddressSearchField.swift
//  Survale
//
//  Address autocomplete field using MapKit
//

import SwiftUI
import MapKit
import Combine

struct AddressSearchField: View {
    let label: String
    @Binding var address: String
    @Binding var city: String
    @Binding var zipCode: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var showResults = false
    @StateObject private var searchCompleter = LocationSearchCompleter()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(label, text: $address)
                .onChange(of: address) { _, newValue in
                    if !newValue.isEmpty {
                        searchCompleter.search(query: newValue)
                        showResults = true
                    } else {
                        showResults = false
                        searchResults = []
                    }
                }
                .onChange(of: searchCompleter.results) { _, results in
                    searchResults = results
                }
            
            if showResults && !searchResults.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(searchResults.prefix(5), id: \.self) { result in
                        Button {
                            selectAddress(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                
                                Text(result.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                        }
                        
                        if result != searchResults.prefix(5).last {
                            Divider()
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                .padding(.top, 4)
            }
        }
    }
    
    private func selectAddress(_ completion: MKLocalSearchCompletion) {
        // Perform a search to get full address details
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            guard let placemark = response?.mapItems.first?.placemark else {
                // Fallback to just using the completion text
                address = completion.title
                showResults = false
                return
            }
            
            // Extract address components
            let street = [
                placemark.subThoroughfare,
                placemark.thoroughfare
            ].compactMap { $0 }.joined(separator: " ")
            
            address = street.isEmpty ? completion.title : street
            city = placemark.locality ?? ""
            zipCode = placemark.postalCode ?? ""
            
            // Set coordinates
            latitude = placemark.coordinate.latitude
            longitude = placemark.coordinate.longitude
            
            showResults = false
        }
    }
}

// MARK: - Location Search Completer

class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    
    private let completer: MKLocalSearchCompleter
    
    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }
    
    func search(query: String) {
        completer.queryFragment = query
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = completer.results
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Address search error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.results = []
        }
    }
}

