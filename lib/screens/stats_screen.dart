import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/study_stats_provider.dart';
import '../theme/app_theme.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas de Estudio', 
          style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.bar_chart),
              text: 'Resumen',
            ),
            Tab(
              icon: Icon(Icons.calendar_month),
              text: 'Actividad',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _SummaryTab(),
          _ActivityTab(),
        ],
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statsProvider = Provider.of<StudyStatsProvider>(context);
    final totalStats = statsProvider.totalStats;
    final currentStreak = statsProvider.currentStreak;
    final totalTimeFormatted = statsProvider.totalTimeFormatted;
    final averageScore = statsProvider.averageScore.toStringAsFixed(1);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjetas de estadísticas principales
          Row(
            children: [
              _StatCard(
                title: 'Puntuación',
                value: '$averageScore%',
                icon: Icons.bar_chart,
                color: AppTheme.accentColor,
              ),
              const SizedBox(width: 12),
              _StatCard(
                title: 'Racha',
                value: '$currentStreak días',
                icon: Icons.local_fire_department,
                color: Colors.deepOrange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatCard(
                title: 'Tarjetas estudiadas',
                value: '${totalStats['totalCardsStudied'] ?? 0}',
                icon: Icons.school,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 12),
              _StatCard(
                title: 'Tiempo total',
                value: totalTimeFormatted,
                icon: Icons.timer,
                color: AppTheme.secondaryColor,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          Text(
            'Resumen de actividad',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          // Datos adicionales
          _buildInfoItem(
            context,
            icon: Icons.calendar_today,
            title: 'Fecha de inicio',
            value: totalStats['startDate'] != null
                ? DateFormat('dd/MM/yyyy').format(
                    DateTime.fromMillisecondsSinceEpoch(totalStats['startDate'])
                  )
                : 'No disponible',
          ),
          _buildInfoItem(
            context,
            icon: Icons.check_circle,
            title: 'Tasa de precisión',
            value: totalStats['totalCardsStudied'] != null && 
                  totalStats['totalCardsStudied'] > 0
                ? '${((totalStats['totalCorrectAnswers'] / totalStats['totalCardsStudied']) * 100).toStringAsFixed(1)}%'
                : 'No disponible',
          ),
          _buildInfoItem(
            context,
            icon: Icons.event_available,
            title: 'Sesiones completadas',
            value: '${totalStats['totalSessions'] ?? 0}',
          ),
          _buildInfoItem(
            context,
            icon: Icons.access_time,
            title: 'Tiempo promedio por sesión',
            value: totalStats['totalSessions'] != null && 
                  totalStats['totalSessions'] > 0 && 
                  totalStats['totalTimeSpent'] != null
                ? _formatDuration(
                    (totalStats['totalTimeSpent'] / totalStats['totalSessions']).round()
                  )
                : 'No disponible',
          ),
          
          // Mensaje motivacional
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '¡Sigue así!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getMotivationalMessage(currentStreak, totalStats),
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.secondaryColor, size: 20),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')} min';
  }
  
  String _getMotivationalMessage(int streak, Map<String, dynamic> stats) {
    final totalCards = stats['totalCardsStudied'] ?? 0;
    
    if (streak > 10) {
      return '¡Impresionante racha de $streak días! Tu constancia está dando frutos.';
    } else if (streak > 5) {
      return 'Llevas $streak días seguidos estudiando. ¡Mantén el ritmo!';
    } else if (streak > 0) {
      return 'Has estudiado $streak días seguidos. La constancia es clave.';
    } else if (totalCards > 100) {
      return 'Has estudiado más de $totalCards tarjetas. ¡Sigue avanzando!';
    } else {
      return 'Estudiar un poco cada día te ayudará a retener mejor la información.';
    }
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statsProvider = Provider.of<StudyStatsProvider>(context);
    final weekStats = statsProvider.lastWeekStats;
    
    // Verificar si hay datos reales
    final hasRealData = weekStats.any((day) => day['hasRealData'] == true);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actividad semanal
          Text(
            'Actividad de los últimos 7 días',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          // Mensaje si no hay datos reales
          if (!hasRealData)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aún no hay datos de estudio registrados. Cuando completes sesiones de estudio, podrás ver tu actividad aquí.',
                      style: TextStyle(color: Colors.amber[800]),
                    ),
                  ),
                ],
              ),
            ),
          
          // Gráfico actividad semanal (simplificado como barras)
          Container(
            height: 160, // Reducido para evitar overflow
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weekStats.map((day) {
                final date = DateTime.fromMillisecondsSinceEpoch(day['date']);
                final stats = day['stats'];
                final cardsStudied = stats['totalCardsStudied'] ?? 0;
                final maxHeight = 110.0; // Reducido para evitar overflow
                final height = cardsStudied > 0 
                    ? (cardsStudied / 20 * maxHeight).clamp(10, maxHeight)
                    : 0.0;
                
                return Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Evita que tome más espacio del necesario
                    children: [
                      SizedBox(
                        height: maxHeight,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: height,
                            width: 18, // Reducido para evitar overflow
                            decoration: BoxDecoration(
                              color: cardsStudied > 0
                                  ? AppTheme.primaryColor
                                  : Colors.grey[300],
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('E').format(date),
                        style: TextStyle(
                          fontSize: 11, // Reducido para evitar overflow
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        DateFormat('d').format(date),
                        style: TextStyle(
                          fontSize: 12, // Reducido para evitar overflow
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (cardsStudied > 0)
                        Text(
                          '$cardsStudied',
                          style: TextStyle(
                            fontSize: 10, // Reducido para evitar overflow
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Detalle diario
          Text(
            'Detalle diario',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          ...weekStats.map((day) {
            final date = DateTime.fromMillisecondsSinceEpoch(day['date']);
            final stats = day['stats'];
            final cardsStudied = stats['totalCardsStudied'] ?? 0;
            final timeSpent = stats['totalTimeSpent'] ?? 0;
            final sessions = stats['sessions'] ?? 0;
            
            // No mostrar días sin actividad
            if (cardsStudied == 0) {
              return const SizedBox.shrink();
            }
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          color: AppTheme.primaryColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, d MMM', 'es').format(date),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '$sessions ${sessions == 1 ? 'sesión' : 'sesiones'} de estudio',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _ActivityStat(
                        icon: Icons.school,
                        value: '$cardsStudied',
                        label: 'Tarjetas',
                      ),
                      _ActivityStat(
                        icon: Icons.timer,
                        value: _formatDuration(timeSpent),
                        label: 'Tiempo',
                      ),
                      _ActivityStat(
                        icon: Icons.check_circle,
                        value: stats['totalCorrectAnswers'] != null && cardsStudied > 0
                            ? '${((stats['totalCorrectAnswers'] / cardsStudied) * 100).round()}%'
                            : 'N/A',
                        label: 'Precisión',
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
          
          // Si no hay actividad reciente
          if (weekStats.every((day) => (day['stats']['totalCardsStudied'] ?? 0) == 0))
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Icon(
                    Icons.hourglass_empty,
                    size: 48,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sin actividad reciente',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Comienza a estudiar para ver tus estadísticas aquí',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '$hours h ${remainingMinutes > 0 ? '$remainingMinutes min' : ''}';
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  
  const _StatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
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

class _ActivityStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  
  const _ActivityStat({
    Key? key,
    required this.icon,
    required this.value,
    required this.label,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppTheme.secondaryColor, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
