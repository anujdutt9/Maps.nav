//
//  ViewController.swift
//  Maps.nav
//
//  Created by Anuj Dutt on 11/30/17.
//  Copyright © 2017 Anuj Dutt. All rights reserved.
//

// Steps & Functions:
// 1. Make OS Keyboard disappear on tapping anywhere in the imageView except the text field
// 2. Setup Location Manager and get the "Location Access Authorization" from User else display a Toast Message
// 3. once the Location Access Authorization is given, Zoom into the User's Location
// 4. Once the "User's location is Found", Input the "Coordinates of the Destination" and "Navigate"
// 5. Once the route is found, clear the map and start Navigation
// 6. Provide colors and other options while rendering the overlay route on the Map. This allows users to drop the pin anywhere in the map and gets the coordinates of the destination in the text field by itself

// To Do: Restrict text field to take only numbers as input.

import UIKit
import Toaster
import MapKit
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var userLatitude: UITextField!
    @IBOutlet weak var userLongitude: UITextField!
    @IBOutlet weak var destinationLatitude: UITextField!
    @IBOutlet weak var destinationLongitude: UITextField!
    @IBOutlet weak var mapView: MKMapView!
    
    // Step-2. Setup Location Manager
    let locationManager = CLLocationManager()
    var movedToUserLocation = false
    var userLoc: CLLocation? = nil
    
    // Main Function to run at App Startup
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. Add Tap gesture recognizer for making OSK Disappear
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.OSKDisappear))
        view.addGestureRecognizer(tapRecognizer)
        
        // 2. Set the Map View and Location Manager Delegate to self
        mapView.delegate = self
        locationManager.delegate = self
        // Set desired accuracy for location manager
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        
        // 7. Draw route and Navigate from User Location to Pin Location
        let pinDrop = UILongPressGestureRecognizer(target: self, action: #selector(self.dropAnnotation))
        mapView.addGestureRecognizer(pinDrop)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    // Step-1: Make OS Keyboard disappear on tapping anywhere in the imageView except the text field
    @objc func OSKDisappear(){
        view.endEditing(true)
    }
    
    
    // Step-2: Get the "Location Access Authorization" from User
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
            // If the Location Access is Denied, send a Toast Message
            case .denied,.restricted:
                print("The user denied Location Access Authorization Request !!")
                // Add Toast Message
                Toast(text: "Location Access Denied !! Maps accuracy might be affected.", duration: 1.0).show()
            // If the status is not determined, request Authorization
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            // If authorization was given, start updating user's current location
            default:
                //manager.startUpdatingLocation()
                // Get User Location and Zoom into that Location
                self.zoomIntoUserLocation()
                Toast(text: "Location Access Authorized !! Accessing User Location.", duration: 1.0).show()
                
                // 3. Get the Coordinates of the User's Current Location
                self.userLoc = locationManager.location!
                userLatitude.text = "\(userLoc?.coordinate.latitude ?? 0)"
                userLongitude.text = "\(userLoc?.coordinate.longitude ?? 0)"
            }
    }
    
    
    // Step-3: Zoom into User's Location at App Startup
    func zoomIntoUserLocation(){
        let currLocation = locationManager.location
        let noLocation = CLLocationCoordinate2D(latitude: (currLocation?.coordinate.latitude)!, longitude: (currLocation?.coordinate.longitude)!)
        // Zoom Within 10 meters
        let viewRegion = MKCoordinateRegionMakeWithDistance(noLocation, 10, 10)
        mapView.setRegion(viewRegion, animated: true)
        DispatchQueue.main.async {
            self.locationManager.startUpdatingLocation()
        }
    }
    
    
    // Step-3 (II): Function to open User Location at APP Startup
//    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
//        if !movedToUserLocation{
//            mapView.region.center = mapView.userLocation.coordinate
//            movedToUserLocation = true
//        }
//    }
    
    
    // Step-4: Get the "Coordinates of Destination from Text Fields" and "Navigate The User"
    @IBAction func navigateUser(_ sender: Any) {
        // Hide the Keyboard
        self.OSKDisappear()
        
        // 1. Read the data in the text Fields
        if let longiText = destinationLongitude.text, let latText = destinationLatitude.text {
            
            // 2. Check that if the Longitude and Latitude re not empty, then proceed
            if longiText != "" && latText != "" {
                if let lat = Double(latText), let lon = Double(longiText){
                    // Clear the Map before Routing
                    self.clearMap()
                    
                    // Get coordinates of the Destination
                    let coor = CLLocationCoordinate2D(latitude: CLLocationDegrees(lat), longitude: CLLocationDegrees(lon))
                    
                    // 3. Get a pin Annotation on the map
                    let annotationView: MKPinAnnotationView!
                    let annotationPoint = MKPointAnnotation()
                    annotationPoint.coordinate = coor
                    // Add title to Annotation Point
                    annotationPoint.title = "\(lat), \(lon)"
                    annotationView = MKPinAnnotationView(annotation: annotationPoint, reuseIdentifier: "Annotation")
                    // Add pin Annotation to Map View
                    mapView.addAnnotation(annotationView.annotation!)
                    
                    // 4. Request for Directions
                    let directionRequest = MKDirectionsRequest()
                    directionRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: mapView.userLocation.coordinate))
                    directionRequest.destination = MKMapItem(placemark: MKPlacemark(coordinate: coor))
                    directionRequest.requestsAlternateRoutes = false
                    directionRequest.transportType = .any
                    
                    // 5. Get Directions
                    let directions = MKDirections(request: directionRequest)
                    // Get the Directions Calculated from the directions Request
                    directions.calculate{ (response, error) in
                        if let res = response{
                            // Get the first route from the list of routes
                            let route = res.routes.first
                            // Overlay a line on Map to show the Path
                            self.mapView.add((route?.polyline)!)
                            self.mapView.region.center = coor
                            Toast(text: "Starting Navigation.", duration: 1.0).show()
                        }
                        else{
                            print("Error !!")
                            Toast(text: "Error: Got No Response !!", duration: 1.0).show()
                        }
                    }
                    
                }
            }
        }
    }
    
    
    // Step-5: Function to Clear the Map
    func clearMap(){
        // Get rid of all Annotations
        mapView.removeAnnotations(mapView.annotations)
        // Clear the overlays from the Map
        mapView.removeOverlays(mapView.overlays)
    }
    
    
    // Step-6: Function to Provide colors and other options while rendering the overlay route on the Map
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay as! MKPolyline)
        // Provide
        renderer.strokeColor = .black
        renderer.lineWidth = 3.0
        return renderer
    }
    
    
    // Step-7: Drop Annotation on the Map
    // This allows users to drop the pin anywhere in the map and gets the coordinates of the destination in the text field by itself
    @objc func dropAnnotation(sender: UIGestureRecognizer){
        if sender.state == .began{
            let holdLocation = sender.location(in: mapView)
            // Convert the place where we hold on map to Coordinates
            let locationCoord = mapView.convert(holdLocation, toCoordinateFrom: mapView)
            let annotationView: MKAnnotationView!
            let pointAnnotation = MKPointAnnotation()
            
            pointAnnotation.coordinate = locationCoord
            pointAnnotation.title = "\(locationCoord.latitude), \(locationCoord.longitude)"
            annotationView = MKAnnotationView(annotation: pointAnnotation, reuseIdentifier: "Annotation")
            
            mapView.addAnnotation(annotationView.annotation!)
            destinationLatitude.text = "\(locationCoord.latitude)"
            destinationLongitude.text = "\(locationCoord.longitude)"
        }
    }
}

