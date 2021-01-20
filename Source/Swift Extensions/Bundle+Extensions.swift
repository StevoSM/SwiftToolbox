//
//  Bundle+Extensions.swift
//  Swift Toolbox
//
//  Created by Stevo on 1/19/21.
//  Copyright © 2021 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: Bundle extension
extension Bundle {

	// MARK: Properties
	var	bundleName :String { Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String }
}
