// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, library_private_types_in_public_api
import 'package:flutter/material.dart';
import '../../core/theme/modern_theme.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  _DocumentsScreenState createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  
  // Documents data
  List<DocumentInfo> _documents = [];
  bool _isLoading = true;
  String _overallStatus = 'pending';
  
  @override
  void initState() {
    super.initState();
    
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
    // Simulate loading documents
    await Future.delayed(Duration(seconds: 1));
    
    setState(() {
      _documents = [
        DocumentInfo(
          id: 'license',
          name: 'Licencia de Conducir',
          description: 'Licencia de conducir profesional vigente',
          status: DocumentStatus.approved,
          expiryDate: DateTime.now().add(Duration(days: 730)),
          uploadDate: DateTime.now().subtract(Duration(days: 45)),
          fileUrl: '/mock/license.jpg',
          isRequired: true,
          category: DocumentCategory.license,
          rejectionReason: null,
        ),
        DocumentInfo(
          id: 'id_card',
          name: 'Documento de Identidad',
          description: 'DNI o Pasaporte vigente',
          status: DocumentStatus.approved,
          expiryDate: DateTime.now().add(Duration(days: 1095)),
          uploadDate: DateTime.now().subtract(Duration(days: 30)),
          fileUrl: '/mock/dni.jpg',
          isRequired: true,
          category: DocumentCategory.identity,
          rejectionReason: null,
        ),
        DocumentInfo(
          id: 'vehicle_registration',
          name: 'Tarjeta de Propiedad',
          description: 'Registro vehicular vigente',
          status: DocumentStatus.pending,
          expiryDate: DateTime.now().add(Duration(days: 365)),
          uploadDate: DateTime.now().subtract(Duration(days: 2)),
          fileUrl: '/mock/tarjeta_propiedad.jpg',
          isRequired: true,
          category: DocumentCategory.vehicle,
          rejectionReason: null,
        ),
        DocumentInfo(
          id: 'insurance',
          name: 'SOAT',
          description: 'Seguro Obligatorio de Accidentes de Tránsito',
          status: DocumentStatus.expiring,
          expiryDate: DateTime.now().add(Duration(days: 25)),
          uploadDate: DateTime.now().subtract(Duration(days: 340)),
          fileUrl: '/mock/soat.jpg',
          isRequired: true,
          category: DocumentCategory.insurance,
          rejectionReason: null,
        ),
        DocumentInfo(
          id: 'technical_review',
          name: 'Revisión Técnica',
          description: 'Certificado de revisión técnica vehicular',
          status: DocumentStatus.rejected,
          expiryDate: DateTime.now().subtract(Duration(days: 10)),
          uploadDate: DateTime.now().subtract(Duration(days: 5)),
          fileUrl: '/mock/revision_tecnica.jpg',
          isRequired: true,
          category: DocumentCategory.vehicle,
          rejectionReason: 'El documento se encuentra vencido. Por favor, renueve su revisión técnica.',
        ),
        DocumentInfo(
          id: 'background_check',
          name: 'Antecedentes Policiales',
          description: 'Certificado de antecedentes policiales',
          status: DocumentStatus.approved,
          expiryDate: DateTime.now().add(Duration(days: 270)),
          uploadDate: DateTime.now().subtract(Duration(days: 60)),
          fileUrl: '/mock/antecedentes.jpg',
          isRequired: true,
          category: DocumentCategory.background,
          rejectionReason: null,
        ),
        DocumentInfo(
          id: 'bank_account',
          name: 'Certificación Bancaria',
          description: 'Certificado de cuenta bancaria para depósitos',
          status: DocumentStatus.missing,
          expiryDate: null,
          uploadDate: null,
          fileUrl: null,
          isRequired: false,
          category: DocumentCategory.financial,
          rejectionReason: null,
        ),
      ];
      
      _overallStatus = _calculateOverallStatus();
      _isLoading = false;
    });
    
    _fadeController.forward();
    _slideController.forward();
  }
  
  String _calculateOverallStatus() {
    final required = _documents.where((d) => d.isRequired);
    
    if (required.any((d) => d.status == DocumentStatus.rejected)) {
      return 'rejected';
    }
    
    if (required.any((d) => d.status == DocumentStatus.missing)) {
      return 'incomplete';
    }
    
    if (required.any((d) => d.status == DocumentStatus.pending)) {
      return 'pending';
    }
    
    if (required.any((d) => d.status == DocumentStatus.expiring)) {
      return 'expiring';
    }
    
    return 'approved';
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
      body: _isLoading ? _buildLoadingState() : _buildDocumentsList(),
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
          SizedBox(height: 16),
          Text(
            'Cargando documentos...',
            style: TextStyle(
              color: ModernTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDocumentsList() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Status overview
                _buildStatusOverview(),
                
                // Documents list
                _buildDocumentsSection(),
                
                // Actions
                _buildActionsSection(),
                
                SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatusOverview() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _slideAnimation.value)),
          child: Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: _getStatusGradient(),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor().withValues(alpha: 0.3),
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
                        _getStatusIcon(),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStatusTitle(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _getStatusDescription(),
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
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Total',
                      '${_documents.length}',
                      Icons.description,
                    ),
                    _buildStatItem(
                      'Aprobados',
                      '${_documents.where((d) => d.status == DocumentStatus.approved).length}',
                      Icons.check_circle,
                    ),
                    _buildStatItem(
                      'Pendientes',
                      '${_documents.where((d) => d.status == DocumentStatus.pending).length}',
                      Icons.schedule,
                    ),
                    _buildStatItem(
                      'Por vencer',
                      '${_documents.where((d) => d.status == DocumentStatus.expiring).length}',
                      Icons.warning,
                    ),
                  ],
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
        SizedBox(height: 4),
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
  
  Widget _buildDocumentsSection() {
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
          ..._documents.asMap().entries.map((entry) {
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
  
  Widget _buildDocumentCard(DocumentInfo document) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ModernTheme.cardShadow,
        border: Border.all(
          color: _getDocumentStatusColor(document.status).withValues(alpha: 0.3),
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
                      color: _getDocumentStatusColor(document.status).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getDocumentIcon(document.category),
                      color: _getDocumentStatusColor(document.status),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                document.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: ModernTheme.textPrimary,
                                ),
                              ),
                            ),
                            if (document.isRequired)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: ModernTheme.error.withValues(alpha: 0.1),
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
                        SizedBox(height: 2),
                        Text(
                          document.description,
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
                      color: _getDocumentStatusColor(document.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getDocumentStatusText(document.status),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getDocumentStatusColor(document.status),
                      ),
                    ),
                  ),
                ],
              ),
              
              if (document.status != DocumentStatus.missing) ...[
                SizedBox(height: 12),
                Row(
                  children: [
                    if (document.uploadDate != null) ...[
                      Icon(Icons.upload, size: 14, color: ModernTheme.textSecondary),
                      SizedBox(width: 4),
                      Text(
                        'Subido: ${_formatDate(document.uploadDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ModernTheme.textSecondary,
                        ),
                      ),
                    ],
                    if (document.expiryDate != null) ...[
                      SizedBox(width: 16),
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: document.status == DocumentStatus.expiring
                            ? ModernTheme.warning
                            : ModernTheme.textSecondary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Vence: ${_formatDate(document.expiryDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: document.status == DocumentStatus.expiring
                              ? ModernTheme.warning
                              : ModernTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              
              if (document.rejectionReason != null) ...[
                SizedBox(height: 12),
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
                      Icon(Icons.error_outline, color: ModernTheme.error, size: 16),
                      SizedBox(width: 8),
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
              
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (document.status == DocumentStatus.missing ||
                      document.status == DocumentStatus.rejected ||
                      document.status == DocumentStatus.expiring)
                    ElevatedButton.icon(
                      onPressed: () => _uploadDocument(document),
                      icon: Icon(Icons.cloud_upload, size: 16),
                      label: Text(
                        document.status == DocumentStatus.missing ? 'Subir' : 'Actualizar',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModernTheme.oasisGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  if (document.fileUrl != null) ...[
                    SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _viewDocument(document),
                      icon: Icon(Icons.visibility, size: 16),
                      label: Text('Ver', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ModernTheme.primaryBlue,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
  
  Widget _buildActionsSection() {
    return Container(
      margin: EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _uploadAllDocuments,
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
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _downloadTemplate,
              icon: Icon(Icons.download),
              label: Text('Descargar Lista de Documentos'),
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
  
  Color _getStatusColor() {
    switch (_overallStatus) {
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
  
  LinearGradient _getStatusGradient() {
    final color = _getStatusColor();
    return LinearGradient(
      colors: [color, color.withValues(alpha: 0.8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  IconData _getStatusIcon() {
    switch (_overallStatus) {
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
  
  String _getStatusTitle() {
    switch (_overallStatus) {
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
  
  String _getStatusDescription() {
    switch (_overallStatus) {
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
      case DocumentStatus.pending:
        return ModernTheme.warning;
      case DocumentStatus.rejected:
        return ModernTheme.error;
      case DocumentStatus.expiring:
        return Colors.orange;
      case DocumentStatus.missing:
        return ModernTheme.textSecondary;
    }
  }
  
  String _getDocumentStatusText(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.approved:
        return 'Aprobado';
      case DocumentStatus.pending:
        return 'Pendiente';
      case DocumentStatus.rejected:
        return 'Rechazado';
      case DocumentStatus.expiring:
        return 'Por vencer';
      case DocumentStatus.missing:
        return 'Faltante';
    }
  }
  
  IconData _getDocumentIcon(DocumentCategory category) {
    switch (category) {
      case DocumentCategory.license:
        return Icons.drive_eta;
      case DocumentCategory.identity:
        return Icons.badge;
      case DocumentCategory.vehicle:
        return Icons.directions_car;
      case DocumentCategory.insurance:
        return Icons.security;
      case DocumentCategory.background:
        return Icons.verified_user;
      case DocumentCategory.financial:
        return Icons.account_balance;
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  void _viewDocument(DocumentInfo document) {
    if (document.fileUrl == null) {
      _uploadDocument(document);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    _getDocumentIcon(document.category),
                    color: ModernTheme.oasisGreen,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      document.name,
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
              SizedBox(height: 16),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: ModernTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image,
                      size: 64,
                      color: ModernTheme.textSecondary,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Vista previa del documento',
                      style: TextStyle(
                        color: ModernTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '(Simulación)',
                      style: TextStyle(
                        color: ModernTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _uploadDocument(document);
                      },
                      icon: Icon(Icons.cloud_upload),
                      label: Text('Actualizar'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _downloadDocument(document);
                      },
                      icon: Icon(Icons.download),
                      label: Text('Descargar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ModernTheme.oasisGreen,
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
  
  void _uploadDocument(DocumentInfo document) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Subir ${document.name}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromCamera(document);
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
                      SizedBox(height: 8),
                      Text('Cámara'),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromGallery(document);
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
                      SizedBox(height: 8),
                      Text('Galería'),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromFiles(document);
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.folder,
                          color: Colors.orange,
                          size: 32,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Archivos'),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  void _pickFromCamera(DocumentInfo document) {
    // Simulate camera upload
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Documento capturado y subido exitosamente'),
        backgroundColor: ModernTheme.success,
      ),
    );
    
    setState(() {
      final index = _documents.indexWhere((d) => d.id == document.id);
      if (index != -1) {
        _documents[index] = DocumentInfo(
          id: document.id,
          name: document.name,
          description: document.description,
          status: DocumentStatus.pending,
          expiryDate: document.expiryDate,
          uploadDate: DateTime.now(),
          fileUrl: '/mock/camera/${document.id}.jpg',
          isRequired: document.isRequired,
          category: document.category,
          rejectionReason: null,
        );
      }
      _overallStatus = _calculateOverallStatus();
    });
  }
  
  void _pickFromGallery(DocumentInfo document) {
    // Simulate gallery upload
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Documento seleccionado y subido exitosamente'),
        backgroundColor: ModernTheme.success,
      ),
    );
    
    setState(() {
      final index = _documents.indexWhere((d) => d.id == document.id);
      if (index != -1) {
        _documents[index] = DocumentInfo(
          id: document.id,
          name: document.name,
          description: document.description,
          status: DocumentStatus.pending,
          expiryDate: document.expiryDate,
          uploadDate: DateTime.now(),
          fileUrl: '/mock/gallery/${document.id}.jpg',
          isRequired: document.isRequired,
          category: document.category,
          rejectionReason: null,
        );
      }
      _overallStatus = _calculateOverallStatus();
    });
  }
  
  void _pickFromFiles(DocumentInfo document) {
    // Simulate file upload
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Archivo seleccionado y subido exitosamente'),
        backgroundColor: ModernTheme.success,
      ),
    );
    
    setState(() {
      final index = _documents.indexWhere((d) => d.id == document.id);
      if (index != -1) {
        _documents[index] = DocumentInfo(
          id: document.id,
          name: document.name,
          description: document.description,
          status: DocumentStatus.pending,
          expiryDate: document.expiryDate,
          uploadDate: DateTime.now(),
          fileUrl: '/mock/files/${document.id}.pdf',
          isRequired: document.isRequired,
          category: document.category,
          rejectionReason: null,
        );
      }
      _overallStatus = _calculateOverallStatus();
    });
  }
  
  void _downloadDocument(DocumentInfo document) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Descargando ${document.name}...'),
        backgroundColor: ModernTheme.info,
      ),
    );
  }
  
  void _uploadAllDocuments() {
    final missingDocs = _documents.where((d) => 
        d.isRequired && (d.status == DocumentStatus.missing || d.status == DocumentStatus.rejected));
    
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
        title: Text('Subir Documentos Faltantes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Documentos pendientes:'),
            SizedBox(height: 8),
            ...missingDocs.map((doc) => Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Text('• ${doc.name}'),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _bulkUploadDocuments(missingDocs.toList());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernTheme.oasisGreen,
            ),
            child: Text('Continuar'),
          ),
        ],
      ),
    );
  }
  
  void _bulkUploadDocuments(List<DocumentInfo> documents) {
    // Simulate bulk upload
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Iniciando carga masiva de documentos...'),
        backgroundColor: ModernTheme.info,
      ),
    );
    
    // Show upload for each document with a delay
    for (int i = 0; i < documents.length; i++) {
      Future.delayed(Duration(seconds: i * 2), () {
        _uploadDocument(documents[i]);
      });
    }
  }
  
  void _downloadTemplate() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Descargando lista de documentos requeridos...'),
        backgroundColor: ModernTheme.info,
      ),
    );
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
            SizedBox(width: 8),
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
              SizedBox(height: 8),
              _buildInfoItem(Icons.check_circle, 'Aprobado', 'El documento fue verificado y aceptado', ModernTheme.success),
              _buildInfoItem(Icons.schedule, 'Pendiente', 'El documento está siendo revisado', ModernTheme.warning),
              _buildInfoItem(Icons.error, 'Rechazado', 'El documento fue rechazado y debe ser actualizado', ModernTheme.error),
              _buildInfoItem(Icons.warning, 'Por vencer', 'El documento está próximo a vencer', Colors.orange),
              _buildInfoItem(Icons.description, 'Faltante', 'El documento no ha sido subido', ModernTheme.textSecondary),
              SizedBox(height: 16),
              Text(
                'Consejos:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Asegúrate de que los documentos sean legibles y estén vigentes'),
              Text('• Usa buena iluminación al tomar las fotos'),
              Text('• Evita documentos borrosos o con reflejos'),
              Text('• Mantén tus documentos actualizados'),
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
  
  Widget _buildInfoItem(IconData icon, String title, String description, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(width: 8),
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
    setState(() => _isLoading = true);
    _loadDocuments();
  }
}

// Models
class DocumentInfo {
  final String id;
  final String name;
  final String description;
  final DocumentStatus status;
  final DateTime? expiryDate;
  final DateTime? uploadDate;
  final String? fileUrl;
  final bool isRequired;
  final DocumentCategory category;
  final String? rejectionReason;
  
  DocumentInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    this.expiryDate,
    this.uploadDate,
    this.fileUrl,
    required this.isRequired,
    required this.category,
    this.rejectionReason,
  });
}

enum DocumentStatus {
  approved,
  pending,
  rejected,
  expiring,
  missing,
}

enum DocumentCategory {
  license,
  identity,
  vehicle,
  insurance,
  background,
  financial,
}