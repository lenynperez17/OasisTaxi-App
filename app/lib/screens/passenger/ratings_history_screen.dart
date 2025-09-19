import '../../utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/modern_theme.dart';

class RatingsHistoryScreen extends StatefulWidget {
  const RatingsHistoryScreen({super.key});

  @override
  RatingsHistoryScreenState createState() => RatingsHistoryScreenState();
}

class RatingsHistoryScreenState extends State<RatingsHistoryScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId; // Se obtendrá del usuario actual
  // bool _isLoading = true; // No usado en la UI actual

  late AnimationController _headerController;
  late AnimationController _listController;

  String _selectedFilter = 'all';

  // Lista de calificaciones desde Firebase
  List<RatingData> _ratings = [];

  List<RatingData> get _filteredRatings {
    if (_selectedFilter == 'all') return _ratings;

    final filterValue = int.parse(_selectedFilter);
    return _ratings.where((r) => r.rating == filterValue).toList();
  }

  Map<String, dynamic> get _statistics {
    final totalRatings = _ratings.length;
    final avgRating = totalRatings > 0
        ? _ratings.fold<double>(0, (accumulator, r) => accumulator + r.rating) /
            totalRatings
        : 0.0;

    final ratingCounts = <int, int>{};
    for (var rating in _ratings) {
      ratingCounts[rating.rating] = (ratingCounts[rating.rating] ?? 0) + 1;
    }

    return {
      'total': totalRatings,
      'average': avgRating,
      'counts': ratingCounts,
    };
  }

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('RatingsHistoryScreen', 'initState');

    _headerController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _listController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    )..forward();

    _loadRatingsFromFirebase();
  }

  Future<void> _loadRatingsFromFirebase() async {
    try {
      // setState(() => _isLoading = true);

      // Obtener el usuario actual autenticado
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          // _isLoading = false;
          _ratings = [];
        });
        return;
      }

      _userId = user.uid;

      // Cargar calificaciones del usuario desde Firebase
      final tripsSnapshot = await _firestore
          .collection('trips')
          .where('passengerId', isEqualTo: _userId)
          .where('passengerRating', isNotEqualTo: null)
          .orderBy('passengerRating')
          .orderBy('requestedAt', descending: true)
          .limit(50)
          .get();

      List<RatingData> loadedRatings = [];

      for (var doc in tripsSnapshot.docs) {
        final data = doc.data();

        // Obtener información del conductor
        String driverName = 'Conductor';
        String driverPhoto = '';

        if (data['driverId'] != null) {
          try {
            final driverDoc = await _firestore
                .collection('users')
                .doc(data['driverId'])
                .get();

            if (driverDoc.exists) {
              final driverData = driverDoc.data()!;
              driverName =
                  '${driverData['firstName'] ?? ''} ${driverData['lastName'] ?? ''}'
                      .trim();
              if (driverName.isEmpty) driverName = 'Conductor';
              driverPhoto = driverData['profileImage'] ?? '';
            }
          } catch (e) {
            AppLogger.error('obteniendo datos del conductor', e);
          }
        }

        // Generar tags basados en la calificación
        List<String> tags = [];
        final rating = data['passengerRating'] ?? 0;
        if (rating >= 5) {
          tags = ['Excelente servicio', 'Muy satisfecho'];
        } else if (rating >= 4) {
          tags = ['Buen servicio', 'Satisfecho'];
        } else if (rating >= 3) {
          tags = ['Servicio regular', 'Aceptable'];
        } else {
          tags = ['Necesita mejorar', 'Insatisfecho'];
        }

        loadedRatings.add(RatingData(
          id: doc.id,
          tripId: doc.id,
          driverName: driverName,
          driverPhoto: driverPhoto,
          date: data['requestedAt'] != null
              ? (data['requestedAt'] as Timestamp).toDate()
              : DateTime.now(),
          rating: data['passengerRating'] ?? 0,
          comment: data['passengerComment'] ?? '',
          tags: tags,
          route:
              '${data['pickupAddress'] ?? 'Origen'} → ${data['dropoffAddress'] ?? 'Destino'}',
          tripAmount:
              (data['finalFare'] ?? data['estimatedFare'] ?? 0.0).toDouble(),
        ));
      }

      // Si no hay calificaciones, mostrar lista vacía (sin crear datos de ejemplo)

      setState(() {
        _ratings = loadedRatings;
      });
    } catch (e) {
      AppLogger.error('cargando calificaciones', e);
      // setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar calificaciones'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _headerController.dispose();
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        title: Text(
          'Mis Calificaciones',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Estadísticas
          AnimatedBuilder(
            animation: _headerController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -50 * (1 - _headerController.value)),
                child: Opacity(
                  opacity: _headerController.value,
                  child: _buildStatistics(),
                ),
              );
            },
          ),

          // Filtros
          _buildFilters(),

          // Lista de calificaciones
          Expanded(
            child: _filteredRatings.isEmpty
                ? _buildEmptyState()
                : AnimatedBuilder(
                    animation: _listController,
                    builder: (context, child) {
                      return ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _filteredRatings.length,
                        itemBuilder: (context, index) {
                          final rating = _filteredRatings[index];
                          final delay = (index * 0.1).clamp(0.0, 0.5);
                          final animation = Tween<double>(
                            begin: 0,
                            end: 1,
                          ).animate(
                            CurvedAnimation(
                              parent: _listController,
                              curve: Interval(
                                delay,
                                (delay + 0.5).clamp(0.0, 1.0),
                                curve: Curves.easeOutBack,
                              ),
                            ),
                          );

                          return AnimatedBuilder(
                            animation: animation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(50 * (1 - animation.value), 0),
                                child: Opacity(
                                  opacity: animation.value.clamp(0.0, 1.0),
                                  child: _buildRatingCard(rating),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    final stats = _statistics;
    final ratingCounts = stats['counts'] as Map<int, int>;

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: ModernTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ModernTheme.oasisGreen.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Total de calificaciones
              Column(
                children: [
                  Text(
                    '${stats['total']}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Total',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              // Separador
              Container(
                height: 40,
                width: 1,
                color: Colors.white24,
              ),

              // Promedio
              Column(
                children: [
                  Row(
                    children: [
                      Text(
                        stats['total'] > 0 && !stats['average'].isNaN
                            ? stats['average'].toStringAsFixed(1)
                            : '0.0',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 24,
                      ),
                    ],
                  ),
                  Text(
                    'Promedio',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Distribución de calificaciones
          Column(
            children: [5, 4, 3, 2, 1].map((rating) {
              final count = ratingCounts[rating] ?? 0;
              final percentage = stats['total'] > 0
                  ? (count / stats['total'] * 100).toInt()
                  : 0;

              return Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '$rating',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.star,
                      size: 16,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          AnimatedContainer(
                            duration: Duration(milliseconds: 800),
                            height: 20,
                            width: MediaQuery.of(context).size.width *
                                percentage /
                                100 *
                                0.5,
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('Todas', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('5 ⭐', '5'),
          const SizedBox(width: 8),
          _buildFilterChip('4 ⭐', '4'),
          const SizedBox(width: 8),
          _buildFilterChip('3 ⭐', '3'),
          const SizedBox(width: 8),
          _buildFilterChip('2 ⭐', '2'),
          const SizedBox(width: 8),
          _buildFilterChip('1 ⭐', '1'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: ModernTheme.oasisGreen,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : ModernTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? ModernTheme.oasisGreen : Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildRatingCard(RatingData rating) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: InkWell(
        onTap: () => _showRatingDetails(rating),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con conductor y fecha
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundImage: rating.driverPhoto.isNotEmpty
                        ? NetworkImage(rating.driverPhoto)
                        : null,
                    child: rating.driverPhoto.isEmpty
                        ? Icon(Icons.person, size: 30, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rating.driverName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _formatDate(rating.date),
                          style: TextStyle(
                            color: ModernTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Estrellas
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < rating.rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 20,
                      );
                    }),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Ruta
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ModernTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.route,
                      size: 16,
                      color: ModernTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rating.route,
                        style: TextStyle(
                          fontSize: 13,
                          color: ModernTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'S/ ${rating.tripAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ModernTheme.oasisGreen,
                      ),
                    ),
                  ],
                ),
              ),

              if (rating.comment != null) ...[
                const SizedBox(height: 12),
                Text(
                  rating.comment!,
                  style: TextStyle(
                    fontSize: 14,
                    color: ModernTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              if (rating.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: rating.tags.map((tag) {
                    return Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 11,
                          color: ModernTheme.oasisGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.star_border,
            size: 80,
            color: ModernTheme.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay calificaciones',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ModernTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aquí aparecerán tus calificaciones',
            style: TextStyle(
              color: ModernTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingDetails(RatingData rating) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RatingDetailsModal(rating: rating),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'Hoy';
    if (difference == 1) return 'Ayer';
    if (difference < 7) return 'Hace $difference días';

    return '${date.day}/${date.month}/${date.year}';
  }
}

// Modal de detalles
class RatingDetailsModal extends StatelessWidget {
  final RatingData rating;

  const RatingDetailsModal({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detalles de la Calificación',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Conductor
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: rating.driverPhoto.isNotEmpty
                            ? NetworkImage(rating.driverPhoto)
                            : null,
                        child: rating.driverPhoto.isEmpty
                            ? Icon(Icons.person, size: 40, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rating.driverName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: List.generate(5, (index) {
                                return Icon(
                                  index < rating.rating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 24,
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Información del viaje
                  _buildDetailSection(
                    'Información del Viaje',
                    [
                      _buildDetailRow(Icons.calendar_today, 'Fecha',
                          '${rating.date.day}/${rating.date.month}/${rating.date.year}'),
                      _buildDetailRow(Icons.access_time, 'Hora',
                          '${rating.date.hour.toString().padLeft(2, '0')}:${rating.date.minute.toString().padLeft(2, '0')}'),
                      _buildDetailRow(Icons.route, 'Ruta', rating.route),
                      _buildDetailRow(Icons.attach_money, 'Monto',
                          'S/ ${rating.tripAmount.toStringAsFixed(2)}'),
                      _buildDetailRow(Icons.tag, 'ID Viaje', rating.tripId),
                    ],
                  ),

                  if (rating.comment != null) ...[
                    const SizedBox(height: 20),
                    _buildDetailSection(
                      'Tu Comentario',
                      [
                        Text(
                          rating.comment!,
                          style: TextStyle(
                            fontSize: 14,
                            color: ModernTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (rating.tags.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Etiquetas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ModernTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: rating.tags.map((tag) {
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                ModernTheme.oasisGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: ModernTheme.oasisGreen,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 13,
                              color: ModernTheme.oasisGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Botón de editar (deshabilitado)
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: Icon(Icons.edit),
                    label: Text('No se puede editar'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ModernTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ModernTheme.backgroundLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: ModernTheme.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: ModernTheme.textSecondary),
          ),
          Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// Modelo de datos
class RatingData {
  final String id;
  final String tripId;
  final String driverName;
  final String driverPhoto;
  final DateTime date;
  final int rating;
  final String? comment;
  final List<String> tags;
  final String route;
  final double tripAmount;

  RatingData({
    required this.id,
    required this.tripId,
    required this.driverName,
    required this.driverPhoto,
    required this.date,
    required this.rating,
    this.comment,
    required this.tags,
    required this.route,
    required this.tripAmount,
  });
}
