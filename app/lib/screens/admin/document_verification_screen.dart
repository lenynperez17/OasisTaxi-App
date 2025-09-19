import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/modern_theme.dart';
import '../../providers/admin_document_provider.dart';
import '../../models/document_model.dart';
import '../../services/firebase_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/app_logger.dart';

class DocumentVerificationScreen extends StatefulWidget {
  const DocumentVerificationScreen({super.key});

  @override
  State<DocumentVerificationScreen> createState() =>
      DocumentVerificationScreenState();
}

class DocumentVerificationScreenState extends State<DocumentVerificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AdminDocumentProvider _documentProvider;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('DocumentVerificationScreen', 'initState');
    _tabController = TabController(length: 3, vsync: this);
    _documentProvider = context.read<AdminDocumentProvider>();
    _loadDocuments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    await _documentProvider.loadPendingVerifications();
    await _documentProvider.loadAdminNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisBlack,
        elevation: 0,
        title: const Text(
          'Verificación de Documentos',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: ModernTheme.oasisGreen,
          labelColor: ModernTheme.oasisGreen,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Pendientes'),
            Tab(text: 'En Revisión'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: Consumer<AdminDocumentProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: ModernTheme.oasisGreen,
              ),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar documentos',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.red.shade300,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadDocuments,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModernTheme.oasisGreen,
                    ),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildPendingTab(provider),
              _buildInReviewTab(provider),
              _buildHistoryTab(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPendingTab(AdminDocumentProvider provider) {
    final pendingDrivers = provider.pendingVerifications
        .where((batch) => batch.verificationStatus == 'pending')
        .toList();

    if (pendingDrivers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        title: 'No hay documentos pendientes',
        subtitle: 'Todos los documentos han sido revisados',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      color: ModernTheme.oasisGreen,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pendingDrivers.length,
        itemBuilder: (context, index) {
          final batch = pendingDrivers[index];
          return _buildDriverCard(batch);
        },
      ),
    );
  }

  Widget _buildInReviewTab(AdminDocumentProvider provider) {
    final inReviewDrivers = provider.pendingVerifications
        .where((batch) => batch.verificationStatus == 'under_review')
        .toList();

    if (inReviewDrivers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.pending_outlined,
        title: 'No hay documentos en revisión',
        subtitle: 'Los documentos pendientes aparecerán aquí',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      color: ModernTheme.oasisGreen,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: inReviewDrivers.length,
        itemBuilder: (context, index) {
          final batch = inReviewDrivers[index];
          return _buildDriverCard(batch);
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firebaseService.firestore
          .collection('drivers')
          .where('verificationStatus', whereIn: ['approved', 'rejected'])
          .orderBy('verificationDate', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: ModernTheme.oasisGreen,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history,
            title: 'Sin historial',
            subtitle: 'Los documentos procesados aparecerán aquí',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildHistoryCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildDriverCard(DriverDocumentBatch batch) {
    final hasUrgent = batch.hasUrgentDocuments;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasUrgent ? Colors.orange : Colors.transparent,
          width: hasUrgent ? 2 : 0,
        ),
      ),
      child: InkWell(
        onTap: () => _showDocumentDetails(batch),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor:
                        ModernTheme.oasisGreen.withValues(alpha: 0.1),
                    backgroundImage: batch.driverInfo.photoUrl != null
                        ? CachedNetworkImageProvider(batch.driverInfo.photoUrl!)
                        : null,
                    child: batch.driverInfo.photoUrl == null
                        ? Text(
                            batch.driverInfo.name[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: ModernTheme.oasisGreen,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          batch.driverInfo.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          batch.driverInfo.email,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              batch.driverInfo.phone,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (hasUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'URGENTE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (batch.driverInfo.vehicleInfo != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.directions_car,
                        color: ModernTheme.oasisGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${batch.driverInfo.vehicleInfo!.displayName} - ${batch.driverInfo.vehicleInfo!.plate}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${batch.pendingDocumentsCount} documentos pendientes',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Solicitado ${_formatDate(batch.requestedAt)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showDocumentDetails(batch),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('Revisar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ModernTheme.oasisGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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

  Widget _buildHistoryCard(String driverId, Map<String, dynamic> data) {
    final isApproved = data['verificationStatus'] == 'approved';
    final verificationDate = data['verificationDate'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isApproved
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.1),
          child: Icon(
            isApproved ? Icons.check_circle : Icons.cancel,
            color: isApproved ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          data['name'] ?? 'Conductor',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['email'] ?? ''),
            const SizedBox(height: 4),
            Text(
              verificationDate != null
                  ? 'Verificado: ${_formatDate(verificationDate.toDate())}'
                  : 'Sin fecha',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isApproved
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isApproved ? 'Aprobado' : 'Rechazado',
            style: TextStyle(
              color: isApproved ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showDocumentDetails(DriverDocumentBatch batch) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DocumentDetailsModal(
        batch: batch,
        onApprove: (documentType) => _approveDocument(batch, documentType),
        onReject: (documentType, reason) =>
            _rejectDocument(batch, documentType, reason),
      ),
    );
  }

  Future<void> _approveDocument(
      DriverDocumentBatch batch, DocumentType documentType) async {
    final success = await _documentProvider.approveDocument(
      driverId: batch.driverInfo.id,
      documentType: documentType,
      comments: 'Documento verificado y aprobado',
    );

    if (success && mounted) {
      SnackbarHelper.showSuccess(
        context,
        'Documento ${documentType.displayName} aprobado',
      );
      _loadDocuments();
    } else if (mounted) {
      SnackbarHelper.showError(
        context,
        'Error al aprobar el documento',
      );
    }
  }

  Future<void> _rejectDocument(
    DriverDocumentBatch batch,
    DocumentType documentType,
    String reason,
  ) async {
    final success = await _documentProvider.rejectDocument(
      driverId: batch.driverInfo.id,
      documentType: documentType,
      rejectionReason: reason,
    );

    if (success && mounted) {
      SnackbarHelper.showWarning(
        context,
        'Documento ${documentType.displayName} rechazado',
      );
      _loadDocuments();
    } else if (mounted) {
      SnackbarHelper.showError(
        context,
        'Error al rechazar el documento',
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'hace ${difference.inMinutes} minutos';
      }
      return 'hace ${difference.inHours} horas';
    } else if (difference.inDays == 1) {
      return 'ayer';
    } else if (difference.inDays < 7) {
      return 'hace ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class DocumentDetailsModal extends StatefulWidget {
  final DriverDocumentBatch batch;
  final Function(DocumentType) onApprove;
  final Function(DocumentType, String) onReject;

  const DocumentDetailsModal({
    super.key,
    required this.batch,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<DocumentDetailsModal> createState() => _DocumentDetailsModalState();
}

class _DocumentDetailsModalState extends State<DocumentDetailsModal> {
  DocumentModel? _selectedDocument;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.batch.driverInfo.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.batch.driverInfo.email,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.batch.documents.length,
                  itemBuilder: (context, index) {
                    final document = widget.batch.documents[index];
                    return _buildDocumentCard(document);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocumentCard(DocumentModel document) {
    final isSelected = _selectedDocument?.id == document.id;
    final statusColor = _getStatusColor(document.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? ModernTheme.oasisGreen : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedDocument = isSelected ? null : document;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getDocumentIcon(document.type),
                    color: statusColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.type.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                document.status.displayName,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (document.isExpired) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'EXPIRADO',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (document.url != null) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: document.url!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: ModernTheme.oasisGreen,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (document.uploadedAt != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Subido: ${_formatDate(document.uploadedAt!)}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
              if (document.expiryDate != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Expira: ${_formatDate(document.expiryDate!)}',
                  style: TextStyle(
                    color:
                        document.isExpired ? Colors.red : Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: document.isExpired
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
              if (isSelected &&
                  document.status == DocumentStatus.underReview) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          widget.onApprove(document.type);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Aprobar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showRejectDialog(document),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Rechazar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRejectDialog(DocumentModel document) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rechazar ${document.type.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Por favor, indica el motivo del rechazo:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ej: Documento ilegible, fecha expirada, etc.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: ModernTheme.oasisGreen,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                widget.onReject(document.type, reasonController.text.trim());
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
  }

  IconData _getDocumentIcon(DocumentType type) {
    switch (type) {
      case DocumentType.license:
        return Icons.badge;
      case DocumentType.dni:
        return Icons.credit_card;
      case DocumentType.criminalRecord:
        return Icons.verified_user;
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
      // default:  // Todos los casos están cubiertos
      //   return Icons.description;
    }
  }

  Color _getStatusColor(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.pending:
        return Colors.orange;
      case DocumentStatus.underReview:
        return Colors.blue;
      case DocumentStatus.approved:
        return Colors.green;
      case DocumentStatus.rejected:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'hace ${difference.inMinutes} minutos';
      }
      return 'hace ${difference.inHours} horas';
    } else if (difference.inDays == 1) {
      return 'ayer';
    } else if (difference.inDays < 7) {
      return 'hace ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
