part of 'routing_controller.dart';

/// Signature for a function uses [pagesMap] to build an [AutoRoutePage]
typedef PageBuilder = AutoRoutePage Function(RouteData data);

/// An Implementation of [StackRouter] used by [AutoRouterDelegate]
abstract class RootStackRouter extends StackRouter {
  /// Default constructor
  RootStackRouter({super.navigatorKey}) : super(key: const ValueKey('Root')) {
    _navigationHistory = NavigationHistory.create(this);
  }

  /// Returns a [RouterConfig] instead to be passed
  /// to [MaterialApp.router]
  RouterConfig<UrlState> config({
    DeepLinkTransformer? deepLinkTransformer,
    DeepLinkBuilder? deepLinkBuilder,
    String? navRestorationScopeId,
    WidgetBuilder? placeholder,
    NavigatorObserversBuilder navigatorObservers =
        AutoRouterDelegate.defaultNavigatorObserversBuilder,
    bool includePrefixMatches = !kIsWeb,
    bool Function(String? location)? neglectWhen,
    bool rebuildStackOnDeepLink = false,
    Listenable? reevaluateListenable,
  }) {
    return RouterConfig(
      routeInformationParser: defaultRouteParser(
        includePrefixMatches: includePrefixMatches,
        deepLinkTransformer: deepLinkTransformer,
      ),
      routeInformationProvider: routeInfoProvider(
        neglectWhen: neglectWhen,
      ),
      backButtonDispatcher: RootBackButtonDispatcher(),
      routerDelegate: delegate(
        reevaluateListenable: reevaluateListenable,
        rebuildStackOnDeepLink: rebuildStackOnDeepLink,
        navRestorationScopeId: navRestorationScopeId,
        navigatorObservers: navigatorObservers,
        placeholder: placeholder,
        deepLinkBuilder: deepLinkBuilder,
      ),
    );
  }

  @override
  RouteData get routeData => RouteData(
        router: this,
        type: const RouteType.material(),
        stackKey: _stackKey,
        route: RouteMatch(
          config: DummyRootRoute(path: ''),
          segments: const [''],
          stringMatch: '',
          key: const ValueKey('Root'),
        ),
        pendingChildren: const [],
      );

  /// The list of route entries to match against
  List<AutoRoute> get routes;

  /// A List of Root router guards
  List<AutoRouteGuard> get guards => const [];

  /// The default animation
  RouteType get defaultRouteType => const RouteType.material();

  // ignore: prefer_final_fields
  bool _managedByWidget = false;
  late final NavigationHistory _navigationHistory;

  @override
  bool get managedByWidget => _managedByWidget;

  AutoRouteInformationProvider? _lazyInformationProvider;

  /// Builds a lazy instance of [AutoRouteInformationProvider]
  AutoRouteInformationProvider routeInfoProvider({
    RouteInformation? initialRouteInformation,
    bool Function(String? location)? neglectWhen,
  }) {
    return _lazyInformationProvider ??= AutoRouteInformationProvider(
      initialRouteInformation: initialRouteInformation,
      neglectWhen: neglectWhen,
    );
  }

  AutoRouterDelegate? _lazyRootDelegate;

  /// Builds a lazy instance of [AutoRouterDelegate]
  /// _lazyRootDelegate is only built one time
  AutoRouterDelegate delegate({
    String? navRestorationScopeId,
    WidgetBuilder? placeholder,
    NavigatorObserversBuilder navigatorObservers =
        AutoRouterDelegate.defaultNavigatorObserversBuilder,
    DeepLinkBuilder? deepLinkBuilder,
    bool rebuildStackOnDeepLink = false,
    Listenable? reevaluateListenable,
  }) {
    return _lazyRootDelegate ??= AutoRouterDelegate(
      this,
      navRestorationScopeId: navRestorationScopeId,
      navigatorObservers: navigatorObservers,
      placeholder: placeholder,
      rebuildStackOnDeepLink: rebuildStackOnDeepLink,
      deepLinkBuilder: deepLinkBuilder,
      reevaluateListenable: reevaluateListenable,
    );
  }

  /// Builds a lazy instance of [DefaultRouteParser]
  DefaultRouteParser defaultRouteParser({
    bool includePrefixMatches = !kIsWeb,
    DeepLinkTransformer? deepLinkTransformer,
  }) =>
      DefaultRouteParser(
        matcher,
        includePrefixMatches: includePrefixMatches,
        deepLinkTransformer: deepLinkTransformer ?? (uri) async => uri,
      );

  @override
  void updateRouteData(RouteData data) {
    throw FlutterError('Root RouteData should not update');
  }

  @override
  late final RouteMatcher matcher = RouteMatcher(routeCollection);

  @override
  NavigationHistory get navigationHistory => _navigationHistory;

  @override
  late final RouteCollection routeCollection =
      RouteCollection.fromList(routes, root: true);

  /// Builds a new instance of [RootStackRouter]
  /// with the provided parameters
  factory RootStackRouter.build({
    required List<AutoRoute> routes,
    List<AutoRouteGuard> guards,
    GlobalKey<NavigatorState>? navigatorKey,
    RouteType defaultRouteType,
  }) = _RootStackRouterImpl;
}

class _RootStackRouterImpl extends RootStackRouter {
  @override
  final List<AutoRoute> routes;

  @override
  final List<AutoRouteGuard> guards;

  @override
  final RouteType defaultRouteType;

  _RootStackRouterImpl({
    required this.routes,
    this.guards = const [],
    super.navigatorKey,
    this.defaultRouteType = const RouteType.material(),
  });
}
