import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/flashcard.dart';
import '../models/multiple_choice_question.dart';

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

  // Nombres de boxes
  static const String decksBoxName = 'decks';
  static const String settingsBoxName = 'app_settings';
  static const String statsBoxName = 'study_stats';
  
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
        print('Error esperando inicialización: $e');
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
      print('Error en operación de base de datos ($boxName): $e');
      // Reintento con apertura forzada si es un error de acceso
      try {
        if (box == null) {
          box = await Hive.openBox(boxName, path: null);
          return await operation(box);
        }
      } catch (reopenError) {
        print('Error en segundo intento: $reopenError');
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
      print('DbService: Inicialización ya en progreso, esperando...');
      return _initCompleter!.future;
    }
    
    // Crear un nuevo completer para esta inicialización
    _initCompleter = Completer<void>();
    
    try {
      print('DbService: Inicializando...');
      
      // Intentar inicializar Hive si es necesario
      try {
        print('Intentando inicializar Hive...');
        await Hive.initFlutter();
      } catch (e) {
        // Si ya está inicializado, esto puede lanzar un error que podemos ignorar
        print('Nota: Hive posiblemente ya está inicializado: $e');
      }
      
      // Verificar si los adaptadores están registrados
      try {
        if (!Hive.isAdapterRegistered(0)) { // Flashcard adapter
          print('Advertencia: Adaptadores no registrados. Intentando registrar...');
          Hive.registerAdapter(FlashcardAdapter());
          Hive.registerAdapter(MultipleChoiceQuestionAdapter());
        }
      } catch (e) {
        print('Error al verificar adaptadores: $e');
        // Continuamos de todos modos
      }
      
      // Abrir las boxes básicas
      await Future.wait([
        _openBox(decksBoxName),
        _openBox(settingsBoxName),
        _openBox(statsBoxName),
      ]);
      
      print('DbService: Inicializado correctamente');
      _initialized = true;
      _initCompleter!.complete();
    } catch (e) {
      print('DbService: Error crítico durante la inicialización: $e');
      _initCompleter!.completeError(e);
      throw Exception('Error inicializando la base de datos: $e');
    }
  }
  
  // Método auxiliar para abrir una box con manejo de errores
  Future<void> _openBox(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      print('Box "$boxName" ya está abierta');
      return;
    }
    
    try {
      print('Abriendo box "$boxName"...');
      await Hive.openBox(boxName);
      print('Box "$boxName" abierta con éxito');
    } catch (e) {
      print('Error al abrir box "$boxName": $e');
      
      // Intentar recuperación eliminando archivo corrupto
      try {
        print('Intentando recuperación de "$boxName"...');
        await Hive.deleteBoxFromDisk(boxName);
        await Hive.openBox(boxName);
        print('Recuperación exitosa para "$boxName"');
      } catch (recoverError) {
        print('Fallo en la recuperación de "$boxName": $recoverError');
        throw Exception('No se puede abrir la base de datos "$boxName". Intenta reinstalar la aplicación.');
      }
    }
  }

  /// Obtiene las flashcards de una baraja de forma segura
  Future<List<Flashcard>> getFlashcards(String deckName) async {
    if (deckName.isEmpty) {
      print('Error: Nombre de baraja vacío al obtener flashcards');
      return [];
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
          print('Error convirtiendo flashcards: $e');
        }
        
        return <Flashcard>[];
      });
    } catch (e) {
      print('Error crítico obteniendo flashcards: $e');
      return [];
    }
  }

  /// Obtiene las preguntas de opción múltiple de una baraja de forma segura
  Future<List<MultipleChoiceQuestion>> getQuestions(String deckName) async {
    if (deckName.isEmpty) {
      print('Error: Nombre de baraja vacío al obtener preguntas');
      return [];
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
              print('Error convirtiendo preguntas: $e');
            }
          }
        }
        return <MultipleChoiceQuestion>[];
      });
    } catch (e) {
      print('Error obteniendo preguntas para "$deckName": $e');
      return [];
    }
  }

  /// Guarda una baraja completa con su nombre, tarjetas y preguntas de forma segura
  Future<void> saveDeck(String deckName, List<Flashcard> flashcards,
      [List<MultipleChoiceQuestion>? questions]) async {
    if (deckName.isEmpty) {
      print('Error: No se puede guardar una baraja con nombre vacío');
      throw Exception('No se puede guardar una baraja con nombre vacío');
    }
    
    // Asegurarnos de que flashcards no sea null
    final List<Flashcard> safeFlashcards = flashcards ?? [];
    // Asegurarnos de que questions no sea null
    final List<MultipleChoiceQuestion> safeQuestions = questions ?? [];
    
    try {
      await _safeBoxOperation(decksBoxName, (box) async {
        print('Guardando baraja "$deckName" con ${safeFlashcards.length} tarjetas y ${safeQuestions.length} preguntas');
        
        // Verificar si la baraja ya existe
        final existing = box.get(deckName);
        
        // Preparar los datos para guardar
        final Map<String, dynamic> deckData = {
          'flashcards': safeFlashcards,
          'questions': safeQuestions,
          'updatedAt': DateTime.now().toIso8601String(),
        };
        
        // Si existe y es un mapa, preservar metadatos
        if (existing is Map) {
          deckData['createdAt'] = existing['createdAt'] ?? DateTime.now().toIso8601String();
          deckData['lastStudied'] = existing['lastStudied'];
        } else {
          deckData['createdAt'] = DateTime.now().toIso8601String();
          deckData['lastStudied'] = null;
        }
        
        // Guardar la baraja en formato unificado
        await box.put(deckName, deckData);
        print('Baraja "$deckName" guardada con éxito');
        
        return true;
      });
    } catch (e) {
      print('Error crítico al guardar baraja "$deckName": $e');
      throw Exception('Error al guardar baraja: $e');
    }
  }

  /// Actualiza propiedades de una baraja existente de forma segura
  Future<void> updateDeck(String deckName, Map<String, dynamic> updates) async {
    if (deckName.isEmpty) {
      print('Error: No se puede actualizar una baraja con nombre vacío');
      throw Exception('No se puede actualizar una baraja con nombre vacío');
    }
    
    if (updates.isEmpty) {
      print('Advertencia: Se intentó actualizar una baraja con actualizaciones vacías');
      return; // No hay nada que hacer
    }
    
    try {
      await _safeBoxOperation(decksBoxName, (box) async {
        final existing = box.get(deckName);
        if (existing == null) {
          print('No se encontró la baraja "$deckName" para actualizar');
          return false;
        }
        
        if (existing is Map) {
          // Formato nuevo - fusión de mapas
          final updatedDeck = {...existing, ...updates};
          await box.put(deckName, updatedDeck);
          print('Baraja "$deckName" actualizada (formato nuevo)');
        } else if (existing is List && updates.containsKey('flashcards')) {
          // Formato antiguo - actualización directa de la lista
          await box.put(deckName, updates['flashcards']);
          print('Baraja "$deckName" actualizada (formato antiguo)');
        } else {
          print('Formato no reconocido para baraja "$deckName"');
          return false;
        }
        
        return true;
      });
    } catch (e) {
      print('Error crítico al actualizar baraja "$deckName": $e');
      throw Exception('Error al actualizar baraja: $e');
    }
  }

  /// Elimina una baraja de forma segura
  Future<void> deleteDeck(String deckName) async {
    if (deckName.isEmpty) {
      print('Error: No se puede eliminar una baraja con nombre vacío');
      throw Exception('No se puede eliminar una baraja con nombre vacío');
    }
    
    try {
      await _safeBoxOperation(decksBoxName, (box) async {
        if (!box.containsKey(deckName)) {
          print('No se encontró la baraja "$deckName" para eliminar');
          return false;
        }
        
        await box.delete(deckName);
        print('Baraja "$deckName" eliminada con éxito');
        return true;
      });
    } catch (e) {
      print('Error crítico al eliminar baraja "$deckName": $e');
      throw Exception('Error al eliminar baraja: $e');
    }
  }

  /// Obtiene los nombres de todas las barajas de forma segura
  Future<List<String>> getAllDeckNames() async {
    try {
      return await _safeBoxOperation(decksBoxName, (box) async {
        final keys = box.keys.cast<String>().toList();
        keys.sort();
        print('${keys.length} nombres de barajas recuperados');
        return keys;
      });
    } catch (e) {
      print('Error crítico obteniendo nombres de barajas: $e');
      return [];
    }
  }

  // Métodos para configuraciones de la aplicación de forma segura
  Future<void> saveSettings(String key, dynamic value) async {
    if (key.isEmpty) {
      print('Error: No se puede guardar una configuración con clave vacía');
      throw Exception('No se puede guardar configuración con clave vacía');
    }
    
    try {
      await _safeBoxOperation(settingsBoxName, (box) async {
        await box.put(key, value);
        print('Configuración "$key" guardada correctamente');
        return true;
      });
    } catch (e) {
      print('Error crítico guardando configuración "$key": $e');
      throw Exception('Error al guardar configuración: $e');
    }
  }

  Future<T> getSettings<T>(String key, {T? defaultValue}) async {
    if (key.isEmpty) {
      print('Advertencia: Intentando obtener configuración con clave vacía');
      return defaultValue as T;
    }
    
    try {
      return await _safeBoxOperation(settingsBoxName, (box) async {
        final value = box.get(key, defaultValue: defaultValue);
        return value as T;
      });
    } catch (e) {
      print('Error obteniendo configuración "$key": $e');
      return defaultValue as T;
    }
  }

  // Métodos para estadísticas de estudio de forma segura
  Future<void> saveStudySession(String deckName, int cardsStudied, int correctAnswers) async {
    if (deckName.isEmpty) {
      print('Error: No se puede guardar una sesión de estudio sin nombre de baraja');
      throw Exception('No se puede guardar una sesión de estudio sin nombre de baraja');
    }
    
    if (cardsStudied < 0 || correctAnswers < 0 || correctAnswers > cardsStudied) {
      print('Error: Datos inválidos para estadísticas de estudio');
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
        print('Sesión de estudio para "$deckName" guardada correctamente');
        return true;
      });
      
      // Actualizar la fecha de último estudio del mazo
      try {
        await updateDeck(deckName, {'lastStudied': DateTime.now().toIso8601String()});
      } catch (e) {
        print('Advertencia: No se pudo actualizar fecha de último estudio: $e');
        // No interrumpimos la ejecución si esta parte falla
      }
    } catch (e) {
      print('Error crítico guardando sesión de estudio: $e');
      throw Exception('Error al guardar sesión de estudio: $e');
    }
  }

  /// Obtiene las estadísticas de estudio de una baraja específica
  Future<List<Map<String, dynamic>>> getStudyStatsForDeck(String deckName) async {
    if (deckName.isEmpty) {
      print('Error: Nombre de baraja vacío al obtener estadísticas');
      return [];
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
        
        print('${stats.length} registros de estadísticas encontrados para "$deckName"');
        return stats;
      });
    } catch (e) {
      print('Error crítico obteniendo estadísticas para "$deckName": $e');
      return [];
    }
  }

  /// Valida el formato de las estadísticas
  bool _validateStudyStats(Map<String, dynamic> stats) {
    // Campos requeridos
    final requiredFields = ['deckName', 'cardsStudied', 'correctAnswers'];
    for (var field in requiredFields) {
      if (!stats.containsKey(field)) {
        print('Estadísticas inválidas: falta campo "$field"');
        return false;
      }
    }
    
    // Validar tipos de datos
    if (stats['deckName'] is! String) return false;
    if (stats['cardsStudied'] is! int) return false;
    if (stats['correctAnswers'] is! int) return false;
    
    return true;
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
        
        print('${stats.length} registros de estadísticas recuperados');
        return stats;
      });
    } catch (e) {
      print('Error crítico obteniendo estadísticas: $e');
      return [];
    }
  }

  /// Limpia todas las estadísticas de estudio de forma segura
  Future<void> clearStudyStats() async {
    try {
      await _safeBoxOperation(statsBoxName, (box) async {
        await box.delete('study_stats');
        print('Estadísticas de estudio eliminadas correctamente');
        return true;
      });
    } catch (e) {
      print('Error crítico limpiando estadísticas: $e');
      throw Exception('Error al limpiar estadísticas: $e');
    }
  }

  /// Método para migrar datos al nuevo formato de forma segura si es necesario
  Future<void> migrateDataIfNeeded() async {
    print('DbService: Verificando si es necesario migrar datos...');
    
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
          print('DbService: No es necesario migrar datos');
          return false;
        }
        
        print('DbService: Migrando datos al nuevo formato...');
        int migratedCount = 0;
        
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
              
              migratedCount++;
              print('DbService: Migrada baraja "$deckName"');
            } catch (e) {
              print('Error migrando baraja "$deckName": $e');
              // Continuamos con la siguiente baraja
            }
          }
        }
        
        print('DbService: Migración completada. $migratedCount barajas migradas');
        return true;
      });
    } catch (e) {
      print('DbService: Error durante la migración: $e');
      // No lanzamos excepción para no interrumpir la inicialización
    }
  }

  /// Método para limpiar todos los datos de forma segura (útil para pruebas o reset)
  Future<void> clearAllData() async {
    print('ADVERTENCIA: Eliminando todos los datos de la aplicación');
    
    try {
      // Limpiar cajas principales
      await Future.wait([
        _safeBoxOperation(decksBoxName, (box) async {
          await box.clear();
          print('Datos de barajas eliminados');
          return true;
        }),
        _safeBoxOperation(settingsBoxName, (box) async {
          await box.clear();
          print('Configuraciones eliminadas');
          return true;
        }),
        _safeBoxOperation(statsBoxName, (box) async {
          await box.clear();
          print('Estadísticas eliminadas');
          return true;
        }),
      ]);
      
      print('Todos los datos han sido eliminados correctamente');
    } catch (e) {
      print('Error crítico al limpiar datos: $e');
      throw Exception('Error al limpiar todos los datos: $e');
    }
  }

}