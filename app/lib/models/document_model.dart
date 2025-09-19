import 'package:cloud_firestore/cloud_firestore.dart';

/// Estados posibles de un documento
enum DocumentStatus {
  pending('pending', 'Pendiente'),
  underReview('under_review', 'En Revisión'),
  approved('approved', 'Aprobado'),
  rejected('rejected', 'Rechazado'),
  expired('expired', 'Vencido');

  const DocumentStatus(this.value, this.displayName);
  final String value;
  final String displayName;

  static DocumentStatus fromString(String value) {
    return DocumentStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => DocumentStatus.pending,
    );
  }
}

/// Tipos de documentos requeridos
enum DocumentType {
  license('license', 'Licencia de Conducir', true),
  dni('dni', 'DNI', true),
  criminalRecord('criminal_record', 'Antecedentes Penales', true),
  vehicleCard('vehicle_card', 'Tarjeta de Propiedad', true),
  soat('soat', 'SOAT', true),
  technicalReview('technical_review', 'Revisión Técnica', true),
  vehiclePhotoFront('vehicle_photo_front', 'Foto Frontal del Vehículo', true),
  vehiclePhotoBack('vehicle_photo_back', 'Foto Trasera del Vehículo', true),
  vehiclePhotoPlate('vehicle_photo_plate', 'Foto de Placa del Vehículo', true),
  vehiclePhotoInterior(
      'vehicle_photo_interior', 'Foto Interior del Vehículo', true),
  bankAccount('bank_account', 'Certificación Bancaria', false);

  const DocumentType(this.value, this.displayName, this.isRequired);
  final String value;
  final String displayName;
  final bool isRequired;

  static DocumentType fromString(String value) {
    return DocumentType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => DocumentType.license,
    );
  }

  /// Obtiene la descripción detallada del documento
  String get description {
    switch (this) {
      case DocumentType.license:
        return 'Foto clara de tu licencia de conducir profesional vigente';
      case DocumentType.dni:
        return 'Foto de ambos lados de tu DNI';
      case DocumentType.criminalRecord:
        return 'Certificado de antecedentes penales reciente (máximo 3 meses)';
      case DocumentType.vehicleCard:
        return 'Tarjeta de propiedad del vehículo vigente';
      case DocumentType.soat:
        return 'Seguro obligatorio de accidentes de tránsito vigente';
      case DocumentType.technicalReview:
        return 'Certificado de revisión técnica vehicular vigente';
      case DocumentType.vehiclePhotoFront:
        return 'Foto clara de la parte frontal del vehículo';
      case DocumentType.vehiclePhotoBack:
        return 'Foto clara de la parte trasera del vehículo';
      case DocumentType.vehiclePhotoPlate:
        return 'Foto clara de la placa del vehículo';
      case DocumentType.vehiclePhotoInterior:
        return 'Foto del interior del vehículo mostrando asientos';
      case DocumentType.bankAccount:
        return 'Certificado de cuenta bancaria para depósitos de ganancias';
    }
  }
}

/// Modelo de documento para conductores
class DocumentModel {
  final String id;
  final DocumentType type;
  final DocumentStatus status;
  final String? url;
  final String? fileName;
  final DateTime? uploadedAt;
  final DateTime? expiryDate;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;
  final Map<String, dynamic>? metadata;

  DocumentModel({
    required this.id,
    required this.type,
    required this.status,
    this.url,
    this.fileName,
    this.uploadedAt,
    this.expiryDate,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
    this.metadata,
  });

  /// Constructor desde Firestore
  factory DocumentModel.fromFirestore(Map<String, dynamic> data, String id) {
    return DocumentModel(
      id: id,
      type: DocumentType.fromString(data['type'] ?? ''),
      status: DocumentStatus.fromString(data['status'] ?? 'pending'),
      url: data['url'],
      fileName: data['fileName'],
      uploadedAt: data['uploadedAt'] is Timestamp
          ? (data['uploadedAt'] as Timestamp).toDate()
          : data['uploadedAt'] != null
              ? DateTime.parse(data['uploadedAt'])
              : null,
      expiryDate: data['expiryDate'] is Timestamp
          ? (data['expiryDate'] as Timestamp).toDate()
          : data['expiryDate'] != null
              ? DateTime.parse(data['expiryDate'])
              : null,
      reviewedAt: data['reviewedAt'] is Timestamp
          ? (data['reviewedAt'] as Timestamp).toDate()
          : data['reviewedAt'] != null
              ? DateTime.parse(data['reviewedAt'])
              : null,
      reviewedBy: data['reviewedBy'],
      rejectionReason: data['rejectionReason'],
      metadata: data['metadata'],
    );
  }

  /// Conversión a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.value,
      'status': status.value,
      'url': url,
      'fileName': fileName,
      'uploadedAt': uploadedAt,
      'expiryDate': expiryDate,
      'reviewedAt': reviewedAt,
      'reviewedBy': reviewedBy,
      'rejectionReason': rejectionReason,
      'metadata': metadata,
    };
  }

  /// Crea una copia con cambios específicos
  DocumentModel copyWith({
    String? id,
    DocumentType? type,
    DocumentStatus? status,
    String? url,
    String? fileName,
    DateTime? uploadedAt,
    DateTime? expiryDate,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? rejectionReason,
    Map<String, dynamic>? metadata,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      url: url ?? this.url,
      fileName: fileName ?? this.fileName,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      expiryDate: expiryDate ?? this.expiryDate,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Verifica si el documento está vencido
  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  /// Verifica si el documento está próximo a vencer (30 días)
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final daysUntilExpiry = expiryDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 30 && daysUntilExpiry > 0;
  }

  /// Verifica si el documento necesita acción del conductor
  bool get needsDriverAction {
    return status == DocumentStatus.rejected ||
        status == DocumentStatus.expired ||
        (url == null && type.isRequired);
  }

  @override
  String toString() {
    return 'DocumentModel(id: $id, type: ${type.displayName}, status: ${status.displayName})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DocumentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Estado general de verificación del conductor
class DriverVerificationStatus {
  final bool isVerified;
  final String
      status; // 'pending', 'under_review', 'approved', 'rejected', 'incomplete'
  final DateTime? verificationDate;
  final String? rejectionReason;
  final List<DocumentModel> documents;
  final int pendingDocuments;
  final int approvedDocuments;
  final int rejectedDocuments;

  DriverVerificationStatus({
    required this.isVerified,
    required this.status,
    this.verificationDate,
    this.rejectionReason,
    required this.documents,
    required this.pendingDocuments,
    required this.approvedDocuments,
    required this.rejectedDocuments,
  });

  /// Constructor desde datos de Firestore
  factory DriverVerificationStatus.fromFirestore(
    Map<String, dynamic> driverData,
    List<DocumentModel> documents,
  ) {
    final pending =
        documents.where((d) => d.status == DocumentStatus.pending).length;
    final approved =
        documents.where((d) => d.status == DocumentStatus.approved).length;
    final rejected =
        documents.where((d) => d.status == DocumentStatus.rejected).length;

    return DriverVerificationStatus(
      isVerified: driverData['isVerified'] ?? false,
      status: driverData['verificationStatus'] ?? 'pending',
      verificationDate: driverData['verificationDate'] is Timestamp
          ? (driverData['verificationDate'] as Timestamp).toDate()
          : null,
      rejectionReason: driverData['rejectionReason'],
      documents: documents,
      pendingDocuments: pending,
      approvedDocuments: approved,
      rejectedDocuments: rejected,
    );
  }

  /// Verifica si todos los documentos requeridos están completos
  bool get allRequiredDocumentsUploaded {
    final requiredTypes = DocumentType.values.where((type) => type.isRequired);
    for (final type in requiredTypes) {
      final hasDocument =
          documents.any((doc) => doc.type == type && doc.url != null);
      if (!hasDocument) return false;
    }
    return true;
  }

  /// Verifica si todos los documentos requeridos están aprobados
  bool get allRequiredDocumentsApproved {
    final requiredTypes = DocumentType.values.where((type) => type.isRequired);
    for (final type in requiredTypes) {
      final hasApprovedDocument = documents.any(
        (doc) => doc.type == type && doc.status == DocumentStatus.approved,
      );
      if (!hasApprovedDocument) return false;
    }
    return true;
  }

  /// Verifica si hay documentos próximos a vencer
  bool get hasExpiringDocuments {
    return documents.any((doc) => doc.isExpiringSoon);
  }

  /// Verifica si hay documentos vencidos
  bool get hasExpiredDocuments {
    return documents.any((doc) => doc.isExpired);
  }

  /// Obtiene documentos que necesitan acción del conductor
  List<DocumentModel> get documentsNeedingAction {
    return documents.where((doc) => doc.needsDriverAction).toList();
  }
}
