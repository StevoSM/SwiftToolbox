//
//  FilesystemEventsTracker.swift
//  Swift Toolbox Apple AddOn
//
//  Created by Stevo on 2/13/20.
//  Copyright © 2020 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: FilesystemEventsTracker
class FilesystemEventsTracker {

	// MARK: Types
	typealias EventInfo = (id :FSEventStreamEventId, url :URL, flags :FSEventStreamEventFlags)

	// MARK: Properties
			var	processProc :(_ eventInfo :EventInfo) -> Void = { _ in }

	private	var	eventStreamRef :FSEventStreamRef!

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(urls :[URL],
			lastEventStreamEventID :FSEventStreamEventId = FSEventStreamEventId(kFSEventStreamEventIdSinceNow)) {
		// Setup
		let	eventStreamCallback :FSEventStreamCallback =
					{ eventStreamRef, contextInfo, eventCount, eventPaths, eventFlags, eventIDs in
						// Setup
						guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }

						let	filesystemEventsTracker = unsafeBitCast(contextInfo, to: FilesystemEventsTracker.self)

						// Iterate all events
						for i in 0..<eventCount {
							// Call proc
							filesystemEventsTracker.processProc(
									(eventIDs[i], URL(fileURLWithPath: paths[i]), eventFlags[i]))
						}
					}

		var	eventStreamContext =
					FSEventStreamContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
		eventStreamContext.info = Unmanaged.passUnretained(self).toOpaque()
		self.eventStreamRef =
				FSEventStreamCreate(kCFAllocatorDefault, eventStreamCallback, &eventStreamContext,
						(urls.map({ $0.path })) as CFArray, lastEventStreamEventID, 0,
						UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents))

		// Start
		FSEventStreamSetDispatchQueue(self.eventStreamRef, DispatchQueue.global(qos: .background))
		FSEventStreamStart(self.eventStreamRef)
	}

	//------------------------------------------------------------------------------------------------------------------
	deinit {
		// Stop and cleanupo
		FSEventStreamStop(self.eventStreamRef)
		FSEventStreamInvalidate(self.eventStreamRef)
		FSEventStreamRelease(self.eventStreamRef)
	}
}
