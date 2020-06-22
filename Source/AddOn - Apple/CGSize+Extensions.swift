//
//  String+CoreGraphics.swift
//  Swift Toolbox
//
//  Created by Stevo on 3/9/20.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

import CoreGraphics
import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: CGSize extension
extension CGSize {

	// MARK: Properties
	var	aspectRatio :CGFloat { self.width / self.height }

	// MARK: Lifecycle methoeds
	//------------------------------------------------------------------------------------------------------------------
	init?(_ string :String?) {
		// Preflight
		guard string != nil else { return nil }

		// Get info
		let	components = string!.components(separatedBy: CharacterSet(charactersIn: "{},"))
		guard components.count == 4 else { return nil }
		guard let width = components[1].toDouble() else { return nil }
		guard let height = components[2].toDouble() else { return nil }

		self.init(width: width, height: height)
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func aspectFit(in size :CGSize) -> CGSize {
		// Setup
		let	widthFactor = size.width / self.width
		let	heightFactor = size.height / self.height

		// Check which dimension is more constrained
		if widthFactor < heightFactor {
			// Width constrained
			return CGSize(width: self.width * widthFactor, height: self.height * widthFactor)
		} else {
			// Height constrained
			return CGSize(width: self.width * heightFactor, height: self.height * heightFactor)
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: String CoreGraphics Extension
extension String {

	// MARK: Lifecycle methoeds
	//------------------------------------------------------------------------------------------------------------------
	public init(_ size :CGSize) { self.init("{\(size.width),\(size.height)}") }
}
