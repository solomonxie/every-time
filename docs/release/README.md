# App Store Release

Bundle ID `com.example.everytime` · iOS 18.0+ · iPhone only, portrait · widget.

- [`listing.md`](listing.md) — step-by-step plan and every App Store Connect field, ready to paste
- [`privacy-policy.md`](privacy-policy.md) — the policy; its GitHub URL is the Privacy Policy URL
- `screenshots/` — upload-ready iPhone sets (8 Demo-mode simulator shots, 2026-10-02), from `make screenshots SHOTS=<dir>`; retake steps in `listing.md` → Screenshots.

Upload a build: `make release` (archives app + widget with automatic signing → App Store Connect; build number = timestamp).

Versioning: `MARKETING_VERSION` in `project.yml` (project-level, shared by all targets) is the user-visible version; bump it per release.

Store region: release builds use `STORE=us`. One binary serves every storefront; `cn` is an install-time flag only.
