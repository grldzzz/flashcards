import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flip_card/flip_card.dart';

import '../models/flashcard.dart';
import '../providers/deck_provider.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

class FlashcardScreen extends StatefulWidget {
  final String deckName;
  const FlashcardScreen({Key? key, required this.deckName}) : super(key: key);

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  final _aiService = AiService();
  final _inputCtrl = TextEditingController();
  bool _loading = false;
  bool _isLoadingCards = true;
  List<Flashcard> _cards = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFlashcards();
  }

  Future<void> _loadFlashcards() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingCards = true;
      _errorMessage = null;
    });

    try {
      final deckProv = Provider.of<DeckProvider>(context, listen: false);
      final cards = await deckProv.getFlashcardsAsync(widget.deckName);
      
      if (mounted) {
        setState(() {
          _cards = cards;
          _isLoadingCards = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error cargando tarjetas: ${e.toString()}';
          _isLoadingCards = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deckProv = context.watch<DeckProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.deckName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Toca las tarjetas para voltearlas'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppTheme.primaryColor,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoadingCards
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                      const SizedBox(height: 16),
                      Text(
                        'Error al cargar tarjetas',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadFlashcards,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _cards.isEmpty
                  ? Center(
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
                      Icons.content_paste,
                      size: 60,
                      color: AppTheme.primaryColor.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Esta baraja está vacía',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agrega tarjetas usando el botón +',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _cards.length,
              itemBuilder: (context, index) {
                final card = _cards[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: FlipCard(
                    direction: FlipDirection.HORIZONTAL,
                    speed: 400,
                    front: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.primaryColor, Color(0xFF34495E)],
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.help_outline, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'PREGUNTA',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: GestureDetector(
                              onTap: () => _toggleFavorite(index),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  card.isFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: card.isFavorite ? Colors.red : Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                card.question,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const Positioned(
                            right: 12,
                            bottom: 12,
                            child: Icon(
                              Icons.touch_app,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    back: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.3)),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.lightbulb_outline, color: AppTheme.secondaryColor, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    'RESPUESTA',
                                    style: TextStyle(
                                      color: AppTheme.secondaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                card.answer,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGenerateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Agregar tarjetas'),
        backgroundColor: AppTheme.accentColor,
      ),
    );
  }

  void _toggleFavorite(int index) {
    final deckProv = context.read<DeckProvider>();
    final card = deckProv.getFlashcards(widget.deckName)[index];
    deckProv.toggleFavorite(widget.deckName, card);
  }

  void _showGenerateDialog() {
    int cardCount = 5; // Valor predeterminado
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppTheme.accentColor, size: 24),
                const SizedBox(width: 8),
                const Text('Generar flashcards'),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pega texto o una URL para generar tarjetas:',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _inputCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Texto o URL...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                        borderSide: const BorderSide(color: AppTheme.secondaryColor, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.format_list_numbered, color: AppTheme.secondaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Cantidad de tarjetas: $cardCount',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 8),
                      const Text('3', style: TextStyle(color: AppTheme.textSecondary)),
                      Expanded(
                        child: Slider(
                          value: cardCount.toDouble(),
                          min: 3,
                          max: 15,
                          divisions: 12,
                          label: cardCount.toString(),
                          onChanged: (value) {
                            setState(() {
                              cardCount = value.toInt();
                            });
                          },
                        ),
                      ),
                      const Text('15', style: TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: _loading ? null : () => _onGeneratePressed(cardCount),
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome),
                label: const Text('Generar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onGeneratePressed(int cardCount) async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) return;
    Navigator.pop(context);
    setState(() => _loading = true);
    try {
      final List<Flashcard> newCards =
      await _aiService.generateFlashcards(input, count: cardCount);
      for (var c in newCards) {
        await context.read<DeckProvider>().addFlashcard(widget.deckName, c);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Se agregaron ${newCards.length} tarjetas a la baraja'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
      _inputCtrl.clear();
    }
  }
}
