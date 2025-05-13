import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flashcard.dart';
import '../providers/deck_provider.dart';
import '../providers/study_stats_provider.dart';
import '../theme/app_theme.dart';

class StudySessionScreen extends StatefulWidget {
  final String deckName;
  final bool randomOrder;
  final bool dueModeOnly;
  
  const StudySessionScreen({
    Key? key, 
    required this.deckName, 
    this.randomOrder = false,
    this.dueModeOnly = false,
  }) : super(key: key);

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen> {
  // Variables para la sesión de estudio
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _sessionCompleted = false;
  List<Flashcard> _studyCards = [];
  
  // Variables para puntuación
  int _correctAnswers = 0;
  
  // Variables para temporizador
  int _sessionDuration = 0; // en segundos
  Timer? _timer;
  
  // Variables para animación
  final _cardKey = GlobalKey();
  double _cardRotationY = 0;
  bool _isFlipping = false;
  
  @override
  void initState() {
    super.initState();
    _initStudySession();
    _startTimer();
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  void _initStudySession() {
    final deckProvider = Provider.of<DeckProvider>(context, listen: false);
    List<Flashcard> allCards = deckProvider.getFlashcards(widget.deckName);
    
    // Filtrar tarjetas si el modo SRS está activado
    if (widget.dueModeOnly) {
      allCards = allCards.where((card) => card.isDueForReview()).toList();
    }
    
    // Si no hay tarjetas para estudiar después del filtrado
    if (allCards.isEmpty) {
      setState(() {
        _studyCards = [];
        _sessionCompleted = true;
      });
      return;
    }
    
    // Aplicar orden aleatorio si está activado
    if (widget.randomOrder) {
      allCards.shuffle();
    }
    
    setState(() {
      _studyCards = allCards;
      _currentIndex = 0;
      _showAnswer = false;
      _sessionCompleted = false;
      _correctAnswers = 0;
    });
  }
  
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _sessionDuration++;
      });
    });
  }
  
  void _flipCard() {
    setState(() {
      _isFlipping = true;
      _showAnswer = !_showAnswer;
    });
    
    // Animación de giro
    for (int i = 0; i < 18; i++) {
      Future.delayed(Duration(milliseconds: i * 10), () {
        if (mounted) {
          setState(() {
            if (i < 9) {
              _cardRotationY = i / 9;
            } else {
              _cardRotationY = 1 - ((i - 9) / 9);
            }
          });
        }
      });
    }
    
    // Restablecer el estado de la animación
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) {
        setState(() {
          _isFlipping = false;
          _cardRotationY = 0;
        });
      }
    });
  }
  
  void _markAnswer(bool isCorrect) {
    if (_currentIndex >= _studyCards.length) return;
    
    final currentCard = _studyCards[_currentIndex];
    
    // Actualizar estadísticas de la tarjeta
    currentCard.updateReviewSchedule(isCorrect);
    
    // Actualizar puntuación de la sesión
    if (isCorrect) {
      setState(() {
        _correctAnswers++;
      });
    }
    
    // Pasar a la siguiente tarjeta
    if (_currentIndex < _studyCards.length - 1) {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
    } else {
      _finishSession();
    }
  }
  
  Future<void> _finishSession() async {
    _timer?.cancel();
    
    // Guardar estadísticas de la sesión
    await Provider.of<StudyStatsProvider>(context, listen: false).recordStudySession(
      deckName: widget.deckName,
      cardsStudied: _studyCards.length,
      correctAnswers: _correctAnswers,
      duration: _sessionDuration,
    );
    
    setState(() {
      _sessionCompleted = true;
    });
  }
  
  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.school, size: 20),
            const SizedBox(width: 8),
            Text(
              'Estudiando: ${widget.deckName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          // Temporizador
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, size: 16),
                const SizedBox(width: 4),
                Text(_formatDuration(_sessionDuration)),
              ],
            ),
          ),
        ],
      ),
      body: _sessionCompleted
          ? _buildSessionSummary()
          : _studyCards.isEmpty
              ? _buildNoCardsView()
              : _buildStudyView(),
    );
  }
  
  Widget _buildStudyView() {
    final currentCard = _currentIndex < _studyCards.length 
        ? _studyCards[_currentIndex] 
        : null;
    
    if (currentCard == null) {
      return const Center(child: Text('No hay más tarjetas para estudiar'));
    }
    
    // Progreso de la sesión
    final progress = (_currentIndex + 1) / _studyCards.length;
    
    return Column(
      children: [
        // Barra de progreso
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[200],
          color: AppTheme.primaryColor,
        ),
        
        // Contador de progreso
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tarjeta ${_currentIndex + 1} de ${_studyCards.length}',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$_correctAnswers correctas',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Tarjeta de estudio
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: _flipCard,
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(_cardRotationY * 3.14),
                alignment: Alignment.center,
                child: Container(
                  key: _cardKey,
                  decoration: BoxDecoration(
                    color: _showAnswer ? Colors.white : AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: _showAnswer 
                        ? Border.all(color: AppTheme.secondaryColor.withOpacity(0.3))
                        : null,
                  ),
                  child: Stack(
                    children: [
                      // Etiqueta de dificultad
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(currentCard.difficulty).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getDifficultyName(currentCard.difficulty),
                            style: TextStyle(
                              color: _getDifficultyColor(currentCard.difficulty),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      
                      // Etiquetas (tags)
                      if (currentCard.tags.isNotEmpty)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Wrap(
                            spacing: 4,
                            children: currentCard.tags.map((tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _showAnswer 
                                    ? AppTheme.secondaryColor.withOpacity(0.1)
                                    : Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  color: _showAnswer 
                                      ? AppTheme.secondaryColor
                                      : Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )).toList(),
                          ),
                        ),
                      
                      // Contenido de la tarjeta
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _showAnswer ? currentCard.answer : currentCard.question,
                            style: TextStyle(
                              color: _showAnswer ? AppTheme.textPrimary : Colors.white,
                              fontSize: _showAnswer ? 16 : 18,
                              fontWeight: _showAnswer ? FontWeight.normal : FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      
                      // Indicador de tocado para voltear
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Icon(
                          Icons.touch_app,
                          color: _showAnswer ? Colors.black38 : Colors.white70,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Botones de respuesta
        if (_showAnswer)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildResponseButton(
                  icon: Icons.close,
                  label: 'Incorrecta',
                  color: Colors.redAccent,
                  onTap: () => _markAnswer(false),
                ),
                _buildResponseButton(
                  icon: Icons.check,
                  label: 'Correcta',
                  color: Colors.green,
                  onTap: () => _markAnswer(true),
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  Widget _buildResponseButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white),
          label: Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getDifficultyColor(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return Colors.green;
      case Difficulty.medium:
        return Colors.orange;
      case Difficulty.hard:
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
  
  String _getDifficultyName(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return 'Fácil';
      case Difficulty.medium:
        return 'Medio';
      case Difficulty.hard:
        return 'Difícil';
      default:
        return 'Desconocido';
    }
  }
  
  Widget _buildSessionSummary() {
    final score = _studyCards.isEmpty ? 0 : (_correctAnswers / _studyCards.length * 100).round();
    final formattedDuration = _formatDuration(_sessionDuration);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícono de resultado
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              color: _getScoreColor(score).withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              _getScoreIcon(score),
              size: 60,
              color: _getScoreColor(score),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '¡Sesión Completada!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getScoreMessage(score),
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildScoreCard(
            icon: Icons.check_circle,
            title: 'Puntuación',
            value: '$score%',
            color: _getScoreColor(score),
          ),
          const SizedBox(height: 8),
          _buildScoreCard(
            icon: Icons.timer,
            title: 'Duración',
            value: formattedDuration,
            color: AppTheme.secondaryColor,
          ),
          const SizedBox(height: 8),
          _buildScoreCard(
            icon: Icons.school,
            title: 'Tarjetas Estudiadas',
            value: '${_studyCards.length}',
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  _initStudySession();
                  _sessionDuration = 0;
                  _startTimer();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Volver a estudiar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver'),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildScoreCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.redAccent;
  }
  
  IconData _getScoreIcon(int score) {
    if (score >= 80) return Icons.emoji_events;
    if (score >= 60) return Icons.thumb_up;
    return Icons.trending_up;
  }
  
  String _getScoreMessage(int score) {
    if (score >= 80) {
      return '¡Excelente trabajo! Has dominado estas tarjetas.';
    }
    if (score >= 60) {
      return 'Buen trabajo. Sigue practicando para mejorar.';
    }
    return 'Sigue estudiando. La práctica constante es clave.';
  }
  
  Widget _buildNoCardsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.check_circle,
              size: 60,
              color: AppTheme.primaryColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '¡Todo al día!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.dueModeOnly
                ? 'No hay tarjetas pendientes por revisar hoy'
                : 'Esta baraja está vacía',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
