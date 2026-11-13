import Foundation

/// improvement: paging for a list a view loads itself («Входит в списки», «Подборки»): the page after the last one
/// that brought items, one at a time. A failed page waits for Retry and is asked for again; the site's 404 past the last
/// page ends the list. The views counted pages on each trigger, so a failed page was skipped and two could load at once.
struct PageCursor: Equatable {
    /// The last page that brought items.
    private(set) var loaded = 0
    private(set) var isLoading = false
    /// The last page failed: the list shows Retry instead of asking again by itself.
    private(set) var failed = false
    /// The site has no page after `loaded`.
    private(set) var reachedEnd = false

    /// `loaded`: pages already on screen (1 after a refresh replaced the list).
    init(loaded: Int = 0) {
        self.loaded = loaded
    }

    /// The page to ask for now; nil while one is on its way, after a failure (until `retry`) or past the end.
    mutating func next() -> Int? {
        guard !isLoading, !failed, !reachedEnd else { return nil }
        isLoading = true
        return loaded + 1
    }

    mutating func retry() -> Int? {
        failed = false
        return next()
    }

    /// `items`: what the page brought (0 when it didn't load); `isEnd`: the site answered 404, there is no such page.
    mutating func finish(page: Int, items: Int, isEnd: Bool) {
        isLoading = false
        if items > 0 {
            loaded = max(loaded, page)
        } else if isEnd {
            reachedEnd = true
        } else {
            failed = true
        }
    }
}
