# Drift database on web – required files

To run the app in Chrome (or any web browser), **two files must be present** in this `web/` directory. Without them, the app will request `.wasm` / worker scripts and get **HTML** (e.g. a 404 page), which causes:

```text
WebAssembly.instantiateStreaming(): expected magic word 00 61 73 6d, found 3c 21 44 4f
```

(`3c 21 44 4f` = `<!DO` = start of `<!DOCTYPE html>` → the server returned a page instead of the WASM binary.)

---

## 1. sqlite3.wasm

SQLite compiled to WebAssembly.

- **Source:** [simolus3/sqlite3.dart – Releases](https://github.com/simolus3/sqlite3.dart/releases)
- **Match:** Use a build that matches the `sqlite3` version in `pubspec.lock` (e.g. **2.9.x**).
- **File:** Download `sqlite3.wasm` (or the file from a “web” / “wasm” asset in the release) and place it as:
  - **`web/sqlite3.wasm`**

---

## 2. drift_worker.dart.js

Drift web worker script.

- **Source:** [simolus3/drift – Releases](https://github.com/simolus3/drift/releases)
- **Match:** Use a build that matches the `drift` version in `pubspec.lock` (e.g. **2.31.x**).
- **File:** Download `drift_worker.dart.js` from the release assets and place it as:
  - **`web/drift_worker.dart.js`**

---

## Checklist

- [ ] `web/sqlite3.wasm` exists  
- [ ] `web/drift_worker.dart.js` exists  

Then run: `flutter run -d chrome` (or your usual web run). The dev server will serve both files; the service worker in `wasm_mime_sw.js` ensures `.wasm` is served with MIME type `application/wasm`.
