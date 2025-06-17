import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/flashcard.dart';
import '../models/multiple_choice_question.dart';
import '../utils/logger.dart';
import '../utils/app_constants.dart';

/// Servicio simplificado para manejo de persistencia de datos utilizando Hive
class DbService {
  // Singleton pattern
  static final DbService _instance = DbService._internal();
  static bool _initialized = false;
  static Completer<void>? _initCompleter;
  
  // Obtener instancia única
  factory DbService() => _instance;
  
  // Constructor privado
  DbService._internal();

  // Usamos las constantes centralizadas
  static const String decksBoxName = AppConstants.boxDecks;
  static const String settingsBoxName = AppConstants.boxAppSettings;
  static const String statsBoxName = AppConstants.boxStudyStats;
  
  // Para verificar si la inicialización está completa
  Future<void> get ready async {
    if (_initialized) return;
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      return _initCompleter!.future;
    }
    return initialize();
  }
  
  // Método seguro para acceder a una box
  Future<T> _safeBoxOperation<T>(String boxName, Future<T> Function(Box box) operation) async {
    if (!_initialized) {
      try {
        await ready;
      } catch (e) {
        // Continuamos intentando abrir la box directamente
      }
    }
    
    Box? box;
    try {
      // Intentar obtener la box si ya está abierta
      if (Hive.isBoxOpen(boxName)) {
        box = Hive.box(boxName);
      } else {
        // Si no está abierta, intentar abrirla
        box = await Hive.openBox(boxName);
      }
      
      return await operation(box);
    } catch (e) {
      // Reintento con apertura forzada si es un error de acceso
      try {
        if (box == null) {
          box = await Hive.openBox(boxName, path: null);
          return await operation(box);
        }
      } catch (reopenError) {
        rethrow;
      }
      rethrow;
    }
  }

  /// Inicializar el servicio de base de datos
  Future<void> initialize() async {
    // Si ya está inicializado, simplemente devuelve
    if (_initialized) {
      return;
    }
    
    // Si la inicialización está en progreso, esperar a que termine
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      return _initCompleter!.future;
    }
    
    // Crear un nuevo completer para esta inicialización
    _initCompleter = Completer<void>();
    
    try {
      // Intentar inicializar Hive si es necesario
      try {
        if (kIsWeb) {
          // En plataformas web, inicializar sin especificar path
          await Hive.initFlutter();
          
          // Dar tiempo para que se inicialice correctamente
          await Future.delayed(const Duration(milliseconds: 200));
          Logger.info('Hive inicializado para plataforma web');
        } else {
          // En plataformas nativas como Windows, Android, etc.
          await Hive.initFlutter();
          Logger.info('Hive inicializado para plataforma nativa');
        }
      } catch (e) {
        // Si ya está inicializado, esto puede lanzar un error que podemos ignorar
        Logger.info('Hive ya está inicializado o hubo un problema menor: $e');
      }
      
      // Verificar si los adaptadores están registrados
      try {
        if (!Hive.isAdapterRegistered(0)) { // Flashcard adapter
          Hive.registerAdapter(FlashcardAdapter());
          Hive.registerAdapter(MultipleChoiceQuestionAdapter());
        }
      } catch (e) {
        // Continuamos de todos modos
        Logger.info('Los adaptadores podrían estar ya registrados: $e');
      }
      
      // Abrir las boxes básicas
      await Future.wait([
        _openBox(decksBoxName),
        _openBox(settingsBoxName),
        _openBox(statsBoxName),
      ]);
      
      _initialized = true;
      _initCompleter!.complete();
    } catch (e) {
      Logger.error('Error grave al inicializar la base de datos', e);
      _initCompleter!.completeError(e);
      throw Exception('Error inicializando la base de datos: $e');
    }
  }
  
  // Método auxiliar para abrir una box con manejo de errores
  Future<void> _openBox(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      Logger.db('Box "$boxName" ya está abierta');
      return;
    }
    
    try {
      Logger.db('Intentando abrir box "$boxName"');
      
      // Verificamos si estamos en plataforma web (como Chrome)
      if (kIsWeb) {
        // Configuración especial para navegadores
        Logger.db('Detectada plataforma web, usando configuración especial para "$boxName"');
        
        // En web, es importante esperar un poco para garantizar que IndexedDB esté listo
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Para plataformas web no pasamos path porque causa problemas
        final box = await Hive.openBox(boxName);
        
        // Verificamos que la box se haya abierto correctamente
        // Y forzamos una operación de escritura para garantizar persistencia
        if (!box.containsKey('_web_init_key')) {
          await box.put('_web_init_key', true);
        }
      } else {
        // En plataformas nativas, el comportamiento normal es suficiente
        await Hive.openBox(boxName);
      }
      
      Logger.db('Box "$boxName" abierta con éxito');
    } catch (e) {
      // Intentar recuperación eliminando archivo corrupto
      Logger.error('Error al abrir box "$boxName", intentando recuperación', e);
      try {
        await Hive.deleteBoxFromDisk(boxName);
        await Hive.openBox(boxName);
        Logger.db('Box "$boxName" recuperada tras eliminar archivo corrupto');
      } catch (recoverError) {
        Logger.error('Fallo crítico en recuperación de box "$boxName"', recoverError);
        throw Exception('No se puede abrir la base de datos "$boxName". Intenta reinstalar la aplicación.');
      }
    }
  }

  /// Obtiene las flashcards de una baraja de forma segura
  Future<List<Flashcard>> getFlashcards(String deckName) async {
    if (deckName.isEmpty) {
      throw Exception('No se puede obtener flashcards con nombre de baraja vacío');
    }
    
    try {
      return await _safeBoxOperation(decksBoxName, (box) async {
        final stored = box.get(deckName);
        if (stored == null) return <Flashcard>[];
        
        // Manejamos formatos diferentes con manejo de errores
        try {
          if (stored is Map && stored.containsKey('flashcards')) {
            final flashcardsData = stored['flashcards'];
            if (flashcardsData is List) {
              return List<Flashcard>.from(flashcardsData);
            }
          } else if (stored is List) {
            return List<Flashcard>.from(stored);
          }
        } catch (e) {
          rethrow;
        }
        
        return <Flashcard>[];
      });
    } catch (e) {
      throw Exception('Error obteniendo flashcards: $e');
    }
  }

  /// Obtiene las preguntas de opción múltiple de una baraja de forma segura
  Future<List<MultipleChoiceQuestion>> getQuestions(String deckName) async {
    if (deckName.isEmpty) {
      throw Exception('No se puede obtener preguntas con nombre de baraja vacío');
    }
    
    try {
      // Primero intentamos con la box principal
      return await _safeBoxOperation(decksBoxName, (box) async {
        final stored = box.get(deckName);
        if (stored != null && stored is Map && stored.containsKey('questions')) {
          final questionsData = stored['questions'];
          if (questionsData is List) {
            try {
              return List<MultipleChoiceQuestion>.from(questionsData);
            } catch (e) {
              rethrow;
            }
          }
        }
        return <MultipleChoiceQuestion>[];
      });
    } catch (e) {
      throw Exception('Error obteniendo preguntas: $e');
    }
  }

  /// Guarda una baraja completa con su nombre, tarjetas y preguntas de forma segura
  Future<void> saveDeck(String deckName, List<Flashcard> flashcards,
      [List<MultipleChoiceQuestion>? questions]) async {
    if (deckName.isEmpty) {
      throw Exception('No se puede guardar una baraja con nombre vacío');
    }
    
    // Asegurarnos de que flashcards no sea null
    final List<Flashcard> safeFlashcards = flashcards;
    // Asegurarnos de que questions no sea null
    final List<MultipleChoiceQuestion> safeQuestions = questions ?? [];
    
    try {
      await _safeBoxOperation(decksBoxName, (box) async {
        // Preparar los datos para guardar
        final Map<String, dynamic> deckData = {
          'flashcards': safeFlashcards,
          'questions': safeQuestions,
          'updatedAt': DateTime.now().toIso8601String(),
        };
        
        // Si existe y es un mapa, preservar metadatos
        final existing = box.get(deckName);
        if (existing is Map) {
          deckData['createdAt'] = existing['createdAt'] ?? DateTime.now().toIso8601String();
          deckData['lastStudied'] = existing['lastStudied'];
        } else {
          deckData['createdAt'] = DateTime.now().toIso8601String();
          deckData['lastStudied'] = null;
        }
        
        // Guardar la baraja en formato unificado
        await box.put(deckName, deckData);
        return true;
      });
    } catch (e) {
      throw Exception('Error al guardar baraja: $e');
    }
  }

  /// Actualiza propiedades de una baraja existente de forma segura
  Future<void> updateDeck(String deckName, Map<String, dynamic> updates) async {
    if (deckName.isEmpty) {
      throw Exception('No se puede actualizar una baraja con nombre vacío');
    }
    
    if (updates.isEmpty) {
      return; // No hay nada que hacer
    }
    
    try {
      await _safeBoxOperation(decksBoxName, (box) async {
        final existing = box.get(deckName);
        if (existing == null) {
          return false;
        }
        
        if (existing is Map) {
          // Formato nuevo - fusión de mapas
          final updatedDeck = {...existing, ...updates};
          await box.put(deckName, updatedDeck);
          return true;
        } else if (existing is List && updates.containsKey('flashcards')) {
          // Formato antiguo - actualización directa de la lista
          await box.put(deckName, updates['flashcards']);
          return true;
        } else {
          return false;
        }
      });
    } catch (e) {
      throw Exception('Error al actualizar baraja: $e');
    }
  }

  /// Elimina una baraja de forma segura
  Future<void> deleteDeck(String deckName) async {
    if (deckName.isEmpty) {
      throw Exception('No se puede eliminar una baraja con nombre vacío');
    }
    
    try {
      await _safeBoxOperation(decksBoxName, (box) async {
        if (!box.containsKey(deckName)) {
          return false;
        }
        
        await box.delete(deckName);
        return true;
      });
    } catch (e) {
      throw Exception('Error al eliminar baraja: $e');
    }
  }

  /// Obtiene los nombres de todas las barajas de forma segura
  Future<List<String>> getAllDeckNames() async {
    try {
      return await _safeBoxOperation(decksBoxName, (box) async {
        final keys = box.keys.cast<String>().toList();
        keys.sort();
        return keys;
      });
    } catch (e) {
      throw Exception('Error obteniendo nombres de barajas: $e');
    }
  }

  // Métodos para configuraciones de la aplicación de forma segura
  Future<void> saveSettings(String key, dynamic value) async {
    if (key.isEmpty) {
      throw Exception('No se puede guardar configuración con clave vacía');
    }
    
    try {
      await _safeBoxOperation(settingsBoxName, (box) async {
        await box.put(key, value);
        return true;
      });
    } catch (e) {
      throw Exception('Error al guardar configuración: $e');
    }
  }

  Future<T> getSettings<T>(String key, {T? defaultValue}) async {
    if (key.isEmpty) {
      return defaultValue as T;
    }
    
    try {
      return await _safeBoxOperation(settingsBoxName, (box) async {
        final value = box.get(key, defaultValue: defaultValue);
        return value as T;
      });
    } catch (e) {
      return defaultValue as T;
    }
  }

  // Métodos para estadísticas de estudio de forma segura
  Future<void> saveStudySession(String deckName, int cardsStudied, int correctAnswers) async {
    if (deckName.isEmpty) {
      throw Exception('No se puede guardar una sesión de estudio sin nombre de baraja');
    }
    
    if (cardsStudied < 0 || correctAnswers < 0 || correctAnswers > cardsStudied) {
      throw Exception('Datos inválidos para estadísticas de estudio');
    }
    
    try {
      // Crear datos de sesión
      final sessionData = {
        'deckName': deckName,
        'timestamp': DateTime.now().toIso8601String(),
        'cardsStudied': cardsStudied,
        'correctAnswers': correctAnswers,
        'duration': 0, // Valor por defecto
      };
      
      // Guardar la sesión con un ID único
      final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      
      await _safeBoxOperation(statsBoxName, (box) async {
        await box.put(sessionId, sessionData);
        return true;
      });
      
      // Actualizar la fecha de último estudio del mazo
      try {
        await updateDeck(deckName, {'lastStudied': DateTime.now().toIso8601String()});
      } catch (e) {
        // No interrumpimos la ejecución si esta parte falla
      }
    } catch (e) {
      throw Exception('Error al guardar sesión de estudio: $e');
    }
  }

  /// Obtiene las estadísticas de estudio de una baraja específica
  Future<List<Map<String, dynamic>>> getStudyStatsForDeck(String deckName) async {
    if (deckName.isEmpty) {
      throw Exception('Nombre de baraja vacío al obtener estadísticas');
    }
    
    try {
      return await _safeBoxOperation(statsBoxName, (box) async {
        final List<Map<String, dynamic>> stats = [];
        
        // Recorrer todas las claves de estadísticas
        for (final key in box.keys) {
          final session = box.get(key);
          if (session != null && session is Map) {
            // Verificar si corresponde a la baraja solicitada
            final sessionDeckName = session['deckName'] ?? session['deckId'];
            if (sessionDeckName == deckName) {
              stats.add({...Map<String, dynamic>.from(session), 'id': key});
            }
          }
        }
        
        return stats;
      });
    } catch (e) {
      throw Exception('Error obteniendo estadísticas para "$deckName": $e');
    }
  }

  /// Obtiene todas las estadísticas de estudio de forma segura
  Future<List<Map<String, dynamic>>> getStudyStats() async {
    try {
      return await _safeBoxOperation(statsBoxName, (box) async {
        final statsRaw = box.get('study_stats') ?? [];
        List<Map<String, dynamic>> stats = [];
        
        if (statsRaw is List) {
          for (var item in statsRaw) {
            if (item is Map) {
              stats.add(Map<String, dynamic>.from(item));
            }
          }
        }
        
        return stats;
      });
    } catch (e) {
      throw Exception('Error obteniendo estadísticas: $e');
    }
  }

  /// Limpia todas las estadísticas de estudio de forma segura
  Future<void> clearStudyStats() async {
    try {
      await _safeBoxOperation(statsBoxName, (box) async {
        await box.delete('study_stats');
        return true;
      });
    } catch (e) {
      throw Exception('Error al limpiar estadísticas: $e');
    }
  }

  /// Método para migrar datos al nuevo formato de forma segura si es necesario
  Future<void> migrateDataIfNeeded() async {
    try {
      await _safeBoxOperation(decksBoxName, (box) async {
        bool needsMigration = false;
        
        // Verificar si hay barajas en formato antiguo (List<Flashcard>)
        for (final key in box.keys) {
          final value = box.get(key);
          if (value is List) {
            needsMigration = true;
            break;
          }
        }
        
        if (!needsMigration) {
          return false;
        }
        
        // Iterar sobre todas las barajas
        for (final deckName in box.keys.cast<String>().toList()) {
          final value = box.get(deckName);
          
          // Solo migrar si es una lista (formato antiguo)
          if (value is List) {
            try {
              final flashcards = List<Flashcard>.from(value);
              
              // Guardar en el nuevo formato
              await box.put(deckName, {
                'flashcards': flashcards,
                'questions': <MultipleChoiceQuestion>[],
                'createdAt': DateTime.now().toIso8601String(),
                'lastStudied': null,
              });
            } catch (e) {
              // Continuamos con la siguiente baraja
            }
          }
        }
        
        return true;
      });
    } catch (e) {
      // No lanzamos excepción para no interrumpir la inicialización
    }
  }

  /// Método para limpiar todos los datos de forma segura (útil para pruebas o reset)
  Future<void> clearAllData() async {
    try {
      // Limpiar cajas principales
      await Future.wait([
        _safeBoxOperation(decksBoxName, (box) async {
          await box.clear();
          return true;
        }),
        _safeBoxOperation(settingsBoxName, (box) async {
          await box.clear();
          return true;
        }),
        _safeBoxOperation(statsBoxName, (box) async {
          await box.clear();
          return true;
        }),
      ]);
    } catch (e) {
      throw Exception('Error al limpiar todos los datos: $e');
    }
  }

}