import UIKit
import MapLibre

class ViewController: UIViewController {
    
    private let mapBounds: MLNCoordinateBounds = MLNCoordinateBounds(
        sw: CLLocationCoordinate2D(latitude: -65, longitude: -180),
        ne: CLLocationCoordinate2D(latitude: 90, longitude: 180)
    )
    
    var layers = [MLNFillStyleLayer]()
    
    private let migrationRegions = ["caribbean", "south_american", "central_american"]
    
    private var cachedShapeMap = [String: MLNShape]()
    private var countryPatternFillLayerMap = [String: MLNFillStyleLayer]()
    private var cachedPatterns = [String: String]()

    private static let FillPatternImage = "pattern_image_%@"
    private var defaultZoomCountryList = [String]()
  
    var shapeLayers = [MLNSymbolStyleLayer]()
    
    var mapView: MLNMapView!
    
    var temp: String!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView = MLNMapView(frame: view.bounds)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.delegate = self
        
        mapView.setCenter(CLLocationCoordinate2D(latitude: 41.8864, longitude: -87.7135), zoomLevel: 1, animated: false)
        view.addSubview(mapView)
    }
    
    
    private func setupMapView() {
        self.mapView.delegate = self
        
        // set style URL for default styling and admin layers
        self.mapView.styleURL = URL(fileURLWithPath: Bundle.main.path(forResource: "mapBoxStyle", ofType: "json")!)
        self.view.addSubview(self.mapView)
        
    }
    
    private func applyConstraints() {
        NSLayoutConstraint.activate([
            self.mapView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.mapView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            self.mapView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.mapView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
        ])
    }
    
}

extension ViewController: MLNMapViewDelegate {
    
    func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        DispatchQueue.global().async {
            [weak self] in
            guard let self = self else { return }
            let url = URL(fileURLWithPath: Bundle.main.path(forResource: "ac47Geo", ofType: "json")!)
            guard let feature = self.getGeoJsonShapeCollection(url: url) else {
                DispatchQueue.main.async {
                    
                }
                return
            }
            
            DispatchQueue.main.async {
                self.handleCountryTileLayerDisplay(isVisible: false)
                
                // Add geoJson source as features to preserve geoJson attributes in the shapes to reduce the
                // number of geoJson sources
                
                let source = MLNShapeSource(
                    identifier: "WorldGeoJson",
                    features: feature.shapes,
                    options: nil)
                style.addSource(source)
                
                self.createMigrationRegionPatternMap()
                self.createCountryShapeLayers(source: source, shapes: feature.shapes)
                
                self.resetZoomToDefault()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    
                    // Will work for most shapes
                    let shape = self.cachedShapeMap["BRA"]!
                    
                    for countryLayer in self.countryPatternFillLayerMap.values {
                        countryLayer.fillPattern = nil
                    }
                    self.zoomToShape(shape: shape)
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    for countryLayer in self.countryPatternFillLayerMap.values {
                        countryLayer.fillPattern = NSExpression(forConstantValue: self.temp)
                    }
                    
                    self.resetZoomToDefault()
                }
            }
        }
    }
}

extension ViewController {
    private func getGeoJsonShapeCollection(
        url: URL,
        regionIbdCountryCode: String? = nil) -> MLNShapeCollectionFeature? {
        do {
            let data = try Data(contentsOf: url)
            let shapeCollectionFeature = try? MLNShape(
                data: data,
                encoding: String.Encoding.utf8.rawValue) as? MLNShapeCollectionFeature
            if let regionIbdCountryCode = regionIbdCountryCode, let shapes = shapeCollectionFeature?.shapes {
                // NOTE: use country metadata to re-write geoJson attributes such as iso, id, name etc for country hits
                // This is being done since geoJson properties may not match metadata generated by RAC machine.
                shapes.forEach({
                    $0.attributes.updateValue(regionIbdCountryCode, forKey: "iso")
                    $0.attributes.updateValue(regionIbdCountryCode, forKey: "id")
                    $0.attributes.updateValue(regionIbdCountryCode, forKey: "name")
                })
                return MLNShapeCollectionFeature(shapes: shapes)
            }
            return shapeCollectionFeature
        } catch {
            assertionFailure("Could not cast geoJson data into MLNShapeCollectionFeature url: \(url)")
            return nil
        }
    }
    
    private func handleCountryTileLayerDisplay(isVisible: Bool) {
        if let countryTileLayer = self.mapView.style?.layer(withIdentifier: "place_country") {
            countryTileLayer.isVisible = isVisible
        }
    }
    
    private func createMigrationRegionPatternMap() {
        for region in migrationRegions {
            let stripedView = StripedView(
                frame: CGRect(x: 0, y: 0, width: 1024, height: 1024)
            )
            stripedView.configure(
                viewModel: StripedViewModel(
                    lineGap: CGFloat(2.0),
                    lineWidth: CGFloat(1.0),
                    lineColor: UIColor.gray,
                    backgroundColor: UIColor.white,
                    lineDirection: .leftToRight))
            // Add patterned image to mapBox style layer for later access as fill pattern
            let imageName = String(format: ViewController.FillPatternImage, region)
            self.mapView.style?.setImage(stripedView.asImage(), forName: imageName)
        }
    }
    
    private func createCountryShapeLayers(source: MLNShapeSource, shapes: [MLNShape & MLNFeature]) {
        for shape in shapes {
            // discard shapes without an iso
            guard let iso = shape.attribute(forKey: "iso") as? String, !iso.isEmpty else {
                continue
            }
            self.cachedShapeMap[iso] = shape
            
            if let countryFillPatternName = self.getPatternImageNameForCountry(iso) {
                self.temp = countryFillPatternName
                let identifier = "migration_" + iso
                let patternLayer = MLNFillStyleLayer(identifier: identifier, source: source)
                patternLayer.fillPattern = NSExpression(forConstantValue: countryFillPatternName)
                patternLayer.predicate = NSPredicate(format: "%@ == %@", "iso", iso)
                patternLayer.fillOutlineColor = NSExpression(forConstantValue: UIColor.white)
                self.countryPatternFillLayerMap[iso] = patternLayer
                self.insertLayer(layer: patternLayer, belowCityLayer: false)
            }
        }
    }
    
    private func insertLayer(layer: MLNStyleLayer, belowCityLayer: Bool) {
        guard let cityLayer = self.mapView.style?.layers.first(
            where: { $0.identifier.contains("place_city_town_village")}) else {
            self.mapView.style?.addLayer(layer)
            return
        }
        if belowCityLayer {
            self.mapView.style?.insertLayer(layer, below: cityLayer)
        } else {
            self.mapView.style?.insertLayer(layer, above: cityLayer)
        }
    }
    
    private func resetZoomToDefault() {
        self.handleCountryTileLayerDisplay(isVisible: false)
        guard !self.defaultZoomCountryList.isEmpty, !self.cachedShapeMap.isEmpty else {
            self.mapView.setVisibleCoordinateBounds(self.mapBounds, animated: true)
            return
        }
        var shapes = [MLNShape]()
        for country in self.defaultZoomCountryList {
            if let shape = self.cachedShapeMap[country] {
                shapes.append(shape)
            }
        }
        let compositeShape = MLNShapeCollectionFeature(shapes: shapes)
        self.zoomToShape(shape: compositeShape)
    }
    
    private func getPatternImageNameForCountry(_ countryId: String) -> String? {
        for migrationRegion in self.migrationRegions {
            let fillPatternImageName = String(format: ViewController.FillPatternImage, migrationRegion)
            self.cachedPatterns[countryId] = fillPatternImageName
            return fillPatternImageName
        }
        return nil
    }
    
    private func zoomToShape(shape: MLNShape, completion: (() -> Void)? = nil) {
        let camera = self.mapView.cameraThatFitsShape(shape, direction: .zero, edgePadding: UIEdgeInsets())
        self.mapView.setCamera(
            camera,
            withDuration: 0.6,
            animationTimingFunction: CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut),
            completionHandler: completion
        )
    }
}

