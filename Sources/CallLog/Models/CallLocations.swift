//
//  CallLocations.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Where a home folder keeps each store — a real home, or a fixture one.
public struct CallLocations: Sendable, Hashable {

    /// The call history: every Phone, FaceTime and CallKit-app call.
    public var callHistory: URL

    /// Voicemail and other left messages, with their transcripts.
    public var messages: URL

    /// The folder of message audio, `Assets/<first two of the id>/<id>.<type>`.
    public var messageAssets: URL

    /// FaceTime links.
    public var links: URL

    /// The block list's preferences file.
    public var blockList: URL

    public init(callHistory: URL, messages: URL, messageAssets: URL, links: URL, blockList: URL) {
        self.callHistory = callHistory
        self.messages = messages
        self.messageAssets = messageAssets
        self.links = links
        self.blockList = blockList
    }

    /// Every store under `home`, where macOS 26 and 27 keep them.
    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        let library = home.appendingPathComponent("Library", isDirectory: true)
        let store = library.appendingPathComponent(
            "Group Containers/group.com.apple.FaceTime/com.apple.facetimemessagestored/Data Store", isDirectory: true)
        self.init(
            callHistory: library.appendingPathComponent("Application Support/CallHistoryDB/CallHistory.storedata"),
            messages: store.appendingPathComponent("FaceTimeMessageStore-local.sqlitedb"),
            messageAssets: store.appendingPathComponent("Assets", isDirectory: true),
            links: library.appendingPathComponent("Application Support/FaceTime/FaceTime.sqlite3"),
            blockList: library.appendingPathComponent("Preferences/com.apple.cmfsyncagent.plist")
        )
    }
}
