//
//  ViewController.swift
//  Turn-by-Turn Navigation
//
//  Created by Anuj Dutt on 2/19/19.
//  Copyright © 2019 Anuj Dutt. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import AVFoundation

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var destinationAddress: UITextField!
    
    // Setup Location Manager
    let locationManager = CLLocationManager()
    // User's Current Location Coordinates
    var userCurrentCoordinates: CLLocationCoordinate2D? = nil
    // Destination Coordinates
    var destinationCoordinates: CLLocationCoordinate2D? = nil
    var headingImageView: UIImageView?
    // Get User Heading Direction
    var userHeading: CLLocationDirection?
    // Turn by Turn Directions
    var steps = [MKRoute.Step]()
    // Geo-Coordinates of all turns, starting from user's current location
    var geoCoordinates: [CLLocationCoordinate2D] = []
    // Spoken Directions
    let speechSynthesizer = AVSpeechSynthesizer()
    // Variable to Store Directions with Distance
    var turnDirectionsWithDistance = [String]()
    // Step Counter
    var stepCounter = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Add Tap gesture recognizer for making OSK Disappear
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.OSKDisappear))
        view.addGestureRecognizer(tapRecognizer)
        
        // Set the Map View and Location Manager Delegate to self
        mapView.delegate = self
        locationManager.delegate = self
        
        // Set desired accuracy for location manager
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    }

    
    // ****************
    // Start Navigation
    // ****************
    @IBAction func navigate(_ sender: Any) {
        // Remove OSK
        self.OSKDisappear()
        // Clear map for new navigation
        self.clearMap()
        // Start updating heading Direction on Map
        locationManager.startUpdatingHeading()
        
        // Get Coordinates for the destination address
        self.getCoordinate(addressString: destinationAddress.text!) { (coord, err) in
            if (err == nil){
                print("Destination: \(String(describing: self.destinationAddress.text))\t Coordinates: \(coord)")
                self.destinationCoordinates = coord
                
                // ---------------------------------------------------
                // Get a pin Annotation on the map for the destination
                // ---------------------------------------------------
                let annotationView: MKPinAnnotationView!
                let annotationPoint = MKPointAnnotation()
                annotationPoint.coordinate = self.destinationCoordinates!
                // Add title to Annotation Point
                annotationPoint.title = "\(self.destinationAddress.text!)"
                annotationView = MKPinAnnotationView(annotation: annotationPoint, reuseIdentifier: "Annotation")
                // Add pin Annotation to Map View
                self.mapView.addAnnotation(annotationView.annotation!)
                
                // -------------------------------------
                // Request for Directions to Destination
                // -------------------------------------
                let directionRequest = MKDirections.Request()
                directionRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: self.mapView.userLocation.coordinate))
                directionRequest.destination = MKMapItem(placemark: MKPlacemark(coordinate: coord))
                directionRequest.requestsAlternateRoutes = false
                directionRequest.transportType = .automobile
                
                // -----------------------------
                // Get Directions to Destination
                // -----------------------------
                let directions = MKDirections(request: directionRequest)
                // Get the Directions Calculated from the directions Request
                directions.calculate{ (response, error) in
                    if let res = response{
                        // Get the first route from the list of routes
                        let route = res.routes.first
                        
                        // Stop Monitoring
                        self.locationManager.monitoredRegions.forEach({self.locationManager.stopMonitoring(for: $0)})
                        
                        // ------------ Set Geo-Fence ----------
                        self.steps = (route?.steps)!
                        
                        for i in 0..<route!.steps.count {
                            let step = route?.steps[i]
                            let region = CLCircularRegion(center: (step?.polyline.coordinate)!, radius: 20, identifier: "\(i)")
                            if (i > 0){
                                self.turnDirectionsWithDistance.append("In \(String(format: "%.2f", step!.distance/1609.34)) miles, \(String(describing: step!.instructions))")
                            }
                            print("\nIn \(String(describing: round(1000*step!.distance/1609.34)/1000)) miles, \(String(describing: step!.instructions))")
                            print("Geo-Coordinates: \(String(describing: step!.polyline.coordinate))\n")
                            // Coordinates of each turn on the way. Format [Latitude,Longitude]
                            self.geoCoordinates.append(step!.polyline.coordinate)
                            self.locationManager.startMonitoring(for: region)
                            // Setting up Geo-Fence Boundary
                            let circle = MKCircle(center: region.center, radius: region.radius)
                            self.mapView.addOverlay(circle)
                        }
                        // Test out the Arrays
                        print("Geocoordinate Array: \(self.geoCoordinates)")
                        print("\n\nSpoken Directions: \(self.turnDirectionsWithDistance)")
                        
                        // Speech Directions
                        DispatchQueue.main.async {
                            for j in 0...self.turnDirectionsWithDistance.count-1{
                                let speechUtterance = AVSpeechUtterance(string: self.turnDirectionsWithDistance[j])
                                self.speechSynthesizer.speak(speechUtterance)
                            }
                        }
                        self.stepCounter += 1
                        
                        // Overlay a line on Map to show the Path
                        self.mapView.addOverlay((route?.polyline)!)
                        self.mapView.region.center = coord
                        self.mapView.showsCompass = true
                        self.mapView.showsTraffic = true
                        self.mapView.showsPointsOfInterest = true
                        self.mapView.showsBuildings = true
                        self.mapView.showsScale = true
                        // Place the user to starting point of the map
                        let rect = route?.polyline.boundingMapRect
                        self.mapView.setRegion(MKCoordinateRegion(rect!), animated: true)

                        print("Starting Navigation....")
                    }
                    else{
                        print("Error: \(String(describing: error))")
                    }
                }
            }
            else{
                print("Error: \(String(describing: err))")
            }
        }
        
        
    }
    
    
    // *************************************************************************************
    // Make OS Keyboard disappear on tapping anywhere in the imageView except the text field
     // *************************************************************************************
    @objc func OSKDisappear(){
        view.endEditing(true)
    }
    
    
    // **************************************************************************
    // Function to return Geocoordinates for a String Location entered by the user
    // **************************************************************************
    func getCoordinate( addressString : String, completionHandler: @escaping(CLLocationCoordinate2D, NSError?) -> Void ) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(addressString) { (placemarks, error) in
            if error == nil {
                if let placemark = placemarks?[0] {
                    let location = placemark.location!
                    completionHandler(location.coordinate, nil)
                    return
                }
            }
            completionHandler(kCLLocationCoordinate2DInvalid, error as NSError?)
        }
    }
    
    
    // ********************************************************************
    // Function to get User's current GPS location and Zoom in to location.
     // ********************************************************************
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        // If the Location Access is Denied, send a Toast Message
        case .denied,.restricted:
            print("The user denied Location Access Authorization Request !!")
        // If the status is not determined, request Authorization
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        // If authorization was given, start updating user's current location
        default:
            //manager.startUpdatingLocation()
            // Get User Location and Zoom into that Location
            self.zoomIntoUserLocation()
            self.mapView.showsUserLocation = true
            self.mapView.showsCompass = true
            self.mapView.showsTraffic = true
            self.mapView.showsPointsOfInterest = true
            // Get the Coordinates of the User's Current Location
            self.userCurrentCoordinates = locationManager.location?.coordinate
        }
    }
    
    
    // Function to Stop Updating Location and Heading
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationManager.stopUpdatingLocation()
        self.mapView.userTrackingMode = .followWithHeading
    }
    
    
    // ********************************************
    // Function to check if we entered the GeoFence
    // ********************************************
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        self.stepCounter += 1
        if (self.stepCounter < steps.count){
            let currentStep = steps[stepCounter]
            let message = "In \(String(format: "%.2f", currentStep.distance/1609.34)) miles, \(currentStep.instructions)"
            let speechUtterance = AVSpeechUtterance(string: message)
            speechSynthesizer.speak(speechUtterance)
        }
        else{
            let message = "Arrived at destination."
            let speechUtterance = AVSpeechUtterance(string: message)
            speechSynthesizer.speak(speechUtterance)
            stepCounter = 0
            locationManager.monitoredRegions.forEach({self.locationManager.stopMonitoring(for: $0)})
        }
    }
    
    
    // ****************************************************
    // Function to Zoom into User's Location at App Startup
    // ****************************************************
    func zoomIntoUserLocation(){
        let currLocation = locationManager.location
        let noLocation = CLLocationCoordinate2D(latitude: (currLocation?.coordinate.latitude)!, longitude: (currLocation?.coordinate.longitude)!)
        // Zoom Within 10 meters
        let viewRegion = MKCoordinateRegion(center: noLocation, latitudinalMeters: 20, longitudinalMeters: 20)
        self.mapView.setRegion(viewRegion, animated: true)
        self.mapView.showsCompass = true
        DispatchQueue.main.async {
            self.locationManager.startUpdatingLocation()
            self.locationManager.startUpdatingHeading()
            //self.locationManager.allowsBackgroundLocationUpdates = true
        }
    }
    
    
    // *************************
    // Function to Clear the Map
    // *************************
    func clearMap(){
        // Get rid of all Annotations
        mapView.removeAnnotations(mapView.annotations)
        // Clear the overlays from the Map
        mapView.removeOverlays(mapView.overlays)
        // Clear Geocoordinates Array
        self.geoCoordinates.removeAll()
    }
    
    
    // *****************************************************************************************
    // Function to Provide colors and other options while rendering the overlay route on the Map
    // *****************************************************************************************
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKPolyline{
            let renderer = MKPolylineRenderer(overlay: overlay as! MKPolyline)
            // Provide
            renderer.strokeColor = UIColor.blue
            renderer.lineWidth = 3.0
            return renderer
        }
        
        if overlay is MKCircle {
            let renderer = MKCircleRenderer(overlay: overlay)
            // Provide
            renderer.strokeColor = UIColor.red
            renderer.alpha = 0.5
            return renderer
        }
        return MKOverlayRenderer()
    }
    
    
    // ********************************************************
    // Function to get user current heading and updating on Map
    // ********************************************************
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        if views.last?.annotation is MKUserLocation {
            self.addHeadingView(toAnnotationView: views.last!)
        }
    }
    
    
    // *************************************
    // Function to add heading arrow on Map
    // *************************************
    func addHeadingView(toAnnotationView annotationView: MKAnnotationView) {
        if headingImageView == nil {
            let image = UIImage(named: "arrowIcon.png")
            headingImageView = UIImageView(image: image)
            headingImageView!.frame = CGRect(x: (annotationView.frame.size.width - image!.size.width)/2, y: (annotationView.frame.size.height - image!.size.height)/2, width: image!.size.width, height: image!.size.height)
            annotationView.insertSubview(headingImageView!, at: 0)
            headingImageView!.isHidden = true
        }
    }
    
    
    // **************************************
    // Function to get user's updated heading
    // **************************************
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if newHeading.headingAccuracy < 0 { return }
        
        let heading = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading
        self.userHeading = heading
        //NotificationCenter.default.post(name: Notification.Name(rawValue: "updateMap"), object: self, userInfo: nil)
        self.updateHeadingRotation()
    }
    
    
    // ******************************************
    // Function to update user's heading rotation
    // ******************************************
    func updateHeadingRotation() {
        if let heading = self.userHeading,
        let headingImageView = headingImageView {
            
            self.headingImageView!.isHidden = false
            let rotation = CGFloat(heading/180 * Double.pi)
            self.headingImageView!.transform = CGAffineTransform(rotationAngle: rotation)
        }
    }
}
