//
//  ViewController.swift
//  Turn by Turn Navigation
//
//  Created by Anuj Dutt on 2/21/19.
//  Copyright © 2019 Anuj Dutt. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import AVFoundation

class ViewController: UIViewController, CLLocationManagerDelegate, UISearchBarDelegate, MKMapViewDelegate {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var mapView: MKMapView!
    
    let locationManager = CLLocationManager()
    var currentCoordinate: CLLocationCoordinate2D?
    var steps = [MKRoute.Step]()
    let speechSynthesizer = AVSpeechSynthesizer()
    var stepCounter = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.requestAlwaysAuthorization()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.startUpdatingLocation()
        self.searchBar.delegate = self
        self.mapView.delegate = self
    }

    func getDirections(to destination: MKMapItem){
        let sourcePlacemark = MKPlacemark(coordinate: self.currentCoordinate!)
        let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
        let directionRequest = MKDirections.Request()
        directionRequest.source = sourceMapItem
        directionRequest.destination = destination
        directionRequest.transportType = .automobile
        
        let directions = MKDirections(request: directionRequest)
        directions.calculate { (response, error) in
            guard let response = response else {return}
            guard let route = response.routes.first else {return}
            self.mapView.addOverlay(route.polyline)
            self.locationManager.monitoredRegions.forEach({self.locationManager.stopMonitoring(for: $0)})
            self.steps = route.steps
            for i in 0 ..< route.steps.count{
                let step = route.steps[i]
                //print("Instructions: \(step.instructions)")
                //print("Distance: \(step.distance)")
                let region = CLCircularRegion(center: step.polyline.coordinate, radius: 20, identifier: "\(i)")
                self.locationManager.startMonitoring(for: region)
                let circle = MKCircle(center: region.center, radius: region.radius)
                self.mapView.addOverlay(circle)
            }
            
            let message = "In \(self.steps[0].distance) meters, \(self.steps[0].instructions), then in \(self.steps[1].distance) meters, \(self.steps[1].instructions)."
            let speechUtterance = AVSpeechUtterance(string: message)
            self.speechSynthesizer.speak(speechUtterance)
            self.stepCounter += 1
        }
    }
    
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        manager.stopUpdatingLocation()
        guard let currentLocation = locations.first else {return}
        self.currentCoordinate = currentLocation.coordinate
        mapView.userTrackingMode = .followWithHeading
    }

    
    // If entered a geofence
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        stepCounter += 1
        if stepCounter < steps.count{
            let currentStep = steps[stepCounter]
            let message = "In \(currentStep.distance) meters, \(currentStep.instructions)."
            let speechUtterance = AVSpeechUtterance(string: message)
            speechSynthesizer.speak(speechUtterance)
        }
        else{
            print("Arrived at Destination.")
            let message = "Arrived at Destination."
            let speechUtterance = AVSpeechUtterance(string: message)
            speechSynthesizer.speak(speechUtterance)
            stepCounter = 0
            locationManager.monitoredRegions.forEach({self.locationManager.stopMonitoring(for: $0)})
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
        let localSearchRequest = MKLocalSearch.Request()
        localSearchRequest.naturalLanguageQuery = searchBar.text
        let region = MKCoordinateRegion(center: currentCoordinate!, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        localSearchRequest.region = region
        let localSearch = MKLocalSearch(request: localSearchRequest)
        localSearch.start { (response, error) in
            guard let response = response else {return}
            guard let firstMapItem = response.mapItems.first else {return}
            self.getDirections(to: firstMapItem)
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKPolyline {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = UIColor.blue
            renderer.lineWidth = 5
            return renderer
        }
        if overlay is MKCircle {
            let renderer = MKCircleRenderer(overlay: overlay)
            renderer.strokeColor = UIColor.red
            renderer.fillColor = UIColor.red
            renderer.alpha = 0.5
            return renderer
        }
        return MKOverlayRenderer()
    }
}

