//
//  SQLiteTable.swift
//  Swift Toolbox
//
//  Created by Stevo on 10/15/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: SQLiteTableColumn extension
fileprivate extension SQLiteTableColumn {

	// MARK: Properties
	var	createString :String {
				// Compose column string
				var	string = "\(self.name) "

				switch self.kind {
					case .integer:
						// Integer
						string += "INTEGER"

					case .real:
						// Real
						string += "REAL"

					case .text, .dateISO8601FractionalSecondsAutoSet, .dateISO8601FractionalSecondsAutoUpdate:
						// Text
						string += "TEXT"

					case .blob:
						// Blob
						string += "BLOB"
				}

				self.options.forEach() {
					// What is option
					switch $0 {
						case .primaryKey:		string += " PRIMARY KEY"
						case .autoincrement:	string += " AUTOINCREMENT"
						case .notNull:			string += " NOT NULL"
						case .unique:			string += " UNIQUE"
						case .check:			string += " CHECK"
					}
				}

				if self.defaultValue != nil {
					// Default
					string += " DEFAULT (\(self.defaultValue!))"
				}

				return string
			}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - SQLiteTable
@dynamicMemberLookup
public struct SQLiteTable {

	// MARK: Types
	public	struct Options : OptionSet {

				static	public	let	withoutRowID = Options(rawValue: 1 << 0)

						public	let	rawValue :Int

				// MARK: Lifecycle methods
				public init(rawValue :Int) { self.rawValue = rawValue }
			}

	// MARK: Properties
	static	private			let	countAllTableColumn = SQLiteTableColumn("COUNT(*)", .integer)

			private(set)	var	name :String

			private			let	options :Options
			private			let tableColumnReferenceMap :[String : SQLiteTableColumn.Reference]
			private			let	statementPerformer :SQLiteStatementPerformer

			private			var	tableColumns :[SQLiteTableColumn]
			private			var	tableColumnsMap = [String : SQLiteTableColumn]()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(name :String, options :Options, tableColumns :[SQLiteTableColumn],
			references :[SQLiteTableColumn.Reference] = [], statementPerformer :SQLiteStatementPerformer) {
		// Store
		self.name = name

		self.options = options
		self.tableColumns = tableColumns
		self.tableColumnReferenceMap = Dictionary(references.map({ ($0.tableColumn.name, $0) }))
		self.statementPerformer = statementPerformer

		// Setup
		tableColumns.forEach() { self.tableColumnsMap["\($0.name)TableColumn"] = $0 }
	}

	// MARK: Property methods
	//------------------------------------------------------------------------------------------------------------------
	public subscript(dynamicMember member :String) -> SQLiteTableColumn { self.tableColumnsMap[member]! }

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	public func create(ifNotExists :Bool = true) {
		// Setup
		let	columnInfos :[String] =
					self.tableColumns.map() {
						// Start with create string
						var	columnInfo = $0.createString

						// Add references if applicable
						if let tableColumnReference = self.tableColumnReferenceMap[$0.name] {
							// Add reference
							columnInfo +=
									" REFERENCES \(tableColumnReference.referencedTable.name)(\(tableColumnReference.referencedTableColumn.name)) ON UPDATE CASCADE"
						}

						return columnInfo
					}

		// Create
		let	statement =
					"CREATE TABLE" + (ifNotExists ? " IF NOT EXISTS" : "") + " `\(self.name)`" +
							" (" + String(combining: columnInfos) + ")" +
							(self.options.contains(.withoutRowID) ? " WITHOUT ROWID" : "")
		self.statementPerformer.addToTransactionOrPerform(statement: statement)
	}

	//------------------------------------------------------------------------------------------------------------------
	public mutating func rename(to name :String) {
		// Perform
		self.statementPerformer.addToTransactionOrPerform(statement: "ALTER TABLE `\(self.name)` RENAME TO `\(name)`")

		// Update
		self.name = name
	}

	//------------------------------------------------------------------------------------------------------------------
	public mutating func add(_ tableColumn :SQLiteTableColumn) {
		// Perform
		self.statementPerformer.addToTransactionOrPerform(
				statement: "ALTER TABLE `\(self.name)` ADD COLUMN \(tableColumn.createString)")

		// Update
		self.tableColumns.append(tableColumn)
		self.tableColumnsMap["\(tableColumn.name)TableColumn"] = tableColumn
	}

	//------------------------------------------------------------------------------------------------------------------
	public func add(_ trigger :SQLiteTrigger) {
		// Perform
		self.statementPerformer.addToTransactionOrPerform(statement: trigger.string(for: self))
	}

	//------------------------------------------------------------------------------------------------------------------
	public func drop() {
		// Perform
		self.statementPerformer.addToTransactionOrPerform(statement: "DROP TABLE `\(self.name)`")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func hasRow(where sqliteWhere :SQLiteWhere) -> Bool { count(where: sqliteWhere) > 0 }

	//------------------------------------------------------------------------------------------------------------------
	public func count(where sqliteWhere :SQLiteWhere? = nil) -> Int {
		// Perform
		var	count :Int64 = 0
		self.statementPerformer.perform(statement: "SELECT COUNT(*) FROM `\(self.name)`" + (sqliteWhere?.string ?? ""),
				values: sqliteWhere?.values) {
					// Query count
					count = $0.integer(for: type(of: self).countAllTableColumn)!
				}

		return Int(count)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func rowID(for sqliteWhere :SQLiteWhere) throws -> Int64? {
		// Query rowID
		var	rowID :Int64? = nil
		try select(tableColumns: [.rowID], where: sqliteWhere) { rowID = $0.integer(for: .rowID)! }

		return rowID
	}

	//------------------------------------------------------------------------------------------------------------------
	public func select(tableColumns :[SQLiteTableColumn]? = nil, innerJoin :SQLiteInnerJoin? = nil,
			where sqliteWhere :SQLiteWhere? = nil, orderBy :SQLiteOrderBy? = nil, resultsRowProc :SQLiteResultsRow.Proc)
			throws {
		// Perform
		try select(columnNames: (tableColumns != nil) ? columnNames(for: tableColumns!) : "*", innerJoin: innerJoin,
				where: sqliteWhere, orderBy: orderBy, resultsRowProc: resultsRowProc)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func select(tableColumns :[(table :SQLiteTable, tableColumn :SQLiteTableColumn)],
			innerJoin :SQLiteInnerJoin? = nil, where sqliteWhere :SQLiteWhere? = nil, orderBy :SQLiteOrderBy? = nil,
			resultsRowProc :SQLiteResultsRow.Proc) throws {
		// Perform
		try select(columnNames: columnNames(for: tableColumns), innerJoin: innerJoin, where: sqliteWhere,
				orderBy: orderBy, resultsRowProc: resultsRowProc)
	}

	//------------------------------------------------------------------------------------------------------------------
	@discardableResult
	public func insertRow(_ info :[(tableColumn :SQLiteTableColumn, value :Any)]) -> Int64 {
		// Perform
		var	lastInsertRowID :Int64 = 0
		insertRow(info) { lastInsertRowID = $0 }

		return lastInsertRowID
	}

	//------------------------------------------------------------------------------------------------------------------
	public func insertRow(_ info :[(tableColumn :SQLiteTableColumn, value :Any)],
			lastInsertRowIDProc :@escaping (_ lastInsertRowID :Int64) -> Void) {
		// Setup
		let	tableColumns = info.map() { $0.tableColumn }
		let	statement =
					"INSERT INTO `\(self.name)` (" + columnNames(for: tableColumns) + ") VALUES (" +
							String(combining: Array(repeating: "?", count: info.count), with: ",") + ")"
		let	values = info.map() { $0.value }

		// Perform
		self.statementPerformer.addToTransactionOrPerform(statement: statement, values: values,
				lastInsertRowIDProc: lastInsertRowIDProc)
	}

	//------------------------------------------------------------------------------------------------------------------
	@discardableResult
	public func insertOrReplaceRow(_ info :[(tableColumn :SQLiteTableColumn, value :Any)]) -> Int64 {
		// Perform
		var	lastInsertRowID :Int64 = 0
		insertOrReplaceRow(info) { lastInsertRowID = $0 }

		return lastInsertRowID
	}

	//------------------------------------------------------------------------------------------------------------------
	public func insertOrReplaceRow(_ info :[(tableColumn :SQLiteTableColumn, value :Any)],
			lastInsertRowIDProc :@escaping (_ lastInsertRowID :Int64) -> Void) {
		// Setup
		let	tableColumns = info.map() { $0.tableColumn }
		let	statement =
					"INSERT OR REPLACE INTO `\(self.name)` (" + columnNames(for: tableColumns) + ") VALUES (" +
							String(combining: Array(repeating: "?", count: info.count), with: ",") + ")"
		let	values = info.map() { $0.value }

		// Perform
		self.statementPerformer.addToTransactionOrPerform(statement: statement, values: values,
				lastInsertRowIDProc: lastInsertRowIDProc)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func insertOrReplaceRows(_ tableColumn :SQLiteTableColumn, values :[Any]) {
		// Perform in chunks of SQLITE_LIMIT_VARIABLE_NUMBER
		values.forEachChunk(chunkSize: self.statementPerformer.variableNumberLimit) {
			// Setup
			let	statement =
						"INSERT OR REPLACE INTO `\(self.name)` (" + columnNames(for: [tableColumn]) + ") VALUES "
								+ String(combining: Array(repeating: "(?)", count: $0.count), with: ",")

			// Perform
			self.statementPerformer.addToTransactionOrPerform(statement: statement, values: $0)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func update(_ info :[(tableColumn :SQLiteTableColumn, value :Any)], where sqliteWhere :SQLiteWhere) {
		// Setup
		let	statement =
					"UPDATE `\(self.name)` SET " + String(combining: info.map({ "`\($0.tableColumn.name)` = ?" })) +
							sqliteWhere.string
		let	values = info.map({ $0.value }) + (sqliteWhere.values ?? [])

		// Perform
		self.statementPerformer.addToTransactionOrPerform(statement: statement, values: values)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func deleteRows(_ tableColumn :SQLiteTableColumn, values :[Any]) {
		// Perform in chunks of SQLITE_LIMIT_VARIABLE_NUMBER
		values.forEachChunk(chunkSize: self.statementPerformer.variableNumberLimit) {
			// Setup
			let	statement =
						"DELETE FROM `\(self.name)` WHERE `\(tableColumn.name)` IN (" +
								String(combining: Array(repeating: "?", count: $0.count), with: ",") + ")"

			// Perform
			self.statementPerformer.addToTransactionOrPerform(statement: statement, values: $0)
		}
	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func columnNames(for tableColumns :[SQLiteTableColumn]) -> String {
		// Return string
		return String(combining: tableColumns.map({ "`\($0.name)`" }), with: ",")
	}

	//------------------------------------------------------------------------------------------------------------------
	private func columnNames(for tableColumns :[(table :SQLiteTable, tableColumn :SQLiteTableColumn)]) -> String {
		// Return string
		return String(combining: tableColumns.map({ "`\($0.table.name)`.`\($0.tableColumn.name)`" }), with: ",")
	}

	//------------------------------------------------------------------------------------------------------------------
	private func select(columnNames :String, innerJoin :SQLiteInnerJoin?, where sqliteWhere :SQLiteWhere?,
			orderBy :SQLiteOrderBy?, resultsRowProc :SQLiteResultsRow.Proc) throws {
		// Check if we have SQLiteWhere
		if sqliteWhere != nil {
			// Iterate all groups in SQLiteWhere
			let	variableNumberLimit = self.statementPerformer.variableNumberLimit
			try sqliteWhere!.forEachValueGroup(groupSize: variableNumberLimit) { string, values in
				// Compose statement
				let	statement =
							"SELECT \(columnNames) FROM `\(self.name)`" + (innerJoin?.string ?? "") + string +
									(orderBy?.string ?? "")

				// Run lean
				try autoreleasepool() {
					// Perform
					try self.statementPerformer.perform(statement: statement, values: values,
							resultsRowProc: resultsRowProc)
				}
			}
		} else {
			// No SQLiteWhere
			let	statement =
						"SELECT \(columnNames) FROM `\(self.name)`" + (innerJoin?.string ?? "") +
								(orderBy?.string ?? "")

			// Run lean
			try autoreleasepool() {
				// Perform
				try self.statementPerformer.perform(statement: statement, values: nil, resultsRowProc: resultsRowProc)
			}
		}
	}
}
