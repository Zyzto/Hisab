import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/navigation/decorative_route.dart';
import 'package:hisab/core/navigation/route_paths.dart';

void main() {
  group('appRoutePathFromBrowserUri', () {
    test('reads hash URL strategy fragment route', () {
      expect(
        appRoutePathFromBrowserUri(
          Uri.parse('https://hisab.app/#/groups/g1/balance'),
        ),
        '/groups/g1/balance',
      );
      expect(
        appRoutePathFromBrowserUri(
          Uri.parse('https://hisab.app/#/onboarding/preferences'),
        ),
        '/onboarding/preferences',
      );
      expect(
        appRoutePathFromBrowserUri(
          Uri.parse('https://hisab.app/#/groups/create/style'),
        ),
        '/groups/create/style',
      );
      expect(
        appRoutePathFromBrowserUri(Uri.parse('https://hisab.app/#/settings')),
        '/settings',
      );
      expect(
        appRoutePathFromBrowserUri(
          Uri.parse('https://hisab.app/#/groups/g1/expenses/e1'),
        ),
        '/groups/g1/expenses/e1',
      );
      expect(
        appRoutePathFromBrowserUri(
          Uri.parse('https://hisab.app/#/groups/g1/analytics'),
        ),
        '/groups/g1/analytics',
      );
    });

    test('strips query from hash fragment route', () {
      expect(
        appRoutePathFromBrowserUri(
          Uri.parse('https://hisab.app/#/groups/g1/people?x=1'),
        ),
        '/groups/g1/people',
      );
    });

    test('reads path URL strategy pathname', () {
      expect(
        appRoutePathFromBrowserUri(
          Uri.parse('https://hisab.app/groups/g1/balance'),
        ),
        '/groups/g1/balance',
      );
      expect(appRoutePathFromBrowserUri(Uri.parse('https://hisab.app/')), '/');
    });

    test('ignores OAuth-style fragment without leading slash', () {
      expect(
        appRoutePathFromBrowserUri(
          Uri.parse(
            'https://hisab.app/?code=abc#access_token=tok&expires_in=3600',
          ),
        ),
        '/',
      );
      expect(
        appRoutePathFromBrowserUri(
          Uri.parse('https://hisab.app/home/combined#access_token=tok'),
        ),
        '/home/combined',
      );
    });

    test('handles path+stale-hash mix by preferring fragment route', () {
      expect(
        appRoutePathFromBrowserUri(
          Uri.parse('https://hisab.app/groups/g1/people#/groups/g1/expenses'),
        ),
        '/groups/g1/expenses',
      );
      expect(
        appRoutePathFromBrowserUri(
          Uri.parse('https://hisab.app/settings#/groups/g1/balance'),
        ),
        '/groups/g1/balance',
      );
      expect(
        appRoutePathFromBrowserUri(
          Uri.parse('https://hisab.app/profile#/settings'),
        ),
        '/settings',
      );
    });
  });

  group('isLeakedAppPathname / hashStrategyPathname', () {
    test('detects leaked app routes in pathname', () {
      expect(isLeakedAppPathname('/settings'), isTrue);
      expect(isLeakedAppPathname('/groups/g1/expenses'), isTrue);
      expect(isLeakedAppPathname('/home/combined'), isTrue);
      expect(isLeakedAppPathname('/profile'), isTrue);
      expect(isLeakedAppPathname('/onboarding/welcome'), isTrue);
      expect(isLeakedAppPathname('/'), isFalse);
      expect(isLeakedAppPathname('/index.html'), isFalse);
      expect(isLeakedAppPathname('/assets/font.ttf'), isFalse);
    });

    test('hashStrategyPathname resets leaked routes to root', () {
      expect(hashStrategyPathname('/settings'), '/');
      expect(hashStrategyPathname('/groups/g1/balance'), '/');
      expect(hashStrategyPathname('/'), '/');
      expect(hashStrategyPathname('/index.html'), '/index.html');
      expect(hashStrategyPathname('/app/'), '/app/');
    });
  });

  group('RoutePaths entry URLs stay absolute app paths', () {
    test('group and settings entry points', () {
      expect(RoutePaths.groupDetail('g1').startsWith('/groups/'), isTrue);
      expect(RoutePaths.groupDetail('g1'), '/groups/g1/expenses');
      expect(RoutePaths.settings, '/settings');
      expect(
        RoutePaths.settingsFocus('display_currency'),
        '/settings?focus=display_currency',
      );
      expect(RoutePaths.groupAnalytics('g1'), '/groups/g1/analytics');
      expect(RoutePaths.groupSettings('g1'), '/groups/g1/settings');
      expect(
        RoutePaths.groupExpenseDetail('g1', 'e1'),
        '/groups/g1/expenses/e1',
      );
    });
  });
}
