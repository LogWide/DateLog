import SwiftUI
import UIKit
import NMapsMap

struct MapView: UIViewRepresentable {
    let places: [DatePlace]

    @Binding var selectedCoordinate: CoordinateData?
    @Binding var selectedSavedPlace: DatePlace?
    @Binding var selectedPlaceName: String

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> NMFNaverMapView {
        let naverMapView = NMFNaverMapView()

        naverMapView.showZoomControls = true
        naverMapView.showLocationButton = true
        naverMapView.showCompass = true
        naverMapView.showScaleBar = true

        naverMapView.mapView.touchDelegate = context.coordinator

        let seoul = NMGLatLng(
            lat: 37.5665,
            lng: 126.9780
        )

        let cameraUpdate = NMFCameraUpdate(
            scrollTo: seoul,
            zoomTo: 11
        )

        naverMapView.mapView.moveCamera(cameraUpdate)

        return naverMapView
    }

    func updateUIView(
        _ uiView: NMFNaverMapView,
        context: Context
    ) {
        context.coordinator.parent = self

        context.coordinator.updateSavedMarkers(
            places: places,
            mapView: uiView.mapView
        )

        context.coordinator.updateRouteLine(
            places: places,
            mapView: uiView.mapView
        )

        context.coordinator.updateSelectionMarker(
            coordinate: selectedCoordinate,
            placeName: selectedPlaceName,
            mapView: uiView.mapView
        )

        if selectedCoordinate == nil {
            context.coordinator.fitCameraToPlaces(
                places: places,
                mapView: uiView.mapView
            )
        }
    }

    final class Coordinator: NSObject, NMFMapViewTouchDelegate {
        var parent: MapView

        let selectionMarker = NMFMarker()

        private var savedMarkers: [NMFMarker] = []
        private var routeLine: NMFPolylineOverlay?

        private var lastCameraPlaceKey = ""
        private var lastSelectionCameraKey = ""

        init(parent: MapView) {
            self.parent = parent
        }

        func mapView(
            _ mapView: NMFMapView,
            didTapMap latlng: NMGLatLng,
            point: CGPoint
        ) {
            parent.selectedSavedPlace = nil
            parent.selectedPlaceName = ""

            parent.selectedCoordinate = CoordinateData(
                latitude: latlng.lat,
                longitude: latlng.lng
            )
        }

        func updateSelectionMarker(
            coordinate: CoordinateData?,
            placeName: String,
            mapView: NMFMapView
        ) {
            guard let coordinate else {
                selectionMarker.mapView = nil
                lastSelectionCameraKey = ""
                return
            }

            let latLng = NMGLatLng(
                lat: coordinate.latitude,
                lng: coordinate.longitude
            )

            selectionMarker.position = latLng

            selectionMarker.captionText =
                placeName.isEmpty ? "새 위치" : placeName

            selectionMarker.mapView = mapView

            let key =
                "\(coordinate.latitude)-\(coordinate.longitude)"

            guard key != lastSelectionCameraKey else {
                return
            }

            lastSelectionCameraKey = key

            let cameraUpdate = NMFCameraUpdate(
                scrollTo: latLng,
                zoomTo: 16
            )

            cameraUpdate.animation = .easeIn
            cameraUpdate.animationDuration = 0.5

            mapView.moveCamera(cameraUpdate)
        }

        func updateSavedMarkers(
            places: [DatePlace],
            mapView: NMFMapView
        ) {
            savedMarkers.forEach {
                $0.mapView = nil
            }

            savedMarkers.removeAll()

            let sortedPlaces = places.sorted {
                $0.order < $1.order
            }

            for (index, place) in sortedPlaces.enumerated() {
                guard
                    let latitude = place.latitude,
                    let longitude = place.longitude
                else {
                    continue
                }

                let marker = NMFMarker()

                marker.position = NMGLatLng(
                    lat: latitude,
                    lng: longitude
                )

                marker.captionText =
                    "\(index + 1). \(place.name)"

                marker.captionMinZoom = 9

                marker.touchHandler = { [weak self] _ in
                    self?.parent.selectedCoordinate = nil
                    self?.parent.selectedPlaceName = ""
                    self?.parent.selectedSavedPlace = place

                    return true
                }

                marker.mapView = mapView
                savedMarkers.append(marker)
            }
        }

        func updateRouteLine(
            places: [DatePlace],
            mapView: NMFMapView
        ) {
            routeLine?.mapView = nil
            routeLine = nil

            let coordinates = places
                .sorted { $0.order < $1.order }
                .compactMap { place -> NMGLatLng? in
                    guard
                        let latitude = place.latitude,
                        let longitude = place.longitude
                    else {
                        return nil
                    }

                    return NMGLatLng(
                        lat: latitude,
                        lng: longitude
                    )
                }

            guard coordinates.count >= 2 else {
                return
            }

            guard let polyline = NMFPolylineOverlay(
                coordinates
            ) else {
                return
            }

            polyline.width = 5
            polyline.color = UIColor.systemPink
            polyline.capType = NMFOverlayLineCap.round
            polyline.joinType = NMFOverlayLineJoin.round
            polyline.mapView = mapView

            routeLine = polyline
        }

        func fitCameraToPlaces(
            places: [DatePlace],
            mapView: NMFMapView
        ) {
            let coordinatePlaces = places
                .filter {
                    $0.latitude != nil &&
                    $0.longitude != nil
                }
                .sorted {
                    $0.order < $1.order
                }

            let currentKey = coordinatePlaces
                .map {
                    "\($0.order)-\($0.latitude ?? 0)-\($0.longitude ?? 0)"
                }
                .joined(separator: "|")

            guard currentKey != lastCameraPlaceKey else {
                return
            }

            lastCameraPlaceKey = currentKey

            let coordinates = coordinatePlaces.compactMap {
                place -> NMGLatLng? in

                guard
                    let latitude = place.latitude,
                    let longitude = place.longitude
                else {
                    return nil
                }

                return NMGLatLng(
                    lat: latitude,
                    lng: longitude
                )
            }

            guard !coordinates.isEmpty else {
                return
            }

            if coordinates.count == 1 {
                let cameraUpdate = NMFCameraUpdate(
                    scrollTo: coordinates[0],
                    zoomTo: 15
                )

                cameraUpdate.animation = .easeIn
                mapView.moveCamera(cameraUpdate)
                return
            }

            var minLatitude = coordinates[0].lat
            var maxLatitude = coordinates[0].lat
            var minLongitude = coordinates[0].lng
            var maxLongitude = coordinates[0].lng

            for coordinate in coordinates.dropFirst() {
                minLatitude = min(
                    minLatitude,
                    coordinate.lat
                )

                maxLatitude = max(
                    maxLatitude,
                    coordinate.lat
                )

                minLongitude = min(
                    minLongitude,
                    coordinate.lng
                )

                maxLongitude = max(
                    maxLongitude,
                    coordinate.lng
                )
            }

            let bounds = NMGLatLngBounds(
                southWest: NMGLatLng(
                    lat: minLatitude,
                    lng: minLongitude
                ),
                northEast: NMGLatLng(
                    lat: maxLatitude,
                    lng: maxLongitude
                )
            )

            let cameraUpdate = NMFCameraUpdate(
                fit: bounds,
                padding: 80
            )

            cameraUpdate.animation = .easeIn
            mapView.moveCamera(cameraUpdate)
        }
    }
}

struct CoordinateData: Equatable {
    let latitude: Double
    let longitude: Double
}

#Preview {
    MapView(
        places: [],
        selectedCoordinate: .constant(nil),
        selectedSavedPlace: .constant(nil),
        selectedPlaceName: .constant("")
    )
}
