# MatchMate

A small matrimonial-style iOS app. It fetches profiles from the [Random User API](https://randomuser.me/documentation), shows them as cards in a paginated list, lets you open a full profile, and **Accept / Decline** from either screen. Decisions are stored locally, work offline, survive relaunch, and stay in sync between the list and detail views.

Built with **SwiftUI + SwiftData**, MVVM + repository, and `URLSession` + `async/await`.

---

## How to run

- **Requirements:** Xcode 26.2+ and an iOS 17+ simulator (or device).
- Open `MatchMate/MatchMate.xcodeproj`.
- Select an iOS Simulator (e.g. iPhone 16) and press **⌘R**.
- Run tests with **⌘U** (or the `MatchMateTests` target).

> Note on project format: the project was originally created with an Xcode 27 beta (`objectVersion = 110`). It has been set to `objectVersion = 77` so it opens in the current stable Xcode (26.2). A newer Xcode may re-upgrade this on open, which is expected.

From the command line:

```bash
xcodebuild build -project MatchMate/MatchMate.xcodeproj -scheme MatchMate \
  -destination 'platform=iOS Simulator,name=iPhone 16'

xcodebuild test -project MatchMate/MatchMate.xcodeproj -scheme MatchMate \
  -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:MatchMateTests
```

---

## Architecture

Layered MVVM with a repository as the single source of truth. Every boundary is a protocol, and dependencies are injected — so ViewModels can be unit-tested with mocks, and the concrete wiring lives in exactly one place (`AppDependencies`).

```
┌──────────────────────────────────────────────────────────┐
│  Views (SwiftUI, thin)                                     │
│  MatchListView · MatchCardView · MatchDetailView           │
└───────────────┬──────────────────────────────────────────┘
                │ observes / calls
┌───────────────▼──────────────────────────────────────────┐
│  ViewModels (@MainActor, @Observable)                      │
│  MatchListViewModel  — pagination, load phases, offline    │
│  MatchDetailViewModel — accept/decline for one profile     │
└───────────────┬──────────────────────────────────────────┘
                │ MatchRepositoryProtocol (injected)
┌───────────────▼──────────────────────────────────────────┐
│  MatchRepository  — single source of truth                 │
│   ├── ProfileAPIServiceProtocol → ProfileAPIService        │
│   │       URLSession + async/await, pagination, seed       │
│   └── SwiftData ModelContext                               │
│           persistence, cache, status                       │
└───────────────┬──────────────────────────────────────────┘
                │
        ┌───────▼────────┐     ┌────────────────────┐
        │  MatchProfile   │     │  NetworkMonitor     │
        │  @Model (SwiftData)  │  NWPathMonitor        │
        └────────────────┘     └────────────────────┘
```

### Folder layout

```
MatchMate/
├── App/            AppDependencies (composition root), MatchMateApp
├── Models/         MatchProfile (@Model) + MatchStatus, DTOs, DTO→Model mapping
├── Networking/     ProfileAPIService (+protocol), APIError
├── Repository/     MatchRepository (+protocol), RepositoryError
├── Common/         NetworkMonitor, shared status controls
└── Features/
    ├── List/       MatchListView, MatchCardView, MatchListViewModel
    └── Detail/     MatchDetailView, MatchDetailViewModel
MatchMateTests/     ViewModel + repository tests, mocks, factories
```

---

## Database choice — why SwiftData

I chose **SwiftData** over Core Data because:

- **Target is iOS 17**, which is SwiftData's minimum — so there's no compatibility cost.
- **Less boilerplate**: the model is a plain `@Model` class; no `.xcdatamodeld`, no `NSManagedObject` subclassing.
- **It directly serves the "one source of truth" requirement.** A `@Model` instance is an `Observable` reference type. The list and the detail screen hold the **same** `MatchProfile` object, so a status change made on either screen mutates that one object and both SwiftUI views re-render automatically — no manual refresh, no cross-screen notification plumbing.
- The repository still owns the `ModelContext`, so persistence stays behind a protocol and remains testable (tests use an in-memory container).

Trade-off acknowledged: Core Data has a more mature background-context and migration story. For an app of this scope, SwiftData's simplicity and built-in observation win.

---

## How pagination works

- The API is called as `…/api/?page=N&results=10&seed=matchmate`. The **seed is fixed** so paginated results stay stable across runs.
- `MatchListViewModel` tracks `currentPage` and loads page 1 on first appearance.
- Each card triggers `loadMoreIfNeeded(currentItem:)` via `.task`; when the **last** item appears, the next page is requested (infinite scroll). Re-entrancy is guarded by `isLoadingNextPage`.
- The repository fetches the page, **upserts** it into SwiftData keyed by `login.uuid`, and returns the full ordered list. A `sortIndex` preserves fetch order across relaunches.

## How status sync works

There is exactly **one** `MatchProfile` per `login.uuid` in SwiftData.

- **Action on the list card** → `MatchListViewModel` → `repository.setStatus` → mutates the shared model and saves. The card observes `profile.status`, so it flips to Accepted/Declined immediately.
- **Action on the detail screen** → `MatchDetailViewModel` mutates the **same** model instance the list is holding. The detail UI updates right away, and because the list card observes that same object, it already shows the new status when you navigate back — no refresh.
- **Merge preserves decisions**: when a page is re-fetched, existing profiles are updated with fresh API fields but their `status` (and `sortIndex`) are left untouched, so an accept/decline is never clobbered.
- **Persistence**: status is saved to SwiftData on every change, so it survives app kill/relaunch.

## Offline & error handling

- **Offline reads**: if the device is offline (via `NWPathMonitor`) or a request fails for connectivity reasons, the list falls back to cached profiles from SwiftData and shows an inline "you're offline" banner. If there's no cache yet, a full-screen retryable error is shown.
- **Offline actions**: Accept/Decline are pure local DB writes, so they always work regardless of connectivity.
- **Error surfaces**:
  - *API* — `APIError` (invalid URL, not connected, request failed, bad status, decoding) with user-friendly messages.
  - *Database* — `RepositoryError` (save/fetch) surfaced as a banner (list) or inline message (detail).
  - *Connectivity* — distinguished from hard errors so the app can degrade gracefully to cache.

---

## Tests

Unit tests focus on the ViewModels (the requirement) plus the repository's merge logic:

- **`MatchListViewModelTests`** — first-load population, load-once guard, infinite-scroll pagination, offline-with-cache vs offline-empty, connectivity fallback to cache, hard-error state, accept/decline routing, and save-failure banner.
- **`MatchDetailViewModelTests`** — accept/decline update the shared model; save failure surfaces an error and leaves status unchanged.
- **`MatchRepositoryTests`** — against a real **in-memory SwiftData** store: insertion + ordering, page appending, **status preserved on re-fetch**, status persistence, empty cache.

Mocks (`MockMatchRepository`, `MockAPIService`, `MockNetworkMonitor`) and factories live in `TestSupport.swift`. Tests use the **Swift Testing** framework.

---

## Known gaps / things I'd do next

- No pull-to-refresh (not required; status sync is automatic). Easy to add.
- The API returns a full page for our seed, so "end of list" isn't specially handled beyond the offline stop.
- Images use SwiftUI `AsyncImage` (in-memory URL cache only); a disk image cache would improve true-offline photo display.
- No UI/snapshot tests — the template UI-test target is left as-is; effort went into ViewModel/repository coverage.
- Accessibility is basic (labels on the accept/decline buttons); could be expanded.

## Rough hours spent

~5–6 hours (design + implementation + tests + README).
