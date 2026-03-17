import SwiftUI
import MapKit
import CoreLocation
import FirebaseAuth

struct MapScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var spotService = SpotService()
    @StateObject private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    )
    @State private var showAddSpotSheet = false
    @State private var showSkateShopsSheet = false
    @State private var selectedLatitude: Double = 37.7749
    @State private var selectedLongitude: Double = -122.4194
    @State private var mapRegion: MKCoordinateRegion?
    @State private var mapProxy: MapProxy?
    @State private var draggingSpot: SkateSpot?
    @State private var dragOffset: CGSize = .zero
    @State private var mapViewSize: CGSize = .zero
    @State private var selectedSpot: SkateSpot? = nil
    @State private var hasCenteredOnUserLocation = false
    @State private var isLoadingSpots = true
    
    // Filters
    @State private var selectedTagFilter: String? = nil
    @State private var selectedDifficultyFilter: String? = nil
    @State private var selectedStatusFilter: String? = nil
    
    private let allTags = ["Street", "Park", "DIY", "Ledge", "Rail", "Hubba", "Bowl"]
    private let allDifficulties = ["Beginner", "Intermediate", "Advanced"]
    private let allStatuses = ["Good", "Sketchy", "Busted", "Under construction"]
    
    private var filteredSpots: [SkateSpot] {
        spotService.spots.filter { spot in
            if let tag = selectedTagFilter {
                let tags = spot.tags ?? []
                if !tags.contains(tag) { return false }
            }
            if let diff = selectedDifficultyFilter {
                if spot.difficulty != diff { return false }
            }
            if let status = selectedStatusFilter {
                if spot.status != status { return false }
            }
            return true
        }
    }
    
    // Helper function to check if current user owns a spot
    private func isOwner(of spot: SkateSpot) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return false
        }
        return spot.createdBy == currentUserId
    }
    
    // Helper function to determine pin color
    private func pinColor(for spot: SkateSpot) -> Color {
        if draggingSpot?.id == spot.id {
            return .orange  // Orange when dragging
        } else if isOwner(of: spot) {
            return .blue  // Blue if user owns it
        } else {
            return .red  // Red if someone else owns it
        }
    }

    // Loading indicator view
    private var loadingIndicator: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
            Text("Loading spots...")
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .zIndex(1)
    }
    
    
    // Drag gesture for moving spots
    private func spotDragGesture(for spot: SkateSpot) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard isOwner(of: spot) else { return }
                
                switch value {
                case .second(true, let drag):
                    if draggingSpot == nil {
                        draggingSpot = spot
                    }
                    if let drag = drag {
                        dragOffset = drag.translation
                    }
                default:
                    break
                }
            }
            .onEnded { value in
                guard isOwner(of: spot) else { return }
                
                switch value {
                case .second(true, let drag):
                    if let drag = drag, let region = mapRegion {
                        let mapHeight = mapViewSize.height > 0 ? mapViewSize.height : 600.0
                        let mapWidth = mapViewSize.width > 0 ? mapViewSize.width : 400.0
                        
                        let latitudeDelta = -drag.translation.height * region.span.latitudeDelta / mapHeight
                        let longitudeDelta = drag.translation.width * region.span.longitudeDelta / mapWidth
                        
                        let newLatitude = spot.latitude + latitudeDelta
                        let newLongitude = spot.longitude + longitudeDelta
                        
                        Task {
                            do {
                                try await spotService.updateSpotLocation(
                                    spot,
                                    latitude: newLatitude,
                                    longitude: newLongitude
                                )
                            } catch {
                                print("Error updating spot location: \(error)")
                            }
                        }
                    }
                default:
                    break
                }
                
                draggingSpot = nil
                dragOffset = .zero
            }
    }
    
    // Tap gesture for opening spot details
    private func spotTapGesture(for spot: SkateSpot) -> some Gesture {
        TapGesture()
            .onEnded { _ in
                selectedSpot = spot
            }
    }
    
    // Center indicator view
    private var centerIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .blur(radius: 4)
                    
                    // Outer ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 50, height: 50)
                    
                    // Inner dot
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 10, height: 10)
                        .shadow(color: .blue.opacity(0.5), radius: 4, x: 0, y: 2)
                }
                Spacer()
            }
            Spacer()
        }
    }
    
    // Map view with all its modifiers
    @ViewBuilder
    private func mapView(geometry: GeometryProxy, proxy: MapProxy) -> some View {
        Map(position: $cameraPosition) {
            ForEach(filteredSpots) { spot in
                Annotation(spot.name, coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(pinColor(for: spot))
                        .font(.title2)
                        .scaleEffect(draggingSpot?.id == spot.id ? 1.2 : 1.0)
                        .offset(draggingSpot?.id == spot.id ? dragOffset : .zero)
                        .gesture(spotDragGesture(for: spot))
                        .highPriorityGesture(spotTapGesture(for: spot))
                }
                .annotationTitles(.visible)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
        }
        .onMapCameraChange(frequency: .continuous) { context in
            let newRegion = context.region
            mapRegion = newRegion
            selectedLatitude = newRegion.center.latitude
            selectedLongitude = newRegion.center.longitude
        }
        .ignoresSafeArea()
        .onAppear {
            mapProxy = proxy
            mapViewSize = geometry.size
            let initialRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapRegion = initialRegion
            selectedLatitude = initialRegion.center.latitude
            selectedLongitude = initialRegion.center.longitude
        }
        .onChange(of: geometry.size) { oldSize, newSize in
            mapViewSize = newSize
        }
    }
    
    // Main map content
    @ViewBuilder
    private func mapContent(geometry: GeometryProxy) -> some View {
        ZStack {
            if isLoadingSpots {
                loadingIndicator
            }
            
            MapReader { proxy in
                mapView(geometry: geometry, proxy: proxy)
            }
            
            centerIndicator
            
            // Filter bar – centered, pulled up into the nav bar area
            VStack {
                HStack {
                    Spacer()
                    filterBarCompact
                    Spacer()
                }
                .padding(.top, -24) // stronger negative to move higher
                Spacer()
            }
            .zIndex(90)
            
            // Re-center button (blue arrow-style) aligned with filter bar / nav bar
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        if let userLocation = locationManager.location {
                            let coord = userLocation.coordinate
                            // Make sure coordinates are valid before centering
                            if coord.latitude >= -90, coord.latitude <= 90,
                               coord.longitude >= -180, coord.longitude <= 180,
                               coord.latitude != 0 || coord.longitude != 0 {
                                cameraPosition = .region(
                                    MKCoordinateRegion(
                                        center: coord,
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                    )
                                )
                                hasCenteredOnUserLocation = true
                            }
                        }
                    }) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(
                                Circle().fill(Color.blue)
                            )
                    }
                    .padding(.trailing, 12)
                }
                .padding(.top, -24) // match filter bar vertical offset
                Spacer()
            }
            .zIndex(95)
            
            // Spotfinder logo at bottom in a bubble with black outline
            VStack {
                Spacer()
                Image("SpotfinderLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 72)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black)
                            .overlay(
                                Capsule()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 4
                                    )
                            )
                    )
                    .padding(.bottom, 16)
            }
        }
    }
    
    // Shrunk filter bar for toolbar (between back and favorite)
    @ViewBuilder
    private var filterBarCompact: some View {
        HStack(spacing: 6) {
            Menu {
                Button("All tags") { selectedTagFilter = nil }
                ForEach(allTags, id: \.self) { tag in
                    Button(tag) { selectedTagFilter = tag }
                }
            } label: {
                Label(selectedTagFilter ?? "Tags", systemImage: "tag")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(.systemGray5)))
                    .overlay(Capsule().stroke(Color.black, lineWidth: 1.5))
            }
            Menu {
                Button("Any level") { selectedDifficultyFilter = nil }
                ForEach(allDifficulties, id: \.self) { level in
                    Button(level) { selectedDifficultyFilter = level }
                }
            } label: {
                Label(selectedDifficultyFilter ?? "Difficulty", systemImage: "speedometer")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(.systemGray5)))
                    .overlay(Capsule().stroke(Color.black, lineWidth: 1.5))
            }
            Menu {
                Button("Any status") { selectedStatusFilter = nil }
                ForEach(allStatuses, id: \.self) { s in
                    Button(s) { selectedStatusFilter = s }
                }
            } label: {
                Label(selectedStatusFilter ?? "Status", systemImage: "flag")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(.systemGray5)))
                    .overlay(Capsule().stroke(Color.black, lineWidth: 1.5))
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black, lineWidth: 1.5)
                )
        )
    }
    
    // Toolbar content
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Friends and Skate shops as icon-only buttons next to the system back button
        ToolbarItemGroup(placement: .navigationBarLeading) {
            NavigationLink(destination: FriendsListView()) {
                Image(systemName: "person.2.fill")
            }
            
            Button(action: { showSkateShopsSheet = true }) {
                Image(systemName: "storefront.fill")
            }
        }
        
        // Center home icon between leading and trailing items; tap to go back home
        ToolbarItem(placement: .principal) {
            Button(action: { dismiss() }) {
                Image(systemName: "house.fill")
                    .foregroundColor(.primary)
            }
        }
        
        // Favorites and plus buttons (no outlines, gray circles)
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 10) {
                NavigationLink(destination: FavoritesListView()) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.pink)
                        .padding(8)
                }
                
                Button(action: {
                    if let region = mapRegion {
                        selectedLatitude = region.center.latitude
                        selectedLongitude = region.center.longitude
                    }
                    showAddSpotSheet = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.primary)
                        .padding(8)
                }
            }
        }
    }
    
    // Setup task logic
    private func setupTask() {
        spotService.listenToSpots()
        if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startLocationUpdates()
            if let userLocation = locationManager.location, !hasCenteredOnUserLocation {
                let lat = userLocation.coordinate.latitude
                let lon = userLocation.coordinate.longitude
                if lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 && (lat != 0 || lon != 0) {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: userLocation.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    ))
                    hasCenteredOnUserLocation = true
                }
            }
        } else {
            locationManager.requestLocationPermission()
        }
    }
    
    // Handle authorization status change
    private func handleAuthorizationChange(newStatus: CLAuthorizationStatus) {
        if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
            locationManager.startLocationUpdates()
        }
    }
    
    // Handle spots change
    private func handleSpotsChange(newSpots: [SkateSpot]) {
        if !newSpots.isEmpty && isLoadingSpots {
            isLoadingSpots = false
        }
    }
    
    // Handle location change
    private func handleLocationChange(newLocation: CLLocation?) {
        guard let userLocation = newLocation, !hasCenteredOnUserLocation else { return }
        let lat = userLocation.coordinate.latitude
        let lon = userLocation.coordinate.longitude
        if lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 && (lat != 0 || lon != 0) {
            cameraPosition = .region(MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
            hasCenteredOnUserLocation = true
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            mapContent(geometry: geometry)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showAddSpotSheet) {
            AddSpotView(
                spotService: spotService,
                latitude: selectedLatitude,
                longitude: selectedLongitude
            )
        }
        .sheet(item: $selectedSpot) { spot in
            SpotDetailView(spot: spot, spotService: spotService)
        }
        .sheet(isPresented: $showSkateShopsSheet) {
            NearbySkateShopsView(
                latitude: selectedLatitude,
                longitude: selectedLongitude,
                radiusMeters: 10000
            )
        }
        .task {
            setupTask()
        }
        .onChange(of: locationManager.authorizationStatus) { oldStatus, newStatus in
            handleAuthorizationChange(newStatus: newStatus)
        }
        .onChange(of: spotService.spots) { oldSpots, newSpots in
            handleSpotsChange(newSpots: newSpots)
        }
        .onChange(of: locationManager.location) { oldLocation, newLocation in
            handleLocationChange(newLocation: newLocation)
        }
    }
}

#Preview {
    MapScreen()
}