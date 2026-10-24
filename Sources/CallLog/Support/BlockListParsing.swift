//
//  BlockListParsing.swift
//  CallLog
//
//  Created by David Sherlock on 2026.
//
//  The block list is the CommunicationsFilter agent's preferences
//  (com.apple.cmfsyncagent): one dictionary under
//  __kCMFBlockListStoreTopLevelKey holding a revision, a timestamp and the
//  entries. MEASURED shape — a phone entry:
//    __kCMFItemTypeKey 0, __kCMFItemVersionKey 1,
//    __kCMFItemPhoneNumberUnformattedKey "+447700900123" (E.164),
//    __kCMFItemPhoneNumberCountryCodeKey "gb";
//  an email entry: type 1 with __kCMFItemEmailUnformattedKey. The agent's
//  own API refuses any process without Apple's private entitlement, so the
//  file is the only way in.
//

import Foundation

/// Reading the block list.
public enum BlockListParsing {

    static let topLevelKey = "__kCMFBlockListStoreTopLevelKey"
    static let itemsKey = "__kCMFBlockListStoreArrayKey"
    static let revisionKey = "__kCMFBlockListStoreRevisionKey"
    static let typeKey = "__kCMFItemTypeKey"
    static let phoneKey = "__kCMFItemPhoneNumberUnformattedKey"
    static let countryKey = "__kCMFItemPhoneNumberCountryCodeKey"
    static let emailKey = "__kCMFItemEmailUnformattedKey"

    /// The entries in the agent's preferences, in their stored order.
    public static func items(_ preferences: [String: Any]) -> [BlockedItem] {
        let store = preferences[topLevelKey] as? [String: Any]
        let entries = store?[itemsKey] as? [[String: Any]] ?? []
        return entries.compactMap(item)
    }

    /// The store's revision — it rises with every change.
    public static func revision(_ preferences: [String: Any]) -> Int? {
        (preferences[topLevelKey] as? [String: Any])?[revisionKey] as? Int
    }

    /// One entry, by which value key it carries.
    static func item(_ entry: [String: Any]) -> BlockedItem? {
        let type = entry[typeKey] as? Int
        if let phone = entry[phoneKey] as? String, !phone.isEmpty {
            return BlockedItem(kind: .phoneNumber, value: phone, countryCode: entry[countryKey] as? String, typeCode: type)
        }
        if let email = entry[emailKey] as? String, !email.isEmpty {
            return BlockedItem(kind: .email, value: email, typeCode: type)
        }
        // A kind this library has not seen (a business id, perhaps): its
        // first string value, so it is listed rather than silently dropped.
        guard let value = entry.filter({ $0.key != typeKey }).sorted(by: { $0.key < $1.key })
            .compactMap({ $0.value as? String }).first else { return nil }
        return BlockedItem(kind: .other, value: value, typeCode: type)
    }
}
