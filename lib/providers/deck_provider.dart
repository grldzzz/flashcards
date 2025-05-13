import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math';
import '../models/flashcard.dart';
import '../models/multiple_choice_question.dart';
import '../services/db_service.dart';

class DeckProvider extends ChangeNotifier {
  // Instancia del servicio de base de datos
  final DbService _dbService = DbService();
  
  // Constructor que inicializa el servicio si es necesario
  DeckProvider() {
    _initializeDbService();
  }
  
  // Inicializar el servicio de base de datos si es necesario
  Future<void> _initializeDbService() async {
    try {
      // Intentar migrar datos al nuevo formato si es necesario
      await _dbService.migrateDataIfNeeded();
    } catch (e) {
      print('Error inicializando DbService en DeckProvider: $e');
      // No relanzamos la excepción para evitar romper la UI
    }
  }

  // Cache para los nombres de las barajas (optimización)
  List<String>? _cachedDeckNames;
  
  /// Nombres de todas las barajas
  Future<List<String>> getDeckNames() async {
    try {
      // Usar cache si está disponible
      if (_cachedDeckNames != null) return _cachedDeckNames!;
      
      // Obtener nuevos datos
      final names = await _dbService.getAllDeckNames();
      _cachedDeckNames = names;
      return names;
    } catch (e) {
      print('Error obteniendo nombres de barajas: $e');
      return [];
    }
  }
  
  /// Obtiene los nombres de barajas de forma síncronizada (para compatibilidad)
  List<String> get deckNames {
    return _cachedDeckNames ?? [];
  }

  /// Obtiene las flashcards de una baraja de forma asíncrona
  Future<List<Flashcard>> getFlashcardsAsync(String deckName) async {
    try {
      return await _dbService.getFlashcards(deckName);
    } catch (e) {
      print('Error obteniendo flashcards: $e');
      return [];
    }
  }
  
  /// Obtiene las flashcards de forma síncronizada (para compatibilidad)
  List<Flashcard> getFlashcards(String deckName) {
    // Devolvemos una lista vacía y dejaremos que la versión asíncrona actualice la UI
    return [];
  }
  
  /// Obtiene las preguntas de opción múltiple de una baraja de forma asíncrona
  Future<List<MultipleChoiceQuestion>> getQuestionsAsync(String deckName) async {
    try {
      return await _dbService.getQuestions(deckName);
    } catch (e) {
      print('Error obteniendo preguntas: $e');
      return [];
    }
  }
  
  /// Obtiene las preguntas de opción múltiple de forma síncronizada (para compatibilidad)
  List<MultipleChoiceQuestion> getQuestions(String deckName) {
    // Devolvemos una lista vacía y dejaremos que la versión asíncrona actualice la UI
    return [];
  }

  /// Crea una nueva baraja vacía
  Future<void> addDeck(String name) async {
    try {
      if (name.isEmpty) throw Exception('El nombre no puede estar vacío.');
      if (deckNames.contains(name)) {
        throw Exception('La baraja "$name" ya existe.');
      }
      await _dbService.saveDeck(name, <Flashcard>[]);
      notifyListeners();
    } catch (e) {
      print('Error al crear baraja: $e');
      rethrow;
    }
  }

  /// Elimina una baraja
  Future<void> deleteDeck(String name) async {
    try {
      if (deckNames.contains(name)) {
        await _dbService.deleteDeck(name);
        notifyListeners();
      }
    } catch (e) {
      print('Error al eliminar baraja: $e');
      // No relanzamos la excepción para evitar fallos en la UI
    }
  }

  /// Renombra una baraja
  Future<void> renameDeck(String oldName, String newName) async {
    try {
      if (newName.isEmpty) throw Exception('El nuevo nombre no puede estar vacío.');
      if (deckNames.contains(newName)) {
        throw Exception('Ya existe una baraja llamada "$newName".');
      }
      
      if (deckNames.contains(oldName)) {
        final cards = getFlashcards(oldName);
        final questions = getQuestions(oldName);
        await _dbService.deleteDeck(oldName);
        await _dbService.saveDeck(newName, cards, questions);
        notifyListeners();
      }
    } catch (e) {
      print('Error al renombrar baraja: $e');
      rethrow;
    }
  }

  /// Añade una flashcard a la baraja
  Future<void> addFlashcard(String deckName, Flashcard card) async {
    if (deckName.isEmpty) {
      print('Error: Nombre de baraja vacío al añadir flashcard');
      throw Exception('El nombre de la baraja no puede estar vacío');
    }
    
    if (card.question.isEmpty || card.answer.isEmpty) {
      print('Error: Flashcard con contenido vacío');
      throw Exception('La tarjeta debe tener pregunta y respuesta');
    }
    
    try {
      print('Añadiendo flashcard a "$deckName": ${card.question.substring(0, min(20, card.question.length))}...');
      
      // Verificar si la baraja existe, si no, la creamos
      if (!deckNames.contains(deckName)) {
        print('Baraja "$deckName" no existe. Creándola...');
        await addDeck(deckName);
      }
      
      // Obtener flashcards existentes
      final cards = getFlashcards(deckName);
      cards.add(card);
      
      // Obtener preguntas existentes
      final questions = getQuestions(deckName);
      
      // Guardar la baraja actualizada
      await _dbService.saveDeck(deckName, cards, questions);
      print('Flashcard añadida con éxito a "$deckName". Total: ${cards.length} tarjetas');
      
      notifyListeners();
    } catch (e) {
      print('Error al añadir flashcard a "$deckName": $e');
      // Añadir detalles del error para depuración
      print('Detalles de la flashcard - Pregunta: ${card.question.substring(0, min(30, card.question.length))}...');
      rethrow;
    }
  }

  /// Quita la flashcard [index] de la baraja
  Future<void> removeFlashcard(String deckName, int index) async {
    try {
      final cards = getFlashcards(deckName);
      if (index < 0 || index >= cards.length) return;
      cards.removeAt(index);
      final questions = getQuestions(deckName);
      await _dbService.saveDeck(deckName, cards, questions);
      notifyListeners();
    } catch (e) {
      print('Error al eliminar flashcard: $e');
      // No relanzamos la excepción para evitar fallos en la UI
    }
  }
  
  /// Añade varias flashcards a una baraja
  Future<void> addFlashcards(String deckName, List<Flashcard> newCards) async {
    if (deckName.isEmpty) {
      print('Error: Nombre de baraja vacío al añadir múltiples flashcards');
      throw Exception('El nombre de la baraja no puede estar vacío');
    }
    
    if (newCards.isEmpty) {
      print('Advertencia: Se intentó añadir una lista vacía de flashcards');
      return; // No hay necesidad de continuar si no hay tarjetas para añadir
    }
    
    try {
      print('Añadiendo ${newCards.length} flashcards a "$deckName"');
      
      // Verificar si la baraja existe, si no, la creamos
      if (!deckNames.contains(deckName)) {
        print('Baraja "$deckName" no existe. Creándola...');
        await addDeck(deckName);
      }
      
      // Obtener flashcards existentes
      final cards = getFlashcards(deckName);
      
      // Filtrar tarjetas vacías o inválidas antes de añadirlas
      int tarjetasValidas = 0;
      for (final card in newCards) {
        if (card.question.isNotEmpty && card.answer.isNotEmpty) {
          cards.add(card);
          tarjetasValidas++;
        } else {
          print('Advertencia: Ignorando flashcard inválida (pregunta o respuesta vacía)');
        }
      }
      
      // Obtener preguntas existentes
      final questions = getQuestions(deckName);
      
      // Guardar la baraja actualizada
      await _dbService.saveDeck(deckName, cards, questions);
      print('${tarjetasValidas} flashcards añadidas con éxito a "$deckName". Total: ${cards.length} tarjetas');
      
      notifyListeners();
    } catch (e) {
      print('Error al añadir múltiples flashcards a "$deckName": $e');
      rethrow;
    }
  }
  
  /// Añade preguntas de opción múltiple a una baraja
  Future<void> addMultipleChoiceQuestions(String deckName, List<MultipleChoiceQuestion> newQuestions) async {
    try {
      // Verificar si la baraja existe, si no, la creamos
      if (!deckNames.contains(deckName)) {
        await addDeck(deckName);
      }
      
      final cards = getFlashcards(deckName);
      final questions = getQuestions(deckName);
      questions.addAll(newQuestions);
      await _dbService.saveDeck(deckName, cards, questions);
      notifyListeners();
    } catch (e) {
      print('Error al añadir preguntas: $e');
      rethrow;
    }
  }
}
