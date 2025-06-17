import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flashcard.dart';
import '../providers/deck_provider.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';
import '../utils/logger.dart';
import '../utils/validation_utils.dart';
import '../utils/app_constants.dart';

class CreateDeckScreen extends StatefulWidget {
  const CreateDeckScreen({Key? key}) : super(key: key);

  @override
  State<CreateDeckScreen> createState() => _CreateDeckScreenState();
}

class _CreateDeckScreenState extends State<CreateDeckScreen> {
  final _nameCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _aiService = AiService();
  String? _error;
  bool _loading = false;
  bool _generatingCards = false;
  List<Flashcard> _generatedCards = [];
  bool _viewGeneratedCards = false;
  bool _contentHasText = false;
  int _cardCount = 5; // Cantidad predeterminada de flashcards
  
  @override
  void initState() {
    super.initState();
    // Añadir listener para detectar cambios en el campo de contenido
    _contentCtrl.addListener(_updateContentState);
  }
  
  @override
  void dispose() {
    // Eliminar el listener cuando se destruye el widget
    _contentCtrl.removeListener(_updateContentState);
    _nameCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }
  
  // Actualizar el estado cuando cambia el contenido
  void _updateContentState() {
    final hasText = !ValidationUtils.isEmptyOrWhitespace(_contentCtrl.text);
    if (hasText != _contentHasText) {
      setState(() {
        _contentHasText = hasText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear nueva baraja', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _viewGeneratedCards ? _buildGeneratedCardsView() : _buildCreateDeckForm(),
      ),
    );
  }
  
  Widget _buildCreateDeckForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Título de la sección
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Información de la baraja',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: 'Nombre de la baraja',
            errorText: _error,
            errorMaxLines: 3, // Permitir múltiples líneas para mensajes de error
            prefixIcon: const Icon(Icons.bookmark, color: AppTheme.secondaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              borderSide: const BorderSide(color: AppTheme.secondaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              borderSide: BorderSide(color: AppTheme.errorColor, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              borderSide: BorderSide(color: AppTheme.errorColor, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppTheme.accentColor),
                  const SizedBox(width: 8),
                  Text(
                    'Generación con IA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Pega texto o una URL para generar tarjetas automáticamente:',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Texto o URL...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                    borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.5)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.format_list_numbered, color: AppTheme.secondaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Cantidad de tarjetas: $_cardCount',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 8),
                  const Text('3', style: TextStyle(color: AppTheme.textSecondary)),
                  Expanded(
                    child: Slider(
                      value: _cardCount.toDouble(),
                      min: 3,
                      max: 15,
                      divisions: 12,
                      label: _cardCount.toString(),
                      onChanged: (value) {
                        setState(() {
                          _cardCount = value.toInt();
                        });
                      },
                    ),
                  ),
                  Text('15', style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_generatingCards) ...[  
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppTheme.accentColor),
                  SizedBox(height: 16),
                  Text(
                    'Generando tarjetas con IA...',
                    style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          )
        ] else if (_loading) ...[  
          const Center(child: CircularProgressIndicator(color: AppTheme.accentColor))
        ] else ...[  
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _createDeck,
                    icon: const Icon(Icons.add_box_outlined),
                    label: const Text('Crear baraja vacía'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _contentHasText 
                        ? _createDeckWithAI 
                        : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generar con IA'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.3),
                      disabledForegroundColor: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
  
  Widget _buildGeneratedCardsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Se generaron ${_generatedCards.length} tarjetas para tu baraja', 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _generatedCards.length,
            itemBuilder: (context, index) {
              final card = _generatedCards[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.help_outline,
                              color: AppTheme.primaryColor,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Pregunta:', 
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 30, top: 4, bottom: 12),
                        child: Text(
                          card.question,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.lightbulb_outline,
                              color: AppTheme.secondaryColor,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Respuesta:', 
                            style: TextStyle(
                              color: AppTheme.secondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 30, top: 4),
                        child: Text(
                          card.answer,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _viewGeneratedCards = false;
                  });
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver'),
              ),
              ElevatedButton.icon(
                onPressed: _saveDeckWithCards,
                icon: const Icon(Icons.save),
                label: const Text('Guardar baraja'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Future<void> _createDeck() async {
    final name = _nameCtrl.text.trim();
    if (ValidationUtils.isEmptyOrWhitespace(name)) {
      setState(() => _error = AppConstants.errorEmptyDeckName);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Usar try-catch para manejar posibles errores en el provider
      final provider = Provider.of<DeckProvider>(context, listen: false);
      await provider.addDeck(name);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Manejo mejorado de errores
      Logger.error('Error al crear baraja', e);
      if (mounted) {
        setState(() => _error = 'Error al crear baraja: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  
  Future<void> _createDeckWithAI() async {
    final name = _nameCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    
    if (ValidationUtils.isEmptyOrWhitespace(name)) {
      setState(() => _error = AppConstants.errorEmptyDeckName);
      return;
    }
    
    if (ValidationUtils.isEmptyOrWhitespace(content)) {
      setState(() => _error = AppConstants.errorEmptyContent);
      return;
    }
    
    // Detectar si el contenido es una URL para mejorar generación
    bool isUrl = ValidationUtils.isValidUrl(content);
    Logger.info('Generando flashcards a partir de ${isUrl ? "URL" : "texto"}: ${content.substring(0, content.length > 50 ? 50 : content.length)}...');
    
    setState(() {
      _generatingCards = true;
      _error = null;
    });
    
    try {
      // Pasar la cantidad de tarjetas seleccionada
      final cards = await _aiService.generateFlashcards(content, count: _cardCount);
      if (mounted) {
        setState(() {
          _generatedCards = cards;
          _viewGeneratedCards = true;
          _error = null; // Limpiar cualquier error previo
        });
      }
    } catch (e) {
      Logger.error('Error al generar flashcards', e);
      if (mounted) {
        setState(() => _error = 'Error al generar tarjetas: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _generatingCards = false);
    }
  }
  
  Future<void> _saveDeckWithCards() async {
    final name = _nameCtrl.text.trim();
    
    if (ValidationUtils.isEmptyOrWhitespace(name)) {
      setState(() => _error = AppConstants.errorEmptyDeckName);
      return;
    }
    
    if (_generatedCards.isEmpty) {
      setState(() {
        _viewGeneratedCards = false;
        _error = AppConstants.errorEmptyCards;
      });
      return;
    }
    
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      // Usar try-catch para manejar posibles errores en el provider
      final provider = Provider.of<DeckProvider>(context, listen: false);
      
      // En lugar de crear una baraja vacía y luego añadir tarjetas individualmente,
      // vamos a usar directamente addFlashcards que está diseñado para manejar esto
      // de forma más eficiente en una sola operación de base de datos
      await provider.addFlashcards(name, _generatedCards);
      Logger.info('Baraja "$name" creada con ${_generatedCards.length} flashcards');
      
      // Forzar recarga explícita de la lista de barajas
      await provider.getDeckNames();
      
      // Ahora validamos que la baraja se haya guardado correctamente
      final decks = await provider.getDeckNames();
      if (!decks.contains(name)) {
        throw Exception('La baraja se guardó pero no aparece en la lista. Posible error de DB.');
      }
      
      Logger.info('Verificada baraja "$name" en lista de barajas: ${decks.join(", ")}');
      
      
      // Mostrar mensaje de éxito antes de salir
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Baraja "$name" guardada con ${_generatedCards.length} tarjetas'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      Logger.error('Error al guardar baraja con tarjetas', e);
      if (mounted) {
        setState(() {
          _viewGeneratedCards = false;
          _error = 'Error al guardar: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
