import SwiftUI
import UIKit
import MapKit
import NMapsMap

struct MapDistrict {
    let code: String
    let name: String
    let province: String?
    let polygons: [[NMGLatLng]]

    var displayName: String {
        guard let province, !province.isEmpty else {
            return name
        }

        return "\(province) \(name)"
    }
}

struct MapDistrictVisitSummary: Identifiable, Hashable {
    let code: String
    let name: String
    let visitCount: Int
    let latitude: Double
    let longitude: Double

    var id: String {
        code
    }
}

private struct DistrictGeoJSONProperties: Decodable {
    let code: String
    let name: String
    let province: String?

    enum CodingKeys: String, CodingKey {
        case code = "SIG_CD"
        case name = "SIG_KOR_NM"
        case id
        case title
        case province
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(
            String.self,
            forKey: .code
        ) ?? container.decode(
            String.self,
            forKey: .id
        )
        name = try container.decodeIfPresent(
            String.self,
            forKey: .name
        ) ?? container.decode(
            String.self,
            forKey: .title
        )
        province = try container.decodeIfPresent(
            String.self,
            forKey: .province
        )
    }
}

enum MapDistrictStore {
    private static var cachedDistricts: [MapDistrict]?

    static func districts() -> [MapDistrict] {
        if let cachedDistricts {
            return cachedDistricts
        }

        guard
            let url = Bundle.main.url(
                forResource: "sig",
                withExtension: "geojson"
            ),
            let data = try? Data(contentsOf: url),
            let objects = try? MKGeoJSONDecoder().decode(data)
        else {
            cachedDistricts = []
            return []
        }

        let districts = objects.compactMap { object -> MapDistrict? in
            guard
                let feature = object as? MKGeoJSONFeature,
                let propertiesData = feature.properties,
                let properties = try? JSONDecoder().decode(
                    DistrictGeoJSONProperties.self,
                    from: propertiesData
                )
            else {
                return nil
            }

            let polygons = feature.geometry.flatMap { geometry in
                districtPolygons(from: geometry)
            }

            guard !polygons.isEmpty else {
                return nil
            }

            return MapDistrict(
                code: properties.code,
                name: properties.name,
                province: properties.province,
                polygons: polygons
            )
        }

        cachedDistricts = districts
        return districts
    }

    static func district(withCode code: String) -> MapDistrict? {
        districts().first { $0.code == code }
    }

    static func districtCode(for place: DatePlace) -> String? {
        districts().first { district in
            districtMatches(place: place, district: district)
        }?.code
    }

    private static func districtPolygons(
        from geometry: any MKShape & MKGeoJSONObject
    ) -> [[NMGLatLng]] {
        if let polygon = geometry as? MKPolygon {
            return [coordinates(from: polygon)]
        }

        if let multiPolygon = geometry as? MKMultiPolygon {
            return multiPolygon.polygons.map {
                coordinates(from: $0)
            }
        }

        return []
    }

    private static func coordinates(from polygon: MKPolygon) -> [NMGLatLng] {
        var coordinates = Array(
            repeating: CLLocationCoordinate2D(),
            count: polygon.pointCount
        )
        polygon.getCoordinates(
            &coordinates,
            range: NSRange(
                location: 0,
                length: polygon.pointCount
            )
        )

        return coordinates.map {
            NMGLatLng(
                lat: $0.latitude,
                lng: $0.longitude
            )
        }
    }

    private static func districtMatches(
        place: DatePlace,
        district: MapDistrict
    ) -> Bool {
        if
            let latitude = place.latitude,
            let longitude = place.longitude,
            districtContains(
                coordinate: NMGLatLng(lat: latitude, lng: longitude),
                district: district
            )
        {
            return true
        }

        if place.address.contains(district.name) {
            return true
        }

        if place.name.contains(district.name) {
            return true
        }

        return false
    }

    private static func districtContains(
        coordinate: NMGLatLng,
        district: MapDistrict
    ) -> Bool {
        district.polygons.contains {
            polygonContains(coordinate: coordinate, polygon: $0)
        }
    }

    private static func polygonContains(
        coordinate: NMGLatLng,
        polygon: [NMGLatLng]
    ) -> Bool {
        guard polygon.count >= 3 else {
            return false
        }

        var isInside = false
        var previousIndex = polygon.count - 1

        for currentIndex in polygon.indices {
            let currentPoint = polygon[currentIndex]
            let previousPoint = polygon[previousIndex]
            let crossesLatitude = (currentPoint.lat > coordinate.lat) !=
                (previousPoint.lat > coordinate.lat)

            if crossesLatitude {
                let intersectionLongitude = (previousPoint.lng - currentPoint.lng) *
                    (coordinate.lat - currentPoint.lat) /
                    (previousPoint.lat - currentPoint.lat) +
                    currentPoint.lng

                if coordinate.lng < intersectionLongitude {
                    isInside.toggle()
                }
            }

            previousIndex = currentIndex
        }

        return isInside
    }
}


struct MapView: UIViewRepresentable {

    let places: [DatePlace]
    let showsHeatmap: Bool
    let showsMarkerOrder: Bool

    @AppStorage("dateLogTheme")
    private var selectedThemeRawValue = DateLogTheme.standard.rawValue

    private var selectedTheme: DateLogTheme {
        DateLogTheme(rawValue: selectedThemeRawValue) ?? .standard
    }

    @Binding var selectedCoordinate: CoordinateData?
    @Binding var selectedSavedPlace: DatePlace?
    @Binding var selectedPlaceName: String
    @Binding var selectedDistrictVisit: MapDistrictVisitSummary?
    var onDistrictBubbleTap: (MapDistrictVisitSummary) -> Void = { _ in }

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

        if showsHeatmap {
            context.coordinator.clearSavedMarkers()
            context.coordinator.updateHeatmapMarkers(
                places: places,
                mapView: uiView.mapView
            )
        } else {
            context.coordinator.clearHeatmapMarkers()
            context.coordinator.clearDistrictOverlays()
            context.coordinator.updateSavedMarkers(
                places: places,
                mapView: uiView.mapView
            )
        }

        context.coordinator.updateDistrictBubble(
            summary: showsHeatmap ? selectedDistrictVisit : nil,
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
        private var heatmapMarkers: [NMFMarker] = []
        private var districtOverlays: [NMFPolygonOverlay] = []
        private let districtBubbleMarker = NMFMarker()

        private var lastCameraPlaceKey = ""
        private var lastSelectionCameraKey = ""
        private var lastMarkerPlaceKey = ""
        private var lastHeatmapPlaceKey = ""
        private var lastDistrictHeatmapKey = ""
        private var lastDistrictBubbleKey = ""

        init(parent: MapView) {
            self.parent = parent
        }

        func mapView(
            _ mapView: NMFMapView,
            didTapMap latlng: NMGLatLng,
            point: CGPoint
        ) {
        }

        func mapView(
            _ mapView: NMFMapView,
            didLongTapMap latlng: NMGLatLng,
            point: CGPoint
        ) {
            parent.selectedSavedPlace = nil
            parent.selectedDistrictVisit = nil
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
            selectionMarker.iconImage = NMF_MARKER_IMAGE_PINK
            selectionMarker.iconTintColor = UIColor(parent.selectedTheme.primaryColor)
            selectionMarker.width = 38
            selectionMarker.height = 48
            selectionMarker.captionText =
                placeName.isEmpty ? "새 위치" : placeName
            selectionMarker.captionColor = UIColor.label
            selectionMarker.captionHaloColor = UIColor.systemBackground
            selectionMarker.zIndex = 3000
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
            let sortedPlaces = places.sorted {
                $0.order < $1.order
            }

            let markerKey = sortedPlaces
                .map {
                    let category = PlaceCategoryNormalizer.categoryName(
                        from: $0.categoryName
                    )

                    return "\($0.order)-\($0.name)-\(category)-\($0.latitude ?? 0)-\($0.longitude ?? 0)"
                }
                .joined(separator: "|")
                + "-\(parent.showsMarkerOrder)"

            guard markerKey != lastMarkerPlaceKey else {
                return
            }

            lastMarkerPlaceKey = markerKey

            savedMarkers.forEach {
                $0.mapView = nil
            }

            savedMarkers.removeAll()

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

                marker.iconImage = NMFOverlayImage(
                    image: categoryMarkerImage(for: place.categoryName)
                )
                marker.width = 32
                marker.height = 42
                marker.captionText = parent.showsMarkerOrder
                    ? "\(index + 1). \(place.name)"
                    : place.name
                marker.captionColor = UIColor.label
                marker.captionHaloColor = UIColor.systemBackground
                marker.captionMinZoom = 9
                marker.zIndex = 1500 + index

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

        private func categoryMarkerImage(for category: String) -> UIImage {
            let size = CGSize(width: 32, height: 42)
            let renderer = UIGraphicsImageRenderer(size: size)
            let pinColor = PlaceCategoryNormalizer.uiColor(for: category)

            return renderer.image { context in
                let cgContext = context.cgContext
                let bodyRect = CGRect(x: 5, y: 3, width: 22, height: 22)
                let path = UIBezierPath(ovalIn: bodyRect)
                path.move(to: CGPoint(x: 16, y: 39))
                path.addLine(to: CGPoint(x: 9, y: 22))
                path.addQuadCurve(
                    to: CGPoint(x: 23, y: 22),
                    controlPoint: CGPoint(x: 16, y: 29)
                )
                path.close()

                cgContext.saveGState()
                cgContext.setShadow(
                    offset: CGSize(width: 0, height: 3),
                    blur: 5,
                    color: UIColor.black.withAlphaComponent(0.22).cgColor
                )
                pinColor.setFill()
                path.fill()
                cgContext.restoreGState()

                UIColor.white.withAlphaComponent(0.90).setStroke()
                path.lineWidth = 2
                path.stroke()

                UIColor.white.withAlphaComponent(0.88).setFill()
                UIBezierPath(
                    ovalIn: CGRect(x: 12, y: 10, width: 8, height: 8)
                ).fill()
            }
        }

        func clearSavedMarkers() {
            guard !savedMarkers.isEmpty else {
                return
            }

            savedMarkers.forEach {
                $0.mapView = nil
            }
            savedMarkers.removeAll()
            lastMarkerPlaceKey = ""
        }

        func clearHeatmapMarkers() {
            guard !heatmapMarkers.isEmpty else {
                return
            }

            heatmapMarkers.forEach {
                $0.mapView = nil
            }
            heatmapMarkers.removeAll()
            lastHeatmapPlaceKey = ""
        }

        func clearDistrictOverlays() {
            guard !districtOverlays.isEmpty else {
                return
            }

            districtOverlays.forEach {
                $0.mapView = nil
            }
            districtOverlays.removeAll()
            lastDistrictHeatmapKey = ""
        }

        func updateHeatmapMarkers(
            places: [DatePlace],
            mapView: NMFMapView
        ) {
            clearHeatmapMarkers()
            updateDistrictHeatmap(
                places: places,
                mapView: mapView
            )
        }

        @discardableResult
        private func updateDistrictHeatmap(
            places: [DatePlace],
            mapView: NMFMapView
        ) -> Bool {
            let districts = MapDistrictStore.districts()

            guard !districts.isEmpty else {
                return false
            }

            let visitCounts = districtVisitCounts(
                places: places,
                districts: districts
            )

            let districtHeatmapKey = visitCounts
                .map { "\($0.key)-\($0.value)" }
                .sorted()
                .joined(separator: "|")
                + "-\(parent.selectedTheme.rawValue)"

            guard districtHeatmapKey != lastDistrictHeatmapKey else {
                return true
            }

            lastDistrictHeatmapKey = districtHeatmapKey
            clearDistrictOverlays()
            lastDistrictHeatmapKey = districtHeatmapKey

            let maximumCount = max(visitCounts.values.max() ?? 1, 1)

            for district in districts {
                guard let count = visitCounts[district.code], count > 0 else {
                    continue
                }

                let intensity = CGFloat(count) / CGFloat(maximumCount)
                let center = districtCenter(of: district)

                for points in district.polygons where points.count >= 3 {
                    let polygonPoints = naverPolygonPoints(from: points)

                    guard polygonPoints.count >= 3 else {
                        continue
                    }

                    guard let overlay = NMFPolygonOverlay(polygonPoints) else {
                        continue
                    }
                    overlay.fillColor = UIColor(
                        parent.selectedTheme.primaryColor
                    )
                    .withAlphaComponent(0.24 + 0.48 * intensity)
                    overlay.outlineColor = UIColor(
                        parent.selectedTheme.primaryColor
                    )
                    .withAlphaComponent(0.52 + 0.38 * intensity)
                    overlay.outlineWidth = 1
                    overlay.zIndex = 900
                    overlay.touchHandler = { [weak self] _ in
                        self?.parent.selectedCoordinate = nil
                        self?.parent.selectedPlaceName = ""
                        self?.parent.selectedSavedPlace = nil
                        self?.parent.selectedDistrictVisit = MapDistrictVisitSummary(
                            code: district.code,
                            name: district.displayName,
                            visitCount: count,
                            latitude: center.lat,
                            longitude: center.lng
                        )

                        return true
                    }
                    overlay.mapView = mapView

                    districtOverlays.append(overlay)
                }
            }

            return true
        }

        func updateDistrictBubble(
            summary: MapDistrictVisitSummary?,
            mapView: NMFMapView
        ) {
            guard let summary else {
                districtBubbleMarker.mapView = nil
                lastDistrictBubbleKey = ""
                return
            }

            let bubbleKey =
                "\(summary.code)-\(summary.visitCount)-\(parent.selectedTheme.rawValue)"

            if bubbleKey != lastDistrictBubbleKey {
                lastDistrictBubbleKey = bubbleKey

                let (image, anchor) = districtBubbleImage(
                    name: summary.name,
                    visitCount: summary.visitCount
                )

                districtBubbleMarker.iconImage = NMFOverlayImage(image: image)
                districtBubbleMarker.anchor = anchor
            }

            districtBubbleMarker.position = NMGLatLng(
                lat: summary.latitude,
                lng: summary.longitude
            )
            districtBubbleMarker.zIndex = 2600
            districtBubbleMarker.touchHandler = { [weak self] _ in
                guard let summary = self?.parent.selectedDistrictVisit else {
                    return true
                }

                self?.parent.onDistrictBubbleTap(summary)
                return true
            }
            districtBubbleMarker.mapView = mapView
        }

        private func districtBubbleImage(
            name: String,
            visitCount: Int
        ) -> (image: UIImage, anchor: CGPoint) {
            let titleFont = UIFont(name: "Pretendard-Bold", size: 14)
                ?? .systemFont(ofSize: 14, weight: .bold)
            let subtitleFont = UIFont(name: "Pretendard-Medium", size: 12)
                ?? .systemFont(ofSize: 12, weight: .medium)
            let countFont = UIFont(name: "Pretendard-Bold", size: 12)
                ?? .systemFont(ofSize: 12, weight: .bold)

            let title = NSAttributedString(
                string: name,
                attributes: [
                    .font: titleFont,
                    .foregroundColor: UIColor.black.withAlphaComponent(0.86)
                ]
            )

            let subtitle = NSMutableAttributedString()
            subtitle.append(
                NSAttributedString(
                    string: "총 ",
                    attributes: [
                        .font: subtitleFont,
                        .foregroundColor: UIColor.black.withAlphaComponent(0.58)
                    ]
                )
            )
            subtitle.append(
                NSAttributedString(
                    string: "\(visitCount)회",
                    attributes: [
                        .font: countFont,
                        .foregroundColor: UIColor(parent.selectedTheme.primaryColor)
                    ]
                )
            )
            subtitle.append(
                NSAttributedString(
                    string: " 방문",
                    attributes: [
                        .font: subtitleFont,
                        .foregroundColor: UIColor.black.withAlphaComponent(0.58)
                    ]
                )
            )

            let titleSize = title.size()
            let subtitleSize = subtitle.size()
            let horizontalPadding: CGFloat = 15
            let verticalPadding: CGFloat = 10
            let lineSpacing: CGFloat = 3
            let tailWidth: CGFloat = 14
            let tailHeight: CGFloat = 8
            let shadowPadding: CGFloat = 14

            let bubbleWidth = max(titleSize.width, subtitleSize.width)
                + horizontalPadding * 2
            let bubbleHeight = titleSize.height + lineSpacing + subtitleSize.height
                + verticalPadding * 2
            let imageSize = CGSize(
                width: bubbleWidth + shadowPadding * 2,
                height: bubbleHeight + tailHeight + shadowPadding * 2
            )

            let renderer = UIGraphicsImageRenderer(size: imageSize)

            let image = renderer.image { context in
                let bubbleRect = CGRect(
                    x: shadowPadding,
                    y: shadowPadding,
                    width: bubbleWidth,
                    height: bubbleHeight
                )

                let path = UIBezierPath(
                    roundedRect: bubbleRect,
                    cornerRadius: 13
                )

                let tailTipX = imageSize.width / 2
                let tail = UIBezierPath()
                tail.move(
                    to: CGPoint(
                        x: tailTipX - tailWidth / 2,
                        y: bubbleRect.maxY - 1
                    )
                )
                tail.addLine(
                    to: CGPoint(
                        x: tailTipX,
                        y: bubbleRect.maxY + tailHeight
                    )
                )
                tail.addLine(
                    to: CGPoint(
                        x: tailTipX + tailWidth / 2,
                        y: bubbleRect.maxY - 1
                    )
                )
                tail.close()
                path.append(tail)

                let cgContext = context.cgContext
                cgContext.saveGState()
                cgContext.setShadow(
                    offset: CGSize(width: 0, height: 4),
                    blur: 10,
                    color: UIColor.black.withAlphaComponent(0.22).cgColor
                )
                UIColor.white.setFill()
                path.fill()
                cgContext.restoreGState()

                title.draw(
                    at: CGPoint(
                        x: shadowPadding + (bubbleWidth - titleSize.width) / 2,
                        y: shadowPadding + verticalPadding
                    )
                )
                subtitle.draw(
                    at: CGPoint(
                        x: shadowPadding + (bubbleWidth - subtitleSize.width) / 2,
                        y: shadowPadding + verticalPadding
                            + titleSize.height + lineSpacing
                    )
                )
            }

            let anchor = CGPoint(
                x: 0.5,
                y: (shadowPadding + bubbleHeight + tailHeight) / imageSize.height
            )

            return (image, anchor)
        }

        private func districtCenter(of district: MapDistrict) -> NMGLatLng {
            let largestPolygon = district.polygons.max {
                polygonArea($0) < polygonArea($1)
            }

            guard
                let largestPolygon,
                let centroid = polygonCentroid(largestPolygon)
            else {
                return district.polygons.first?.first
                    ?? NMGLatLng(lat: 37.5665, lng: 126.9780)
            }

            return centroid
        }

        private func polygonArea(_ points: [NMGLatLng]) -> Double {
            guard points.count >= 3 else {
                return 0
            }

            var doubledArea = 0.0

            for index in points.indices {
                let current = points[index]
                let next = points[(index + 1) % points.count]
                doubledArea += current.lng * next.lat - next.lng * current.lat
            }

            return abs(doubledArea) / 2
        }

        private func polygonCentroid(_ points: [NMGLatLng]) -> NMGLatLng? {
            guard points.count >= 3 else {
                return nil
            }

            var doubledArea = 0.0
            var latitudeSum = 0.0
            var longitudeSum = 0.0

            for index in points.indices {
                let current = points[index]
                let next = points[(index + 1) % points.count]
                let cross = current.lng * next.lat - next.lng * current.lat
                doubledArea += cross
                longitudeSum += (current.lng + next.lng) * cross
                latitudeSum += (current.lat + next.lat) * cross
            }

            guard abs(doubledArea) > .ulpOfOne else {
                return nil
            }

            return NMGLatLng(
                lat: latitudeSum / (3 * doubledArea),
                lng: longitudeSum / (3 * doubledArea)
            )
        }

        private func naverPolygonPoints(
            from points: [NMGLatLng]
        ) -> [NMGLatLng] {
            var normalizedPoints = points

            if
                let first = normalizedPoints.first,
                let last = normalizedPoints.last,
                first.lat == last.lat,
                first.lng == last.lng
            {
                normalizedPoints.removeLast()
            }

            if !isClockwise(normalizedPoints) {
                normalizedPoints.reverse()
            }

            return normalizedPoints
        }

        private func isClockwise(_ points: [NMGLatLng]) -> Bool {
            guard points.count >= 3 else {
                return true
            }

            let area = zip(points, points.dropFirst() + [points[0]])
                .reduce(0.0) { partialResult, pair in
                    let current = pair.0
                    let next = pair.1

                    return partialResult +
                        (current.lng * next.lat - next.lng * current.lat)
                }

            return area < 0
        }

        private func districtVisitCounts(
            places: [DatePlace],
            districts: [MapDistrict]
        ) -> [String: Int] {
            var counts: [String: Int] = [:]

            for place in places {
                guard
                    let district = districts.first(where: {
                        districtMatches(place: place, district: $0)
                    })
                else {
                    continue
                }

                counts[district.code, default: 0] += 1
            }

            return counts
        }

        private func districtMatches(
            place: DatePlace,
            district: MapDistrict
        ) -> Bool {
            if
                let latitude = place.latitude,
                let longitude = place.longitude,
                districtContains(
                    coordinate: NMGLatLng(
                        lat: latitude,
                        lng: longitude
                    ),
                    district: district
                )
            {
                return true
            }

            if place.address.contains(district.name) {
                return true
            }

            if place.name.contains(district.name) {
                return true
            }

            return false
        }

        private func districtContains(
            coordinate: NMGLatLng,
            district: MapDistrict
        ) -> Bool {
            district.polygons.contains {
                polygonContains(
                    coordinate: coordinate,
                    polygon: $0
                )
            }
        }

        private func polygonContains(
            coordinate: NMGLatLng,
            polygon: [NMGLatLng]
        ) -> Bool {
            guard polygon.count >= 3 else {
                return false
            }

            var isInside = false
            var previousIndex = polygon.count - 1

            for currentIndex in polygon.indices {
                let current = polygon[currentIndex]
                let previous = polygon[previousIndex]
                let crossesLatitude = (current.lat > coordinate.lat) !=
                    (previous.lat > coordinate.lat)

                if crossesLatitude {
                    let intersectionLongitude =
                        (previous.lng - current.lng) *
                        (coordinate.lat - current.lat) /
                        (previous.lat - current.lat) +
                        current.lng

                    if coordinate.lng < intersectionLongitude {
                        isInside.toggle()
                    }
                }

                previousIndex = currentIndex
            }

            return isInside
        }

        private func heatmapRegionKey(
            address: String,
            latitude: Double,
            longitude: Double
        ) -> String {
            let addressParts = address
                .split(separator: " ")
                .map(String.init)

            if addressParts.count >= 2 {
                return "\(addressParts[0]) \(addressParts[1])"
            }

            if let firstPart = addressParts.first {
                return firstPart
            }

            return String(
                format: "%.2f, %.2f",
                latitude,
                longitude
            )
        }

        private func heatmapImage(
            color: UIColor,
            alpha: CGFloat
        ) -> UIImage {
            let size = CGSize(width: 96, height: 96)
            let renderer = UIGraphicsImageRenderer(size: size)

            return renderer.image { context in
                let rect = CGRect(origin: .zero, size: size)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let colors = [
                    color.withAlphaComponent(alpha).cgColor,
                    color.withAlphaComponent(alpha * 0.38).cgColor,
                    color.withAlphaComponent(0).cgColor
                ] as CFArray
                let locations: [CGFloat] = [0, 0.58, 1]

                guard let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors,
                    locations: locations
                ) else {
                    color.withAlphaComponent(alpha).setFill()
                    context.cgContext.fillEllipse(in: rect)
                    return
                }

                context.cgContext.drawRadialGradient(
                    gradient,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: size.width / 2,
                    options: [.drawsAfterEndLocation]
                )
            }
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

#Preview {
    MapView(
        places: [],
        showsHeatmap: false,
        showsMarkerOrder: true,
        selectedCoordinate: .constant(nil),
        selectedSavedPlace: .constant(nil),
        selectedPlaceName: .constant(""),
        selectedDistrictVisit: .constant(nil)
    )
}
