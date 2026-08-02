import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/bible/bible_store.dart';
import 'package:livro_registro/data/engagement/engagement_store.dart';
import 'package:livro_registro/data/harpa/harpa_store.dart';
import 'package:livro_registro/data/storage.dart';
import 'package:livro_registro/features/auth/birthday_overlay.dart';
import 'package:livro_registro/features/auth/login_screen.dart';
import 'package:livro_registro/features/home/home_screen.dart';
import 'package:livro_registro/services/auth_service.dart';
import 'package:livro_registro/services/bible_repository.dart';
import 'package:livro_registro/services/fcm_service.dart';
import 'package:livro_registro/services/harpa_repository.dart';
import 'package:livro_registro/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    try {
      await dotenv.load(fileName: '.env.example');
    } catch (_) {}
  }
  await initializeDateFormatting('pt_BR');
  final storage = await EbdStorage.open();
  final engagement = await EngagementStore.open();
  final state = AppState(storage, engagement: engagement);
  await state.load();
  final bibleStore = await BibleStore.open();
  final bible = BibleRepository(bibleStore);
  await bible.load();
  final harpaStore = await HarpaStore.open();
  final harpa = HarpaRepository(harpaStore);
  await harpa.load();
  final auth = AuthService();
  await auth.init();
  final fcm = FcmService();
  await fcm.init();
  runApp(
    EbdApp(
      state: state,
      auth: auth,
      fcm: fcm,
      bible: bible,
      harpa: harpa,
      engagement: engagement,
    ),
  );
}

class EbdApp extends StatelessWidget {
  const EbdApp({
    super.key,
    required this.state,
    required this.auth,
    required this.fcm,
    required this.bible,
    required this.harpa,
    required this.engagement,
  });

  final AppState state;
  final AuthService auth;
  final FcmService fcm;
  final BibleRepository bible;
  final HarpaRepository harpa;
  final EngagementStore engagement;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: bible),
        ChangeNotifierProvider.value(value: harpa),
        ChangeNotifierProvider.value(value: engagement),
        Provider.value(value: fcm),
      ],
      child: MaterialApp(
        title: 'EBD',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const _RootGate(),
      ),
    );
  }
}

class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  bool _birthdayShown = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.isLoggedIn) {
      _birthdayShown = false;
      return LoginScreen(onLoggedIn: () => setState(() {}));
    }

    final user = auth.currentUser!;
    final showBirthday = user.isBirthdayToday && !_birthdayShown;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fcm = context.read<FcmService>();
      fcm.registerTokenForProfile(user.id);
    });

    return Stack(
      children: [
        const HomeScreen(),
        if (showBirthday)
          BirthdayOverlay(
            nome: user.nome,
            onDone: () => setState(() => _birthdayShown = true),
          ),
      ],
    );
  }
}
