//
//  ViewController.swift
//  FlickFinder
//
//  Created by Jarrod Parkes on 11/5/15.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit;

// MARK: - ViewController: UIViewController

class ViewController: UIViewController {
    
    // MARK: Properties
    
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var photoTitleLabel: UILabel!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var phraseSearchButton: UIButton!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var latLonSearchButton: UIButton!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        phraseTextField.delegate = self
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
        subscribeToNotification(.UIKeyboardWillShow, selector: #selector(keyboardWillShow))
        subscribeToNotification(.UIKeyboardWillHide, selector: #selector(keyboardWillHide))
        subscribeToNotification(.UIKeyboardDidShow, selector: #selector(keyboardDidShow))
        subscribeToNotification(.UIKeyboardDidHide, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Search Actions
    
    @IBAction func searchByPhrase(_ sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if !phraseTextField.text!.isEmpty {
            photoTitleLabel.text = "Searching..."
            
            let inputParameters: [String: String?] = [Constants.FlickrParameterKeys.SafeSearch :
            Constants.FlickrParameterValues.SafeSearch,
            Constants.FlickrParameterKeys.Text :
            phraseTextField.text,
            Constants.FlickrParameterKeys.Extras :
            Constants.FlickrParameterValues.MediumURL,
            Constants.FlickrParameterKeys.APIKey :
            Constants.FlickrParameterValues.APIKey,
            Constants.FlickrParameterKeys.Method :
            Constants.FlickrParameterValues.SearchMethod,
            Constants.FlickrParameterKeys.Format :
            Constants.FlickrParameterValues.ResponseFormat,
            Constants.FlickrParameterKeys.NoJSONCallback :
            Constants.FlickrParameterValues.DisableJSONCallback];
            
            displayImageFromFlickrBySearch(inputParameters as [String : AnyObject]);
        } else {
            setUIEnabled(true)
            photoTitleLabel.text = "Phrase Empty."
        }
    }
    
    @IBAction func searchByLatLon(_ sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if isTextFieldValid(latitudeTextField, forRange: Constants.Flickr.SearchLatRange) && isTextFieldValid(longitudeTextField, forRange: Constants.Flickr.SearchLonRange) {
            photoTitleLabel.text = "Searching..."
            // TODO: Set necessary parameters!
            
            let methodParameters: [String: String?] = [Constants.FlickrParameterKeys.SafeSearch :
                Constants.FlickrParameterValues.SafeSearch,
                Constants.FlickrParameterKeys.Extras :
                Constants.FlickrParameterValues.MediumURL,
                Constants.FlickrParameterKeys.APIKey :
                Constants.FlickrParameterValues.APIKey,
                Constants.FlickrParameterKeys.BoundingBox: bboxString(),
                Constants.FlickrParameterKeys.Method :
                Constants.FlickrParameterValues.SearchMethod,
                Constants.FlickrParameterKeys.Format :
                Constants.FlickrParameterValues.ResponseFormat,
                Constants.FlickrParameterKeys.NoJSONCallback :
                Constants.FlickrParameterValues.DisableJSONCallback];
            
            displayImageFromFlickrBySearch(methodParameters as [String : AnyObject]);
        }
        else {
            setUIEnabled(true)
            photoTitleLabel.text = "Lat should be [-90, 90].\nLon should be [-180, 180]."
        }
    }
    
    private func bboxString() -> String {
        if let latitude = Double(latitudeTextField.text!),
            let logitude = Double(longitudeTextField.text!) {
            
            let minLatit = max(latitude - Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLatRange.0);
            let minLongi = max(logitude - Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.0);
            let maxLatit = min(latitude + Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLatRange.1);
            let maxLongi = min(logitude + Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.1);
            return "\(minLongi),\(minLatit),\(maxLongi),\(maxLatit)";
        } else {
            return "0,0,0,0";
        }
    }
    
    // MARK: Flickr API
    
    private func displayImageFromFlickrBySearch(_ inputParameters: [String: AnyObject]) {
        
        let session = URLSession.shared;
        let request = URLRequest(url: flickrURLFromParameters(inputParameters));
        
        let task = session.dataTask(with: request) { (data, response, error) in
            
            func displayError(error: String) {
                print(error);
                performUIUpdatesOnMain {
                    self.setUIEnabled(true);
                    self.photoTitleLabel.text = "Nenhuma foto retornada. Tente Novamente!";
                    self.photoImageView = nil;
                }
            }
            
            guard(error == nil) else {
                displayError(error: "Houve um erro na sua requisição: \(String(describing: error))");
                return;
            }
            
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                displayError(error: "Sua requisição retornou um código diferente de 2xx!");
                return;
            }
            
            guard let data = data else {
                displayError(error: "Nenhum dado retornado pela sua requisição!");
                return;
            }
            
            let parsedResult: [String:AnyObject]!
            do {
                parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            } catch {
                displayError(error: "Não é possível converter os dados para JSON: '\(data)'");
                return;
            }
            
            guard let stat = parsedResult[Constants.FlickrResponseKeys.Status] as? String, stat == Constants.FlickrResponseValues.OKStatus else {
                displayError(error: "Flickr API returned an error. See error code and message in \(parsedResult)")
                return
            }
            
            guard let photosDictionary = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String: AnyObject],
                let photoArray = photosDictionary[Constants.FlickrResponseKeys.Photo] as? [[String:AnyObject]] else {
                    
                    displayError(error: "Cannot find keys '\(Constants.FlickrResponseKeys.Photos)' and '\(Constants.FlickrResponseKeys.Photo)' in \(parsedResult)");
                    return;
            }
            
            let randomPhotoIndex = Int(arc4random_uniform(UInt32(photoArray.count)));
            
            guard let urlPhoto = photoArray[randomPhotoIndex][Constants.FlickrResponseKeys.MediumURL] as? String,
                let tituloPhoto = photoArray[randomPhotoIndex][Constants.FlickrResponseKeys.Title] as? String else {
                    displayError(error: "Cannot find key '\(Constants.FlickrResponseKeys.MediumURL)'");
                    return;
                    
            }
            
            if error == nil {
                self.carregarImagem(url: urlPhoto, titulo: tituloPhoto);
                print(urlPhoto);
                print(tituloPhoto);
            } else {
                print(error!.localizedDescription);
            }
            
        }
        task.resume();
    }
    
    private func carregarImagem(url: String, titulo: String) {
        let imageURL = URL(string: url)!
        
        //        let task = URLSession.shared.dataTask(with: imageURL) {(data, response, error) in
        //guard if usuario?.endereco?.pais?.estado?.cidade? == "recife"
        //            print("task finished");
        //
        //            if error == nil{
        //                let downloadedImage = UIImage(data: data!);
        
        if let imageData = try? Data(contentsOf: imageURL){
            
            performUIUpdatesOnMain {
                //self.photoImageView.image = downloadedImage;
                self.photoImageView.image = UIImage(data: imageData);
                self.photoTitleLabel.text = titulo;
                self.setUIEnabled(true);
            }
        }
        
        //        task.resume();
        
    }
    
    // MARK: Helper for Creating a URL from Parameters
    
    private func flickrURLFromParameters(_ parameters: [String: AnyObject]) -> URL {
        
        var components = URLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [URLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = URLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        return components.url!
    }
}

// MARK: - ViewController: UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(_ notification: Notification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
        }
    }
    
    func keyboardWillHide(_ notification: Notification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
        }
    }
    
    func keyboardDidShow(_ notification: Notification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(_ notification: Notification) {
        keyboardOnScreen = false
    }
    
    func keyboardHeight(_ notification: Notification) -> CGFloat {
        let userInfo = (notification as NSNotification).userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.cgRectValue.height
    }
    
    func resignIfFirstResponder(_ textField: UITextField) {
        if textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(_ sender: AnyObject) {
        resignIfFirstResponder(phraseTextField)
        resignIfFirstResponder(latitudeTextField)
        resignIfFirstResponder(longitudeTextField)
    }
    
    // MARK: TextField Validation
    
    func isTextFieldValid(_ textField: UITextField, forRange: (Double, Double)) -> Bool {
        if let value = Double(textField.text!), !textField.text!.isEmpty {
            return isValueInRange(value, min: forRange.0, max: forRange.1)
        } else {
            return false
        }
    }
    
    func isValueInRange(_ value: Double, min: Double, max: Double) -> Bool {
        return !(value < min || value > max)
    }
}

// MARK: - ViewController (Configure UI)

private extension ViewController {
    
     func setUIEnabled(_ enabled: Bool) {
        photoTitleLabel.isEnabled = enabled
        phraseTextField.isEnabled = enabled
        latitudeTextField.isEnabled = enabled
        longitudeTextField.isEnabled = enabled
        phraseSearchButton.isEnabled = enabled
        latLonSearchButton.isEnabled = enabled
        
        // adjust search button alphas
        if enabled {
            phraseSearchButton.alpha = 1.0
            latLonSearchButton.alpha = 1.0
        } else {
            phraseSearchButton.alpha = 0.5
            latLonSearchButton.alpha = 0.5
        }
    }
}

// MARK: - ViewController (Notifications)

private extension ViewController {
    
    func subscribeToNotification(_ notification: NSNotification.Name, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    func unsubscribeFromAllNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}
