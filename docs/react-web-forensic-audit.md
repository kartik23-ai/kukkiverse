# Rotty Music React Web App — Forensic Product Audit

**Audit date:** 2026-08-08  
**Scope:** `web/` React/Vite app, with duplicate-source comparison against `web-player/` and `website/`  
**Audit mode:** static code review, local build/lint/dependency checks, desktop visual pass, mobile visual pass, and basic interaction/runtime pass  
**Status:** audit only; no application source was changed for this report

## Executive verdict

The React app is a working prototype shell, not a production-ready premium music product yet. The visual language is consistent enough to identify the brand, but the information architecture is tab-state driven, content is sparse when the API fails, the player has several race/buffering risks, and important user/security flows are implemented on the client.

The highest-risk findings are:

1. **Playback/content availability is not reliable.** In the local runtime, the `/api/home` and `/api/search` proxy responses produced AES decryption errors, then the direct JioSaavn fallback failed with `TypeError: Failed to fetch`; Home rendered empty sections and Search rendered “No songs found.”
2. **Authentication is not safe.** The client accepts the hard-coded OTP `777777`, creates guest identities in the browser, stores session identity in `localStorage`, and the forgot-password path only simulates changing the password.
3. **Supporter entitlement is forgeable.** The Support screen contains a client-side bypass for values containing `bypass` or equal to `777777`, and trusts `localStorage` for supporter state.
4. **The product can destroy data.** Settings calls `localStorage.clear()`, which removes auth, library, install, and unrelated app state rather than only cache data.
5. **The player is not engineered as a state machine.** Async URL resolution, autoplay refill, queue mutation, media errors, remote sync, and Web Audio effects all share mutable closures and independent timers.
6. **The design system is mostly inline styling.** This makes spacing, motion, accessibility, responsive behavior, theming, and visual QA difficult to control.
7. **The app is not quality-gated.** `npm run build` passed, but `npm run lint` reported **109 problems: 101 errors and 8 warnings**. `npm audit` reported **4 high-severity vulnerabilities** in development dependencies.

## What was inspected

### Source inventory

The canonical `web/src` tree contains 29 source/public files and approximately 9,498 lines. The largest modules are:

| Area | File | Size |
|---|---|---:|
| App shell | `web/src/App.tsx` | 921 lines |
| Playback engine | `web/src/context/AudioContext.tsx` | 1,197 lines |
| Authentication | `web/src/components/AuthModal.tsx` | 1,016 lines |
| Now playing | `web/src/components/NowPlayingPanel.tsx` | 850 lines |
| Home/catalog | `web/src/views/Home.tsx` | 1,034 lines |
| Support/payment | `web/src/views/Support.tsx` | 561 lines |
| Library | `web/src/views/Library.tsx` | 474 lines |
| Global styles | `web/src/index.css` | 410 lines |

`web-player/src` and `website/src` contain matching copies of the React source files. This is a release-drift and maintenance risk: fixes can land in one copy while the shipped copy remains unchanged.

### Product surfaces inspected

Home, Search, Library, Rotty Labs, Settings, Support Rotty, Auth/Guest prompt, Sidebar, PlayerBar, Now Playing panel, lyrics/queue/connect panes, song options menu, PWA install prompt, service worker, API layer, storage, Firebase REST, Supabase party sync, Spotify sync, and Vite middleware.

### Evidence collected

- `npm run build`: passed; Vite produced a ~397 KB gzip-uncompressed JavaScript bundle and a 6.34 KB CSS bundle.
- `npm run lint`: failed with 109 problems (101 errors, 8 warnings).
- `npm audit --audit-level=high`: 4 high-severity advisories in `brace-expansion`, `nanoid`, `postcss`, and `vite`; fix available via `npm audit fix`.
- Desktop pass at approximately 1280×720: fixed sidebar, fixed Now Playing panel, fixed bottom player, sparse/empty content after API failure.
- Mobile pass at 390×844: bottom navigation works, but Home content is mostly generic controls before content, and many interactive controls appear as generic DOM nodes rather than accessible buttons.
- Runtime console evidence: `[GhostProxy] Decryption error: OperationError` and `Saavn direct search failed: TypeError: Failed to fetch`.

## Severity model

- **P0:** security, data loss, or playback/product availability blocker.
- **P1:** serious UX, architecture, accessibility, or reliability defect.
- **P2:** quality, maintainability, polish, or scalability defect.

# 220 concrete flaws

## A. Architecture, navigation, and app shell

1. **[P1] No real router.** `web/src/App.tsx:31,190-206` stores the active view as an integer, so URLs, browser back/forward, deep links, refresh state, and shareable screens do not work.
2. **[P1] Magic-number navigation.** Tabs `0` through `5` are repeated across the shell and sidebar instead of using a typed route object.
3. **[P1] One oversized shell component.** `App.tsx` owns auth, splash, palette, shortcuts, responsive state, playback controls, views, mobile sheet, and modals in one 921-line component.
4. **[P1] One oversized playback context.** `AudioContext.tsx` combines transport, queue, recommendation fetching, Web Audio, media session, remote sync, party sync, persistence, and UI state in 1,197 lines.
5. **[P1] Duplicate React source trees.** `web`, `web-player`, and `website` contain matching source, so release behavior can diverge and fixes are multiplied.
6. **[P1] No error boundary.** A render error in a view, provider, or panel can take down the entire app without a recovery screen.
7. **[P1] No route-level loading boundary.** Views load synchronously as branches inside the shell, preventing isolated loading/error states and code splitting.
8. **[P1] App state is not URL-addressable.** A selected genre, station, playlist, support form, or player pane cannot be restored from a link.
9. **[P1] Modal state is not URL-addressable.** Scene, concert, wrapped, drive, and station overlays cannot be opened or recovered from browser history.
10. **[P2] Initial viewport is read during render.** `window.innerWidth` is used to initialize state in `App.tsx:34`, which is not safe if the app later adopts SSR, pre-rendering, or test rendering.
11. **[P1] Breakpoints disagree.** App, Home, and Now Playing use 768px while Auth uses about 960px and Library uses about 950px.
12. **[P1] Resize behavior is one-way.** Resizing to mobile closes the right panel, but resizing back to desktop does not restore a deliberate panel state or remember the user’s preference.
13. **[P1] Fixed shell dimensions compete with content.** A 240px sidebar, approximately 320px Now Playing panel, and 90px bottom player consume substantial 1280×720 space before content is shown.
14. **[P1] Main overflow is hidden globally.** `index.css:53-61` sets `html`, `body`, and `#root` to `overflow:hidden`; nested scrolling becomes responsible for keyboard focus and content visibility.
15. **[P1] Full-height layout ignores dynamic mobile viewport units.** `100vh` can place the bottom navigation/player under browser chrome and keyboard areas. 
16. **[P1] No safe-area support.** Bottom navigation and player controls do not reserve `env(safe-area-inset-bottom)` for phones with a home indicator.
17. **[P2] Splash duration is hard-coded.** `App.tsx:87` forces roughly 2.2 seconds before the user can reach the app, even if data and fonts are already ready.
18. **[P2] Splash is also an auth gate.** Guest prompting is coupled to the splash timeout rather than a first-run onboarding state machine.
19. **[P1] Full page reload is used as state management.** Auth and sign-out flows reload the browser instead of updating providers and route state, losing in-memory playback/UI state.
20. **[P2] Palette changes on every tab.** `App.tsx:51-76` changes global accent colors per screen, which makes the product feel like separate templates instead of one controlled brand system.
21. **[P2] Palette transitions can affect unrelated controls.** The same CSS variables drive player, sliders, focus states, and cards, so a tab switch can recolor controls unexpectedly.
22. **[P1] Theme provider is effectively locked.** `ThemeContext.tsx`/`StorageService.getTheme()` return only `normal`, so a “theme” abstraction exists without a usable preference model.
23. **[P2] No application-level state ownership map.** Likes, profile, queue, autoplay, volume, support status, and sync state are read from different sources rather than one typed store.
24. **[P1] Duplicate like state.** App, PlayerBar, mobile player, and storage independently derive `isLiked`, making cross-surface state drift possible.
25. **[P2] Custom events are the synchronization mechanism.** `library-update` is a string event with no typed payload, origin, version, or error semantics.

## B. Visual system, accessibility, and performance

26. **[P1] Global text selection is disabled.** `index.css:68` applies `user-select:none` to every element, including lyrics, errors, artist biographies, and search text.
27. **[P1] No visible focus system.** The CSS defines hover states but no robust `:focus-visible` treatment for keyboard users.
28. **[P1] Many interactive elements are generic divs.** Home search redirect, quick actions, genres, cards, stations, and library collections use `div onClick` instead of buttons/links.
29. **[P1] Icon-only controls lack accessible names.** Search, queue, like, close, shuffle, repeat, menu, and transport controls are not consistently labelled.
30. **[P1] Current navigation lacks semantic state.** Sidebar/bottom-nav items do not consistently expose `aria-current` or an equivalent selected state.
31. **[P1] Custom modals do not provide a reliable dialog contract.** Station, scene, concert, wrapped, drive, support, and auth surfaces need `role=dialog`, `aria-modal`, labelled titles, focus entry, Escape close, and focus return.
32. **[P1] No reduced-motion policy.** Aurora, shimmer, spin, hover lift, 3D tilt, sound waves, and 8D effects continue without `prefers-reduced-motion` handling.
33. **[P2] `transition:all` is broad.** It can animate expensive or unintended properties and makes motion behavior difficult to predict.
34. **[P2] Hover lift is over-applied.** `.liquid-glass-interactive:hover` translates and scales every interactive element, which can overlap neighboring content and feels noisy on a dense music UI.
35. **[P2] Glass styling has no fallback plan.** Heavy `backdrop-filter` use can lose contrast or visual hierarchy in browsers without support.
36. **[P2] Text contrast is inconsistent.** Secondary and tertiary colors use low alpha values (`0.6` and `0.35`) without a measured contrast budget.
37. **[P2] Typography is network-dependent.** `index.css:1` imports Google Fonts at runtime, adding a render dependency and a privacy/CSP concern.
38. **[P2] No type scale or spacing token source.** Most values are inline literals, so global visual correction requires touching many components.
39. **[P2] No component-level design system.** Repeated glass cards, buttons, labels, chips, and rows are manually restyled instead of composed from typed primitives.
40. **[P2] Scrollbar styling is browser-specific.** Only WebKit selectors are customized; Firefox and forced-colors behavior are not designed.
41. **[P2] No high-contrast/forced-colors support.** Borders, accent-only states, and translucent backgrounds can disappear for accessibility modes.
42. **[P2] No print or reduced-data behavior.** The app has no graceful output or low-bandwidth mode for metadata-heavy screens.
43. **[P2] Animated canvas is always mounted.** `AuroraBackground` can consume GPU/CPU even when the user is not on the splash screen.
44. **[P1] Loading visuals are not content-aware.** Empty API results and loading skeletons can look similar, so users cannot tell whether data is missing, still loading, or failed.
45. **[P2] Encoding corruption is visible in user copy.** Several labels and fallback keys contain mojibake such as `ðŸ‡®ðŸ‡³` and malformed emoji.

## C. Home and catalog experience

46. **[P1] Home fetches only once.** `Home.tsx:55-67` loads sections on mount and never refreshes them based on session, date, preferences, or explicit refresh.
47. **[P1] API failure leaves empty headings.** Home sets loading false after failure but does not render an error, retry, source status, or offline explanation.
48. **[P1] Runtime Home is empty on the primary path.** Decryption and direct fallback failures produced headings without song cards in the local audit.
49. **[P1] Home fallback source is JioSaavn.** `api.ts:77-140,174-202` does not implement the current YouTube-primary catalog direction.
50. **[P1] No source health signal.** Users cannot see whether results came from the proxy, a fallback node, stale cache, or no source.
51. **[P1] Search redirect is not a search field.** The Home “Songs, albums, artists” control only navigates to Search and does not preserve intent or typed text.
52. **[P1] Quick actions are not semantic controls.** `Home.tsx:302-334` uses click-only divs with no keyboard behavior, role, pressed state, or tooltip.
53. **[P1] Genre chips are click-only divs.** `Home.tsx:342-362` provides no loading state, selected state, keyboard handling, or accessible label.
54. **[P1] Genre fetches can race.** `handleOpenStation` has no AbortController or request identity, so rapid genre taps can show the wrong station.
55. **[P1] Quick actions have incomplete behavior.** Labs navigates, but Wrapped/Drive and similar actions can open a shell without meaningful data or completion state.
56. **[P2] Home hierarchy starts with controls, not content.** On mobile the first viewport is mostly action cards, chips, AI DJ, streak, and Labs before the music catalog.
57. **[P2] “Trending” is not explainable.** There is no timestamp, region, source, editorial reason, or personalized explanation for sections.
58. **[P2] Personalization is mostly a label.** Streak/profile state is shown, but section ranking is not visibly derived from listening history or preferences.
59. **[P1] No artist/album/playlist result modules on Home.** The product promise names songs, artists, and playlists, but the content model is largely song-card rows.
60. **[P2] No rich hero or editorial focal point.** Home has no primary listening moment, featured album, artist story, or adaptive hero state.
61. **[P2] No artwork fallback strategy.** Image cards rely on remote URLs without a robust `onError`, placeholder color, blur-up, or retry state.
62. **[P2] Generic card geometry is repeated.** Horizontal sections duplicate card markup instead of having a responsive collection component with consistent behavior.
63. **[P2] Cards have unclear action affordance.** Play, like, menu, queue, and open-details actions compete inside small cards without an intentional hierarchy.
64. **[P2] Horizontal shelves do not expose scroll affordances.** Desktop users get no arrow/drag hint, while keyboard users have no visible shelf focus model.
65. **[P2] Shelf rendering has no virtualization.** Large personalized sections can create many DOM nodes and images at once.
66. **[P2] Content padding is inconsistent.** Some Home sections use inline 24px padding, others use nested wrappers, creating alignment drift.
67. **[P2] Home uses an in-render component.** `SkeletonBlock` is declared inside the render path, creating a new component identity each render and triggering lint/static-component findings.
68. **[P2] Skeleton style contains a likely typo.** A skeleton block uses `padding: '0:24px'`, which is ignored by CSS and indicates visual QA gaps.
69. **[P2] Home event listener lifecycle is coupled to current song.** Streak/profile effects can re-register listeners whenever playback changes.
70. **[P2] First render can flash incomplete profile state.** Profile and streak values are loaded after mount rather than through a stable resource state.
71. **[P1] AI DJ has no observable state.** The toggle has no `aria-pressed`, fetching indicator, failure message, queue runway count, or “why this song” explanation.
72. **[P1] Endless queue is not a durable product contract.** The UI suggests autoplay but the queue engine only refills near the end and has no minimum runway guarantee.
73. **[P2] Streak logic is not meaningful listening.** A play event can count as a listen without a minimum duration or completion threshold.
74. **[P2] Home copy is not localized or source-correct.** “Trending Global Searches,” emojis, and fixed Hindi/Punjabi labels are hard-coded.
75. **[P2] Home content has no empty-state education.** A failed or new account sees blank shelves instead of a path to search, choose genres, import, or play a starter mix.

## D. Search, song rows, menus, and collection browsing

76. **[P1] Search has no cancellation.** `Search.tsx:23-39` lets old requests resolve after newer requests and overwrite current results.
77. **[P1] Search has no debounce or request queue.** Repeated Enter/quick-search interactions can create redundant calls.
78. **[P1] Search errors collapse into “No songs found.”** Network, decryption, API, and genuinely empty states are indistinguishable.
79. **[P1] Search does not clear stale results on a new request.** Users can see previous content while a new query is loading unless the request resolves.
80. **[P1] Search has no pagination or load-more contract.** It requests a fixed limit of 20 and cannot discover a deep catalog.
81. **[P2] Search has no result-type filters.** Songs, artists, albums, playlists, videos, and channels are not separated.
82. **[P2] Search has no sort/filter controls.** Language, duration, quality, source, recency, and explicit content are not available.
83. **[P2] Search query is not persisted in URL/history.** Refresh and back navigation lose the user’s search context.
84. **[P2] Search input has no explicit accessible label.** Placeholder text is used as the primary description.
85. **[P1] Search submit icon lacks a name.** The button combines two icons but exposes no reliable `aria-label` or tooltip.
86. **[P2] “Trending Global Searches” is static.** It does not reflect locale, season, user taste, or freshness.
87. **[P2] Search loading copy is misleading.** “Searching server mirrors…” does not describe the actual proxy/direct fallback state or expected wait.
88. **[P1] SongRow is a click-only div.** `SongRow.tsx` is not a keyboard-operable list item/button and does not expose play state to assistive technology.
89. **[P1] SongRow nests controls in a click target.** The row/menu interaction relies on propagation behavior instead of semantic composition.
90. **[P2] SongRow uses index-based keys.** `Search.tsx` uses `${song.id}-${index}`, which weakens React identity when results reorder.
91. **[P2] SongRow uses a third-party placeholder URL.** `https://via.placeholder.com/150` adds an unnecessary remote dependency for a failure path.
92. **[P2] SongRow has no image error fallback.** A broken artwork URL can leave a blank thumbnail.
93. **[P2] Unknown duration is collapsed to `--:--`.** There is no distinction between loading metadata, missing duration, and a zero-length media item.
94. **[P1] Song options menu mutates DOM styles.** It finds the closest row and writes `style.zIndex` imperatively instead of using a layer/portal system.
95. **[P1] Menu can be clipped.** Absolute positioning inside nested overflow containers is unsafe for the right/bottom edges of the viewport.
96. **[P1] Menu has no Escape/focus management.** Outside `mousedown` handling does not provide keyboard close, focus return, or screen-reader context.
97. **[P1] Menu trigger is not semantic.** The options trigger lacks `aria-haspopup`, `aria-expanded`, and an accessible name.
98. **[P2] Menu data is read on every render.** Playlists and recents are read directly from storage rather than delivered by reactive state.
99. **[P2] Menu has no create-playlist CTA.** “No playlists” is a dead end instead of guiding users to create one.
100. **[P2] Menu touch targets are small.** Several compact actions appear below a comfortable 44px target.

## E. Library, Labs, Settings, and Support screens

101. **[P1] Library is storage-first and cloud-state-blind.** It does not show whether local data is synced, stale, conflicted, or offline.
102. **[P2] Library reload effect is overly broad.** `Library.tsx:42` re-runs data loading around selection state and can create redundant render work.
103. **[P1] Library collections are click-only divs.** Liked Songs and playlist entries are not keyboard-selectable or announced as selected.
104. **[P1] Playlist deletion is immediate.** There is no confirmation, undo, toast, or recovery path.
105. **[P2] Playlist IDs use `Math.random()`.** Collision resistance and cross-device identity are not guaranteed.
106. **[P2] Playlist creation has no validation policy.** No duplicate-name handling, length limit, empty-name UX, or character normalization is defined.
107. **[P2] No playlist rename/reorder/description.** The collection model only covers create, delete, add, and remove.
108. **[P2] No playlist artwork/cover strategy.** Collections are visually generic rather than recognizable and emotionally useful.
109. **[P2] Empty library state is too passive.** “Select a collection to view files” does not teach new users how to like, create, import, or sync.
110. **[P1] Large libraries are not virtualized.** Liked songs and playlists can render unbounded rows.
111. **[P1] Spotify sync is modal/alert based.** Success and failure use browser alerts rather than accessible inline status and retry UI.
112. **[P1] Spotify URL validation is minimal.** Nonempty input is accepted without provider/playlist parsing before a network request.
113. **[P2] Sync has no progress or cancellation.** Large imports show only a spinner/text state.
114. **[P1] Web Audio controls lack associated labels.** Labs checkboxes and slider are visually described but not consistently labelled through semantic relationships.
115. **[P2] EQ values are not persisted.** Bass boost, vocal forward, 8D, autoplay, and timer choices reset after reload.
116. **[P2] EQ has no reset/default preset.** Users cannot quickly return to a neutral signal.
117. **[P1] Bass boost has no clipping warning or limiter.** Boosting a lowshelf can exceed safe headroom and distort.
118. **[P2] 8D uses a main-thread 35ms interval.** This can increase CPU/battery usage and is not synchronized to the audio clock.
119. **[P2] Labs gives no browser capability state.** Suspended AudioContext, unsupported Web Audio, and unavailable StereoPanner are not communicated.
120. **[P2] Sleep timer is interval-based.** It can drift when the tab is throttled or backgrounded.
121. **[P2] Sleep timer has no absolute end timestamp.** Reload/background recovery cannot calculate the correct remaining time.
122. **[P2] Focus timer has no custom durations.** Only fixed 25/5 minute behavior is available.
123. **[P2] Focus timer has no break notification/chime preference.** The screen changes state but does not provide a reliable user cue.
124. **[P1] Settings “clear cache” calls `localStorage.clear()`.** This deletes auth, likes, playlists, profile, support status, and PWA state—not just cache.
125. **[P1] Clear-cache copy is false.** It claims to delete cached settings/liked/custom data but cannot clear service-worker Cache Storage, IndexedDB, media blobs, or remote data.
126. **[P2] Settings metrics are not reactive.** Counts are derived during render, so changes elsewhere may not appear until a reload/event.
127. **[P2] Settings has no actual preference sections.** Quality, source, cache limits, language, notifications, privacy, shortcuts, theme, and playback settings are absent.
128. **[P1] Guest is presented as an account.** “Sign Out Account” appears for a locally generated guest identity without explaining data ownership or upgrade/sync behavior.
129. **[P2] No export/import library flow.** Users cannot back up likes/playlists before clearing or migrating devices.
130. **[P2] Version/build diagnostics are hard-coded.** `1.2.0-web`, target, and signature do not expose commit, API health, cache version, or browser capability.
131. **[P1] Support QR depends on a remote QR API.** The desktop pass displayed a blank white QR container when that dependency did not load.
132. **[P1] Support payment verification is client-submitted.** The browser writes directly to `payments_pending/{utr}` with no trusted server verification.
133. **[P0] Support screen includes a client-side bypass.** `Support.tsx:49-66` grants supporter state for email/UTR values containing `bypass` or equal to `777777`.
134. **[P0] Supporter entitlement trusts localStorage.** `StorageService.isSupporter()` reads a client-controlled boolean that can be edited in DevTools.
135. **[P1] UTR is used as a document ID.** Reusing a UTR overwrites the same record and enables collisions without idempotency/audit rules.
136. **[P1] Sensitive payment information is sent directly from the client.** Email, UTR, and UID are written through public-config REST clients without a server-side authorization boundary.
137. **[P2] Support form uses alerts.** Validation, failure, and payment launch feedback are not inline or screen-reader friendly.
138. **[P2] UPI launch navigates away.** `window.open(upiUri, '_self')` can replace the desktop app and has no copy/open-fallback flow.
139. **[P2] UTR field lacks input semantics.** It does not consistently use numeric input mode, pattern, normalization, or paste guidance.
140. **[P2] Support has no refund/privacy/verification policy.** The user is asked for financial identifiers without clear retention and review expectations.

## F. Authentication, identity, and data security

141. **[P0] Hard-coded OTP bypass.** `AuthModal.tsx:272` accepts `777777` for signup and password recovery.
142. **[P0] OTP is generated and verified in the client.** The server never proves that an email/phone challenge was completed.
143. **[P1] OTP has no expiry.** A code remains valid for the lifetime of the modal state.
144. **[P1] OTP has no attempt limit or rate limit.** Brute-force protection is absent.
145. **[P2] OTP input is fragmented without robust paste handling.** A six-digit paste does not reliably populate all fields.
146. **[P2] OTP input lacks numeric/autocomplete semantics.** Mobile keyboards and password managers cannot assist reliably.
147. **[P1] Forgot password does not reset a password.** `handleResetPasswordSubmit` only changes local UI text and never calls a Firebase password reset/update endpoint.
148. **[P1] Client stores identity as session.** UID, email, and display name are read from localStorage without token refresh, expiry, revocation, or observer state.
149. **[P1] Guest identity is weak.** Guest IDs use `Math.random()` and can be reset/duplicated when session data is cleared.
150. **[P1] Guest continuation deletes existing local user data.** `handleContinueAsGuest` calls `clearUserSession()` before creating a guest profile, without migration or confirmation.
151. **[P1] Sign-in clears local library before sync.** A successful login can delete anonymous likes/playlists before cloud merge is safely completed.
152. **[P1] Auth success is blocked by background services.** `Promise.all` waits for RottyConnect, Firestore write, and library sync before completing a valid sign-in.
153. **[P2] Auth success reloads the whole page.** This adds latency and can interrupt playback or other unsaved state.
154. **[P2] Phone field is collected without clear validation/consent.** The data model stores it but the UI does not explain use or format requirements.
155. **[P1] Auth modal plays ambient audio on first document gesture.** This is surprising, can conflict with user expectations, and needs opt-in/reduced-motion handling.
156. **[P2] Auth 3D tilt updates React state on every mouse move.** This can cause high-frequency renders and jank on lower-end hardware.
157. **[P1] Auth modal lacks a robust focus trap.** Background navigation can remain reachable while the modal is open.
158. **[P1] Auth error handling exposes provider text.** Raw `err.message` can leak implementation/provider details and is not mapped to actionable user copy.
159. **[P2] Form fields rely heavily on placeholders.** Labels, autocomplete names, and password-manager semantics are incomplete.
160. **[P2] `any` types are concentrated in auth/prompt logic.** This reduces compiler protection exactly where identity and asynchronous errors are high risk.

## G. Playback, queue, network, cache, and sync reliability

161. **[P0] Media is forced through `crossOrigin='anonymous'`.** Any source without compatible CORS headers can fail or become unusable through Web Audio.
162. **[P1] Audio element has no complete buffering lifecycle.** It listens to `timeupdate`, `durationchange`, `ended`, and `error`, but not `waiting`, `stalled`, `canplay`, `playing`, `progress`, `seeking`, or `seeked`.
163. **[P1] Buffering is not visible to users.** The player cannot distinguish loading, stalled, paused, blocked, and failed states.
164. **[P1] Async song resolution is not cancellable.** A late `resolveSong` result can start a previous selection after the user has already chosen another song.
165. **[P1] Playback requests have no identity/token.** `playSong` can race with next/previous, queue edits, recommendation refill, and remote commands.
166. **[P1] URL freshness is not checked.** `resolveSong` only resolves missing URLs, not expired or invalid cached URLs.
167. **[P1] Error recovery silently skips tracks.** After retry behavior, the player can call `nextSong()` without a user-visible reason, retry control, or diagnostic.
168. **[P1] Retry state is keyed but not bounded by a user policy.** `retryCountRef` can keep historical entries and lacks reset/expiry semantics.
169. **[P1] Autoplay refill has duplicate implementations.** `handleAutoplayRefill` and `triggerAiRefill` can diverge and run concurrently.
170. **[P1] Autoplay refill has no lock.** End-of-song, near-end prefetch, and manual refill can issue overlapping recommendation requests.
171. **[P1] Autoplay prefetch only checks the last queue item.** It does not guarantee a next playable item when the queue is shortened or reordered.
172. **[P2] Recommendation fallback is JioSaavn-based.** It conflicts with the intended YouTube-primary playback/catalog architecture.
173. **[P2] Recommendation results are not playable-item validated.** A response can enter the queue without a confirmed media URL/source capability.
174. **[P1] Queue duplicate prevention is too aggressive.** Fingerprint/id checks prevent intentional repeats and playlist semantics.
175. **[P1] Removing the current track clears `src` without a full media reset.** Current time, duration, loading state, and audio graph can remain stale.
176. **[P1] Shuffle/index bookkeeping is fragile.** `originalQueueRef` and mutable queue indices can disagree after moving/removing items.
177. **[P2] Shuffle/loop preferences are not persisted.** Reload resets listening behavior.
178. **[P2] Mute restores a hard-coded volume.** It does not remember the user’s previous volume value.
179. **[P1] Volume is not validated at storage boundaries.** NaN, negative, or >1 values can enter localStorage and the audio element.
180. **[P2] AudioContext is not explicitly closed.** Provider cleanup pauses media but does not close the Web Audio context.
181. **[P2] 8D timer is not audio-clock driven.** Main-thread `setInterval` panning can jitter under load.
182. **[P1] Media Session handlers are recreated around mutable closures.** Remote/system controls can call stale `togglePlay`, queue, or seek behavior.
183. **[P2] Media Session position state is absent.** OS lock-screen/keyboard UIs cannot show accurate seek position and duration.
184. **[P1] Remote sync repeatedly disposes/restarts connections.** The effect around `currentSong/isPlaying` can tear down RottyConnect on normal playback changes.
185. **[P1] Remote commands use polling and delete records.** Multiple devices can race to consume commands, with no acknowledgement, ordering, or idempotency.
186. **[P1] Party sync polls room and members repeatedly.** Two network reads every few seconds do not scale and waste battery.
187. **[P1] Party playback lacks drift correction.** Remote position is not reliably applied to local media, so members can desynchronize.
188. **[P1] Direct network calls lack a shared abort/timeout/retry policy.** Firebase, Supabase, Spotify sync, and party flows implement inconsistent error handling.
189. **[P1] Local storage writes are not quota-safe.** `setItem` calls are mostly uncaught, so a full quota can break likes/playlists/history.
190. **[P1] No real media cache exists.** The service worker explicitly skips remote media, APIs, and large streams; audio/video prefetch/cache requirements are therefore not implemented.

## H. API, persistence, PWA, and engineering quality

191. **[P0] Client-side AES key is not secret.** `api.ts:49` includes a fallback key in shipped JavaScript; any browser user can inspect and reproduce the decrypt operation.
192. **[P1] AES-CBC has no authenticated integrity.** The payload design does not provide an authentication tag, so tampering is not detected.
193. **[P1] Decryption failures are only logged.** The API layer returns empty data after errors instead of a typed failure with retry/backoff/source detail.
194. **[P1] Fixed 3.5–4 second timeouts are too rigid.** Cold starts, mobile networks, and large playlist sync need endpoint-specific budgets and retries.
195. **[P1] JSON responses are not runtime-validated.** `JSON.parse` results are cast/used without a schema, so malformed payloads can crash UI logic.
196. **[P1] API mapping uses `any`.** JioSaavn/proxy/server payload shape changes are invisible to TypeScript.
197. **[P1] Lyrics errors are swallowed.** A provider outage is displayed as “lyrics not found,” making support diagnosis impossible.
198. **[P2] Lyrics are plain text at the API boundary.** No synced-line schema, timestamp validation, language detection, or attribution contract exists.
199. **[P1] Firebase REST requests do not show a trusted auth boundary.** API keys and direct client REST calls are not a substitute for an ID-token/RLS-backed authorization policy.
200. **[P1] Supabase party operations accept client identity values.** Server-side authorization, host checks, and room ownership are not established in the React code.
201. **[P1] Sync merge policy is implicit.** Local/cloud conflicts are merged without versions, timestamps per record, tombstones, or user-visible conflict resolution.
202. **[P2] Sync is sequential.** Playlists are processed one by one, increasing onboarding time as the library grows.
203. **[P2] Sync has no cancellation or progress model.** Closing the modal does not clearly stop network work.
204. **[P1] Storage has no schema version/migration.** Future fields and old objects can silently fail or reset to empty arrays.
205. **[P2] Stored songs retain unnecessary metadata.** Likes/history strip URLs but can still grow large with repeated full objects.
206. **[P2] Streak dates use UTC.** `toISOString()` can mark a listen on the adjacent day for users near midnight in local time.
207. **[P2] Recent history has no listening-duration signal.** It records a song as soon as it is selected, not after meaningful listening.
208. **[P1] Service worker cache version is static and minimal.** `sw.js` caches only the shell, does not precache hashed JS/CSS, and provides no offline app-data strategy.
209. **[P2] Service worker silently swallows cache failures.** Users receive no offline/degraded-mode indicator.
210. **[P2] PWA manifest forces portrait orientation.** A desktop/tablet music player should not lock the installed experience to portrait.
211. **[P2] Manifest/content contains encoding corruption.** The description has mojibake, which leaks into install metadata.
212. **[P2] PWA install prompt uses browser alerts.** `PwaInstallPrompt.tsx:77` gives generic instructions without platform-specific accessible UI.
213. **[P2] `npm` quality checks are not release gates.** The app can build while lint and dependency audit fail.
214. **[P2] Vite middleware is type-unsafe.** `vite.config.ts` contains many `any` values for request/response/payload transforms.
215. **[P2] Dev-server middleware is doing production-data work.** Catalog sanitization, detail resolution, lyrics, recommendations, and Spotify sync are mixed into Vite configuration.
216. **[P1] Backend boundaries differ by environment.** Local Vite middleware and remote API behavior are not represented by one versioned service contract.
217. **[P2] No automated UI regression suite.** The glass shell, responsive breakpoints, modal focus, player state, and empty/error states have no screenshot or interaction assertions.
218. **[P2] No player reliability metrics.** There is no time-to-first-audio, rebuffer rate, source failure, retry, queue refill, or lyrics success telemetry.
219. **[P2] No test fixtures for bad media/API data.** The runtime failure path was only discovered manually.
220. **[P2] No release artifact provenance.** The web build does not expose commit/version/API contract used to generate a shipped artifact.

# 120 actionable improvements

## Product architecture and design system

1. Create a typed route registry with URL paths for Home, Search, Library, Labs, Settings, Support, artist, album, playlist, and player subviews.
2. Replace integer tabs with a route object containing `id`, `path`, `label`, `icon`, `requiresAuth`, and `accentToken`.
3. Split `App.tsx` into `AppShell`, `AppBootstrap`, `AuthGate`, `PlayerDock`, `MobilePlayerSheet`, and route-level layouts.
4. Split `AudioContext` into `PlaybackStore`, `QueueEngine`, `MediaEngine`, `EffectsEngine`, `RecommendationsClient`, `LyricsClient`, and `RemoteSyncClient`.
5. Keep one canonical React package and make `web-player`/`website` consume it or remove duplicate source trees.
6. Add an error boundary per shell, route, player, and modal layer with retry and diagnostic copy.
7. Add route-level lazy loading and Suspense fallbacks so Search/Library/Labs do not ship or render everything at once.
8. Introduce a design token file for color, spacing, typography, radius, elevation, motion, and breakpoints.
9. Build typed primitives: `Button`, `IconButton`, `Chip`, `Surface`, `SectionHeader`, `Artwork`, `SongRow`, `MediaCard`, `Dialog`, `Toast`, `Skeleton`, and `EmptyState`.
10. Use CSS modules or a consistent utility layer for layout; reserve inline styles for calculated values only.
11. Use one responsive breakpoint map shared by shell, library, auth, player, and modal layouts.
12. Replace `100vh` with `100dvh` plus a safe-area strategy and test browser chrome/keyboard states.
13. Add `padding-bottom: env(safe-area-inset-bottom)` to bottom navigation and mobile player surfaces.
14. Use a three-zone desktop shell that can collapse the right panel without permanently shrinking the main content.
15. Make the Now Playing panel a user-controlled dock with compact, expanded, and hidden modes persisted per viewport.
16. Replace tab-specific accent changes with one brand accent plus contextual semantic colors used sparingly.
17. Add keyboard focus rings, pressed/selected states, `aria-current`, and visible skip-to-content behavior.
18. Add `prefers-reduced-motion`, `prefers-contrast`, forced-colors, and low-data media policies.
19. Bundle or self-host the chosen fonts with a fallback metric strategy; remove render-blocking external font import.
20. Add visual tokens and lint rules for forbidden magic spacing, excessive shadow, and uncontrolled `transition: all`.

## Home, discovery, search, and catalog

21. Make Home a server-backed personalized feed with section IDs, ranking reason, source, freshness, and cache timestamp.
22. Add a clear top-level “Resume listening” hero based on last meaningful playback, not just the last selected song.
23. Add sections for Continue Listening, Made for You, New Releases, Your Mixes, Genres, Artists, Albums, and community/editorial picks.
24. Render song, artist, album, playlist, and video cards through one responsive collection component.
25. Add content density modes: comfortable, compact, and touch-friendly.
26. Make Home search a real input that opens Search with the current text, selection, and route history.
27. Convert quick actions and genre chips to buttons with labels, keyboard operation, pressed state, loading state, and analytics events.
28. Add a genre/station route with a hero, description, mood palette, top tracks, new tracks, artists, and related genres.
29. Add explicit station request cancellation and a request ID so stale genre responses cannot replace the current station.
30. Add pull-to-refresh/refresh action with “updated just now” and stale-cache messaging.
31. Add skeletons shaped like the final cards; add separate offline, empty, and retry states.
32. Use stale-while-revalidate: render cached content immediately, refresh in background, and retain the last good content on failure.
33. Add image CDN transformation, lazy loading, blur-up placeholders, dominant color, and a deterministic local fallback.
34. Add shelf scroll arrows on desktop and keyboard focus management for horizontal rails.
35. Use virtualization or windowing for long feeds and limit eager image loading to the first viewport.
36. Make all content section headers explain their ranking (“Because you played…”, “Fresh today”, “From your Punjabi mix”).
37. Add user controls to hide, reorder, or mute Home sections.
38. Add a first-run taste picker that seeds Home genres, languages, artists, and mood preferences.
39. Add a proper artist page with hero image, verified identity, biography, top tracks, albums, playlists, related artists, and follow action.
40. Add album and playlist pages with artwork, metadata, play/shuffle, queue actions, track list, and source/availability messaging.

## Search and content interaction

41. Debounce typeahead requests and cancel stale requests with AbortController.
42. Keep query, filter, sort, and page cursor in the URL.
43. Add search tabs for All, Songs, Artists, Albums, Playlists, Videos, and Channels.
44. Add filters for language, duration, source, quality, explicit content, and upload recency where the backend supports them.
45. Keep distinct states for idle, loading, cached, empty, no-network, unauthorized, provider failure, and rate-limited.
46. Add pagination or cursor-based infinite loading with a stable key based only on provider ID.
47. Add recent searches with edit/delete/clear controls stored through the versioned storage layer.
48. Make trending queries region-aware and refresh them from the backend; label the update time.
49. Make `SongRow` a semantic list item with a primary play button and separate action buttons.
50. Add explicit “playing,” “queued,” “liked,” “unavailable,” and “video available” states to each row.
51. Add a menu portal anchored to the trigger, with Escape close, focus return, collision detection, and touch-safe sizing.
52. Add “Create playlist” directly inside the song menu and show a success toast with undo.
53. Add drag-and-drop/keyboard reorder only where it has a clear playlist/queue purpose, with announcements.
54. Add bulk selection for library/search results with batch like, add-to-playlist, queue, and download/cache actions.
55. Add a quick preview waveform/metadata hover only on pointer devices; keep touch controls simple.

## Full player, lyrics, video, queue, and motion

56. Model playback as an explicit reducer/state machine: idle, resolving, loading, playing, paused, buffering, seeking, ended, failed, retrying.
57. Give every play request a monotonically increasing request ID and ignore late resolutions for obsolete requests.
58. Add one `MediaController` that owns the audio element, event wiring, cancellation, source changes, and cleanup.
59. Listen for `loadstart`, `loadedmetadata`, `canplay`, `playing`, `waiting`, `stalled`, `progress`, `seeking`, `seeked`, `pause`, `ended`, `error`, and `emptied`.
60. Display buffered range, current network state, retry action, and source fallback status in the player.
61. Resolve YouTube-primary playback through a server-side, policy-compliant resolver and return a short-lived playback asset contract.
62. Separate audio and video assets so audio can start first while video buffers independently.
63. Use one shared clock for audio, video, lyrics, and progress UI; do not let each pane maintain independent timing.
64. Keep the video element mounted when opening full player so the video does not reload; only change layout/presentation mode.
65. Add muted autoplay policy handling: begin audio/video with the browser-allowed mode and provide a clear unmute action.
66. Add a custom video surface with play/pause, seek, volume, captions/lyrics, quality, PiP, and fullscreen controls only where needed.
67. Keep full-screen controls consistent with the app; do not expose native controls if the requirement is a custom player.
68. Add `requestVideoFrameCallback` or a throttled shared clock for video/lyrics sync instead of unrelated timers.
69. Add synced lyrics parsing with line timestamps, active-line scroll, word-level support when supplied, and a plain-text fallback.
70. Make the lyrics pane readable: large active line, dim context lines, stable center lock, manual scroll override, attribution, and retry.
71. Make queue a dedicated pane with “Up next,” current item, source, reorder, remove, clear, shuffle, repeat, and endless-queue runway.
72. Add queue persistence and recovery on reload, including current index and position with privacy controls.
73. Add a queue refill lock, minimum runway threshold, request cancellation, duplicate policy, and reason metadata.
74. Preflight the next track’s metadata/playback URL and retain the current track if prefetch fails.
75. Replace 35ms 8D intervals with `AudioParam` automation or an audio-clock scheduler, and stop it under reduced motion/background mode.

## Playback data, caching, and performance

76. Replace client AES secrets with server-side authentication, signed short-lived payloads, or ordinary TLS JSON responses with schema validation.
77. Use an authenticated encryption scheme server-side if encrypted payloads are genuinely required; do not ship a reusable secret in JS.
78. Add Zod/Valibot runtime schemas for songs, sections, lyrics, queue items, playlists, auth responses, and sync records.
79. Create a typed `ApiClient` with base URL, endpoint timeout, AbortController, retry policy, backoff, request ID, and normalized errors.
80. Add an in-memory request cache plus IndexedDB for catalog metadata, artwork metadata, lyrics, and short-lived playback manifests.
81. Design a bounded media cache with byte/age limits, LRU eviction, cache groups, and a “clear downloaded media” control.
82. Cache the current track and next track metadata/asset manifest, but never silently cache unbounded full video.
83. Add a connection-quality policy: audio-first on weak networks, video deferred, lower artwork quality, and offline banner.
84. Add a stale-cache fallback that clearly labels cached data and keeps the last known Home sections visible.
85. Persist volume, shuffle, loop, EQ, autoplay, and player layout through one versioned preference store.
86. Clamp volume and EQ values at read and write boundaries; preserve the pre-mute volume.
87. Use local calendar dates for streaks, and count a listen only after a configurable meaningful-play threshold.
88. Wrap storage writes in quota/error handling and surface a recoverable “storage full” action.
89. Move large playlist/library payloads to IndexedDB; keep localStorage for small preferences only.
90. Add cross-tab synchronization through `BroadcastChannel` with versioned events and conflict rules.

## Auth, entitlement, cloud, and party safety

91. Remove all development bypasses from production builds and enforce this with a CI grep/security test.
92. Move OTP creation, delivery, expiry, attempt limits, and verification to a trusted backend/provider.
93. Use Firebase Auth SDK or a properly tokenized auth service; store/refresh tokens through the provider, not a handcrafted UID localStorage session.
94. Implement actual password reset with provider email/OOB flow; never claim success before the provider confirms it.
95. Add account/session states: anonymous, guest, authenticated, expired, offline, sync-pending, and signed-out.
96. Merge anonymous library into a new account transactionally, with a preview and conflict policy before deleting anything.
97. Separate account sign-out, guest reset, local cache clear, and delete-my-data operations.
98. Gate supporter entitlements on a server-verified payment record and signed entitlement response.
99. Use a server endpoint for payment submission; validate UTR/email server-side, deduplicate, rate-limit, audit, and redact logs.
100. Use opaque payment submission IDs instead of raw UTR as the document key.
101. Add privacy/retention/refund copy and a deletion/export workflow for email, phone, UTR, and cloud library data.
102. Put Supabase RLS/Firestore authorization rules in the backend contract and test host/member/kick permissions.
103. Replace polling party sync with realtime channels where available, otherwise add ETags/cursors/acks and exponential backoff.
104. Add host leave/room expiry cleanup, presence heartbeat, command sequence numbers, and idempotent command handling.
105. Add party drift correction using authoritative position timestamps and a tolerance threshold.

## Testing, accessibility, observability, and release quality

106. Add unit tests for queue reducer, playback request cancellation, cache eviction, storage migrations, streak dates, and sync merge.
107. Add integration tests for guest onboarding, sign-in, OTP failure/expiry, password reset, playlist creation/deletion/undo, and support submission.
108. Add browser tests for Home/Search/Library/Labs/Settings/Support at desktop, tablet, mobile, keyboard-only, reduced-motion, and offline states.
109. Add screenshot regression tests for shell, full player, lyrics, queue, artist, playlist, error, empty, and modal states.
110. Add accessibility checks with axe plus manual keyboard, focus-return, screen-reader, zoom, high-contrast, and reduced-motion passes.
111. Make lint, typecheck, test, build, dependency audit, and bundle-size budgets required CI checks.
112. Fix the 109 lint findings instead of suppressing them; ban new `any` in app/services with ESLint.
113. Upgrade/fix the four high-severity development advisories and pin a known-good lockfile.
114. Add synthetic playback probes against each provider/source and report time-to-first-audio, error rate, rebuffer rate, and fallback rate.
115. Add structured client errors with endpoint, source, request ID, media ID, browser capability, and redacted reason.
116. Add user-visible diagnostic export from Settings that excludes secrets and payment identifiers.
117. Add feature flags for YouTube source, video, lyrics, endless queue, cloud sync, party, and Labs so degraded providers fail closed.
118. Version API contracts and keep Vite dev middleware out of the product runtime; use a small typed backend service.
119. Publish build commit, app version, API contract, service-worker version, and migration version in the About/diagnostics surface.
120. Do a final production acceptance pass: every screen must have loading, empty, error, offline, success, retry, focus, reduced-motion, and narrow-width states before calling the redesign complete.

# Recommended implementation order

## Phase 0 — Safety and evidence

Remove OTP/support bypasses from all distributable builds, stop `localStorage.clear()`, protect payment/auth endpoints, add error boundaries, and capture playback/API telemetry. This phase is mandatory before visual polish.

## Phase 1 — Playback foundation

Build the reducer/state machine, cancellable media controller, source-aware resolver, buffering UI, audio-first/video-second pipeline, shared audio/video/lyrics clock, and queue refill lock. The acceptance test is 50 consecutive track transitions with no unexplained stop, stale-track start, or position drift.

## Phase 2 — Data and caching

Replace the client encryption secret, add typed API schemas, request cache, IndexedDB metadata/media-manifest cache, bounded eviction, offline mode, and YouTube-primary source contract.

## Phase 3 — Product architecture

Introduce real routes, feature modules, canonical shared source, typed state ownership, and route-level error/loading boundaries. Remove magic tab indexes and reload-based state transitions.

## Phase 4 — Design system and responsive shell

Implement the token system and primitives, then rebuild the desktop shell, mobile shell, Now Playing dock, player bar, dialogs, and navigation with safe-area/focus/reduced-motion support.

## Phase 5 — Screen-by-screen redesign

Rebuild Home, Search, Library, Genre, Artist, Album, Playlist, Labs, Settings, Support, Auth, Full Player, Lyrics, Queue, and Connect using the same content model and state patterns. Each page must be tested with real data and all empty/error/offline states.

## Phase 6 — Quality gate and release

Run unit/integration/browser/accessibility/visual tests, fix lint/audit findings, validate PWA/offline behavior, measure performance, test providers and browsers, and publish a versioned artifact with rollback capability.

# Definition of done for the redesign

- Every screen is reachable by URL and survives refresh/back navigation.
- No auth, entitlement, or payment decision is trusted from browser-controlled storage.
- YouTube-primary audio starts quickly; video can be opened without restarting/reloading the audio.
- Queue, lyrics, player, and video share one clock and remain synchronized after seek, pause, resume, and next.
- Current and next-track metadata are cached with a bounded eviction policy; cache status is visible.
- Every interactive element works with keyboard, has a name/state, and returns focus correctly from dialogs/menus.
- Every async surface has loading, empty, failure, retry, offline, and success states.
- `npm run lint`, typecheck, tests, build, and dependency audit pass in CI.
- Desktop, tablet, mobile, reduced-motion, high-contrast, and low-bandwidth checks pass.
- No duplicate React source tree remains without an explicit package boundary.
