import 'package:go_router/go_router.dart';
import '../../core/navigation/app_page.dart';
import '../groups/pages/group_detail_page.dart';

List<RouteBase> getBalanceRoutes() {
  return [
    GoRoute(
      path: '/groups/:id/balance',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return appFadeSlidePage(
          key: state.pageKey,
          child: GroupDetailPage(
            groupId: id,
            initialTab: GroupDetailTab.balance,
          ),
        );
      },
    ),
  ];
}
