# swift-call-log

A Mac's call history, read-only: every Phone, FaceTime and CallKit-app call (iPhone calls relayed over Continuity included), voicemail with its transcripts, FaceTime links and the block list — and the statistics they add up to. No Apple framework is linked; the stores are read from private copies and never opened in place.

```swift
import CallLog

let store = CallLogStore()
for call in try store.calls().prefix(5) {
    print(call.date, call.address ?? "?", call.status, call.duration)
}

let overview = CallStatistics.overview(try store.calls())
print(overview.answerRate ?? 0, overview.talk.median, overview.missedNotReturned)
```

## Where the data is

| Store | Path under `~/Library` | What |
| --- | --- | --- |
| Calls | `Application Support/CallHistoryDB/CallHistory.storedata` | callhistoryd's Core Data store: every call, its participants, trust and caller checks |
| Voicemail | `Group Containers/group.com.apple.FaceTime/com.apple.facetimemessagestored/Data Store/FaceTimeMessageStore-local.sqlitedb` | messages left (macOS 26+), transcripts, audio in `Assets/<2>/<id>.MOV` |
| FaceTime links | `Application Support/FaceTime/FaceTime.sqlite3` | links this account made |
| Block list | `Preferences/com.apple.cmfsyncagent.plist` | the list Phone, FaceTime and Messages share (synced through iCloud) |

All four sit behind **Full Disk Access**; a refusal is `CallLogError.needsFullDiskAccess`, a missing store `.noStore`.

## Reading safely

Each database and its `-wal`/`-shm` are copied to a private temporary folder, read there, and deleted ([swift-sqlite-reader](https://github.com/arraypress/swift-sqlite-reader)'s snapshot). The live stores are written through a write-ahead log, and on the Mac this was built on the main CallHistory file had not been checkpointed for eleven weeks — every recent call lived only in the `-wal`, so opening the file alone would have missed them. Columns are looked up before they are selected (a column a macOS release lacks reads as `nil`), and the participant join table is found by suffix, because Core Data names it after entity numbers (`Z_2REMOTEPARTICIPANTHANDLES` today) that move when the model gains an entity.

## The codes (measured on macOS 27.0.1)

Nothing here was guessed. The enum tables were read out of Apple's own CallHistory and FaceTimeMessageStore frameworks — each Swift enum's `allCases` and `rawValue`, loaded in-process — and the ObjC constants with `dlsym`:

- **Status** is Apple's `+[CHManager CHCallStatusForCallWithDuration:isOriginated:isAnswered:]`, called on every combination: any duration means connected (in either direction, even with the answered flag at 0 — outgoing calls never set it); a zero-length outgoing call was cancelled; a zero-length incoming call was answered elsewhere if the flag is set, otherwise missed.
- **Media** is `ZCALL_CATEGORY`: 1 audio, 2 video, 4 TTY direct, 8 TTY relay.
- **Trust** (`CommunicationTrustScore`): blocked, junk, blockedByThirdParty, suspectedJunk, unknown, communicatedWith, identifiedByThirdParty, maybe, contact, vip. Outgoing calls carry `unknown`; the score is meaningful for incoming ones.
- **Verification** (STIR/SHAKEN), **caller ID availability**, **junk confidence**, **Call Directory identity**, the 66 **originating UI** names (`siri`, `faceTimeLink`, `handoff`, `answerIncoming`…), **mailboxes** (inbox, junk, trash) and **transcription status** likewise.
- `ZFACE_TIME_DATA` is FaceTime's bytes used (`bytesOfDataUsed`). `ZDISCONNECTED_CAUSE` and `ZFILTERED_OUT_REASON` have no published meaning and are passed through as numbers.
- A **transcript** is a keyed archive of TelephonyUtilities' `TUCaption` (text, confidence) — in the row and again in `<id>.plist` beside the audio. A stand-in class decodes it with secure coding on.
- Message **type 0** is a voicemail (audio left on the phone network); no other type has been seen, so others are reported as `type-<n>`.

## Statistics

`CallStatistics` is pure functions over `[Call]`:

- `overview` — counts by direction and status, answer/connect/missed rates, who starts the calls, talk time (total, average, median, 90th percentile, longest), audio/video, services, group calls, FaceTime data, unknown/junk/withheld/screened callers, active days, the longest run of days with a call and the longest gap, busiest hour and weekday, missed calls never returned and the median call-back delay.
- `people` — the same per person; a `PersonKeying` decides who is who, so a caller holding Contacts can fold one person's numbers into one name.
- `buckets(by:)` — hour, weekday, day, ISO week, month, year (time buckets complete, empty ones included), or service, media, status, direction, country, device, trust, origin.
- `unreturned` — missed calls nobody returned. A run of missed calls ends when you call back (its delay is measured from the first miss) or when they get through again; junk and blocked numbers are never owed a call back.

## Measured

On one Mac (macOS 27.0.1):

- **Decoding agrees with Apple's.** `CHManager.recentCalls`, Apple's in-process reader, returned the same calls as this library, and status, media, provider, data used, trust, verification, junk confidence, caller ID, originating UI, read, disconnect cause, filtered-out reason and duration matched on every one — no mismatch in any field.
- Every store read on real data: messages with audio and transcripts, deleted messages (row kept, audio and transcript gone), FaceTime links, and phone and email block-list entries.
- **Speed:** the call store reads, copy included, in about 10 ms.
- **Not measured:** third-party CallKit calls and group FaceTime calls — none were on that Mac. Both are decoded from the schema, untested on real rows.

## Not offered

- **FaceTime link URLs.** Apple's own builder (`TUConversationLink`) adds a prefix to the stored pseudonym and wraps the key; a rebuild could not be checked against it, so none is offered. The private key column is never selected.
- **Writing.** The block list's own API (`CMFBlockListAddItemForAllServices`) refuses any process without Apple's private entitlement — measured: the agent logs "Denying xpc connection, task does not have entitlement". Writing the agent's preferences directly does not work either: an entry added with the revision bumped and `com.apple.cmfsyncagent.storedidchangeexternally` posted stayed in the file but never reached the iPhone's list (checked on the phone); the file was restored byte-for-byte afterwards.

## Requirements

macOS 14 or later (the voicemail store appears with macOS 26's Phone app). Swift 6.2.

## Licence

MIT.
