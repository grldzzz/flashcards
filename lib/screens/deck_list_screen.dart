import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/deck_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/study_stats_provider.dart';
import '../theme/app_theme.dart';
import 'create_deck_screen.dart';
import 'flashcard_screen.dart';
import 'study_session_screen.dart';
import 'stats_screen.dart';

class DeckListScreen extends StatefulWidget {
  const DeckListScreen({Key? key}) : super(key: key);

  @override
  State<DeckListScreen> createState() => _DeckListScreenState();
}

class _DeckListScreenState extends State<DeckListScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      // Simular un breve retraso para permitir que Hive se inicialice completamente
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Acceso de lectura para verificar que todo funciona
      context.read<DeckProvider>().deckNames;
      
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al inicializar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Barajas', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          // Botón para estadísticas
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Ver estadísticas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatsScreen()),
              );
            },
          ),
          // Botón para cambiar tema
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return IconButton(
                icon: Icon(
                  themeProvider.themeMode == ThemeMode.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                tooltip: themeProvider.themeMode == ThemeMode.dark
                    ? 'Cambiar a tema claro'
                    : 'Cambiar a tema oscuro',
                onPressed: () => themeProvider.toggleTheme(),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                      const SizedBox(height: 16),
                      Text(
                        'Error al cargar datos',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _initializeData();
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : Consumer<DeckProvider>(
                  builder: (context, deckProv, _) {
                    final decks = deckProv.deckNames;
                    if (decks.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 150,
                              width: 150,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(75),
                              ),
                              child: Icon(
                                Icons.menu_book,
                                size: 80,
                                color: AppTheme.primaryColor.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No tienes barajas', 
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '¡Crea tu primera baraja de estudio!',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CreateDeckScreen()),
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('Crear baraja nueva'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: decks.length,
                      itemBuilder: (context, i) {
                        final name = decks[i];
                        final count = deckProv.getFlashcards(name).length;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 3,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                            onTap: () => _showDeckOptions(context, name, count),

                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  // Icono de la baraja
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.menu_book,
                                      color: AppTheme.textLight,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Información de la baraja
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.secondaryColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '$count carta${count != 1 ? 's' : ''}',
                                                style: TextStyle(
                                                  color: AppTheme.secondaryColor,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Botón de eliminar
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: AppTheme.errorColor.withOpacity(0.8)),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Eliminar baraja'),
                                          content: Text('¿Seguro que quieres borrar "$name"?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Cancelar'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Eliminar'),
                                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        try {
                                          await deckProv.deleteDeck(name);
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: const Text('Baraja eliminada correctamente'),
                                                backgroundColor: AppTheme.successColor,
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Error al eliminar: $e'),
                                                backgroundColor: AppTheme.errorColor,
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateDeckScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nueva baraja'),
        elevation: 4,
      ),
    );
  }
  
  void _showDeckOptions(BuildContext context, String deckName, int cardCount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.menu_book, color: AppTheme.textLight),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deckName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$cardCount carta${cardCount != 1 ? 's' : ''}',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Opciones
            _buildOptionTile(
              context: context,
              icon: Icons.visibility,
              title: 'Ver tarjetas',
              subtitle: 'Hojea todas las tarjetas de la baraja',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FlashcardScreen(deckName: deckName),
                  ),
                );
              },
            ),
            
            // Modo de estudio
            _buildOptionTile(
              context: context,
              icon: Icons.school,
              title: 'Modo de estudio',
              subtitle: 'Estudia y evalúa tu conocimiento',
              onTap: () {
                Navigator.pop(context);
                _showStudyModeOptions(context, deckName);
              },
            ),
            
            // Espaciado de repetición (SRS)
            _buildOptionTile(
              context: context,
              icon: Icons.calendar_today,
              title: 'Repetición espaciada',
              subtitle: 'Estudia solo las tarjetas pendientes para hoy',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudySessionScreen(
                      deckName: deckName,
                      dueModeOnly: true,
                      randomOrder: false,
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  
  void _showStudyModeOptions(BuildContext context, String deckName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.school, color: AppTheme.accentColor),
            const SizedBox(width: 10),
            const Text('Modo de estudio'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Elige cómo quieres estudiar esta baraja:',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            _buildStudyOption(
              context: context,
              icon: Icons.format_list_numbered,
              title: 'Orden secuencial',
              description: 'Estudia las tarjetas en orden',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudySessionScreen(
                      deckName: deckName,
                      randomOrder: false,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildStudyOption(
              context: context,
              icon: Icons.shuffle,
              title: 'Orden aleatorio',
              description: 'Mezcla las tarjetas para un mayor desafío',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudySessionScreen(
                      deckName: deckName,
                      randomOrder: true,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primaryColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      onTap: onTap,
    );
  }
  
  Widget _buildStudyOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accentColor, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
