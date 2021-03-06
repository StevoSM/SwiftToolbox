//
//  HTTPEndpointRequest.swift
//  Swift Toolbox
//
//  Created by Stevo on 12/5/19.
//  Copyright © 2019 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: HTTPEndpointRequestError
enum HTTPEndpointRequestError : Error {
	case unableToProcessResponseData
}

extension HTTPEndpointRequestError : LocalizedError {

	// MARK: Properties
	public	var	errorDescription :String? {
						// What are we
						switch self {
							case .unableToProcessResponseData:
									return "Unable to process response data"
						}
					}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: HTTPEndpointRequest
public class HTTPEndpointRequest {

	// MARK: Types
	enum State {
		case queued
		case active
		case finished
	}

	public typealias MultiValueQueryComponent = (key :String, values :[Any])

	// MARK: Properties
					let	method :HTTPEndpointMethod
					let	path :String
					let	queryComponents :[String : Any]?
					let	multiValueQueryComponent :MultiValueQueryComponent?
					let	headers :[String : String]?
					let	timeoutInterval :TimeInterval
					let	bodyData :Data?

	private(set)	var	state :State = .queued
	private(set)	var	isCancelled = false

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public init(method :HTTPEndpointMethod, path :String, queryComponents :[String : Any]? = nil,
			multiValueQueryComponent :MultiValueQueryComponent? = nil, headers :[String : String]? = nil,
			timeoutInterval :TimeInterval = 60.0) {
		// Store
		self.method = method
		self.path = path
		self.queryComponents = queryComponents
		self.multiValueQueryComponent = multiValueQueryComponent
		self.headers = headers
		self.timeoutInterval = timeoutInterval
		self.bodyData = nil
	}

	//------------------------------------------------------------------------------------------------------------------
	public init(method :HTTPEndpointMethod, path :String, queryComponents :[String : Any]? = nil,
			multiValueQueryComponent :MultiValueQueryComponent? = nil, headers :[String : String]? = nil,
			timeoutInterval :TimeInterval = 60.0, bodyData :Data) {
		// Store
		self.method = method
		self.path = path
		self.queryComponents = queryComponents
		self.multiValueQueryComponent = multiValueQueryComponent
		self.headers = headers
		self.timeoutInterval = timeoutInterval
		self.bodyData = bodyData
	}

	//------------------------------------------------------------------------------------------------------------------
	public init(method :HTTPEndpointMethod, path :String, queryComponents :[String : Any]? = nil,
			multiValueQueryComponent :MultiValueQueryComponent? = nil, headers :[String : String]? = nil,
			timeoutInterval :TimeInterval = 60.0, jsonBody :Any) {
		// Setup
		var	headersUse = headers ?? [:]
		headersUse["Content-Type"] = "application/json"

		// Store
		self.method = method
		self.path = path
		self.queryComponents = queryComponents
		self.multiValueQueryComponent = multiValueQueryComponent
		self.headers = headersUse
		self.timeoutInterval = timeoutInterval
		self.bodyData = try! JSONSerialization.data(withJSONObject: jsonBody, options: [])
	}

	//------------------------------------------------------------------------------------------------------------------
	public init(method :HTTPEndpointMethod, path :String, queryComponents :[String : Any]? = nil,
			multiValueQueryComponent :MultiValueQueryComponent? = nil, headers :[String : String]? = nil,
			timeoutInterval :TimeInterval = 60.0, xmlBody :Data) {
		// Setup
		var	headersUse = headers ?? [:]
		headersUse["Content-Type"] = "application/xml"

		// Store
		self.method = method
		self.path = path
		self.queryComponents = queryComponents
		self.multiValueQueryComponent = multiValueQueryComponent
		self.headers = headersUse
		self.timeoutInterval = timeoutInterval
		self.bodyData = xmlBody
	}

	//------------------------------------------------------------------------------------------------------------------
	public init(method :HTTPEndpointMethod, path :String, queryComponents :[String : Any]? = nil,
			multiValueQueryComponent :MultiValueQueryComponent? = nil, headers :[String : String]? = nil,
			timeoutInterval :TimeInterval = 60.0, urlEncodedBody :[String : Any]) {
		// Setup
		var	headersUse = headers ?? [:]
		headersUse["Content-Type"] = "application/x-www-form-urlencoded"

		// Store
		self.method = method
		self.path = path
		self.queryComponents = queryComponents
		self.multiValueQueryComponent = multiValueQueryComponent
		self.headers = headersUse
		self.timeoutInterval = timeoutInterval
		self.bodyData =
				String(combining: urlEncodedBody.map({ "\($0.key)=\($0.value)" }), with: "&")
					.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
					.data(using: .utf8)
	}

	//------------------------------------------------------------------------------------------------------------------
	public init(method :HTTPEndpointMethod = .get, url :URL, headers :[String : String]? = nil,
			timeoutInterval :TimeInterval = 60.0, bodyData :Data? = nil) {
		// Store
		self.method = method
		self.path = url.absoluteString
		self.queryComponents = nil
		self.multiValueQueryComponent = nil
		self.headers = headers
		self.timeoutInterval = timeoutInterval
		self.bodyData = bodyData
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	public func cancel() { self.isCancelled = true }

	//------------------------------------------------------------------------------------------------------------------
	func transition(to state :State) { self.state = state }
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - HTTPEndpointRequestProcessResults
protocol HTTPEndpointRequestProcessResults : HTTPEndpointRequest {

	// MARK: Methods
	//------------------------------------------------------------------------------------------------------------------
	func processResults(response :HTTPURLResponse?, data :Data?, error :Error?)
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - HTTPEndpointRequestProcessMultiResults
protocol HTTPEndpointRequestProcessMultiResults : HTTPEndpointRequest {

	// MARK: Methods
	//------------------------------------------------------------------------------------------------------------------
	func processResults(response :HTTPURLResponse?, data :Data?, error :Error?, totalRequests :Int)
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - DataHTTPEndpointRequest
public class DataHTTPEndpointRequest : HTTPEndpointRequest {

	// MARK: Types
	public	typealias CompletionProc = (_ response :HTTPURLResponse?, _ data :Data?, _ error :Error?) -> Void

	// MARK: Properties
	public	var	completionProc :CompletionProc = { _,_,_ in }
}

extension DataHTTPEndpointRequest : HTTPEndpointRequestProcessResults {

	// MARK: HTTPEndpointRequestProcessResults methods
	//------------------------------------------------------------------------------------------------------------------
	func processResults(response :HTTPURLResponse?, data :Data?, error :Error?) {
		// Check cancelled
		if !self.isCancelled {
			// Call proc
			self.completionProc(response, data, error)
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - FileHTTPEndpointRequest
public class FileHTTPEndpointRequest : HTTPEndpointRequest {

	// MARK: Types
	public	typealias CompletionProc = (_ response :HTTPURLResponse?, _ error :Error?) -> Void

	// MARK: Properties
	public	var	completionProc :CompletionProc = { _,_ in }

	private	let	destinationURL :URL

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(method :HTTPEndpointMethod, path :String, queryComponents :[String : Any]? = nil,
			headers :[String : String]? = nil, timeoutInterval :TimeInterval = 60.0, destinationURL :URL) {
		// Store
		self.destinationURL = destinationURL

		// Do super
		super.init(method: method, path: path, queryComponents: queryComponents, headers: headers,
				timeoutInterval: timeoutInterval)
	}

	//------------------------------------------------------------------------------------------------------------------
	init(method :HTTPEndpointMethod, path :String, queryComponents :[String : Any]? = nil,
			headers :[String : String]? = nil, timeoutInterval :TimeInterval = 60.0, bodyData :Data,
			destinationURL :URL) {
		// Store
		self.destinationURL = destinationURL

		// Do super
		super.init(method: method, path: path, queryComponents: queryComponents, headers: headers,
				timeoutInterval: timeoutInterval, bodyData: bodyData)
	}

	//------------------------------------------------------------------------------------------------------------------
	init(method :HTTPEndpointMethod, path :String, queryComponents :[String : Any]? = nil,
			headers :[String : String]? = nil, timeoutInterval :TimeInterval = 60.0, jsonBody :Any,
			destinationURL :URL) {
		// Store
		self.destinationURL = destinationURL

		// Do super
		super.init(method: method, path: path, queryComponents: queryComponents, headers: headers,
				timeoutInterval: timeoutInterval, jsonBody: jsonBody)
	}

	//------------------------------------------------------------------------------------------------------------------
	init(method :HTTPEndpointMethod, path :String, queryComponents :[String : Any]? = nil,
			headers :[String : String]? = nil, timeoutInterval :TimeInterval = 60.0, urlEncodedBody :[String : Any],
			destinationURL :URL) {
		// Store
		self.destinationURL = destinationURL

		// Do super
		super.init(method: method, path: path, queryComponents: queryComponents, headers: headers,
				timeoutInterval: timeoutInterval, urlEncodedBody: urlEncodedBody)
	}

	//------------------------------------------------------------------------------------------------------------------
	init(method :HTTPEndpointMethod = .get, url :URL, timeoutInterval :TimeInterval = 60.0, destinationURL :URL) {
		// Store
		self.destinationURL = destinationURL

		// Do super
		super.init(method: method, url: url, timeoutInterval: timeoutInterval)
	}
}

extension FileHTTPEndpointRequest : HTTPEndpointRequestProcessResults {

	// MARK: HTTPEndpointRequestProcessResults methods
	//------------------------------------------------------------------------------------------------------------------
	func processResults(response :HTTPURLResponse?, data :Data?, error :Error?) {
		// Check cancelled
		if !self.isCancelled {
			// Handle results
			if data != nil {
				do {
					// Store
					try data!.write(to: self.destinationURL)

					// Call completion
					self.completionProc(response, nil)
				} catch {
					// Error
					self.completionProc(response, error)
				}
			} else {
				// Error
				self.completionProc(response, error)
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - HeadHTTPEndpointRequest
public class HeadHTTPEndpointRequest : HTTPEndpointRequest {

	// MARK: Types
	public	typealias	CompletionProc = (_ response :HTTPURLResponse?, _ error :Error?) -> Void

	// MARK: Properties
	public	var	completionProc :CompletionProc = { _,_ in }
}

extension HeadHTTPEndpointRequest : HTTPEndpointRequestProcessResults {

	// MARK: HTTPEndpointRequestProcessResults methods
	//------------------------------------------------------------------------------------------------------------------
	func processResults(response :HTTPURLResponse?, data :Data?, error :Error?) {
		// Check cancelled
		if !self.isCancelled {
			// Call proc
			self.completionProc(response, error)
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - IntegerHTTPEndpointRequest
public class IntegerHTTPEndpointRequest : HTTPEndpointRequest {

	// MARK: Types
	public	typealias	CompletionProc = (_ response :HTTPURLResponse?, _ value :Int?, _ error :Error?) -> Void

	// MARK: Properties
	public	var	completionProc :CompletionProc = { _,_,_ in }
}

extension IntegerHTTPEndpointRequest : HTTPEndpointRequestProcessResults {

	// MARK: HTTPEndpointRequestProcessResults methods
	//------------------------------------------------------------------------------------------------------------------
	func processResults(response :HTTPURLResponse?, data :Data?, error :Error?) {
		// Handle results
		var	value :Int? = nil
		var	returnError :Error? = error
		if data != nil {
			// Try to compose string from response
			if let string = String(data: data!, encoding: .utf8) {
				// Try to convert to Int
				value = Int(string)
			}

			if value == nil {
				// Unable to transform results
				returnError = HTTPEndpointRequestError.unableToProcessResponseData
			}
		}

		// Check cancelled
		if !self.isCancelled {
			// Call proc
			self.completionProc(response, value, returnError)
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - JSONHTTPEndpointRequest
public class JSONHTTPEndpointRequest<T> : HTTPEndpointRequest {

	// MARK: Types
	public typealias SingleResponseCompletionProc = (_ response :HTTPURLResponse?, _ info :T?, _ error :Error?) -> Void
	public typealias MultiResponsePartialResultsProc =
						(_ response :HTTPURLResponse?, _ info :T?, _ error :Error?) -> Void
	public typealias MultiResponseCompletionProc = (_ errors :[Error]) -> Void

	// MARK: Properties
	public	var	completionProc :SingleResponseCompletionProc?
	public	var	multiResponsePartialResultsProc :MultiResponsePartialResultsProc?
	public	var	multiResponseCompletionProc :MultiResponseCompletionProc?

	private	var	completedRequestsCount = LockingNumeric<Int>()
	private	var	errors = [Error]()
}

extension JSONHTTPEndpointRequest : HTTPEndpointRequestProcessMultiResults {

	// MARK: HTTPEndpointRequestProcessMultiResults methods
	//------------------------------------------------------------------------------------------------------------------
	func processResults(response :HTTPURLResponse?, data :Data?, error :Error?, totalRequests :Int) {
		// Handle results
		var	info :T? = nil
		var	responseError :Error?
		if data != nil {
			// Catch errors
			do {
				// Try to compose info from data
				info = try JSONSerialization.jsonObject(with: data!, options: []) as? T

				// Check if got response data
				if info == nil {
					// Nope
					responseError = HTTPEndpointRequestError.unableToProcessResponseData
				}
			} catch {
				// Error
				responseError = error
			}
		} else {
			// Error
			responseError = error
		}

		if responseError != nil { self.errors.append(responseError!) }

		// Check cancelled
		if !self.isCancelled {
			// Call proc
			if totalRequests == 1 {
				// Single request (but could have been multiple
				if self.completionProc != nil {
					// Single response expected
					self.completionProc!(response, info, responseError)
				} else {
					// Multi-responses possible
					self.multiResponsePartialResultsProc!(response, info, responseError)
					self.multiResponseCompletionProc!(self.errors)
				}
			} else {
				// Multiple requests
				self.multiResponsePartialResultsProc!(response, info, responseError)
				if self.completedRequestsCount.add(1) == totalRequests {
					// All done
					self.multiResponseCompletionProc!(self.errors)
				}
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - StringHTTPEndpointRequest
public class StringHTTPEndpointRequest : HTTPEndpointRequest {

	// MARK: Types
	public	typealias	CompletionProc = (_ response :HTTPURLResponse?, _ string :String?, _ error :Error?) -> Void

	// MARK: Properties
	public	var	completionProc :CompletionProc = { _,_,_ in }
}

extension StringHTTPEndpointRequest : HTTPEndpointRequestProcessResults {

	// MARK: HTTPEndpointRequestProcessResults methods
	//------------------------------------------------------------------------------------------------------------------
	func processResults(response :HTTPURLResponse?, data :Data?, error :Error?) {
		// Handle results
		var	string :String? = nil
		var	returnError :Error? = error
		if data != nil {
			// Try to compose string from data
			string = String(data: data!, encoding: .utf8)

			if string == nil {
				// Unable to transform results
				returnError = HTTPEndpointRequestError.unableToProcessResponseData
			}
		}

		// Check cancelled
		if !self.isCancelled {
			// Call proc
			self.completionProc(response, string, returnError)
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - SuccessHTTPEndpointRequest
public class SuccessHTTPEndpointRequest : HTTPEndpointRequest {

	// MARK: Types
	public	typealias	CompletionProc = (_ response :HTTPURLResponse?, _ error :Error?) -> Void

	// MARK: Properties
	public var	completionProc :CompletionProc = { _,_ in }
}

extension SuccessHTTPEndpointRequest : HTTPEndpointRequestProcessResults {

	// MARK: HTTPEndpointRequestProcessResults methods
	//------------------------------------------------------------------------------------------------------------------
	func processResults(response :HTTPURLResponse?, data :Data?, error :Error?) {
		// Check cancelled
		if !self.isCancelled {
			// Call proc
			self.completionProc(response, error)
		}
	}
}
