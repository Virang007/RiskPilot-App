import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'repositories/stock_repository.dart';
import 'repositories/dhan_token_manager.dart';
import 'blocs/stock/stock_bloc.dart';
import 'blocs/stock/stock_event.dart';
import 'blocs/watchlist/watchlist_bloc.dart';
import 'blocs/watchlist/watchlist_event.dart';
import 'blocs/scan_stock/scan_stock_bloc.dart';
import 'blocs/splash/splash_bloc.dart';
import 'blocs/settings/settings_bloc.dart';
import 'blocs/settings/settings_event.dart';
import 'repositories/ocr_service.dart';
import 'repositories/stock_matching_engine.dart';
import 'views/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set status bar icons to light for dark background
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1E293B),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Auto check and purge expired Dhan token (Daily 6 AM rule)
  await DhanTokenManager.checkAndPurgeExpiredToken();

  final stockRepository = StockRepository();

  runApp(MyApp(stockRepository: stockRepository));
}

class MyApp extends StatelessWidget {
  final StockRepository stockRepository;

  const MyApp({super.key, required this.stockRepository});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<StockRepository>.value(value: stockRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<StockBloc>(
            create: (context) => StockBloc(repository: stockRepository)
              ..add(const LoadTopStocksEvent()),
          ),
          BlocProvider<WatchlistBloc>(
            create: (context) => WatchlistBloc(repository: stockRepository)
              ..add(const LoadWatchlistEvent()),
          ),
          BlocProvider<ScanStockBloc>(
            create: (context) => ScanStockBloc(
              ocrService: OcrTextService(),
              matchingEngine: StockMatchingEngine(),
              stockRepository: stockRepository,
            ),
          ),
          BlocProvider<SplashBloc>(
            create: (context) => SplashBloc(stockRepository: stockRepository),
          ),
          BlocProvider<SettingsBloc>(
            create: (context) => SettingsBloc()..add(const LoadSettingsEvent()),
          ),
        ],
        child: MaterialApp(
          title: 'RiskPilot',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF10B981),
              secondary: Color(0xFF38BDF8),
              surface: Color(0xFF1E293B),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E293B),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
