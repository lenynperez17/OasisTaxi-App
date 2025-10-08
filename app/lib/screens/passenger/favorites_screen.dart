// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import '../../core/theme/modern_theme.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  late AnimationController _listController;
  late AnimationController _fabController;
  late AnimationController _searchController;
  
  final TextEditingController _searchTextController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  String? _userId; // Se obtendrá del usuario actual
  
  // Lugares favoritos desde Firebase
  List<FavoritePlace> _favorites = [];
  List<RecentPlace> _recentPlaces = [];
  
  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fabController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _searchController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    
    _listController.forward();
    _fabController.forward();
    
    // Cargar favoritos desde Firebase
    _loadFavoritesFromFirebase();
  }
  
  Future<void> _loadFavoritesFromFirebase() async {
    try {
      setState(() => _isLoading = true);
      
      // Por ahora usaremos un userId de ejemplo
      // En producción, esto vendría del usuario autenticado
      _userId = 'test_user_id';
      
      // Cargar lugares favoritos
      final favoritesSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('favorites')
          .orderBy('visitCount', descending: true)
          .get();
      
      List<FavoritePlace> loadedFavorites = [];
      
      for (var doc in favoritesSnapshot.docs) {
        final data = doc.data();
        loadedFavorites.add(FavoritePlace(
          id: doc.id,
          name: data['name'] ?? 'Sin nombre',
          address: data['address'] ?? 'Sin dirección',
          icon: _getIconFromString(data['icon'] ?? 'place'),
          color: Color(data['color'] ?? ModernTheme.primaryBlue.value),
          location: LatLng(
            data['latitude'] ?? -12.0464,
            data['longitude'] ?? -77.0428,
          ),
          isDefault: data['isDefault'] ?? false,
          visitCount: data['visitCount'] ?? 0,
          lastVisit: data['lastVisit'] != null 
              ? (data['lastVisit'] as Timestamp).toDate()
              : DateTime.now(),
        ));
      }
      
      // Si no hay favoritos, mostrar lista vacía (sin crear datos de ejemplo)
      
      // Cargar lugares recientes desde el historial de viajes
      final ridesSnapshot = await _firestore
          .collection('rides')
          .where('passengerId', isEqualTo: _userId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();
      
      List<RecentPlace> loadedRecent = [];
      Set<String> uniqueAddresses = {};
      
      for (var doc in ridesSnapshot.docs) {
        final data = doc.data();
        final destinationAddress = data['destinationAddress'] ?? '';
        
        if (destinationAddress.isNotEmpty && !uniqueAddresses.contains(destinationAddress)) {
          uniqueAddresses.add(destinationAddress);
          loadedRecent.add(RecentPlace(
            address: destinationAddress,
            date: data['createdAt'] != null 
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.now(),
            icon: Icons.location_on,
          ));
        }
        
        if (loadedRecent.length >= 3) break;
      }
      
      setState(() {
        _favorites = loadedFavorites;
        _recentPlaces = loadedRecent;
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error cargando favoritos: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar favoritos'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
  
  
  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'home': return Icons.home;
      case 'work': return Icons.work;
      case 'school': return Icons.school;
      case 'fitness': return Icons.fitness_center;
      case 'shopping': return Icons.shopping_cart;
      case 'restaurant': return Icons.restaurant;
      case 'hospital': return Icons.local_hospital;
      default: return Icons.place;
    }
  }
  
  String _getIconString(IconData icon) {
    if (icon == Icons.home) return 'home';
    if (icon == Icons.work) return 'work';
    if (icon == Icons.school) return 'school';
    if (icon == Icons.fitness_center) return 'fitness';
    if (icon == Icons.shopping_cart) return 'shopping';
    if (icon == Icons.restaurant) return 'restaurant';
    if (icon == Icons.local_hospital) return 'hospital';
    return 'place';
  }
  
  Future<void> _addToFavorites(String name, String address, IconData icon, Color color) async {
    try {
      setState(() => _isLoading = true);
      
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('favorites')
          .add({
        'name': name,
        'address': address,
        'icon': _getIconString(icon),
        'color': color.value,
        'latitude': -12.0464,
        'longitude': -77.0428,
        'isDefault': false,
        'visitCount': 0,
        'lastVisit': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Recargar favoritos
      await _loadFavoritesFromFirebase();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lugar agregado a favoritos'),
            backgroundColor: ModernTheme.success,
          ),
        );
      }
    } catch (e) {
      print('Error agregando favorito: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al agregar favorito'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
  
  Future<void> _removeFavorite(FavoritePlace place) async {
    try {
      // Primero eliminar de la lista local para feedback inmediato
      setState(() {
        _favorites.remove(place);
      });
      
      // Luego eliminar de Firebase
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('favorites')
          .doc(place.id)
          .delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${place.name} eliminado'),
            backgroundColor: ModernTheme.success,
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () async {
                // Restaurar en Firebase
                await _firestore
                    .collection('users')
                    .doc(_userId)
                    .collection('favorites')
                    .doc(place.id)
                    .set({
                  'name': place.name,
                  'address': place.address,
                  'icon': _getIconString(place.icon),
                  'color': place.color.value,
                  'latitude': place.location.latitude,
                  'longitude': place.location.longitude,
                  'isDefault': place.isDefault,
                  'visitCount': place.visitCount,
                  'lastVisit': Timestamp.fromDate(place.lastVisit),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                
                // Recargar favoritos
                await _loadFavoritesFromFirebase();
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('Error eliminando favorito: $e');
      
      // Restaurar en caso de error
      setState(() {
        _favorites.add(place);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar favorito'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
  
  Future<void> _editFavorite(FavoritePlace place, String name, String address, IconData icon, Color color) async {
    try {
      setState(() => _isLoading = true);
      
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('favorites')
          .doc(place.id)
          .update({
        'name': name,
        'address': address,
        'icon': _getIconString(icon),
        'color': color.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Recargar favoritos
      await _loadFavoritesFromFirebase();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lugar actualizado'),
            backgroundColor: ModernTheme.success,
          ),
        );
      }
    } catch (e) {
      print('Error actualizando favorito: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar favorito'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }
  
  
  List<FavoritePlace> get _filteredFavorites {
    if (_searchQuery.isEmpty) return _favorites;
    
    return _favorites.where((place) {
      return place.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             place.address.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }
  
  @override
  void dispose() {
    _listController.dispose();
    _fabController.dispose();
    _searchController.dispose();
    _searchTextController.dispose();
    super.dispose();
  }
  
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (_isSearching) {
        _searchController.forward();
      } else {
        _searchController.reverse();
        _searchTextController.clear();
        _searchQuery = '';
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        title: AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          child: _isSearching
              ? TextField(
                  controller: _searchTextController,
                  autofocus: true,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Buscar lugar...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                )
              : Text(
                  'Lugares Favoritos',
                  style: TextStyle(color: Colors.white),
                ),
        ),
        leading: IconButton(
          icon: Icon(
            _isSearching ? Icons.close : Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () {
            if (_isSearching) {
              _toggleSearch();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: Icon(Icons.search, color: Colors.white),
              onPressed: _toggleSearch,
            ),
          IconButton(
            icon: Icon(Icons.map, color: Colors.white),
            onPressed: _showMapView,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Estadísticas
          SliverToBoxAdapter(
            child: _buildStatistics(),
          ),
          
          // Lugares favoritos principales
          if (_filteredFavorites.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  'Tus Lugares',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.textPrimary,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final place = _filteredFavorites[index];
                    final delay = index * 0.1;
                    final animation = Tween<double>(
                      begin: 0,
                      end: 1,
                    ).animate(
                      CurvedAnimation(
                        parent: _listController,
                        curve: Interval(
                          delay,
                          delay + 0.5,
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
                            opacity: animation.value,
                            child: _buildFavoriteCard(place),
                          ),
                        );
                      },
                    );
                  },
                  childCount: _filteredFavorites.length,
                ),
              ),
            ),
          ],
          
          // Lugares recientes
          if (!_isSearching && _searchQuery.isEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  'Visitados Recientemente',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ModernTheme.textPrimary,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final place = _recentPlaces[index];
                    return _buildRecentPlaceCard(place);
                  },
                  childCount: _recentPlaces.length,
                ),
              ),
            ),
          ],
          
          // Espacio al final
          SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _fabController,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabController.value,
            child: FloatingActionButton.extended(
              onPressed: _addNewFavorite,
              backgroundColor: ModernTheme.oasisGreen,
              icon: Icon(Icons.add_location, color: Colors.white),
              label: Text(
                'Agregar Lugar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildStatistics() {
    final totalVisits = _favorites.fold<int>(
      0, (total, place) => total + place.visitCount);
    final mostVisited = _favorites.reduce(
      (a, b) => a.visitCount > b.visitCount ? a : b);
    
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
              _buildStatItem(
                icon: Icons.favorite,
                value: '${_favorites.length}',
                label: 'Favoritos',
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.white24,
              ),
              _buildStatItem(
                icon: Icons.location_on,
                value: '$totalVisits',
                label: 'Visitas',
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.white24,
              ),
              _buildStatItem(
                icon: Icons.star,
                value: mostVisited.name,
                label: 'Más visitado',
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildFavoriteCard(FavoritePlace place) {
    return Dismissible(
      key: Key(place.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: ModernTheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await _confirmDelete(place);
      },
      onDismissed: (direction) async {
        // Eliminar de Firebase
        await _removeFavorite(place);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ModernTheme.cardShadow,
        ),
        child: InkWell(
          onTap: () => _selectPlace(place),
          onLongPress: () => _editPlace(place),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Icono
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: place.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    place.icon,
                    color: place.color,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                
                // Información
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            place.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ModernTheme.textPrimary,
                            ),
                          ),
                          if (place.isDefault) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Principal',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: ModernTheme.oasisGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        place.address,
                        style: TextStyle(
                          fontSize: 14,
                          color: ModernTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: ModernTheme.textSecondary,
                          ),
                          Text(
                            ' ${place.visitCount} visitas',
                            style: TextStyle(
                              fontSize: 12,
                              color: ModernTheme.textSecondary,
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: ModernTheme.textSecondary,
                          ),
                          Text(
                            ' ${_formatLastVisit(place.lastVisit)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: ModernTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Botones de acción
                Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.directions,
                        color: ModernTheme.oasisGreen,
                      ),
                      onPressed: () => _navigateToPlace(place),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildRecentPlaceCard(RecentPlace place) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ModernTheme.backgroundLight,
            shape: BoxShape.circle,
          ),
          child: Icon(
            place.icon,
            color: ModernTheme.textSecondary,
            size: 20,
          ),
        ),
        title: Text(
          place.address,
          style: TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          _formatDate(place.date),
          style: TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.add_circle_outline,
            color: ModernTheme.oasisGreen,
          ),
          onPressed: () => _addRecentToFavorites(place),
        ),
        onTap: () => _selectRecentPlace(place),
      ),
    );
  }
  
  String _formatLastVisit(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inHours < 1) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return 'Hace ${difference.inHours} horas';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else {
      return 'Hace ${difference.inDays} días';
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  void _selectPlace(FavoritePlace place) {
    Navigator.pop(context, place);
  }
  
  void _selectRecentPlace(RecentPlace place) {
    Navigator.pop(context, {
      'address': place.address,
      'isRecent': true,
    });
  }
  
  void _navigateToPlace(FavoritePlace place) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navegando a ${place.name}...'),
        backgroundColor: ModernTheme.oasisGreen,
      ),
    );
    Navigator.pop(context, place);
  }
  
  void _editPlace(FavoritePlace place) {
    _showEditDialog(place);
  }
  
  void _addNewFavorite() {
    _showAddFavoriteDialog();
  }
  
  void _addRecentToFavorites(RecentPlace recentPlace) {
    final newFavorite = FavoritePlace(
      id: 'F${DateTime.now().millisecondsSinceEpoch}',
      name: 'Nuevo Favorito',
      address: recentPlace.address,
      icon: recentPlace.icon,
      color: ModernTheme.primaryBlue,
      location: LatLng(-12.0, -77.0), // Mock location
      visitCount: 1,
      lastVisit: DateTime.now(),
    );
    
    _showEditDialog(newFavorite, isNew: true);
  }
  
  void _showEditDialog(FavoritePlace place, {bool isNew = false}) {
    final nameController = TextEditingController(text: place.name);
    final addressController = TextEditingController(text: place.address);
    IconData selectedIcon = place.icon;
    Color selectedColor = place.color;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(isNew ? 'Agregar Favorito' : 'Editar Lugar'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nombre
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Nombre del lugar',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Dirección
                  TextField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: 'Dirección',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 16),
                  
                  // Selección de icono
                  Text('Icono'),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      Icons.home,
                      Icons.work,
                      Icons.school,
                      Icons.fitness_center,
                      Icons.shopping_cart,
                      Icons.restaurant,
                      Icons.local_hospital,
                      Icons.place,
                    ].map((icon) {
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedIcon = icon;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: selectedIcon == icon
                              ? ModernTheme.oasisGreen.withValues(alpha: 0.2)
                              : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selectedIcon == icon
                                ? ModernTheme.oasisGreen
                                : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(icon, size: 24),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 16),
                  
                  // Selección de color
                  Text('Color'),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ModernTheme.primaryBlue,
                      ModernTheme.warning,
                      ModernTheme.success,
                      Colors.purple,
                      Colors.orange,
                      Colors.pink,
                      Colors.teal,
                      Colors.indigo,
                    ].map((color) {
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = color;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedColor == color
                                ? Colors.black
                                : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);

                  if (isNew) {
                    // Agregar a Firebase
                    await _addToFavorites(
                      nameController.text,
                      addressController.text,
                      selectedIcon,
                      selectedColor,
                    );
                  } else {
                    // Actualizar en Firebase
                    await _editFavorite(
                      place,
                      nameController.text,
                      addressController.text,
                      selectedIcon,
                      selectedColor,
                    );
                  }
                  if (!mounted) return;
                  navigator.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.oasisGreen,
                ),
                child: Text(isNew ? 'Agregar' : 'Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  void _showAddFavoriteDialog() {
    _showEditDialog(
      FavoritePlace(
        id: '',
        name: '',
        address: '',
        icon: Icons.place,
        color: ModernTheme.primaryBlue,
        location: LatLng(0, 0),
        visitCount: 0,
        lastVisit: DateTime.now(),
      ),
      isNew: true,
    );
  }
  
  Future<bool> _confirmDelete(FavoritePlace place) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Eliminar ${place.name}'),
        content: Text(
          '¿Estás seguro de que deseas eliminar este lugar de tus favoritos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.error,
            ),
            child: Text('Eliminar'),
          ),
        ],
      ),
    ) ?? false;
  }
  
  void _showMapView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FavoritesMapScreen(favorites: _favorites),
      ),
    );
  }
}

// Pantalla de mapa con favoritos
class FavoritesMapScreen extends StatefulWidget {
  final List<FavoritePlace> favorites;
  
  const FavoritesMapScreen({super.key, required this.favorites});
  
  @override
  _FavoritesMapScreenState createState() => _FavoritesMapScreenState();
}

class _FavoritesMapScreenState extends State<FavoritesMapScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final bool _isLoading = true;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  
  @override
  void initState() {
    super.initState();
    _createMarkers();
  }
  
  void _createMarkers() {
    for (var place in widget.favorites) {
      _markers.add(
        Marker(
          markerId: MarkerId(place.id),
          position: place.location,
          infoWindow: InfoWindow(
            title: place.name,
            snippet: place.address,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getMarkerHue(place.color),
          ),
        ),
      );
    }
  }
  
  double _getMarkerHue(Color color) {
    if (color == ModernTheme.primaryBlue) return BitmapDescriptor.hueBlue;
    if (color == ModernTheme.warning) return BitmapDescriptor.hueOrange;
    if (color == ModernTheme.success) return BitmapDescriptor.hueGreen;
    if (color == Colors.purple) return BitmapDescriptor.hueViolet;
    return BitmapDescriptor.hueRed;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        title: Text(
          'Mapa de Favoritos',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.favorites.first.location,
          zoom: 13,
        ),
        onMapCreated: (controller) {
          _mapController = controller;
          // Ajustar cámara para mostrar todos los marcadores
          if (_markers.isNotEmpty) {
            _fitAllMarkers();
          }
        },
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
  
  void _fitAllMarkers() {
    if (_markers.isEmpty) return;
    
    double minLat = _markers.first.position.latitude;
    double maxLat = _markers.first.position.latitude;
    double minLng = _markers.first.position.longitude;
    double maxLng = _markers.first.position.longitude;
    
    for (var marker in _markers) {
      minLat = math.min(minLat, marker.position.latitude);
      maxLat = math.max(maxLat, marker.position.latitude);
      minLng = math.min(minLng, marker.position.longitude);
      maxLng = math.max(maxLng, marker.position.longitude);
    }
    
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100,
      ),
    );
  }
}

// Modelos
class FavoritePlace {
  final String id;
  final String name;
  final String address;
  final IconData icon;
  final Color color;
  final LatLng location;
  final bool isDefault;
  final int visitCount;
  final DateTime lastVisit;
  
  FavoritePlace({
    required this.id,
    required this.name,
    required this.address,
    required this.icon,
    required this.color,
    required this.location,
    this.isDefault = false,
    required this.visitCount,
    required this.lastVisit,
  });
}

class RecentPlace {
  final String address;
  final DateTime date;
  final IconData icon;
  
  RecentPlace({
    required this.address,
    required this.date,
    required this.icon,
  });
}