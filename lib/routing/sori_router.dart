import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/session_user.dart';
import '../services/pending_review_return.dart';
import '../services/sori_store.dart';
import '../views/admin_chart_page.dart';
import '../views/admin_chart_writer_page.dart';
import '../views/app_shell_page.dart';
import '../views/care_report_page.dart';
import '../views/customer_care_page.dart';
import '../views/customer_management_cases_page.dart';
import '../views/customer_review_dashboard_page.dart';
import '../views/customer_review_page.dart';
import '../views/customer_profile_page.dart';
import '../views/director_customers_tab.dart';
import '../views/director_review_manage_page.dart';
import '../views/entry_home_page.dart';
import '../views/my_page.dart';
import '../views/splash_page.dart';
import '../views/seminar_class_detail_page.dart';
import '../views/success_cases_page.dart';
import '../views/unified_home_feed_page.dart';
import 'app_router.dart';

/// go_router 경로 SSOT (해시 URL `/#/...` 과 호환).
abstract final class AppPaths {
  static const home = '/';
  static const login = '/login';
  static const app = '/app';
  static const appHome = '/app/home';
  static const appCustomers = '/app/customers';
  static const appReview = '/app/review';
  static const appCases = '/app/cases';
  static const appMy = '/app/my';
  static const review = '/review';
  static const careReport = '/care-report';
  static const chartCreate = '/chart/create';

  static String customerDetail(String customerId) =>
      '$appCustomers/${Uri.encodeComponent(customerId.trim())}';

  static String customerProfile(String customerId) =>
      '/customer/${Uri.encodeComponent(customerId.trim())}/profile';

  static String seminarClass(String classId) =>
      '/seminar/${Uri.encodeComponent(classId.trim())}';
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createSoriGoRouter({String? initialLocation}) {
  final store = SoriStore.instance;
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation ?? _resolveInitialLocation(),
    refreshListenable: store,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final session = store.session;
      final onboarded = session != null && session.onboardingComplete;

      // 딥링크(리뷰/케어/차트/고객프로필)는 셸 밖 — 가드 제외
      if (loc.startsWith(AppPaths.review) ||
          loc.startsWith(AppPaths.careReport) ||
          loc.startsWith('/chart') ||
          loc.startsWith('/customer/') ||
          loc.startsWith('/seminar/')) {
        if (loc.startsWith('/customer/') && !onboarded) {
          return AppPaths.login;
        }
        return null;
      }

      if (loc == AppPaths.app || loc == '/admin') {
        return AppPaths.appHome;
      }

      final inShell = loc.startsWith(AppPaths.app);
      if (inShell && !onboarded) {
        return AppPaths.login;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppPaths.home,
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return SplashPage(initialToken: token);
        },
      ),
      GoRoute(
        path: AppPaths.login,
        builder: (context, state) {
          final page = state.uri.queryParameters['page'];
          final token = state.uri.queryParameters['token'];
          return EntryHomePage(
            initialToken: page == 'review' ? null : token,
          );
        },
      ),
      GoRoute(
        path: AppPaths.review,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return CustomerReviewPage(store: store, token: token);
        },
      ),
      GoRoute(
        path: '${AppPaths.careReport}/:chartId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['chartId'] ?? '';
          return CareReportPage(store: store, chartId: id);
        },
      ),
      GoRoute(
        path: AppPaths.careReport,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.uri.queryParameters['chartId'] ??
              state.uri.queryParameters['id'] ??
              '';
          return CareReportPage(store: store, chartId: id);
        },
      ),
      GoRoute(
        path: AppPaths.chartCreate,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final q = state.uri.queryParameters;
          final customerId =
              (q['customerId'] ?? q['customer_id'] ?? '').trim();
          final chartId = (q['chartId'] ?? q['chart_id'] ?? '').trim();
          final quick = q['quick'] == '1' || q['quick'] == 'true';
          final customer = store.findCustomer(customerId);
          final existing =
              chartId.isEmpty ? null : store.findChartById(chartId);
          return AdminChartWriterPage(
            store: store,
            customerId: customerId,
            customer: customer,
            existingChart: existing,
            forceQuickChart: quick,
          );
        },
      ),
      GoRoute(
        path: '/chart/:customerId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final customerId = state.pathParameters['customerId'] ?? '';
          if (customerId == 'create') {
            return const SizedBox.shrink();
          }
          final customer = store.findCustomer(customerId);
          return AdminChartWriterPage(
            store: store,
            customerId: customerId,
            customer: customer,
          );
        },
      ),

      GoRoute(
        path: '/customer/:customerId/profile',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = Uri.decodeComponent(
            state.pathParameters['customerId'] ?? '',
          );
          return CustomerProfilePage(store: store, customerId: id);
        },
      ),

      GoRoute(
        path: '/seminar/:classId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = Uri.decodeComponent(
            state.pathParameters['classId'] ?? '',
          );
          return SeminarClassDetailPage(store: store, classId: id);
        },
      ),

      // ─── Shell: 하단바 고정 (고객 상세도 브랜치 내부) ───
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShellPage(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.appHome,
                pageBuilder: (context, state) => NoTransitionPage(
                  child: _RoleHome(store: store),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.appCustomers,
                pageBuilder: (context, state) => NoTransitionPage(
                  child: _RoleSecondTab(store: store),
                ),
                routes: [
                  GoRoute(
                    path: ':customerId',
                    builder: (context, state) {
                      final id = state.pathParameters['customerId'] ?? '';
                      return AdminChartPage(
                        store: store,
                        customerId: Uri.decodeComponent(id),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.appReview,
                pageBuilder: (context, state) => NoTransitionPage(
                  child: _RoleReviewTab(store: store),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.appCases,
                pageBuilder: (context, state) => NoTransitionPage(
                  child: _RoleCasesTab(store: store),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppPaths.appMy,
                pageBuilder: (context, state) => NoTransitionPage(
                  child: _RoleMyTab(store: store),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('페이지를 찾을 수 없습니다'),
            TextButton(
              onPressed: () => context.go(AppPaths.home),
              child: const Text('홈으로'),
            ),
          ],
        ),
      ),
    ),
  );
}

String _resolveInitialLocation() {
  final pendingReview = PendingReviewReturn.peek();
  if (pendingReview != null && pendingReview.isNotEmpty) {
    return PendingReviewReturn.reviewLocation(pendingReview);
  }

  final fromLegacy = AppRouter.resolveInitialRoute();
  if (fromLegacy == AppRouter.app || fromLegacy == AppRouter.admin) {
    return AppPaths.appHome;
  }
  if (fromLegacy.startsWith(AppRouter.app)) {
    return fromLegacy;
  }
  // /admin → /app/home
  if (fromLegacy == '/admin' || fromLegacy.startsWith('/admin')) {
    return AppPaths.appHome;
  }
  return fromLegacy.isEmpty ? AppPaths.home : fromLegacy;
}

class _RoleHome extends StatelessWidget {
  const _RoleHome({required this.store});
  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        // 원장·고객 공통 통합 커뮤니티 홈 피드
        return UnifiedHomeFeedPage(
          store: store,
          onSelectTab: (i) => _goShellTab(context, i),
        );
      },
    );
  }
}

class _RoleSecondTab extends StatelessWidget {
  const _RoleSecondTab({required this.store});
  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final isDirector = store.session?.activeMode == UserRole.director;
        if (isDirector) {
          return DirectorCustomersTab(store: store);
        }
        return CustomerCareTab(store: store);
      },
    );
  }
}

class _RoleReviewTab extends StatelessWidget {
  const _RoleReviewTab({required this.store});
  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final isDirector = store.session?.activeMode == UserRole.director;
        if (isDirector) {
          return DirectorReviewManagePage(store: store);
        }
        return CustomerReviewDashboardPage(store: store);
      },
    );
  }
}

class _RoleCasesTab extends StatelessWidget {
  const _RoleCasesTab({required this.store});
  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final isDirector = store.session?.activeMode == UserRole.director;
        if (isDirector) {
          return SuccessCasesPage(store: store);
        }
        return CustomerManagementCasesPage(store: store);
      },
    );
  }
}

class _RoleMyTab extends StatelessWidget {
  const _RoleMyTab({required this.store});
  final SoriStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return MyPage(
          store: store,
          onSelectTab: (i) => _goShellTab(context, i),
        );
      },
    );
  }
}

void _goShellTab(BuildContext context, int index) {
  final shell = StatefulNavigationShell.maybeOf(context);
  if (shell != null) {
    shell.goBranch(index.clamp(0, 4));
    return;
  }
  final path = switch (index) {
    0 => AppPaths.appHome,
    1 => AppPaths.appCustomers,
    2 => AppPaths.appReview,
    3 => AppPaths.appCases,
    4 => AppPaths.appMy,
    _ => AppPaths.appHome,
  };
  context.go(path);
}
