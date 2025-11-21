import SwiftUI
import MapKit
import CoreLocation

struct MapScreen: View {
   @State private var cameraPosition: MapCameraPosition = .region(
    MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
)

    var body: some View {
       Map(position: $cameraPosition)
        .ignoresSafeArea()
    }
}

#Preview {
    MapScreen()
}