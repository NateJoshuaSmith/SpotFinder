import SwiftUI
import MapKit
import CoreLocation
import UIKit
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
    @State private var showSkateParksSheet = false
    @State private var selectedLatitude: Double = 37.7749
    @State private var selectedLongitude: Double = -122.4194
    @State private var mapRegion: MKCoordinateRegion?
    @State private var mapProxy: MapProxy?
    @State private var draggingSpot: SkateSpot?
    @State private var dragOffset: CGSize = .zero
    @State private var mapViewSize: CGSize = .zero
    @State private var selectedSpot: SkateSpot? = nil
    @State private var selectedCalloutSpotId: String?
    /// Live aggregate for the map preview card (Firestore `ratings` subcollection).
    @State private var calloutRatingSummary: SpotService.SpotRatingSummary?
    @State private var isLoadingCalloutRating = false
    @State private var hasCenteredOnUserLocation = false
    @State private var isLoadingSpots = true
    /// After finishing a drag, ignore pin taps briefly so the callout doesn’t open from touch-up.
    @State private var suppressPinTapUntil: Date = .distantPast
    
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
    
    // Render selected callout spot last so its annotation/card is always above other pins.
    private var orderedSpotsForRendering: [SkateSpot] {
        guard let selectedId = selectedCalloutSpotId else { return filteredSpots }
        return filteredSpots.sorted { lhs, rhs in
            let lhsSelected = lhs.id == selectedId
            let rhsSelected = rhs.id == selectedId
            if lhsSelected == rhsSelected { return false }
            return !lhsSelected && rhsSelected
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
    
    /// Same skate-style assets used elsewhere (e.g. home / parks): park-tagged spots use the outdoor park art.
    private func pinAssetName(for spot: SkateSpot) -> String {
        let tags = spot.tags ?? []
        if tags.contains(where: { $0.caseInsensitiveCompare("Park") == .orderedSame }) {
            return "OutdoorPark"
        }
        return "GrassRamp"
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
    
    
    // Long-press then drag to move your own spots (owner-only; Firestore rules should match).
    private func spotDragGesture(for spot: SkateSpot) -> some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard isOwner(of: spot) else { return }
                
                switch value {
                case .second(true, let drag):
                    if draggingSpot == nil {
                        draggingSpot = spot
                        // Block touch-up from firing the pin button before drag `onEnded` runs.
                        suppressPinTapUntil = Date.distantFuture
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
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
                let wasActivelyDragging = draggingSpot?.id == spot.id
                
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
                
                // After a drag, ignore pin taps briefly so the preview doesn’t open from finger-up.
                suppressPinTapUntil = wasActivelyDragging
                    ? Date().addingTimeInterval(0.5)
                    : .distantPast
            }
    }
    
    // Handle pin taps: first tap shows callout, second tap opens details.
    private func handleSpotTap(_ spot: SkateSpot) {
        if Date() < suppressPinTapUntil {
            return
        }
        if selectedCalloutSpotId == spot.id {
            selectedSpot = spot
        } else {
            selectedCalloutSpotId = spot.id
        }
    }
    
    /// Loads real ratings for the map callout (Firestore `ratings` subcollection).
    /// - Parameter showLoadingIndicator: `false` when refreshing after closing detail so the pill doesn’t flash “Loading…”.
    private func loadCalloutRating(for spotId: String, showLoadingIndicator: Bool = true) async {
        if showLoadingIndicator {
            await MainActor.run { isLoadingCalloutRating = true }
        }
        do {
            let summary = try await spotService.fetchRatingSummary(spotId: spotId)
            await MainActor.run {
                guard selectedCalloutSpotId == spotId else { return }
                calloutRatingSummary = summary
                isLoadingCalloutRating = false
            }
        } catch {
            await MainActor.run {
                guard selectedCalloutSpotId == spotId else { return }
                calloutRatingSummary = nil
                isLoadingCalloutRating = false
            }
        }
    }
    
    private func openDirections(for spot: SkateSpot) {
        let coordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = spot.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    @ViewBuilder
    private func pinContent(for spot: SkateSpot) -> some View {
        let ring = pinColor(for: spot)
        let asset = pinAssetName(for: spot)
        let selected = selectedCalloutSpotId == spot.id
        Button {
            handleSpotTap(spot)
        } label: {
            ZStack {
                // Same light blue / purple wash as Spot detail, Add spot, Skate shops, etc.
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.2), radius: selected ? 6 : 3, x: 0, y: 2)
                Circle()
                    .stroke(ring, lineWidth: 3)
                    .frame(width: 40, height: 40)
                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            }
            .scaleEffect(
                draggingSpot?.id == spot.id
                ? 1.2
                : (selected ? 1.12 : 1.0)
            )
            .shadow(
                color: selected ? Color.blue.opacity(0.35) : .clear,
                radius: selected ? 8 : 0,
                x: 0,
                y: 2
            )
            .offset(draggingSpot?.id == spot.id ? dragOffset : .zero)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func calloutPreviewThumbnail(for spot: SkateSpot) -> some View {
        let size: CGFloat = 48
        Group {
            if let urlString = spot.primaryImageURLString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .clipped()
                    case .failure:
                        Image(pinAssetName(for: spot))
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                    case .empty:
                        ZStack {
                            Color(.systemGray6)
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    @unknown default:
                        Image(pinAssetName(for: spot))
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                    }
                }
            } else {
                Image(pinAssetName(for: spot))
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .opacity(0.45)
            }
        }
        .frame(width: size, height: size)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func calloutMiniCard(for spot: SkateSpot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                calloutPreviewThumbnail(for: spot)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center) {
                        Text(spot.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        Spacer(minLength: 4)
                        Button {
                            selectedCalloutSpotId = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            if !spot.comment.isEmpty {
                Text(spot.comment)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack(spacing: 6) {
                Group {
                    if isLoadingCalloutRating {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.65)
                            Text("Loading…")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.08)))
                    } else if let s = calloutRatingSummary, s.count > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption2)
                            Text(String(format: "%.1f", s.average))
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.primary)
                            Text("(\(s.count))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.08)))
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "star")
                                .foregroundColor(.secondary)
                                .font(.caption2)
                            Text("No ratings yet")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.08)))
                    }
                }
                
                if let tags = spot.tags, !tags.isEmpty {
                    ForEach(Array(tags.prefix(2)), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.blue.opacity(0.12)))
                    }
                }
            }
            
            HStack(spacing: 8) {
                if let difficulty = spot.difficulty, !difficulty.isEmpty {
                    Label(difficulty, systemImage: "speedometer")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let status = spot.status, !status.isEmpty {
                    Label(status, systemImage: "flag.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 8) {
                Button("Open") {
                    selectedSpot = spot
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button("Directions") {
                    openDirections(for: spot)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.top, 2)
        }
        .padding(10)
        .frame(width: 248, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func selectedCalloutOverlay(in geometry: GeometryProxy) -> some View {
        Group {
            if
                let selectedId = selectedCalloutSpotId,
                let spot = filteredSpots.first(where: { $0.id == selectedId }),
                let proxy = mapProxy,
                let point = proxy.convert(
                    CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                    to: .local
                )
            {
                // Keep the card in-bounds and above the selected pin.
                let halfWidth: CGFloat = 124
                let minX: CGFloat = halfWidth + 12
                let maxX: CGFloat = geometry.size.width - halfWidth - 12
                let x = min(max(point.x, minX), maxX)
                let y = max(90, point.y - 130)
                
                calloutMiniCard(for: spot)
                    .position(x: x, y: y)
                    .zIndex(300)
            } else {
                EmptyView()
            }
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
            ForEach(orderedSpotsForRendering) { spot in
                Annotation(spot.name, coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)) {
                    VStack(spacing: 6) {
                        if isOwner(of: spot) {
                            // Long-press (~0.35s) then drag. Simultaneous with tap so callout / open still work.
                            pinContent(for: spot)
                                .simultaneousGesture(spotDragGesture(for: spot))
                                .zIndex(1)
                        } else {
                            pinContent(for: spot)
                                .zIndex(1)
                        }
                    }
                    .zIndex(selectedCalloutSpotId == spot.id ? 1000 : 0)
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
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    // Faster tap-out: dismiss on any map tap event.
                    if selectedCalloutSpotId != nil {
                        selectedCalloutSpotId = nil
                    }
                }
        )
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
            
            selectedCalloutOverlay(in: geometry)
            
            centerIndicator
            
            // Filter bar – centered close under the nav bar
            VStack {
                HStack {
                    Spacer()
                    filterBarCompact
                    Spacer()
                }
                .padding(.top, 36)
                Spacer()
            }
            .zIndex(90)
            
            // Re-center button (blue arrow-style) aligned with filter bar
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
                .padding(.top, 36)
                Spacer()
            }
            .zIndex(95)
            
        }
    }
    
    private var bottomLogoOverlay: some View {
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
            .allowsHitTesting(false)
    }
    
    // Shrunk filter bar with centered home icon above tags
    @ViewBuilder
    private var filterBarCompact: some View {
        VStack(spacing: 4) {
            // Home icon centered above the filters
            Button(action: { dismiss() }) {
                Image(systemName: "house.fill")
                    .foregroundColor(.primary)
                    .padding(6)
                    .background(
                        Circle().fill(Color(.systemGray5))
                    )
            }
            
            HStack(spacing: 6) {
                Menu {
                    Button("All tags") { selectedTagFilter = nil }
                    ForEach(allTags, id: \.self) { tag in
                        Button(tag) { selectedTagFilter = tag }
                    }
                } label: {
                    Label(selectedTagFilter ?? "Tags", systemImage: "tag")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(selectedTagFilter == nil ? .primary : .blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(
                                selectedTagFilter == nil
                                    ? Color(.systemGray5)
                                    : Color.blue.opacity(0.18)
                            )
                        )
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
                        .foregroundColor(selectedDifficultyFilter == nil ? .primary : .purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(
                                selectedDifficultyFilter == nil
                                    ? Color(.systemGray5)
                                    : Color.purple.opacity(0.18)
                            )
                        )
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
                        .foregroundColor(selectedStatusFilter == nil ? .primary : .green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(
                                selectedStatusFilter == nil
                                    ? Color(.systemGray5)
                                    : Color.green.opacity(0.18)
                            )
                        )
                        .overlay(Capsule().stroke(Color.black, lineWidth: 1.5))
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                // Solid light blue bubble background (not transparent, but soft)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.86, green: 0.93, blue: 1.0),  // light blue
                            Color(red: 0.91, green: 0.88, blue: 1.0)   // light bluish-purple
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black, lineWidth: 1.5)
                )
        )
    }
    
    // Toolbar content
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Back button, Friends, and Skate shops on the leading side
        ToolbarItemGroup(placement: .navigationBarLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
            }
            
            NavigationLink(destination: FriendsListView()) {
                Image(systemName: "person.2.fill")
            }
            
            Button(action: { showSkateShopsSheet = true }) {
                Image(systemName: "storefront.fill")
            }
            
            Button(action: { showSkateParksSheet = true }) {
                Image(systemName: "figure.skateboarding")
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
        .overlay(alignment: .bottom) {
            bottomLogoOverlay
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
        .sheet(isPresented: $showSkateParksSheet) {
            NearbySkateParksView(
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
        .onChange(of: selectedCalloutSpotId) { _, newId in
            if let id = newId {
                calloutRatingSummary = nil
                Task { await loadCalloutRating(for: id, showLoadingIndicator: true) }
            } else {
                calloutRatingSummary = nil
                isLoadingCalloutRating = false
            }
        }
        .onChange(of: selectedSpot) { _, newSpot in
            // After rating in detail, refresh the preview so the average updates.
            if newSpot == nil, let id = selectedCalloutSpotId {
                Task { await loadCalloutRating(for: id, showLoadingIndicator: false) }
            }
        }
    }
}

#Preview {
    MapScreen()
}