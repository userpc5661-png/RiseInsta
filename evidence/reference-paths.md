# Measured reference paths — revision reference02

Reference SHA256: `dab378798f0ea2491d13dbbe512cf6543d4bb23e1386b6d36a8f6d252357b843`.

Addresses are **preferred Mach-O VA**, not runtime VA. Analysis uses the supplied thin ARM64 file, Mach-O load commands, Objective-C selector stubs and Capstone 5.0.7. This is reference-binary evidence, not execution verification in Instagram.

| Reference VA | Observed operation | Implementation |
|---|---|---|
| `0xb9018–0xb9068` | On `IGSundialFeedViewController`, try `currentPlaybackMedia`, then named ivar `_currentPlaybackMedia` | `RIReferenceField` + `RIModelGetters` |
| `0xb90d0–0xb9108` | Walk responders, inspect `_media`, then `media`; later inspect `delegate` | `RIFindMedia` + named ivar lookup |
| `0xb93ec–0xb9408` | `object_getClass` → `class_getInstanceVariable` → `object_getIvar` | Only object-typed named ivars are accepted |
| `0x13050–0x130a0` | `media.photo.imageURLForWidth:`; width in `d0`, measured constant at `0x1a2358` is `9999.0` | Exact `@` return / `double` argument checked before invocation |
| `0x13108–0x13168` | `media.video.allVideoURLs` returning a collection; `anyObject` is called | Supports `NSSet` and `NSArray` URL collections |
| `0x131cc–0x131ec` | Video fallback `videoURLForCurrentNetworkConditions` | Object-returning getter checked before invocation |
| `0x11f54–0x11fc0` | Image fallback `_originalImageVersions`, then candidate `_url` | Named object ivars only |
| `0x82c0–0x82d8` | After `IGStoryFullscreenSectionController.didUpdateToObject:`, read `currentStoryItem` | Weak controller capture; resolve item at action time |
| `0x471c`, `0x4748` | DM `shouldUpdateLastSeenMessage`, class method `builderWithData:metadata:` | Existing reference-derived hooks retained; call/block counters added |
| `0x49e4`, `0x6398–0x64a4` | Typing hook with active flag, thread key, metadata, type; suppress original when preference is enabled | Runtime signature recorded; explicit 32/64-bit type adapters |
| `0x3d5c8`, `0x3d5ec` | Story/Reels `parsedObjectFromResponse:` instance hooks | Return nil when ad preference enabled, as observed at `0x3d868` / `0x3d8fc` |

No source-code class layout or numeric ivar offset is assumed. Existing private hook names already came from the same reference in the previous candidate; their presence alone does not explain why the tester's features failed. The new report records actual method encodings, call counts, suppression counts, preferences and unresolved media paths to identify that failure on the target device.

The Instagram-side return and argument encodings are not recoverable completely from the tweak's Objective-C metadata. They are checked on the device before hooking. A skipped hook is reported, never treated as a working feature.

Known limits: no on-device test has been performed for this revision; full feature parity with the reference is not implemented; DASH-only media that require separate audio/video merging remain unsupported.
