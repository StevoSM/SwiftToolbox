//
//  SQLiteResults.swift
//  Swift Toolbox
//
//  Created by Stevo on 10/25/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

import SQLite3

//----------------------------------------------------------------------------------------------------------------------
// MARK: SQLiteResults
public class SQLiteResults {

	// MARK: Types
	typealias ResultsProc = (_ results :SQLiteResults) -> Void

	// MARK: Properties
	private	let	statement :OpaquePointer

	private	var	columnNameInfoMap = [/* column name */ String : /* index */ Int32]()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(statement :OpaquePointer) {
		// Store
		self.statement = statement

		// Setup column name map
		for index in 0..<sqlite3_column_count(statement) {
			// Add to map
			let	columnName = String(cString: sqlite3_column_name(statement, index))
			self.columnNameInfoMap[columnName] = index
		}
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	@discardableResult
	public func next() -> Bool { return sqlite3_step(self.statement) == SQLITE_ROW }

	//------------------------------------------------------------------------------------------------------------------
	public func integer<T : BinaryInteger>(for tableColumn :SQLiteTableColumn) -> T? {
		// Preflight
		let	name = tableColumn.name
		guard case .integer(_, _) = tableColumn.kind else
			{ fatalError("SQLiteResults column type mismatch: \"\(name)\" is not the expected type of integer") }
		guard let index = self.columnNameInfoMap[name] else
			{ fatalError("SQLiteResults column key not found: \"\(name)\"") }

		return (sqlite3_column_type(self.statement, index) != SQLITE_NULL) ?
				T(sqlite3_column_int64(self.statement, index)) : nil
	}

	//------------------------------------------------------------------------------------------------------------------
	public func real(for tableColumn :SQLiteTableColumn) -> Double? {
		// Preflight
		let	name = tableColumn.name
		guard case .real(_) = tableColumn.kind else
			{ fatalError("SQLiteResults column type mismatch: \"\(name)\" is not the expected type of real") }
		guard let index = self.columnNameInfoMap[tableColumn.name] else
			{ fatalError("SQLiteResults column key not found: \"\(name)\"") }

		return (sqlite3_column_type(self.statement, index) != SQLITE_NULL) ?
				sqlite3_column_double(self.statement, index) : nil
	}

	//------------------------------------------------------------------------------------------------------------------
	public func text(for tableColumn :SQLiteTableColumn) -> String? {
		// Preflight
		let	name = tableColumn.name
		guard case .text(_, _) = tableColumn.kind else
			{ fatalError("SQLiteResults column type mismatch: \"\(name)\" is not the expected type of text") }
		guard let index = self.columnNameInfoMap[tableColumn.name] else
			{ fatalError("SQLiteResults column key not found: \"\(name)\"") }

		// Get value
		if let text = sqlite3_column_text(self.statement, index) {
			// Have value
			return String(cString: text)
		} else {
			// Don't have value
			return nil
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func blob(for tableColumn :SQLiteTableColumn) -> Data? {
		// Preflight
		let	name = tableColumn.name
		guard case .blob = tableColumn.kind else
			{ fatalError("SQLiteResults column type mismatch: \"\(name)\" is not the expected type of blob") }
		guard let index = self.columnNameInfoMap[tableColumn.name] else
			{ fatalError("SQLiteResults column key not found: \"\(name)\"") }

		// Get value
		if let blob = sqlite3_column_blob(self.statement, index) {
			// Have value
			return Data(bytes: blob, count: Int(sqlite3_column_bytes(self.statement, index)))
		} else {
			// Don't have value
			return nil
		}
	}
}
