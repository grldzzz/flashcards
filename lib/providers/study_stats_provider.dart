import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/db_service.dart';

/// Proveedor para manejar estadísticas de estudio usando DbService
class StudyStatsProvider extends ChangeNotifier {
  // Referencia al servicio de base de datos
  final DbService _dbService = DbService();
  
  // Datos en memoria
  int _totalCardsStudied = 0;
  int _totalCorrectAnswers = 0;
  int _totalTimeSpent = 0; // en segundos
  int _sessionsCompleted = 0;
  List<Map<String, dynamic>> _sessionHistory = [];
  String? _lastStudyDate;
  
  // Constructor
  StudyStatsProvider() {
    _loadStats();
  }
  
  // Cargar estadísticas guardadas
  Future<void> _loadStats() async {
    try {
      // Convertir todos los métodos a async ya que ahora DbService es asíncrono
      _totalCardsStudied = await _dbService.getSettings('totalCardsStudied', defaultValue: 0);
      _totalCorrectAnswers = await _dbService.getSettings('totalCorrectAnswers', defaultValue: 0);
      _totalTimeSpent = await _dbService.getSettings('totalTimeSpent', defaultValue: 0);
      _sessionsCompleted = await _dbService.getSettings('sessionsCompleted', defaultValue: 0);
      _lastStudyDate = await _dbService.getSettings('lastStudyDate');
      
      // Cargar historial de sesiones
      await _loadSessionHistory();
      
      print('Estadísticas cargadas: $_totalCardsStudied tarjetas, $_sessionsCompleted sesiones');
      notifyListeners(); // Notificar a los widgets para que se actualicen
    } catch (e) {
      print('Error cargando estadísticas: $e');
    }
  }
  
  // Cargar historial de sesiones de forma asíncrona
  Future<void> _loadSessionHistory() async {
    try {
      // Obtener todos los nombres de barajas (ahora es asíncrono)
      final allDecks = await _dbService.getAllDeckNames();
      _sessionHistory = [];
      
      // Usar Future.wait para cargar todas las estadísticas en paralelo
      if (allDecks.isNotEmpty) {
        final allStats = await Future.wait(
          allDecks.map((deck) => _dbService.getStudyStatsForDeck(deck))
        );
        
        // Agregar todas las estadísticas al historial
        for (final deckStats in allStats) {
          _sessionHistory.addAll(deckStats);
        }
        
        // Ordenar por fecha (más reciente primero)
        _sessionHistory.sort((a, b) {
          final dateA = a['timestamp'] ?? '';
          final dateB = b['timestamp'] ?? '';
          return dateB.compareTo(dateA);
        });
      }
      
      print('Historial de sesiones cargado: ${_sessionHistory.length} sesiones');
    } catch (e) {
      print('Error cargando historial de sesiones: $e');
    }
  }
  
  /// Inicializa la box de estadísticas
  static Future<void> initialize() async {
    try {
      // El DbService ya debe estar inicializado en main.dart
      // No es necesario hacer nada adicional aquí
      print('StudyStatsProvider inicializado');
    } catch (e) {
      print('Error inicializando StudyStatsProvider: $e');
    }
  }
  
  /// Registra una sesión de estudio completa
  Future<void> recordStudySession({
    required String deckName, 
    required int cardsStudied, 
    required int correctAnswers,
    required int duration, // duración en segundos
  }) async {
    try {
      // Actualizar totales en memoria
      _totalCardsStudied += cardsStudied;
      _totalCorrectAnswers += correctAnswers;
      _totalTimeSpent += duration;
      _sessionsCompleted++;
      _lastStudyDate = DateTime.now().toIso8601String();
      
      // Guardar los totales en ajustes generales
      await _dbService.saveSettings('totalCardsStudied', _totalCardsStudied);
      await _dbService.saveSettings('totalCorrectAnswers', _totalCorrectAnswers);
      await _dbService.saveSettings('totalTimeSpent', _totalTimeSpent);
      await _dbService.saveSettings('sessionsCompleted', _sessionsCompleted);
      await _dbService.saveSettings('lastStudyDate', _lastStudyDate);
      
      // Guardar la sesión individual para estadísticas detalladas
      await _dbService.saveStudySession(deckName, cardsStudied, correctAnswers);
      
      // Recargar historial de sesiones
      _loadSessionHistory();
      
      print('Sesión registrada: $cardsStudied tarjetas para $deckName');
    } catch (e) {
      print('Error guardando estadísticas: $e');
    }
    
    notifyListeners();
  }
  
  /// Getters básicos para estadísticas
  int get totalCardsStudied => _totalCardsStudied;
  int get totalCorrectAnswers => _totalCorrectAnswers;
  int get totalTimeSpent => _totalTimeSpent;
  int get sessionsCompleted => _sessionsCompleted;
  
  /// Obtiene el promedio de puntuación (porcentaje de aciertos)
  double get averageScore {
    if (_totalCardsStudied == 0) return 0.0;
    return (_totalCorrectAnswers / _totalCardsStudied) * 100;
  }
  
  /// Obtiene una racha de estudio simulada (1-5 días)
  int get currentStreak => _sessionsCompleted.clamp(0, 5);
  
  /// Obtiene el tiempo total de estudio (formateado)
  String get totalTimeFormatted {
    final hours = _totalTimeSpent ~/ 3600;
    final minutes = (_totalTimeSpent % 3600) ~/ 60;
    
    if (hours > 0) {
      return '$hours h $minutes min';
    } else {
      return '$minutes min';
    }
  }
  
  /// Obtiene solo las estadísticas REALES de la última semana (sin datos ficticios)
  List<Map<String, dynamic>> get lastWeekStats {
    List<Map<String, dynamic>> results = [];
    final today = DateTime.now();
    
    // Crear estructura para los últimos 7 días (pero sin datos iniciales)
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dateString = _formatDateForComparison(date);
      
      results.add({
        'date': date.millisecondsSinceEpoch,
        'dateString': dateString,
        'stats': {
          'totalCardsStudied': 0,
          'totalCorrectAnswers': 0,
          'totalTimeSpent': 0,
          'sessions': 0,
        },
        // Agregamos una bandera para indicar si hay datos reales
        'hasRealData': false,
      });
    }
    
    // Si no hay historial, devolver los días vacíos
    if (_sessionHistory.isEmpty) {
      return results;
    }
    
    try {
      // Filtrar sesiones de la última semana y agruparlas por día
      final lastWeekDate = today.subtract(const Duration(days: 7));
      
      for (final session in _sessionHistory) {
        // Convertir timestamp a DateTime
        final timestamp = session['timestamp'];
        if (timestamp == null) continue;
        
        DateTime sessionDate;
        try {
          sessionDate = DateTime.parse(timestamp);
        } catch (e) {
          print('Error al parsear fecha de sesión: $e');
          continue; // Si no podemos parsear la fecha, ignoramos esta sesión
        }
        
        // Solo considerar sesiones de la última semana
        if (sessionDate.isBefore(lastWeekDate)) {
          continue;
        }
        
        // Convertir a formato de comparación (YYYY-MM-DD)
        final dateString = _formatDateForComparison(sessionDate);
        
        // Buscar el día correspondiente en los resultados
        for (final day in results) {
          if (day['dateString'] == dateString) {
            // Asegurarse de que los datos tengan sentido
            final cardsStudied = session['cardsStudied'] is int ? session['cardsStudied'] : 0;
            final correctAnswers = session['correctAnswers'] is int ? session['correctAnswers'] : 0;
            
            // Solo actualizar si son datos válidos
            if (cardsStudied > 0) {
              final stats = day['stats'] as Map<String, dynamic>;
              
              // Actualizar estadísticas del día
              stats['totalCardsStudied'] = (stats['totalCardsStudied'] ?? 0) + cardsStudied;
              stats['totalCorrectAnswers'] = (stats['totalCorrectAnswers'] ?? 0) + correctAnswers;
              stats['sessions'] = (stats['sessions'] ?? 0) + 1;
              
              // Estimación del tiempo si no está disponible
              if (session.containsKey('duration')) {
                stats['totalTimeSpent'] = (stats['totalTimeSpent'] ?? 0) + (session['duration'] ?? 0);
              } else {
                // Estimación basada en cantidad de tarjetas (promedio 10 segundos por tarjeta)
                final estimatedTime = cardsStudied * 10;
                stats['totalTimeSpent'] = (stats['totalTimeSpent'] ?? 0) + estimatedTime;
              }
              
              // Marcar que este día tiene datos reales
              day['hasRealData'] = true;
            }
            break;
          }
        }
      }
      
      return results;
    } catch (e) {
      print('Error calculando estadísticas de la semana: $e');
      return results;
    }
  }
  
  // Formatea una fecha como YYYY-MM-DD para comparaciones
  String _formatDateForComparison(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  /// Datos simulados para las estadísticas totales
  Map<String, dynamic> get totalStats {
    return {
      'totalCardsStudied': _totalCardsStudied,
      'totalCorrectAnswers': _totalCorrectAnswers,
      'totalTimeSpent': _totalTimeSpent,
      'totalSessions': _sessionsCompleted,
      'startDate': DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch,
      'lastSession': DateTime.now().millisecondsSinceEpoch,
      'studyStreak': currentStreak,
    };
  }
}
