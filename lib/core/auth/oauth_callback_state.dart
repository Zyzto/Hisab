/// Set when a web OAuth return (`?code=` / error) fails to establish a session.
/// Consumed once by [App] to show a user-visible toast.
String? pendingWebOAuthCallbackError;
