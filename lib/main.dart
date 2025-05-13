import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'models/flashcard.dart';
import 'models/multiple_choice_question.dart';
import 'providers/deck_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/study_stats_provider.dart';
import 'screens/deck_list_screen.dart';
import 'theme/app_theme.dart';
import 'services/db_service.dart';

// Wrapper para mostrar una pantalla de carga mientras se inicializa
class AppStartup extends StatefulWidget {
  const AppStartup({super.key});

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  // Si inicialización falló y mensaje de error
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  // Inicializar la aplicación con manejo de errores
  Future<void> _initializeApp() async {
    try {
      // Inicializar en este orden
      try {
        // Inicializar intl para traducciones
        await initializeDateFormatting('es', null);

        // Intentamos cargar las variables de entorno
        await dotenv.load(fileName: '.env');
      } catch (e) {
        print('Advertencia: No se pudo cargar el archivo .env: $e');
        // Continuamos con la aplicación aunque no se pueda cargar .env
      }
      
      await Hive.initFlutter();
      
      // Registrar adaptadores
      Hive.registerAdapter(FlashcardAdapter());
      Hive.registerAdapter(MultipleChoiceQuestionAdapter());
      
      // Abrir boxes para persistencia
      await Hive.openBox('decks');
      await Hive.openBox('app_settings');
      await Hive.openBox('study_stats');
      
      try {
        // Inicializar el servicio de base de datos
        final dbService = DbService();
        await dbService.initialize();
        // Intentar migrar datos si es necesario
        await Future.delayed(const Duration(milliseconds: 500)); // Pequeña pausa para asegurar que Hive esté listo
        await dbService.migrateDataIfNeeded();
        print('DbService inicializado correctamente');
      } catch (e) {
        print('Advertencia: Problema al inicializar DbService: $e');
        // Mostrar el error en la consola para depuración
        print('Detalles del error: ${e.toString()}');
        // Continuamos con la aplicación aunque haya problemas con DbService
      }
      
      // Inicializar proveedores
      await ThemeProvider.initialize();
      await StudyStatsProvider.initialize();
      
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      print('Error durante la inicialización: $e');
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mostrar pantalla de error si falla la inicialización
    if (_error != null) {
      return MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                const SizedBox(height: 16),
                Text(
                  'Error al inicializar la aplicación',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                    });
                    _initializeApp();
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Mostrar indicador de carga mientras se inicializa
    if (!_initialized) {
      return MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.primaryColor, Color(0xFF34495E)],
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.accentColor),
                  SizedBox(height: 24),
                  Text(
                    'Inicializando aplicación...',
                    style: TextStyle(fontSize: 18, color: AppTheme.textLight),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    // La aplicación está inicializada, mostrar la app principal
    return const MyApp();
  }
}

// Punto de entrada principal
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppStartup());
}

// Aplicación principal
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeckProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => StudyStatsProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Flashcards Maker',
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: themeProvider.themeMode,
            home: const DeckListScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
