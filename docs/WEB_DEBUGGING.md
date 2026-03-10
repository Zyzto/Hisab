# Flutter web debugging and Dart Debug Chrome extension

When developing or debugging the Flutter web app locally, you get clearer console output, breakpoints, and Dart DevTools if Chrome has the **Dart Debug Extension** installed.

## Install the extension

1. Open Chrome and go to the [Dart Debug Extension](https://chromewebstore.google.com/detail/dart-debug-extension/eljbmlghnomdjgdjmbdekegdkbabckhm) in the Chrome Web Store.
2. Click **Add to Chrome** and confirm.

The extension is maintained by the Dart team (Google) and is used to connect Chrome to the Dart VM for debugging and DevTools.

## When it helps

- **`flutter run -d web-server`** — You open the served URL (e.g. `http://localhost:xxxxx`) in Chrome yourself. With the extension installed, you get:
  - Meaningful Dart stack traces and logs in the console instead of minified JS.
  - The option to open Dart DevTools (e.g. via the Dart icon in the browser toolbar).
  - Better breakpoint and source mapping when debugging.
- **`flutter run -d chrome`** — Flutter launches Chrome; if that Chrome profile has the extension, the same benefits apply when you open DevTools or the console.

## Optional: Chrome flag for background timers

For more reliable behavior with the debug extension, you can disable **Throttle expensive background timers** in Chrome:

1. Open `chrome://flags` in Chrome.
2. Search for “throttle expensive background timers”.
3. Set it to **Disabled** and restart Chrome.

## Integration tests (`flutter drive`)

Integration tests run with `flutter drive -d web-server --release`. In **release** mode there is no Dart debug service, so the extension does not change test output. The extension is for **interactive** web debugging (run, hot reload, DevTools), not for the automated drive runs.

## References

- [Debugging Dart web apps](https://dart.dev/web/debugging) (dart.dev)
- [Flutter web debugging](https://docs.flutter.dev/platform-integration/web/debugging) (docs.flutter.dev)
