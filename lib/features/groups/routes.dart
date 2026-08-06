import 'package:go_router/go_router.dart';
import '../../core/navigation/app_page.dart';
import '../../core/navigation/route_paths.dart';
import 'pages/group_analytics_page.dart';
import 'pages/group_categories_page.dart';
import 'pages/group_create_page.dart';
import 'pages/group_detail_page.dart';
import 'pages/group_settings_page.dart';
import 'pages/invite_accept_page.dart';
import 'pages/invite_group_preview_page.dart';
import 'pages/invite_management_page.dart';
import 'pages/invite_redirect_proxy_page.dart';
import 'pages/invite_scan_page.dart';

List<RouteBase> getGroupRoutes() {
  return [
    GoRoute(
      path: '/invite',
      redirect: (context, state) {
        final token = state.uri.queryParameters['token']?.trim() ?? '';
        if (token.isNotEmpty) {
          return RoutePaths.inviteAccept(token);
        }
        return null;
      },
      pageBuilder: (context, state) {
        final token =
            state.pathParameters['token'] ??
            state.uri.queryParameters['token'] ??
            '';
        return appFadeSlidePage(
          key: state.pageKey,
          child: InviteAcceptPage(token: token),
        );
      },
    ),
    GoRoute(
      path: '/invite/:token/preview/expenses/:eid',
      pageBuilder: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        final expenseId = state.pathParameters['eid'] ?? '';
        return appNoTransitionPage(
          key: state.pageKey,
          child: InvitePreviewExpenseDetailPage(
            token: token,
            expenseId: expenseId,
          ),
        );
      },
    ),
    GoRoute(
      path: '/invite/:token/preview',
      redirect: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        if (token.isEmpty) return RoutePaths.home;
        return RoutePaths.invitePreviewExpenses(token);
      },
    ),
    GoRoute(
      path: '/invite/:token/preview/expenses',
      pageBuilder: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        return appFadeSlidePage(
          key: state.pageKey,
          child: InviteGroupPreviewPage(
            token: token,
            initialTab: GroupDetailTab.expenses,
          ),
        );
      },
    ),
    GoRoute(
      path: '/invite/:token/preview/balance',
      pageBuilder: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        return appFadeSlidePage(
          key: state.pageKey,
          child: InviteGroupPreviewPage(
            token: token,
            initialTab: GroupDetailTab.balance,
          ),
        );
      },
    ),
    GoRoute(
      path: '/invite/:token/preview/people',
      pageBuilder: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        return appFadeSlidePage(
          key: state.pageKey,
          child: InviteGroupPreviewPage(
            token: token,
            initialTab: GroupDetailTab.people,
          ),
        );
      },
    ),
    GoRoute(
      path: '/invite/:token',
      pageBuilder: (context, state) {
        final token = state.pathParameters['token'] ?? '';
        return appFadeSlidePage(
          key: state.pageKey,
          child: InviteAcceptPage(token: token),
        );
      },
    ),
    GoRoute(
      path: RoutePaths.scanInvite,
      pageBuilder: (context, state) =>
          appFadeSlidePage(key: state.pageKey, child: const InviteScanPage()),
    ),
    // Custom-domain invite link: hisab.shenepoy.com/functions/v1/invite-redirect?token=...
    // Redirects to Supabase Edge Function so token is validated and user sent to redirect.html.
    GoRoute(
      path: '/functions/v1/invite-redirect',
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: InviteRedirectProxyPage(uri: state.uri),
      ),
    ),
    // One shell per wizard so PageView state is not disposed on step changes.
    GoRoute(
      path: RoutePaths.groupCreate,
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: const GroupCreatePage(isPersonal: false),
      ),
    ),
    GoRoute(
      path: RoutePaths.groupCreatePersonal,
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: const GroupCreatePage(isPersonal: true),
      ),
    ),
    // Per-step URLs for bookmarks / reload. In-wizard step changes still use
    // decorative hash sync on the canonical route so PageView state is not
    // disposed; these builders only matter on cold start / F5.
    GoRoute(
      path: RoutePaths.groupCreateDetails,
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: const GroupCreatePage(isPersonal: false, initialStep: 0),
      ),
    ),
    GoRoute(
      path: RoutePaths.groupCreateParticipants,
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: const GroupCreatePage(isPersonal: false, initialStep: 1),
      ),
    ),
    GoRoute(
      path: RoutePaths.groupCreateStyle,
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: const GroupCreatePage(isPersonal: false, initialStep: 2),
      ),
    ),
    GoRoute(
      path: RoutePaths.groupCreateReview,
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: const GroupCreatePage(isPersonal: false, initialStep: 3),
      ),
    ),
    GoRoute(
      path: RoutePaths.groupCreatePersonalDetails,
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: const GroupCreatePage(isPersonal: true, initialStep: 0),
      ),
    ),
    GoRoute(
      path: RoutePaths.groupCreatePersonalStyle,
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: const GroupCreatePage(isPersonal: true, initialStep: 1),
      ),
    ),
    GoRoute(
      path: RoutePaths.groupCreatePersonalReview,
      pageBuilder: (context, state) => appFadeSlidePage(
        key: state.pageKey,
        child: const GroupCreatePage(isPersonal: true, initialStep: 2),
      ),
    ),
    GoRoute(
      path: '/groups/:id',
      redirect: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        if (id.isEmpty) return RoutePaths.home;
        return RoutePaths.groupExpenses(id);
      },
    ),
    GoRoute(
      path: '/groups/:id/people',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return appFadeSlidePage(
          key: state.pageKey,
          child: GroupDetailPage(
            groupId: id,
            initialTab: GroupDetailTab.people,
          ),
        );
      },
    ),
    GoRoute(
      path: '/groups/:id/settings',
      pageBuilder: (context, state) {
        final groupId = state.pathParameters['id'] ?? '';
        return appFadeSlidePage(
          key: state.pageKey,
          child: GroupSettingsPage(groupId: groupId),
        );
      },
    ),
    GoRoute(
      path: '/groups/:id/analytics',
      pageBuilder: (context, state) {
        final groupId = state.pathParameters['id'] ?? '';
        return appFadeSlidePage(
          key: state.pageKey,
          child: GroupAnalyticsPage(groupId: groupId),
        );
      },
    ),
    GoRoute(
      path: '/groups/:id/invites',
      pageBuilder: (context, state) {
        final groupId = state.pathParameters['id'] ?? '';
        return appFadeSlidePage(
          key: state.pageKey,
          child: InviteManagementPage(groupId: groupId),
        );
      },
    ),
    GoRoute(
      path: '/groups/:id/categories',
      pageBuilder: (context, state) {
        final groupId = state.pathParameters['id'] ?? '';
        return appFadeSlidePage(
          key: state.pageKey,
          child: GroupCategoriesPage(groupId: groupId),
        );
      },
    ),
  ];
}
