//
//  LockingArray.swift
//  Swift Toolbox
//
//  Created by Stevo on 12/6/19.
//  Copyright © 2019 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: LockingArray
public class LockingArray<T> {

	// MARK: Properties
	public	var	count :Int { self.lock.read() { self.array.count } }
	public	var	values :[T] { self.lock.read() { self.array } }

	private	let	lock = ReadPreferringReadWriteLock()

	private	var	array = [T]()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public init() {}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	public func append(_ value :T) { self.lock.write({ self.array.append(value) }) }

	//------------------------------------------------------------------------------------------------------------------
	public func append(_ values :[T]) { self.lock.write({ self.array += values }) }

	//------------------------------------------------------------------------------------------------------------------
	public func forEach(proc :(_ value :T) -> Void) { self.lock.read({ self.array.forEach({ proc($0) }) }) }

	//------------------------------------------------------------------------------------------------------------------
	public func sort(by compareProc :(_ value1 :T, _ value2 :T) -> Bool) {
		// Sort
		self.lock.write({ self.array.sort(by: compareProc) })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func removeFirst() -> T { self.lock.write({ self.array.removeFirst() }) }

	//------------------------------------------------------------------------------------------------------------------
	public func removeAll(where proc :(_ value :T) -> Bool) {
		// Remove all using proc
		self.lock.write({ self.array.removeAll(where: proc) })
	}

	//------------------------------------------------------------------------------------------------------------------
	@discardableResult
	public func removeAll() -> [T]
		{ self.lock.write({ let values = self.array; self.array.removeAll(); return values }) }
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - Operators
public func += <T>(left :inout LockingArray<T>, right :[T]) { left.append(right) }
