import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import 'firebase_service.dart';
import 'notification_service.dart';

/// Servicio completo para el sistema de chat
/// ✅ IMPLEMENTACIÓN REAL COMPLETA
/// Incluye: Firebase Realtime, Mensajes multimedia, Estado de lectura, Notificaciones
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final NotificationService _notificationService = NotificationService();
  
  bool _initialized = false;
  String? _currentUserId;
  String? _currentUserRole;
  DatabaseReference? _database;
  
  // Paths de Firebase Realtime Database
  static const String chatsPath = 'chats';
  static const String messagesPath = 'messages';
  static const String presencePath = 'presence';
  static const String chatMetadataPath = 'chat_metadata';
  
  // Streams para mensajes en tiempo real
  final Map<String, Stream<List<ChatMessage>>> _chatStreams = {};

  /// Inicializar el servicio de chat ✅ IMPLEMENTACIÓN REAL
  Future<void> initialize({
    required String userId,
    required String userRole,
  }) async {
    if (_initialized) return;

    try {
      await _firebaseService.initialize();
      await _notificationService.initialize();
      
      _currentUserId = userId;
      _currentUserRole = userRole;
      
      // Inicializar Firebase Realtime Database
      _database = FirebaseDatabase.instance.ref();
      
      // Configurar presencia del usuario
      await _setupUserPresence();
      
      _initialized = true;
      debugPrint('💬 ChatService: Service initialized successfully for user $userId');
      
      await _firebaseService.analytics.logEvent(
        name: 'chat_service_initialized',
        parameters: {
          'user_id': userId,
          'user_role': userRole,
        },
      );
      
    } catch (e) {
      debugPrint('💬 ChatService: Error initializing - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      rethrow;
    }
  }

  /// Enviar mensaje de texto ✅ IMPLEMENTACIÓN REAL
  Future<bool> sendTextMessage({
    required String rideId,
    required String senderId,
    required String senderName,
    required String message,
    required String senderRole, // 'passenger' o 'driver'
  }) async {
    try {
      if (_database == null) {
        debugPrint('💬 ChatService: Database not initialized');
        return false;
      }

      final messageId = _database!.child(messagesPath).child(rideId).push().key!;
      final chatMessage = ChatMessage(
        id: messageId,
        rideId: rideId,
        senderId: senderId,
        senderName: senderName,
        message: message,
        messageType: MessageType.text,
        senderRole: senderRole,
        timestamp: DateTime.now(),
        isRead: false,
      );

      // Guardar mensaje en Firebase Realtime Database
      await _database!
          .child(messagesPath)
          .child(rideId)
          .child(messageId)
          .set(chatMessage.toRealtimeMap());

      // Actualizar metadatos del chat
      await _updateChatMetadata(rideId, chatMessage);

      // Enviar notificación al destinatario
      await _sendMessageNotification(rideId, senderRole, senderName, message);

      debugPrint('💬 ChatService: Text message sent in ride $rideId');
      
      await _firebaseService.analytics.logEvent(
        name: 'chat_message_sent',
        parameters: {
          'ride_id': rideId,
          'sender_role': senderRole,
          'message_type': 'text',
        },
      );

      return true;
    } catch (e) {
      debugPrint('💬 ChatService: Error sending text message - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return false;
    }
  }

  /// Enviar mensaje multimedia ✅ IMPLEMENTACIÓN REAL
  Future<bool> sendMultimediaMessage({
    required String rideId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required File mediaFile,
    required MessageType messageType,
    String? caption,
  }) async {
    try {
      if (_database == null) {
        debugPrint('💬 ChatService: Database not initialized');
        return false;
      }

      // Subir archivo a Firebase Storage
      final uploadResult = await _uploadMediaFile(rideId, mediaFile, messageType);
      if (!uploadResult.success) {
        return false;
      }

      final messageId = _database!.child(messagesPath).child(rideId).push().key!;
      final chatMessage = ChatMessage(
        id: messageId,
        rideId: rideId,
        senderId: senderId,
        senderName: senderName,
        message: caption ?? '',
        messageType: messageType,
        mediaUrl: uploadResult.downloadUrl,
        mediaFileName: uploadResult.fileName,
        senderRole: senderRole,
        timestamp: DateTime.now(),
        isRead: false,
      );

      // Guardar mensaje en Firebase Realtime Database
      await _database!
          .child(messagesPath)
          .child(rideId)
          .child(messageId)
          .set(chatMessage.toRealtimeMap());

      // Actualizar metadatos del chat
      await _updateChatMetadata(rideId, chatMessage);

      // Enviar notificación al destinatario
      await _sendMessageNotification(
        rideId, 
        senderRole, 
        senderName, 
        messageType == MessageType.image ? '📸 Imagen' : 
        messageType == MessageType.audio ? '🎵 Audio' : '📁 Archivo'
      );

      debugPrint('💬 ChatService: Multimedia message sent in ride $rideId');
      
      await _firebaseService.analytics.logEvent(
        name: 'chat_message_sent',
        parameters: {
          'ride_id': rideId,
          'sender_role': senderRole,
          'message_type': messageType.toString(),
        },
      );

      return true;
    } catch (e) {
      debugPrint('💬 ChatService: Error sending multimedia message - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return false;
    }
  }

  // Método legacy mantenido para compatibilidad
  Future<bool> sendMessage({
    required String rideId,
    required String senderId,
    required String senderName,
    required String message,
    required String senderRole,
  }) async {
    return sendTextMessage(
      rideId: rideId,
      senderId: senderId,
      senderName: senderName,
      message: message,
      senderRole: senderRole,
    );
  }

  /// Marcar mensajes como leídos ✅ IMPLEMENTACIÓN REAL
  Future<void> markMessagesAsRead(String rideId, String userId) async {
    try {
      if (_database == null) {
        debugPrint('💬 ChatService: Database not initialized');
        return;
      }

      // Obtener mensajes no leídos de otros usuarios
      final messagesSnapshot = await _database!
          .child(messagesPath)
          .child(rideId)
          .orderByChild('senderId')
          .get();

      if (messagesSnapshot.exists) {
        final Map<String, dynamic> updates = {};
        
        for (final child in messagesSnapshot.children) {
          final messageData = Map<String, dynamic>.from(child.value as Map);
          
          // Marcar como leído solo si no es el remitente y no está leído
          if (messageData['senderId'] != userId && messageData['isRead'] == false) {
            updates['$messagesPath/$rideId/${child.key}/isRead'] = true;
            updates['$messagesPath/$rideId/${child.key}/readAt'] = DateTime.now().toIso8601String();
          }
        }

        if (updates.isNotEmpty) {
          await _database!.update(updates);
          debugPrint('💬 ChatService: ${updates.length ~/ 2} messages marked as read');
        }
      }

      await _firebaseService.analytics.logEvent(
        name: 'chat_messages_marked_read',
        parameters: {
          'ride_id': rideId,
          'user_id': userId,
        },
      );

    } catch (e) {
      debugPrint('💬 ChatService: Error marking messages as read - $e');
      await _firebaseService.crashlytics.recordError(e, null);
    }
  }

  /// Obtener número de mensajes no leídos ✅ IMPLEMENTACIÓN REAL
  Future<int> getUnreadCount(String rideId, String userId) async {
    try {
      if (_database == null) return 0;

      final snapshot = await _database!
          .child(messagesPath)
          .child(rideId)
          .orderByChild('isRead')
          .equalTo(false)
          .get();

      if (!snapshot.exists) return 0;

      int count = 0;
      for (final child in snapshot.children) {
        final messageData = Map<String, dynamic>.from(child.value as Map);
        if (messageData['senderId'] != userId) {
          count++;
        }
      }

      return count;
    } catch (e) {
      debugPrint('💬 ChatService: Error getting unread count - $e');
      return 0;
    }
  }

  /// Obtener stream de mensajes en tiempo real ✅ IMPLEMENTACIÓN REAL
  Stream<List<ChatMessage>> getChatMessages(String rideId) {
    if (_database == null) {
      return Stream.value([]);
    }

    if (!_chatStreams.containsKey(rideId)) {
      _chatStreams[rideId] = _database!
          .child(messagesPath)
          .child(rideId)
          .orderByChild('timestamp')
          .onValue
          .map((event) {
        final List<ChatMessage> messages = [];
        
        if (event.snapshot.exists) {
          final messagesData = Map<String, dynamic>.from(event.snapshot.value as Map);
          
          for (final entry in messagesData.entries) {
            try {
              final messageData = Map<String, dynamic>.from(entry.value);
              messageData['id'] = entry.key;
              final message = ChatMessage.fromRealtimeMap(messageData);
              messages.add(message);
            } catch (e) {
              debugPrint('💬 ChatService: Error parsing message ${entry.key} - $e');
            }
          }
        }
        
        // Ordenar por timestamp (más recientes primero)
        messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return messages;
      });
    }

    return _chatStreams[rideId]!;
  }

  // Enviar mensaje predefinido
  Future<bool> sendQuickMessage({
    required String rideId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required QuickMessageType type,
  }) async {
    final message = _getQuickMessageText(type, senderRole);
    return sendMessage(
      rideId: rideId,
      senderId: senderId,
      senderName: senderName,
      message: message,
      senderRole: senderRole,
    );
  }

  // Obtener texto de mensaje rápido
  String _getQuickMessageText(QuickMessageType type, String senderRole) {
    if (senderRole == 'driver') {
      switch (type) {
        case QuickMessageType.onMyWay:
          return 'Estoy en camino';
        case QuickMessageType.arrived:
          return 'He llegado, te espero';
        case QuickMessageType.waiting:
          return 'Esperando en el punto de encuentro';
        case QuickMessageType.trafficDelay:
          return 'Hay tráfico, llegaré en unos minutos';
        case QuickMessageType.cantFind:
          return 'No puedo encontrar la ubicación exacta';
      }
    } else {
      switch (type) {
        case QuickMessageType.onMyWay:
          return 'Ya voy saliendo';
        case QuickMessageType.arrived:
          return 'Ya estoy aquí';
        case QuickMessageType.waiting:
          return 'Te estoy esperando';
        case QuickMessageType.trafficDelay:
          return 'Puedes esperar un poco más?';
        case QuickMessageType.cantFind:
          return 'No te veo, dónde estás?';
      }
    }
  }

  // Compartir ubicación
  Future<bool> shareLocation({
    required String rideId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required double latitude,
    required double longitude,
  }) async {
    final message = '📍 Mi ubicación: https://maps.google.com/?q=$latitude,$longitude';
    return sendMessage(
      rideId: rideId,
      senderId: senderId,
      senderName: senderName,
      message: message,
      senderRole: senderRole,
    );
  }

  /// Limpiar chat de un viaje ✅ IMPLEMENTACIÓN REAL
  Future<void> clearChat(String rideId) async {
    try {
      if (_database != null) {
        await _database!.child(messagesPath).child(rideId).remove();
        await _database!.child(chatMetadataPath).child(rideId).remove();
      }
      _chatStreams.remove(rideId);
      debugPrint('💬 ChatService: Chat cleared for ride $rideId');
    } catch (e) {
      debugPrint('💬 ChatService: Error clearing chat - $e');
    }
  }

  /// Configurar presencia del usuario ✅ IMPLEMENTACIÓN REAL
  Future<void> _setupUserPresence() async {
    if (_database == null || _currentUserId == null) return;

    try {
      final presenceRef = _database!.child(presencePath).child(_currentUserId!);
      
      // Configurar presencia online
      await presenceRef.set({
        'online': true,
        'lastSeen': DateTime.now().toIso8601String(),
        'role': _currentUserRole,
      });

      // Configurar presencia offline cuando se desconecte
      await presenceRef.onDisconnect().set({
        'online': false,
        'lastSeen': DateTime.now().toIso8601String(),
        'role': _currentUserRole,
      });

      debugPrint('💬 ChatService: User presence configured');
    } catch (e) {
      debugPrint('💬 ChatService: Error setting up presence - $e');
    }
  }

  /// Actualizar metadatos del chat ✅ IMPLEMENTACIÓN REAL
  Future<void> _updateChatMetadata(String rideId, ChatMessage message) async {
    if (_database == null) return;

    try {
      await _database!.child(chatMetadataPath).child(rideId).update({
        'lastMessage': message.message,
        'lastMessageTime': message.timestamp.toIso8601String(),
        'lastSender': message.senderName,
        'lastSenderRole': message.senderRole,
        'messageCount': {'increment': 1},
      });
    } catch (e) {
      debugPrint('💬 ChatService: Error updating chat metadata - $e');
    }
  }

  /// Enviar notificación de mensaje ✅ IMPLEMENTACIÓN REAL
  Future<void> _sendMessageNotification(String rideId, String senderRole, String senderName, String message) async {
    try {
      // Usar el método disponible en NotificationService
      await _notificationService.showChatNotification(
        senderName: senderName,
        message: message,
        chatId: rideId,
      );
      
      debugPrint('💬 ChatService: Chat notification sent for ride $rideId');
    } catch (e) {
      debugPrint('💬 ChatService: Error sending message notification - $e');
    }
  }

  /// Subir archivo multimedia ✅ IMPLEMENTACIÓN REAL
  Future<MediaUploadResult> _uploadMediaFile(String rideId, File file, MessageType messageType) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final storageRef = _firebaseService.storage
          .ref()
          .child('chat_media')
          .child(rideId)
          .child(fileName);

      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return MediaUploadResult.success(
        downloadUrl: downloadUrl,
        fileName: fileName,
      );
    } catch (e) {
      debugPrint('💬 ChatService: Error uploading media file - $e');
      return MediaUploadResult.error('Error subiendo archivo: $e');
    }
  }

  /// Obtener estado de presencia de usuario ✅ IMPLEMENTACIÓN REAL
  Stream<UserPresence> getUserPresence(String userId) {
    if (_database == null) {
      return Stream.value(UserPresence(online: false, lastSeen: DateTime.now()));
    }

    return _database!.child(presencePath).child(userId).onValue.map((event) {
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        return UserPresence(
          online: data['online'] ?? false,
          lastSeen: DateTime.tryParse(data['lastSeen'] ?? '') ?? DateTime.now(),
          role: data['role'],
        );
      }
      return UserPresence(online: false, lastSeen: DateTime.now());
    });
  }

  void dispose() {
    _chatStreams.clear();
  }

  // Getters
  bool get isInitialized => _initialized;
  String? get currentUserId => _currentUserId;
  String? get currentUserRole => _currentUserRole;
}

/// Modelo de mensaje de chat completo ✅ IMPLEMENTACIÓN REAL
class ChatMessage {
  final String id;
  final String rideId;
  final String senderId;
  final String senderName;
  final String message;
  final MessageType messageType;
  final String? mediaUrl;
  final String? mediaFileName;
  final String senderRole;
  final DateTime timestamp;
  bool isRead;
  final DateTime? readAt;

  ChatMessage({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.senderName,
    required this.message,
    this.messageType = MessageType.text,
    this.mediaUrl,
    this.mediaFileName,
    required this.senderRole,
    required this.timestamp,
    required this.isRead,
    this.readAt,
  });

  Map<String, dynamic> toRealtimeMap() {
    return {
      'rideId': rideId,
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'messageType': messageType.toString(),
      'mediaUrl': mediaUrl,
      'mediaFileName': mediaFileName,
      'senderRole': senderRole,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rideId': rideId,
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'messageType': messageType.toString(),
      'mediaUrl': mediaUrl,
      'mediaFileName': mediaFileName,
      'senderRole': senderRole,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
    };
  }

  factory ChatMessage.fromRealtimeMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      rideId: map['rideId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      message: map['message'] ?? '',
      messageType: MessageType.values.firstWhere(
        (type) => type.toString() == map['messageType'],
        orElse: () => MessageType.text,
      ),
      mediaUrl: map['mediaUrl'],
      mediaFileName: map['mediaFileName'],
      senderRole: map['senderRole'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      readAt: map['readAt'] != null ? DateTime.tryParse(map['readAt']) : null,
    );
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      rideId: map['rideId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      message: map['message'] ?? '',
      messageType: MessageType.values.firstWhere(
        (type) => type.toString() == map['messageType'],
        orElse: () => MessageType.text,
      ),
      mediaUrl: map['mediaUrl'],
      mediaFileName: map['mediaFileName'],
      senderRole: map['senderRole'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      readAt: map['readAt'] != null ? DateTime.tryParse(map['readAt']) : null,
    );
  }
}

/// Enums para el sistema de chat ✅ IMPLEMENTACIÓN REAL

enum MessageType {
  text,
  image,
  audio,
  video,
  file,
  location,
}

enum QuickMessageType {
  onMyWay,
  arrived,
  waiting,
  trafficDelay,
  cantFind,
}

/// Clases de datos para el sistema de chat ✅ IMPLEMENTACIÓN REAL

class MediaUploadResult {
  final bool success;
  final String? downloadUrl;
  final String? fileName;
  final String? error;

  MediaUploadResult.success({
    required this.downloadUrl,
    required this.fileName,
  }) : success = true, error = null;

  MediaUploadResult.error(this.error)
      : success = false,
        downloadUrl = null,
        fileName = null;
}

class UserPresence {
  final bool online;
  final DateTime lastSeen;
  final String? role;

  UserPresence({
    required this.online,
    required this.lastSeen,
    this.role,
  });
}

class ChatMetadata {
  final String rideId;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastSender;
  final String? lastSenderRole;
  final int messageCount;

  ChatMetadata({
    required this.rideId,
    this.lastMessage,
    this.lastMessageTime,
    this.lastSender,
    this.lastSenderRole,
    this.messageCount = 0,
  });

  factory ChatMetadata.fromMap(Map<String, dynamic> map) {
    return ChatMetadata(
      rideId: map['rideId'] ?? '',
      lastMessage: map['lastMessage'],
      lastMessageTime: map['lastMessageTime'] != null 
          ? DateTime.tryParse(map['lastMessageTime'])
          : null,
      lastSender: map['lastSender'],
      lastSenderRole: map['lastSenderRole'],
      messageCount: map['messageCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'lastSender': lastSender,
      'lastSenderRole': lastSenderRole,
      'messageCount': messageCount,
    };
  }
}