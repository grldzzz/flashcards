import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math';
import '../models/flashcard.dart';
import '../models/multiple_choice_question.dart';
import '../services/db_service.dart';
import '../utils/logger.dart';

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
      Logger.error('Error inicializando DbService en DeckProvider', e);
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
      Logger.error('Error obteniendo nombres de barajas', e);
      return [];
    }
  }
  
  /// Obtiene los nombres de barajas de forma síncronizada (para compatibilidad)
  List<String> get deckNames {
    // Si no hay caché, iniciamos una carga asíncrona
    if (_cachedDeckNames == null) {
      _loadDeckNamesAsync();
      return []; // Mientras tanto devolvemos lista vacía
    }
    return _cachedDeckNames!;
  }
  
  /// Carga asíncrona de nombres de barajas en segundo plano
  Future<void> _loadDeckNamesAsync() async {
    try {
      final names = await _dbService.getAllDeckNames();
      _cachedDeckNames = names;
      // Notificar a los widgets que escuchan este provider
      notifyListeners();
      Logger.info('Cargados ${names.length} nombres de barajas desde la DB');
    } catch (e) {
      Logger.error('Error cargando nombres de barajas de forma asíncrona', e);
    }
  }

  /// Obtiene las flashcards de una baraja de forma asíncrona
  Future<List<Flashcard>> getFlashcardsAsync(String deckName) async {
    try {
      return await _dbService.getFlashcards(deckName);
    } catch (e) {
      Logger.error('Error obteniendo flashcards', e);
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
      Logger.error('Error obteniendo preguntas', e);
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
      Logger.error('Error al crear baraja', e);
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
      Logger.error('Error al eliminar baraja', e);
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
        // Usar las versiones asíncronas para obtener datos reales
        final cards = await getFlashcardsAsync(oldName);
        final questions = await getQuestionsAsync(oldName);
        
        // Eliminar la baraja antigua y crear la nueva
        await _dbService.deleteDeck(oldName);
        await _dbService.saveDeck(newName, cards, questions);
        
        // Invalidar caché para forzar recarga de datos
        _cachedDeckNames = null;
        
        Logger.info('Baraja "$oldName" renombrada a "$newName" con ${cards.length} tarjetas');
        
        notifyListeners();
      }
    } catch (e) {
      Logger.error('Error al renombrar baraja', e);
      rethrow;
    }
  }

  /// Añade una flashcard a la baraja
  Future<void> addFlashcard(String deckName, Flashcard card) async {
    if (deckName.isEmpty) {
      Logger.error('Error: Nombre de baraja vacío al añadir flashcard', null);
      throw Exception('El nombre de la baraja no puede estar vacío');
    }
    
    if (card.question.isEmpty || card.answer.isEmpty) {
      Logger.error('Error: Flashcard con contenido vacío', null);
      throw Exception('La tarjeta debe tener pregunta y respuesta');
    }
    
    try {
      Logger.db('Añadiendo flashcard a "$deckName": ${card.question.substring(0, min(20, card.question.length))}...');
      
      // Verificar si la baraja existe, si no, la creamos
      if (!deckNames.contains(deckName)) {
        print('Baraja "$deckName" no existe. Creándola...');
        await addDeck(deckName);
      }
      
      // Obtener flashcards existentes usando la versión asíncrona que realmente lee de la DB
      final cards = await getFlashcardsAsync(deckName);
      cards.add(card);
      
      // Obtener preguntas existentes usando la versión asíncrona
      final questions = await getQuestionsAsync(deckName);
      
      // Guardar la baraja actualizada
      await _dbService.saveDeck(deckName, cards, questions);
      Logger.info('Flashcard añadida con éxito a "$deckName". Total: ${cards.length} tarjetas');
      
      // Invalidar caché para forzar recarga de datos
      _cachedDeckNames = null;
      
      notifyListeners();
    } catch (e) {
      Logger.error('Error al añadir flashcard a "$deckName"', e);
      // Añadir detalles del error para depuración
      Logger.error('Detalles de la flashcard - Pregunta: ${card.question.substring(0, min(30, card.question.length))}...', null);
      rethrow;
    }
  }

  /// Quita la flashcard [index] de la baraja
  Future<void> removeFlashcard(String deckName, int index) async {
    try {
      final cards = await getFlashcardsAsync(deckName);
      if (index < 0 || index >= cards.length) return;
      cards.removeAt(index);
      final questions = await getQuestionsAsync(deckName);
      await _dbService.saveDeck(deckName, cards, questions);
      
      // Invalidar caché para forzar recarga de datos
      _cachedDeckNames = null;
      
      notifyListeners();
      
      Logger.info('Flashcard eliminada de "$deckName". Quedan: ${cards.length} tarjetas');
    } catch (e) {
      Logger.error('Error al eliminar flashcard', e);
      // No relanzamos la excepción para evitar fallos en la UI
    }
  }
  
  /// Añade varias flashcards a una baraja
  Future<void> addFlashcards(String deckName, List<Flashcard> newCards) async {
    if (deckName.isEmpty) {
      Logger.error('Error: Nombre de baraja vacío al añadir múltiples flashcards', null);
      throw Exception('El nombre de la baraja no puede estar vacío');
    }
    
    if (newCards.isEmpty) {
      Logger.info('Advertencia: Se intentó añadir una lista vacía de flashcards');
      return; // No hay necesidad de continuar si no hay tarjetas para añadir
    }
    
    try {
      Logger.db('Añadiendo ${newCards.length} flashcards a "$deckName"');
      
      // Verificar si la baraja existe, si no, la creamos
      if (!deckNames.contains(deckName)) {
        print('Baraja "$deckName" no existe. Creándola...');
        await addDeck(deckName);
      }
      
      // Obtener flashcards existentes usando la versión asíncrona
      final cards = await getFlashcardsAsync(deckName);
      
      // Filtrar tarjetas vacías o inválidas antes de añadirlas
      int tarjetasValidas = 0;
      for (final card in newCards) {
        if (card.question.isNotEmpty && card.answer.isNotEmpty) {
          cards.add(card);
          tarjetasValidas++;
        } else {
          Logger.info('Advertencia: Ignorando flashcard inválida (pregunta o respuesta vacía)');
        }
      }
      
      // Obtener preguntas existentes usando la versión asíncrona
      final questions = await getQuestionsAsync(deckName);
      
      // Guardar la baraja actualizada
      await _dbService.saveDeck(deckName, cards, questions);
      Logger.info('${tarjetasValidas} flashcards añadidas con éxito a "$deckName". Total: ${cards.length} tarjetas');
      
      // Invalidar caché para forzar recarga de datos
      _cachedDeckNames = null;
      
      notifyListeners();
    } catch (e) {
      Logger.error('Error al añadir múltiples flashcards a "$deckName"', e);
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
      Logger.error('Error al añadir preguntas', e);
      rethrow;
    }
  }
  
  /// Alternar el estado de favorito de una tarjeta
  Future<void> toggleFavorite(String deckName, Flashcard card) async {
    try {
      final cards = getFlashcards(deckName);
      final questions = getQuestions(deckName);
      
      // Encontrar la tarjeta y cambiar su estado de favorito
      for (int i = 0; i < cards.length; i++) {
        if (cards[i].question == card.question && cards[i].answer == card.answer) {
          cards[i].isFavorite = !cards[i].isFavorite;
          break;
        }
      }
      
      // Guardar los cambios
      await _dbService.saveDeck(deckName, cards, questions);
      notifyListeners();
    } catch (e) {
      Logger.error('Error al cambiar favorito', e);
      rethrow;
    }
  }
  
  /// Actualiza una flashcard específica en una baraja
  /// 
  /// Este método es importante para guardar el estado de repaso espaciado
  /// como la dificultad, fechas de repaso y estado de aprendizaje.
  Future<void> updateCard(String deckName, int index, Flashcard updatedCard) async {
    try {
      if (index < 0) {
        Logger.error('Error: Índice inválido al actualizar flashcard', null);
        throw Exception('Índice de flashcard inválido');
      }
      
      Logger.db('Actualizando flashcard #$index en "$deckName"');
      
      final cards = getFlashcards(deckName);
      if (index >= cards.length) {
        Logger.error('Error: Índice fuera de rango al actualizar flashcard', null);
        throw Exception('Índice fuera de rango');
      }
      
      // Actualizar la tarjeta en la posición especificada
      cards[index] = updatedCard;
      
      // Obtener preguntas existentes para mantenerlas
      final questions = getQuestions(deckName);
      
      // Guardar la baraja actualizada
      await _dbService.saveDeck(deckName, cards, questions);
      Logger.info('Flashcard #$index actualizada con éxito en "$deckName"');
      
      // Solo notificar si cambian datos importantes para la UI
      // El estado de repaso espaciado interno normalmente no requiere redibujar la UI
      if (updatedCard.isFavorite != cards[index].isFavorite ||
          updatedCard.question != cards[index].question ||
          updatedCard.answer != cards[index].answer) {
        notifyListeners();
      }
    } catch (e) {
      Logger.error('Error al actualizar flashcard en "$deckName"', e);
      rethrow;
    }
  }
}
