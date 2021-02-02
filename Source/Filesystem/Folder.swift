//
//  Folder.swift
//  Swift Toolbox
//
//  Created by Stevo on 9/22/20.
//  Copyright © 2020 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: Folder
public class Folder {

	// MARK: Types
	enum Action {
		case process
		case ignore
	}

	typealias SubPathProc = (_ folder :Folder, _ subPath :String) -> Void
	typealias SubPathDeepProc = (_ folder :Folder, _ subPath :String) -> Action

	// MARK: Properties
	public	let	url :URL

	public	var	name :String { self.url.lastPathComponent }
	public	var	path :String { self.url.path }

	// MARK: Class methods
	//------------------------------------------------------------------------------------------------------------------
	static func from(_ url :URL?) -> Folder? { (url != nil) ? Folder(url!) : nil }

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public init(_ url :URL) {
		// Store
		self.url = url
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	public func folder(with subPath :String) -> Folder { Folder(self.url.appendingPathComponent(subPath)) }

	//------------------------------------------------------------------------------------------------------------------
	public func file(with subPath :String) -> File { File(self.url.appendingPathComponent(subPath)) }

	//------------------------------------------------------------------------------------------------------------------
	public func subPath(for folder :Folder) -> String { self.url.path.relativePath(for: folder.path) }

	//------------------------------------------------------------------------------------------------------------------
	public func subPath(for file :File) -> String { self.url.path.relativePath(for: file.path) }
}
