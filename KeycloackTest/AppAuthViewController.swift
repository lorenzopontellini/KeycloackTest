//
//  AppAuthViewController.swift
//  KeycloackTest
//
//  Created by stage1 on 14/07/25.
//
import UIKit
import AppAuth
import AuthenticationServices

typealias PostRegistrationCallback = (_ configuration: OIDServiceConfiguration?, _ registrationResponse: OIDRegistrationResponse?) -> Void

/**
 The OIDC issuer from which the configuration will be discovered.
*/
let baseUrl: String = "http://192.168.5.149:8080";
//let baseUrl: String = "http://192.168.1.14:8080";
let tenantName: String = "test"

/**
 The OAuth client ID.
 Set to nil to use dynamic registration with this example.
*/
let kClientID: String? = "client-app";

/**
 The OAuth redirect URI for the client @c kClientID.
*/
let schemaURI: String = "com.test.appauth"
let loginRedirectURI: String = "\(schemaURI):/login";
let logoutRedirectURI: String = "\(schemaURI):/logout";
let clientSecretValue: String = "Fhw9Rg3QHcAVMbBP0fLbFGK1sIMWB2GJ"

/**
 NSCoding key for the authState property.
*/
let kAppAuthExampleAuthStateKey: String = "authState";

class AppAuthViewController: UIViewController{
    
    @IBOutlet private weak var authAutoButton: UIButton!
    @IBOutlet private weak var authManual: UIButton!
    @IBOutlet private weak var codeExchangeButton: UIButton!
    @IBOutlet private weak var userinfoButton: UIButton!
    @IBOutlet private weak var logTextView: UITextView!
    @IBOutlet private weak var trashButton: UIBarButtonItem!

    private var authState: OIDAuthState?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.loadState()
        self.updateUI()
    }
}
extension AppAuthViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return self.view.window!
    }
}

//MARK: IBActions
extension AppAuthViewController {
    
    @IBAction func logout(_ sender: UIButton){
        
        guard let authState = authState,
              let idToken = authState.lastTokenResponse?.idToken,
              let _ = authState.lastAuthorizationResponse.request.configuration.discoveryDocument?.issuer else {
            print("Missing data")
            return
        }

//        let logoutEndpoint = "http://192.168.5.149:8080/realms/test/protocol/openid-connect/logout".appendingPathComponent("protocol/openid-connect/logout")
        guard let logoutUrl:URL = URL(string: "\(baseUrl)/realms/\(tenantName)/protocol/openid-connect/logout"),
            var logoutUrlComponent: URLComponents = URLComponents(url: logoutUrl, resolvingAgainstBaseURL: false) else {
            print("Missing logout URL")
            return
        }
        
        logoutUrlComponent.queryItems = [
            URLQueryItem(name: "id_token_hint", value: idToken),
            URLQueryItem(name: "post_logout_redirect_uri", value: logoutRedirectURI)
        ]

        guard let logoutURL = logoutUrlComponent.url else {
            print("Could not build logout URL")
            return
        }

        let session = ASWebAuthenticationSession(url: logoutURL, callbackURLScheme: schemaURI) { callbackURL, error in
            // Handle logout result here
        }
        session.presentationContextProvider = self  // conforms to ASWebAuthenticationPresentationContextProviding
        session.start()
    }

    @IBAction func authWithAutoCodeExchange(_ sender: UIButton) {

        //%s/realms/%s/protocol/openid-connect/auth
        
        guard let urlLogin = URL(string: "\(baseUrl)/realms/\(tenantName)/") else{
            print("Could not build logout URL")
            return
        }

        self.logMessage("Fetching configuration for issuer: \(urlLogin)")

        // discovers endpoints
        OIDAuthorizationService.discoverConfiguration(forIssuer: urlLogin) { configuration, error in

            guard let config = configuration else {
                self.logMessage("Error retrieving discovery document: \(error?.localizedDescription ?? "DEFAULT_ERROR")")
                self.setAuthState(nil)
                return
            }

            self.logMessage("Got configuration: \(config)")

            if let clientId = kClientID {
                self.doAuthWithAutoCodeExchange(configuration: config, clientID: clientId, clientSecret: clientSecretValue)
            } else {
                self.doClientRegistration(configuration: config) { configuration, response in

                    guard let configuration = configuration, let clientID = response?.clientID else {
                        self.logMessage("Error retrieving configuration OR clientID")
                        return
                    }

                    self.doAuthWithAutoCodeExchange(configuration: configuration,
                                                    clientID: clientID,
                                                    clientSecret: response?.clientSecret)
                }
            }
        }

    }

    @IBAction func authNoCodeExchange(_ sender: UIButton) {

//        let url = kIssuer + "/realms/test/"
//        guard let issuer = URL(string: url) else {
//            self.logMessage("Error creating URL for : \(kIssuer)")
//            return
//        }
//
//        self.logMessage("Fetching configuration for issuer: \(issuer)")
//
//        OIDAuthorizationService.discoverConfiguration(forIssuer: issuer) { configuration, error in
//
//            if let error = error  {
//                self.logMessage("Error retrieving discovery document: \(error.localizedDescription)")
//                return
//            }
//
//            guard let configuration = configuration else {
//                self.logMessage("Error retrieving discovery document. Error & Configuration both are NIL!")
//                return
//            }
//
//            self.logMessage("Got configuration: \(configuration)")
//
//            if let clientId = kClientID {
//
//                self.doAuthWithoutCodeExchange(configuration: configuration, clientID: clientId, clientSecret: nil)
//
//            } else {
//
//                self.doClientRegistration(configuration: configuration) { configuration, response in
//
//                    guard let configuration = configuration, let response = response else {
//                        return
//                    }
//
//                    self.doAuthWithoutCodeExchange(configuration: configuration,
//                                                   clientID: response.clientID,
//                                                   clientSecret: response.clientSecret)
//                }
//            }
//        }
    }

    @IBAction func codeExchange(_ sender: UIButton) {

        guard let tokenExchangeRequest = self.authState?.lastAuthorizationResponse.tokenExchangeRequest() else {
            self.logMessage("Error creating authorization code exchange request")
            return
        }

        self.logMessage("Performing authorization code exchange with request \(tokenExchangeRequest)")

        OIDAuthorizationService.perform(tokenExchangeRequest) { response, error in

            if let tokenResponse = response {
                self.logMessage("Received token response with accessToken: \(tokenResponse.accessToken ?? "DEFAULT_TOKEN")")
            } else {
                self.logMessage("Token exchange error: \(error?.localizedDescription ?? "DEFAULT_ERROR")")
            }
            self.authState?.update(with: response, error: error)
        }
    }

    @IBAction func userinfo(_ sender: UIButton) {

        guard let userinfoEndpoint = self.authState?.lastAuthorizationResponse.request.configuration.discoveryDocument?.userinfoEndpoint else {
            self.logMessage("Userinfo endpoint not declared in discovery document")
            return
        }

        self.logMessage("Performing userinfo request")

        let currentAccessToken: String? = self.authState?.lastTokenResponse?.accessToken
        
        

        self.authState?.performAction() { (accessToken, idToken, error) in

            if error != nil  {
                self.logMessage("Error fetching fresh tokens: \(error?.localizedDescription ?? "ERROR")")
                return
            }

            guard let accessToken = accessToken else {
                self.logMessage("Error getting accessToken")
                return
            }

            if currentAccessToken != accessToken {
                self.logMessage("Access token was refreshed automatically (\(currentAccessToken ?? "CURRENT_ACCESS_TOKEN") to \(accessToken))")
            } else {
                self.logMessage("Access token was fresh and not updated \(accessToken)")
            }

            var urlRequest = URLRequest(url: userinfoEndpoint)
            urlRequest.allHTTPHeaderFields = ["Authorization":"Bearer \(accessToken)"]

            let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in

                DispatchQueue.main.async {
                    
                    guard error == nil else {
                        self.logMessage("HTTP request failed \(error?.localizedDescription ?? "ERROR")")
                        return
                    }

                    guard let response = response as? HTTPURLResponse else {
                        self.logMessage("Non-HTTP response")
                        return
                    }

                    guard let data = data else {
                        self.logMessage("HTTP response data is empty")
                        return
                    }

                    var json: [AnyHashable: Any]?

                    do {
                        json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    } catch {
                        self.logMessage("JSON Serialization Error")
                    }

                    if response.statusCode != 200 {
                        // server replied with an error
                        let responseText: String? = String(data: data, encoding: String.Encoding.utf8)

                        if response.statusCode == 401 {
                            // "401 Unauthorized" generally indicates there is an issue with the authorization
                            // grant. Puts OIDAuthState into an error state.
                            let oauthError = OIDErrorUtilities.resourceServerAuthorizationError(withCode: 0,
                                                                                                errorResponse: json,
                                                                                                underlyingError: error)
                            self.authState?.update(withAuthorizationError: oauthError)
                            self.logMessage("Authorization Error (\(oauthError)). Response: \(responseText ?? "RESPONSE_TEXT")")
                        } else {
                            self.logMessage("HTTP: \(response.statusCode), Response: \(responseText ?? "RESPONSE_TEXT")")
                        }

                        return
                    }

                    if let json = json {
                        self.logMessage("Success: \(json)")
                    }
                }
            }

            task.resume()
        }
    }

    @IBAction func trashClicked(_ sender: UIBarButtonItem) {

        let alert = UIAlertController(title: nil,
                                      message: nil,
                                      preferredStyle: UIAlertController.Style.actionSheet)

        let clearAuthAction = UIAlertAction(title: "Clear OAuthState", style: .destructive) { (_: UIAlertAction) in
            self.setAuthState(nil)
            self.updateUI()
        }
        alert.addAction(clearAuthAction)
        
        let clearLogs = UIAlertAction(title: "Clear Logs", style: .default) { (_: UIAlertAction) in
            DispatchQueue.main.async {
                self.logTextView.text = ""
            }
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)


        alert.addAction(clearLogs)
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)

    }
}


//MARK: AppAuth Methods
extension AppAuthViewController {

    func doClientRegistration(configuration: OIDServiceConfiguration, callback: @escaping PostRegistrationCallback) {

        guard let redirectURI = URL(string: loginRedirectURI) else {
            self.logMessage("Error creating URL for : \(loginRedirectURI)")
            return
        }

        let request: OIDRegistrationRequest = OIDRegistrationRequest(configuration: configuration, redirectURIs: [redirectURI], responseTypes: nil, grantTypes: nil, subjectType: nil, tokenEndpointAuthMethod: "client_secret_post", initialAccessToken: nil, additionalParameters: nil)
        

        // performs registration request
        self.logMessage("Initiating registration request")

        OIDAuthorizationService.perform(request) { response, error in

            if let regResponse = response {
                self.setAuthState(OIDAuthState(registrationResponse: regResponse))
                self.logMessage("Got registration response: \(regResponse)")
                callback(configuration, regResponse)
            } else {
                self.logMessage("Registration error: \(error?.localizedDescription ?? "DEFAULT_ERROR")")
                self.setAuthState(nil)
            }
        }
    }

    func doAuthWithAutoCodeExchange(configuration: OIDServiceConfiguration, clientID: String, clientSecret: String?) {

        guard let redirectURI = URL(string: loginRedirectURI) else {
            self.logMessage("Error creating URL for : \(loginRedirectURI)")
            return
        }

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            self.logMessage("Error accessing AppDelegate")
            return
        }

        // builds authentication request
        let request = OIDAuthorizationRequest(configuration: configuration,
                                              clientId: clientID,
                                              clientSecret: clientSecret,
                                              scopes: [OIDScopeOpenID, OIDScopeProfile],
                                              redirectURL: redirectURI,
                                              responseType: OIDResponseTypeCode,
                                              additionalParameters: nil)

        // performs authentication request
        logMessage("Initiating authorization request with scope: \(request.scope ?? "DEFAULT_SCOPE")")

        appDelegate.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request, presenting: self) { authState, error in

            if let authState = authState {
                self.setAuthState(authState)
                self.logMessage("Got authorization tokens. Access token: \(authState.lastTokenResponse?.accessToken ?? "DEFAULT_TOKEN")")
            } else {
                self.logMessage("Authorization error: \(error?.localizedDescription ?? "DEFAULT_ERROR")")
                self.setAuthState(nil)
            }
        }
    }

    func doAuthWithoutCodeExchange(configuration: OIDServiceConfiguration, clientID: String, clientSecret: String?) {

        guard let redirectURI = URL(string: loginRedirectURI) else {
            self.logMessage("Error creating URL for : \(loginRedirectURI)")
            return
        }

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            self.logMessage("Error accessing AppDelegate")
            return
        }

        // builds authentication request
        let request = OIDAuthorizationRequest(configuration: configuration,
                                              clientId: clientID,
                                              clientSecret: clientSecret,
                                              scopes: [OIDScopeOpenID, OIDScopeProfile],
                                              redirectURL: redirectURI,
                                              responseType: OIDResponseTypeCode,
                                              additionalParameters: nil)

        // performs authentication request
        logMessage("Initiating authorization request with scope: \(request.scope ?? "DEFAULT_SCOPE")")

        appDelegate.currentAuthorizationFlow = OIDAuthorizationService.present(request, presenting: self) { (response, error) in

            if let response = response {
                let authState = OIDAuthState(authorizationResponse: response)
                self.setAuthState(authState)
                self.logMessage("Authorization response with code: \(response.authorizationCode ?? "DEFAULT_CODE")")
                // could just call [self tokenExchange:nil] directly, but will let the user initiate it.
            } else {
                self.logMessage("Authorization error: \(error?.localizedDescription ?? "DEFAULT_ERROR")")
            }
        }
    }
}

//MARK: OIDAuthState Delegate
extension AppAuthViewController: OIDAuthStateChangeDelegate, OIDAuthStateErrorDelegate {

    func didChange(_ state: OIDAuthState) {
        self.stateChanged()
    }

    func authState(_ state: OIDAuthState, didEncounterAuthorizationError error: Error) {
        self.logMessage("Received authorization error: \(error)")
    }
}

//MARK: Helper Methods
extension AppAuthViewController {

    func saveState() {

        var data: Data? = nil

        if let authState = self.authState {
            data = NSKeyedArchiver.archivedData(withRootObject: authState)
        }
        
        if let userDefaults = UserDefaults(suiteName: "group.net.openid.appauth.Example") {
            userDefaults.set(data, forKey: kAppAuthExampleAuthStateKey)
            userDefaults.synchronize()
        }
    }

    func loadState() {
        guard let data = UserDefaults(suiteName: "group.net.openid.appauth.Example")?.object(forKey: kAppAuthExampleAuthStateKey) as? Data else {
            return
        }

        if let authState = NSKeyedUnarchiver.unarchiveObject(with: data) as? OIDAuthState {
            self.setAuthState(authState)
        }
    }

    func setAuthState(_ authState: OIDAuthState?) {
        if (self.authState == authState) {
            return;
        }
        self.authState = authState;
        self.authState?.stateChangeDelegate = self;
        self.stateChanged()
    }

    func updateUI() {

        self.codeExchangeButton.isEnabled = self.authState?.lastAuthorizationResponse.authorizationCode != nil && !((self.authState?.lastTokenResponse) != nil)

        if let authState = self.authState {
            self.authAutoButton.setTitle("1. Re-Auth", for: .normal)
            self.authManual.setTitle("1(A) Re-Auth", for: .normal)
            self.userinfoButton.isEnabled = authState.isAuthorized ? true : false
        } else {
            self.authAutoButton.setTitle("1. Auto", for: .normal)
            self.authManual.setTitle("1(A) Manual", for: .normal)
            self.userinfoButton.isEnabled = false
        }
    }

    func stateChanged() {
        self.saveState()
        self.updateUI()
    }

    func logMessage(_ message: String?) {

        guard let message = message else {
            return
        }

        print(message);

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "hh:mm:ss";
        let dateString = dateFormatter.string(from: Date())

        // appends to output log
        DispatchQueue.main.async {
            let logText = "\(self.logTextView.text ?? "")\n\(dateString): \(message)"
            self.logTextView.text = logText
        }
    }
}
