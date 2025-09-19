import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/modern_theme.dart';
import '../../models/document_model.dart';
import '../../providers/document_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_logger.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  DocumentsScreenState createState() => DocumentsScreenState();
}

class DocumentsScreenState extends State<DocumentsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('DocumentsScreen', 'initState');

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );

    _loadDocuments();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _loadDocuments() async {
    final authProvider = context.read<AuthProvider>();
    final documentProvider = context.read<DocumentProvider>();

    if (authProvider.user?.uid != null) {
      await documentProvider.loadDriverDocuments(authProvider.user!.uid);
      _fadeController.forward();
      _slideController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        elevation: 0,
        title: Text(
          'Mis Documentos',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showDocumentInfo,
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshDocuments,
          ),
        ],
      ),
      body: Consumer<DocumentProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return _buildLoadingState();
          }

          if (provider.error != null) {
            return _buildErrorState(provider.error!);
          }

          return _buildDocumentsList(provider);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ModernTheme.oasisGreen),
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando documentos...',
            style: TextStyle(
              color: ModernTheme.textSecondary,
            ),
          ),
          if (context.read<DocumentProvider>().uploadProgress > 0) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: context.read<DocumentProvider>().uploadProgress,
                backgroundColor: Colors.grey.shade300,
                valueColor:
                    AlwaysStoppedAnimation<Color>(ModernTheme.oasisGreen),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Subiendo: ${(context.read<DocumentProvider>().uploadProgress * 100).toInt()}%',
              style: TextStyle(
                color: ModernTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 64, color: ModernTheme.error),
          const SizedBox(height: 16),
          Text(
            'Error al cargar documentos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: ModernTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _refreshDocuments,
            icon: Icon(Icons.refresh),
            label: Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList(DocumentProvider provider) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Status overview
                _buildStatusOverview(provider),

                // Documents list
                _buildDocumentsSection(provider),

                // Actions
                _buildActionsSection(provider),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusOverview(DocumentProvider provider) {
    final overallStatus = _calculateOverallStatus(provider);

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _slideAnimation.value)),
          child: Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: _getStatusGradient(overallStatus),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor(overallStatus).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getStatusIcon(overallStatus),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStatusTitle(overallStatus),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _getStatusDescription(overallStatus),
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Total',
                      '${provider.documents.length}',
                      Icons.description,
                    ),
                    _buildStatItem(
                      'Aprobados',
                      '${provider.getDocumentsByStatus(DocumentStatus.approved).length}',
                      Icons.check_circle,
                    ),
                    _buildStatItem(
                      'Pendientes',
                      '${provider.getDocumentsByStatus(DocumentStatus.pending).length + provider.getDocumentsByStatus(DocumentStatus.underReview).length}',
                      Icons.schedule,
                    ),
                    _buildStatItem(
                      'Rechazados',
                      '${provider.getDocumentsByStatus(DocumentStatus.rejected).length}',
                      Icons.error,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Barra de progreso
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: provider.verificationProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Progreso: ${(provider.verificationProgress * 100).toInt()}%',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
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

  Widget _buildDocumentsSection(DocumentProvider provider) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Lista de Documentos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ModernTheme.textPrimary,
              ),
            ),
          ),
          ...provider.documents.asMap().entries.map((entry) {
            final index = entry.key;
            final document = entry.value;
            final delay = index * 0.1;

            final animation = Tween<double>(
              begin: 0,
              end: 1,
            ).animate(
              CurvedAnimation(
                parent: _slideController,
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
                    child: _buildDocumentCard(document),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(DocumentModel document) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
        border: Border.all(
          color:
              _getDocumentStatusColor(document.status).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _viewDocument(document),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getDocumentStatusColor(document.status)
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getDocumentIcon(document.type),
                      color: _getDocumentStatusColor(document.status),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                document.type.displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: ModernTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (document.type.isRequired)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      ModernTheme.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Requerido',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: ModernTheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          document.type.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: ModernTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getDocumentStatusColor(document.status)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      document.status.displayName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getDocumentStatusColor(document.status),
                      ),
                    ),
                  ),
                ],
              ),
              if (document.url != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (document.uploadedAt != null) ...[
                      Icon(Icons.upload,
                          size: 14, color: ModernTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Subido: ${_formatDate(document.uploadedAt!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                    ],
                    if (document.expiryDate != null) ...[
                      const SizedBox(width: 16),
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: document.isExpiringSoon || document.isExpired
                            ? ModernTheme.warning
                            : ModernTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Vence: ${_formatDate(document.expiryDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: document.isExpiringSoon || document.isExpired
                              ? ModernTheme.warning
                              : ModernTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              if (document.rejectionReason != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ModernTheme.error.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ModernTheme.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline,
                          color: ModernTheme.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          document.rejectionReason!,
                          style: TextStyle(
                            fontSize: 12,
                            color: ModernTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (document.needsDriverAction)
                    ElevatedButton.icon(
                      onPressed: () => _uploadDocument(document.type),
                      icon: Icon(Icons.cloud_upload, size: 16),
                      label: Text(
                        document.url == null ? 'Subir' : 'Actualizar',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModernTheme.oasisGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  if (document.url != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _viewDocument(document),
                      icon: Icon(Icons.visibility, size: 16),
                      label: Text('Ver', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ModernTheme.primaryBlue,
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionsSection(DocumentProvider provider) {
    return Container(
      margin: EdgeInsets.all(16),
      child: Column(
        children: [
          if (!provider.allRequiredDocumentsApproved) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: provider.getDocumentsNeedingAction().isNotEmpty
                    ? _uploadMissingDocuments
                    : null,
                icon: Icon(Icons.upload_file),
                label: Text('Subir Documentos Faltantes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.oasisGreen,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (provider.documents
                      .where((d) => d.url != null && d.type.isRequired)
                      .length ==
                  provider.requiredDocumentTypes.length &&
              !provider.allRequiredDocumentsApproved) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _requestVerification,
                icon: Icon(Icons.verified_user),
                label: Text('Solicitar Verificación'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ModernTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showDocumentInfo,
              icon: Icon(Icons.help_outline),
              label: Text('Ayuda y Requisitos'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ModernTheme.primaryBlue,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateOverallStatus(DocumentProvider provider) {
    final documents = provider.documents;
    final requiredDocuments = documents.where((d) => d.type.isRequired);

    if (requiredDocuments.any((d) => d.status == DocumentStatus.rejected)) {
      return 'rejected';
    }

    if (requiredDocuments.any((d) => d.url == null)) {
      return 'incomplete';
    }

    if (requiredDocuments.any((d) =>
        d.status == DocumentStatus.pending ||
        d.status == DocumentStatus.underReview)) {
      return 'pending';
    }

    if (requiredDocuments.any((d) => d.isExpiringSoon)) {
      return 'expiring';
    }

    if (provider.allRequiredDocumentsApproved) {
      return 'approved';
    }

    return 'pending';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return ModernTheme.success;
      case 'pending':
        return ModernTheme.warning;
      case 'rejected':
      case 'incomplete':
        return ModernTheme.error;
      case 'expiring':
        return Colors.orange;
      default:
        return ModernTheme.textSecondary;
    }
  }

  LinearGradient _getStatusGradient(String status) {
    final color = _getStatusColor(status);
    return LinearGradient(
      colors: [color, color.withValues(alpha: 0.8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'rejected':
      case 'incomplete':
        return Icons.error;
      case 'expiring':
        return Icons.warning;
      default:
        return Icons.description;
    }
  }

  String _getStatusTitle(String status) {
    switch (status) {
      case 'approved':
        return 'Documentos Aprobados';
      case 'pending':
        return 'En Revisión';
      case 'rejected':
        return 'Documentos Rechazados';
      case 'incomplete':
        return 'Documentos Incompletos';
      case 'expiring':
        return 'Documentos por Vencer';
      default:
        return 'Estado de Documentos';
    }
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'approved':
        return 'Todos tus documentos están aprobados y vigentes';
      case 'pending':
        return 'Algunos documentos están siendo revisados';
      case 'rejected':
        return 'Algunos documentos fueron rechazados y necesitan actualización';
      case 'incomplete':
        return 'Faltan documentos requeridos por subir';
      case 'expiring':
        return 'Algunos documentos están próximos a vencer';
      default:
        return 'Revisa el estado de tus documentos';
    }
  }

  Color _getDocumentStatusColor(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.approved:
        return ModernTheme.success;
      case DocumentStatus.underReview:
      case DocumentStatus.pending:
        return ModernTheme.warning;
      case DocumentStatus.rejected:
      case DocumentStatus.expired:
        return ModernTheme.error;
    }
  }

  IconData _getDocumentIcon(DocumentType type) {
    switch (type) {
      case DocumentType.license:
        return Icons.drive_eta;
      case DocumentType.dni:
        return Icons.badge;
      case DocumentType.criminalRecord:
        return Icons.gavel;
      case DocumentType.vehicleCard:
        return Icons.directions_car;
      case DocumentType.soat:
        return Icons.security;
      case DocumentType.technicalReview:
        return Icons.build;
      case DocumentType.vehiclePhotoFront:
      case DocumentType.vehiclePhotoBack:
      case DocumentType.vehiclePhotoPlate:
      case DocumentType.vehiclePhotoInterior:
        return Icons.photo_camera;
      case DocumentType.bankAccount:
        return Icons.account_balance;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _viewDocument(DocumentModel document) {
    if (document.url == null) {
      _uploadDocument(document.type);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    _getDocumentIcon(document.type),
                    color: ModernTheme.oasisGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      document.type.displayName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: CachedNetworkImage(
                  imageUrl: document.url!,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(ModernTheme.oasisGreen),
                    ),
                  ),
                  errorWidget: (context, url, error) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image,
                          size: 64,
                          color: ModernTheme.textSecondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Error al cargar imagen',
                          style: TextStyle(
                            color: ModernTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _uploadDocument(document.type);
                      },
                      icon: Icon(Icons.cloud_upload),
                      label: Text('Actualizar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _uploadDocument(DocumentType documentType) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Subir ${documentType.displayName}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              documentType.description,
              style: TextStyle(
                color: ModernTheme.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromCamera(documentType);
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ModernTheme.primaryBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: ModernTheme.primaryBlue,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Cámara'),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromGallery(documentType);
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.photo_library,
                          color: ModernTheme.oasisGreen,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Galería'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _pickFromCamera(DocumentType documentType) async {
    final authProvider = context.read<AuthProvider>();
    final documentProvider = context.read<DocumentProvider>();

    if (authProvider.user?.uid != null) {
      final success = await documentProvider.takePhotoFromCamera(
        driverId: authProvider.user!.uid,
        documentType: documentType,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Documento subido exitosamente'),
            backgroundColor: ModernTheme.success,
          ),
        );
      } else if (mounted && documentProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(documentProvider.error!),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  void _pickFromGallery(DocumentType documentType) async {
    final authProvider = context.read<AuthProvider>();
    final documentProvider = context.read<DocumentProvider>();

    if (authProvider.user?.uid != null) {
      final success = await documentProvider.pickImageFromGallery(
        driverId: authProvider.user!.uid,
        documentType: documentType,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Documento subido exitosamente'),
            backgroundColor: ModernTheme.success,
          ),
        );
      } else if (mounted && documentProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(documentProvider.error!),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  void _uploadMissingDocuments() {
    final provider = context.read<DocumentProvider>();
    final missingDocs = provider.getDocumentsNeedingAction();

    if (missingDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay documentos pendientes por subir'),
          backgroundColor: ModernTheme.info,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Documentos Pendientes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Documentos que necesitan acción:'),
            const SizedBox(height: 12),
            ...missingDocs.map((doc) => Container(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getDocumentStatusColor(doc.status)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getDocumentIcon(doc.type),
                        size: 16,
                        color: _getDocumentStatusColor(doc.status),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(doc.type.displayName)),
                      Text(
                        doc.status.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: _getDocumentStatusColor(doc.status),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _requestVerification() async {
    final authProvider = context.read<AuthProvider>();
    final documentProvider = context.read<DocumentProvider>();

    if (authProvider.user?.uid != null) {
      final success =
          await documentProvider.requestVerification(authProvider.user!.uid);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Solicitud de verificación enviada exitosamente'),
            backgroundColor: ModernTheme.success,
          ),
        );
      } else if (mounted && documentProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(documentProvider.error!),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    }
  }

  void _showDocumentInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.info, color: ModernTheme.oasisGreen),
            const SizedBox(width: 8),
            Text('Información de Documentos'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Estados de Documentos:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildInfoItem(
                  Icons.check_circle,
                  'Aprobado',
                  'El documento fue verificado y aceptado',
                  ModernTheme.success),
              _buildInfoItem(
                  Icons.schedule,
                  'En Revisión',
                  'El documento está siendo revisado por nuestro equipo',
                  ModernTheme.warning),
              _buildInfoItem(
                  Icons.pending,
                  'Pendiente',
                  'El documento está pendiente de subir o revisar',
                  ModernTheme.warning),
              _buildInfoItem(
                  Icons.error,
                  'Rechazado',
                  'El documento fue rechazado y debe ser actualizado',
                  ModernTheme.error),
              _buildInfoItem(
                  Icons.timer_off,
                  'Vencido',
                  'El documento está vencido y debe renovarse',
                  ModernTheme.error),
              const SizedBox(height: 16),
              Text(
                'Consejos importantes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                  '• Asegúrate de que los documentos sean legibles y estén vigentes'),
              Text('• Usa buena iluminación al tomar las fotos'),
              Text('• Evita documentos borrosos o con reflejos'),
              Text('• Mantén tus documentos actualizados'),
              Text('• Incluye todas las fotos del vehículo solicitadas'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
            ),
            child: Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
      IconData icon, String title, String description, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: ModernTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _refreshDocuments() {
    _loadDocuments();
  }
}
