import 'package:auto_route/auto_route.dart';
import 'package:auto_route/src/matcher/route_matcher.dart';
import 'package:auto_route/src/navigation_failure.dart';
import 'package:auto_route/src/route/page_route_info.dart';
import 'package:auto_route/src/route/route_config.dart';
import 'package:auto_route/src/router/auto_route_page.dart';
import 'package:auto_route/src/router/root_stack_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../utils.dart';

typedef RouteDataPredicate = bool Function(RouteData route);

abstract class RoutingController implements ChangeNotifier {
  ValueKey<PageRouteInfo> get key;

  RouteMatcher get matcher;

  List<AutoRoutePage> get stack;

  T parent<T extends RoutingController>();

  StackRouter get root;

  RoutingController get topMost;

  RouteData get currentRoute;

  RouteData get routeData;

  RouteCollection get routeCollection;

  bool get hasEntries;

  T innerRouterOf<T extends RoutingController>(String routeName);

  List<PageRouteInfo> get preMatchedRoutes;

  PageBuilder get pageBuilder;

  @override
  String toString() => '$key Routing Controller';

  Future<bool> pop();
}

abstract class TabsRouter extends RoutingController {
  void setActiveIndex(int index);

  int get activeIndex;

  void setupRoutes(List<PageRouteInfo> routes);
}

abstract class StackRouter extends RoutingController {
  Future<void> push(PageRouteInfo route, {OnNavigationFailure onFailure});

  Future<void> navigate(PageRouteInfo route, {OnNavigationFailure onFailure});

  Future<void> pushPath(String path, {bool includePrefixMatches = false, OnNavigationFailure onFailure});

  Future<void> popAndPush(PageRouteInfo route, {OnNavigationFailure onFailure});

  Future<void> pushAndRemoveUntil(PageRouteInfo route,
      {@required RouteDataPredicate predicate, OnNavigationFailure onFailure});

  Future<void> replace(PageRouteInfo route, {OnNavigationFailure onFailure});

  Future<void> pushAll(List<PageRouteInfo> routes, {OnNavigationFailure onFailure});

  Future<void> popAndPushAll(List<PageRouteInfo> routes, {OnNavigationFailure onFailure});

  Future<void> replaceAll(List<PageRouteInfo> routes, {OnNavigationFailure onFailure});

  bool removeUntilRoot();

  bool removeWhere(RouteDataPredicate predicate);

  bool removeUntil(RouteDataPredicate predicate);

  GlobalKey<NavigatorState> get navigatorKey;

  bool removeLast();
}

@protected
class RoutingControllerScope extends InheritedWidget {
  final RoutingController controller;

  const RoutingControllerScope({
    @required Widget child,
    @required this.controller,
  }) : super(child: child);

  static RoutingController of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RoutingControllerScope>().controller;
  }

  @override
  bool updateShouldNotify(covariant RoutingControllerScope oldWidget) {
    return controller != oldWidget.controller;
  }
}

class StackRouterScope extends InheritedWidget {
  final StackRouter controller;

  const StackRouterScope({
    @required Widget child,
    @required this.controller,
  }) : super(child: child);

  static StackRouterScope of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<StackRouterScope>();
  }

  @override
  bool updateShouldNotify(covariant StackRouterScope oldWidget) {
    return controller != oldWidget.controller;
  }
}

abstract class StackEntryItem {
  ValueKey<PageRouteInfo> get key;

  RouteData get routeData;

  factory StackEntryItem.create({
    @required RoutingController parent,
    @required RouteData data,
  }) {
    if (data.config.isSubTree) {
      if (data.config.usesTabsRouter) {
        return ParallelBranchEntry(
            parentController: parent,
            pageBuilder: parent.pageBuilder,
            routeCollection: parent.routeCollection.subCollectionOf(data.name),
            key: ValueKey(data.route),
            routeData: data,
            preMatchedRoutes: data.route.initialChildren);
      } else {
        return BranchEntry(
            parentController: parent,
            key: ValueKey(data.route),
            routeData: data,
            routeCollection: parent.routeCollection.subCollectionOf(data.name),
            pageBuilder: parent.pageBuilder,
            preMatchedRoutes: data.route.initialChildren);
      }
    } else {
      return LeafEntry(data, ValueKey(data.route));
    }
  }
}

class LeafEntry implements StackEntryItem {
  final RouteData routeData;
  final ValueKey<PageRouteInfo> key;

  const LeafEntry(this.routeData, this.key);
}

class ParallelBranchEntry extends ChangeNotifier implements StackEntryItem, TabsRouter {
  final RoutingController parentController;
  final ValueKey<PageRouteInfo> key;
  final RouteCollection routeCollection;
  final PageBuilder pageBuilder;
  final RouteMatcher matcher;
  final RouteData routeData;
  final List<AutoRoutePage> _pages = [];
  final List<PageRouteInfo> preMatchedRoutes;
  int _activeIndex = 0;

  ParallelBranchEntry({
    @required this.routeCollection,
    @required this.pageBuilder,
    this.key,
    this.routeData,
    this.parentController,
    this.preMatchedRoutes,
  }) : matcher = RouteMatcher(routeCollection);

  T parent<T extends RoutingController>() => parent as T;

  @override
  RouteData get currentRoute => _pages[_activeIndex]?.routeData;

  @override
  int get activeIndex => _activeIndex;

  @override
  StackRouter get root => parentController?.root ?? this;

  @override
  void setActiveIndex(int index) {
    assert(index != null);
    assert(index >= 0 && index < _pages.length);
    if (_activeIndex != index) {
      _activeIndex = index;
      notifyListeners();
    }
  }

  @override
  List<AutoRoutePage> get stack => List.unmodifiable(_pages);

  AutoRoutePage get _activePage => _pages[_activeIndex];

  @override
  RoutingController get topMost {
    var activePage = _activePage;
    if (activePage.hasInnerRouter) {
      return (activePage.entry as RoutingController).topMost;
    }
    return this;
  }

  @override
  T innerRouterOf<T extends RoutingController>(String routeName) {
    if (_pages.isEmpty) {
      return null;
    }
    return _pages.map((p) => p.entry).whereType<T>().lastWhere(
          ((c) => c.routeData.name == routeName),
          orElse: () => null,
        );
  }

  @override
  bool get hasEntries => _pages.isNotEmpty;

  @override
  Future<bool> pop() {
    if (parentController != null) {
      return parentController.pop();
    } else {
      return SynchronousFuture<bool>(false);
    }
  }

  @override
  void setupRoutes(List<PageRouteInfo> routes) {
    List<PageRouteInfo> routesToPush = routes;
    if (preMatchedRoutes?.isNotEmpty == true) {
      final preMatchedRoute = preMatchedRoutes.last;
      final correspondingRouteIndex = routes.indexWhere(
        (r) => r.routeName == preMatchedRoute.routeName,
      );
      if (correspondingRouteIndex != -1) {
        routesToPush
          ..removeAt(correspondingRouteIndex)
          ..insert(correspondingRouteIndex, preMatchedRoute);
        _activeIndex = correspondingRouteIndex;
      }
    }
    if (routesToPush?.isNotEmpty == true) {
      _pushAll(routesToPush);
    }
  }

  void _pushAll(List<PageRouteInfo> routes) {
    _pages.clear();
    for (var route in routes) {
      final config = matcher.resolveConfigOrNull(route);
      if (config == null) {
        throw FlutterError("$this can not navigate to ${route.routeName}");
      } else {
        if (config.guards?.isNotEmpty == true) {
          throw FlutterError("Tab routes can not have guards");
        }
        final data = RouteData(
          route: route,
          parent: routeData,
          config: config,
        );
        final entry = StackEntryItem.create(parent: this, data: data);
        _pages.add(pageBuilder(entry));
      }
    }
  }
}

class BranchEntry extends ChangeNotifier implements StackEntryItem, StackRouter {
  final RoutingController parentController;
  final ValueKey<PageRouteInfo> key;
  final RouteCollection routeCollection;
  final PageBuilder pageBuilder;
  final RouteData routeData;
  final GlobalKey<NavigatorState> navigatorKey;
  final List<AutoRoutePage> _pages = [];
  final List<PageRouteInfo> preMatchedRoutes;
  RouteMatcher _lazyMatcher;

  BranchEntry({
    @required this.routeCollection,
    @required this.pageBuilder,
    this.key,
    this.routeData,
    this.parentController,
    this.preMatchedRoutes,
  }) : navigatorKey = GlobalKey<NavigatorState>() {
    _pushInitialRoutes();
  }

  RouteMatcher get matcher => _lazyMatcher ??= RouteMatcher(routeCollection);

  void _pushInitialRoutes() {
    if (!listNullOrEmpty(preMatchedRoutes)) {
      pushAll(preMatchedRoutes);
    } else {
      var defaultConfig = routeCollection.configWithPath('');
      if (defaultConfig != null) {
        if (defaultConfig.isRedirect) {
          pushPath(defaultConfig.redirectTo);
        } else {
          push(RouteMatch(
            config: defaultConfig,
            segments: defaultConfig.path.split('/'),
            pathParams: Parameters({}),
            queryParams: Parameters({}),
          ).toRoute);
        }
      }
    }
  }

  StackRouter get root => parentController?.root ?? this;

  T parent<T extends RoutingController>() => parentController as T;

  @override
  RouteData get currentRoute {
    if (_pages.isNotEmpty) {
      return _pages.last.routeData;
    }
    return null;
  }

  @override
  RoutingController get topMost {
    if (_pages.isNotEmpty) {
      var topPage = _pages.last;
      if (topPage.hasInnerRouter) {
        return (topPage.entry as RoutingController).topMost;
      }
    }
    return this;
  }

  @override
  Future<bool> pop() {
    final NavigatorState navigator = navigatorKey?.currentState;
    if (navigator == null) return SynchronousFuture<bool>(false);
    if (navigator.canPop()) {
      return navigator.maybePop();
    } else if (parentController != null) {
      return parentController.pop();
    } else {
      return SynchronousFuture<bool>(false);
    }
  }

  @override
  bool removeLast() => _removeLast();

  bool _removeLast({bool notify = true}) {
    var didRemove = false;
    if (_pages.length > 1) {
      _pages.removeLast();
      if (notify) {
        notifyListeners();
      }
      didRemove = true;
    }
    return didRemove;
  }

  @override
  List<AutoRoutePage> get stack => List.unmodifiable(_pages);

  @override
  Future<void> push(PageRouteInfo route, {OnNavigationFailure onFailure}) async {
    return _push(route, onFailure: onFailure, notify: true);
  }

  @override
  Future<void> navigate(PageRouteInfo route, {OnNavigationFailure onFailure}) async {
    var entry = _pages.lastWhere((e) => e.key == ValueKey(route), orElse: () => null);
    if (entry != null) {
      removeUntil((d) => d.route == route);
    } else {
      return push(route, onFailure: onFailure);
    }
  }

  Future<void> _push(PageRouteInfo route, {OnNavigationFailure onFailure, bool notify = true}) async {
    var config = _resolveConfigOrReportFailure(route, onFailure);
    if (config == null) {
      return null;
    }
    if (await _canNavigate([route], config, onFailure)) {
      return _addStackEntry(route, config: config, onFailure: onFailure, notify: notify);
    }
    return null;
  }

  @override
  Future<void> replace(
    PageRouteInfo route, {
    OnNavigationFailure onFailure,
  }) {
    assert(_pages.isNotEmpty);
    _pages.removeLast();
    return push(route, onFailure: onFailure);
  }

  @override
  Future<void> pushAll(
    List<PageRouteInfo> routes, {
    OnNavigationFailure onFailure,
  }) {
    return _pushAll(routes, onFailure: onFailure);
  }

  @override
  Future<void> popAndPushAll(List<PageRouteInfo> routes, {onFailure}) {
    pop();
    return _pushAll(routes, onFailure: onFailure);
  }

  @override
  Future<void> replaceAll(
    List<PageRouteInfo> routes, {
    OnNavigationFailure onFailure,
  }) {
    _clearHistory();
    return _pushAll(routes, onFailure: onFailure);
  }

  @override
  bool removeUntilRoot() {
    var didPop = false;
    if (_pages.length > 1) {
      _pages.removeRange(1, _pages.length);
      notifyListeners();
      didPop = true;
    }
    return didPop;
  }

  @override
  Future<void> popAndPush(PageRouteInfo route, {OnNavigationFailure onFailure}) {
    pop();
    return push(route, onFailure: onFailure);
  }

  @override
  bool removeUntil(RouteDataPredicate predicate) => _removeUntil(predicate);

  bool _removeUntil(RouteDataPredicate predicate, {bool notify = true}) {
    var didPop = false;
    for (var candidate in List.unmodifiable(_pages).reversed) {
      if (predicate(candidate.routeData)) {
        break;
      } else {
        _removeLast(notify: false);
        didPop = true;
      }
    }
    if (didPop && notify) {
      notifyListeners();
    }
    return didPop;
  }

  @override
  bool removeWhere(RouteDataPredicate predicate) {
    var didRemove = false;
    for (var entry in List.unmodifiable(_pages)) {
      if (predicate(entry.routeData)) {
        didRemove = true;
        _pages.remove(entry);
      }
    }
    notifyListeners();
    return didRemove;
  }

  void updateDeclarativeRoutes(
    List<PageRouteInfo> routes, {
    bool notify = false,
  }) {
    _clearHistory();

    for (var route in routes) {
      var config = _resolveConfigOrReportFailure(route);
      if (config == null) {
        break;
      }
      if (!listNullOrEmpty(config.guards)) {
        throw FlutterError("Declarative routes can not have guards");
      }

      var entry = _createEntry(route, config: config);
      _addEntry(pageBuilder(entry), notify: notify);
    }
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _pushAll(
    List<PageRouteInfo> routes, {
    OnNavigationFailure onFailure,
    bool notify = true,
  }) async {
    final checkedRoutes = List<PageRouteInfo>.from(routes);
    for (var route in routes) {
      var config = _resolveConfigOrReportFailure(route, onFailure);
      if (config == null) {
        break;
      }
      if (await _canNavigate(checkedRoutes, config, onFailure)) {
        checkedRoutes.remove(route);
        _addStackEntry(route, config: config, notify: false);
      } else {
        break;
      }
    }
    if (notify) {
      notifyListeners();
    }
    return SynchronousFuture(null);
  }

  RouteConfig _resolveConfigOrReportFailure(
    PageRouteInfo route, [
    OnNavigationFailure onFailure,
  ]) {
    var config = matcher.resolveConfigOrNull(route);
    if (config != null) {
      return config;
    } else {
      if (onFailure != null) {
        onFailure(RouteNotFoundFailure(route));
        return null;
      } else {
        throw FlutterError("[${toString()}] Router can not navigate to ${route.fullPath}");
      }
    }
  }

  void _addStackEntry(
    PageRouteInfo route, {
    @required RouteConfig config,
    OnNavigationFailure onFailure,
    bool notify = true,
  }) {
    var entry = _createEntry(route, config: config);
    _addEntry(pageBuilder(entry), notify: notify);
  }

  Future<bool> _canNavigate(
    List<PageRouteInfo> routes,
    RouteConfig config,
    OnNavigationFailure onFailure,
  ) async {
    if (config.guards.isEmpty) {
      return true;
    }
    for (var guard in config.guards) {
      if (!await guard.canNavigate(routes, this)) {
        if (onFailure != null) {
          onFailure(RejectedByGuardFailure(routes, guard));
        }
        return false;
      }
    }
    return true;
  }

  void _addEntry(AutoRoutePage page, {bool notify = true}) {
    _pages.add(page);
    if (notify) {
      notifyListeners();
    }
  }

  StackEntryItem _createEntry(PageRouteInfo route, {RouteConfig config}) {
    final data = RouteData(
      route: route,
      parent: routeData,
      config: config,
    );
    return StackEntryItem.create(
      parent: this,
      data: data,
    );
  }

  Future<void> _replaceAll(List<PageRouteInfo> routes, {bool notify = true}) {
    assert(routes != null && routes.isNotEmpty);
    _clearHistory();
    return _pushAll(routes, notify: notify);
  }

  Future<void> updateOrReplaceRoutes(List<PageRouteInfo> routes) {
    assert(routes != null);
    var route = routes.last;
    var newKey = ValueKey(route);
    var lastKey = _pages.last.key;
    if (lastKey != null && lastKey == newKey) {
      if (route.hasChildren && _pages.last.entry is BranchEntry) {
        // this line should remove any routes below the updated one
        // not sure if this's the desired behaviour
        _pages.sublist(0, _pages.length - 2);
        (_pages.last as BranchEntry).updateOrReplaceRoutes(route.initialChildren);
      }
    } else {
      return _replaceAll(routes, notify: true);
    }
    return SynchronousFuture(null);
  }

  void _clearHistory() {
    _pages.clear();
  }

  @override
  Future<void> pushAndRemoveUntil(
    PageRouteInfo route, {
    @required RouteDataPredicate predicate,
    onFailure,
  }) {
    _removeUntil(predicate, notify: false);
    return push(route, onFailure: onFailure);
  }

  @override
  Future<void> pushPath(
    String path, {
    bool includePrefixMatches = false,
    OnNavigationFailure onFailure,
  }) {
    var matches = matcher.match(path, includePrefixMatches: includePrefixMatches);
    if (matches != null) {
      var routes = matches.map((m) => m.toRoute).toList();
      return _pushAll(routes, onFailure: onFailure, notify: true);
    } else if (onFailure != null) {
      onFailure.call(
        RouteNotFoundFailure(
          PageRouteInfo(null, path: path),
        ),
      );
    }
    return SynchronousFuture(null);
  }

  @override
  T innerRouterOf<T extends RoutingController>(String routeName) {
    if (_pages.isEmpty) {
      return null;
    }
    return _pages.map((p) => p.entry).whereType<T>().lastWhere(
          ((c) => c.routeData.name == routeName),
          orElse: () => null,
        );
  }

  @override
  bool get hasEntries => _pages.isNotEmpty;

  @override
  String toString() {
    return routeData?.name ?? 'Root';
  }
}

class TabsRouterScope extends InheritedWidget {
  final TabsRouter controller;

  const TabsRouterScope({
    @required Widget child,
    @required this.controller,
  }) : super(child: child);

  static TabsRouterScope of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TabsRouterScope>();
  }

  @override
  bool updateShouldNotify(covariant TabsRouterScope oldWidget) {
    return controller != oldWidget.controller;
  }
}
