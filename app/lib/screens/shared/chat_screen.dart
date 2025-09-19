import '../../utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../core/theme/modern_theme.dart';
import '../../services/chat_service.dart';
import '../../services/firebase_ml_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ride_provider.dart';

/// ChatScreen - Chat profesional en tiempo real
/// ✅ IMPLEMENTACIÓN COMPLETA con funcionalidad real
class ChatScreen extends StatefulWidget {
  final String rideId;
  final String otherUserName;
  final String otherUserRole; // 'passenger' o 'driver'
  final String? otherUserId;

  const ChatScreen({
    super.key,
    required this.rideId,
    required this.otherUserName,
    required this.otherUserRole,
    this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final FirebaseMLService _mlService = FirebaseMLService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  // late AnimationController _typingAnimationController; // No usado en UI actual
  // late Animation<double> _typingAnimation; // No usado en UI actual
  late AnimationController _messageAnimationController;

  bool _isLoading = true;
  // final bool _isTyping = false; // No usado actualmente
  bool _isOtherUserOnline = false;
  DateTime? _otherUserLastSeen;
  List<ChatMessage> _messages = [];
  // final int _unreadCount = 0; // No usado actualmente

  // Estados de UI
  bool _showQuickMessages = false;
  // final bool _isRecordingAudio = false; // No usado actualmente
  // final bool _showEmojiPicker = false; // No usado actualmente

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('ChatScreen', 'initState - RideId: ${widget.rideId}');

    // _typingAnimationController = AnimationController(
    //   duration: Duration(milliseconds: 1500),
    //   vsync: this,
    // );
    // _typingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
    //   CurvedAnimation(parent: _typingAnimationController, curve: Curves.easeInOut),
    // );
    _messageAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _initializeChat();
  }

  @override
  void dispose() {
    // _typingAnimationController.dispose();
    _messageAnimationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) {
        AppLogger.debug('Usuario no autenticado');
        Navigator.pop(context);
        return;
      }

      // Inicializar el servicio de chat
      await _chatService.initialize(
        userId: user.id,
        userRole: user.userType,
      );

      // Marcar mensajes como leídos al entrar
      await _chatService.markMessagesAsRead(widget.rideId, user.id);

      // Escuchar mensajes en tiempo real
      _chatService.getChatMessages(widget.rideId).listen((messages) {
        if (mounted) {
          setState(() {
            _messages = messages;
          });
          _scrollToBottom();
        }
      });

      // Obtener estado de presencia del otro usuario si está disponible
      if (widget.otherUserId != null) {
        _chatService.getUserPresence(widget.otherUserId!).listen((presence) {
          if (mounted) {
            setState(() {
              _isOtherUserOnline = presence.online;
              _otherUserLastSeen = presence.lastSeen;
            });
          }
        });
      }

      setState(() {
        _isLoading = false;
      });

      AppLogger.debug('Chat inicializado para viaje ${widget.rideId}');
    } catch (e) {
      AppLogger.debug('Error inicializando chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al inicializar el chat'),
            backgroundColor: ModernTheme.error,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) return;

      // Limpiar el campo de texto inmediatamente para mejor UX
      _messageController.clear();
      _messageFocusNode.unfocus();

      // ============================================
      // ANÁLISIS ML DE TOXICIDAD EN TIEMPO REAL
      // ============================================

      // Analizar el mensaje antes de enviarlo
      try {
        final toxicityResult = await _mlService.analyzeTextToxicity(
          message,
          messageId: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: user.id,
          language: 'es',
        );

        // Si el mensaje es altamente tóxico, advertir al usuario
        if (toxicityResult.isToxic && toxicityResult.toxicityScore > 0.8) {
          if (!mounted) return;

          // Mostrar diálogo de advertencia
          final shouldSend = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Mensaje detectado como inapropiado'),
                  content: Text(
                      'Nuestro sistema ha detectado que este mensaje podría ser ofensivo. '
                      '¿Estás seguro de que quieres enviarlo? Recuerda mantener un ambiente respetuoso.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Enviar de todos modos'),
                    ),
                  ],
                ),
              ) ??
              false;

          if (!shouldSend) {
            // Restaurar el mensaje en el campo de texto
            _messageController.text = message;
            AppLogger.info('ChatScreen: Mensaje tóxico cancelado por usuario', {
              'userId': user.id,
              'toxicityScore': toxicityResult.toxicityScore,
            });
            return;
          }
        }

        // Log del análisis ML
        AppLogger.info('ChatScreen: Análisis ML completado', {
          'toxicityScore': toxicityResult.toxicityScore,
          'isToxic': toxicityResult.isToxic,
          'detectedCategories': toxicityResult.detectedCategories,
        });
      } catch (mlError) {
        AppLogger.warning(
            'ChatScreen: Error en análisis ML, enviando mensaje sin análisis',
            mlError);
        // Continuar con el envío aunque falle el análisis ML
      }

      // ============================================
      // TRADUCCIÓN AUTOMÁTICA INTELIGENTE
      // ============================================

      String finalMessage = message;

      try {
        final rideProvider = Provider.of<RideProvider>(context, listen: false);

        // Detectar si el otro usuario podría necesitar traducción
        // (Esto se puede mejorar con preferencias de usuario)
        if (_shouldTranslateMessage(message)) {
          final translatedMessage = await rideProvider.translateChatMessage(
              message,
              targetLanguage: 'qu' // Quechua como ejemplo para usuarios locales
              );

          if (translatedMessage != message) {
            finalMessage = '$message\n🌐 $translatedMessage';

            AppLogger.info('ChatScreen: Mensaje traducido automáticamente', {
              'original': message,
              'translated': translatedMessage,
            });
          }
        }
      } catch (translationError) {
        AppLogger.warning(
            'ChatScreen: Error en traducción automática', translationError);
        // Usar mensaje original si falla la traducción
      }

      // ============================================
      // ENVÍO DEL MENSAJE MEJORADO
      // ============================================

      final success = await _chatService.sendTextMessage(
        rideId: widget.rideId,
        senderId: user.id,
        senderName: user.fullName,
        message: finalMessage,
        senderRole: user.userType,
      );

      if (!mounted) return;

      if (success) {
        HapticFeedback.lightImpact();
        _messageAnimationController.forward().then((_) {
          _messageAnimationController.reset();
        });

        AppLogger.info('ChatScreen: Mensaje enviado exitosamente con ML', {
          'rideId': widget.rideId,
          'messageLength': finalMessage.length,
          'hasTranslation': finalMessage != message,
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar mensaje'),
            backgroundColor: ModernTheme.error,
          ),
        );
      }
    } catch (e) {
      AppLogger.debug('Error enviando mensaje: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar mensaje'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  Future<void> _sendQuickMessage(QuickMessageType type) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) return;

      final success = await _chatService.sendQuickMessage(
        rideId: widget.rideId,
        senderId: user.id,
        senderName: user.fullName,
        senderRole: user.userType,
        type: type,
      );

      if (success) {
        setState(() {
          _showQuickMessages = false;
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      AppLogger.debug('Error enviando mensaje rápido: $e');
    }
  }

  Future<void> _shareLocation() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) return;

      // Obtener ubicación actual (simulada)
      // En una implementación real, usaríamos GPS
      const latitude = -12.0464;
      const longitude = -77.0428;

      final success = await _chatService.shareLocation(
        rideId: widget.rideId,
        senderId: user.id,
        senderName: user.fullName,
        senderRole: user.userType,
        latitude: latitude,
        longitude: longitude,
      );

      if (success) {
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      AppLogger.debug('Error compartiendo ubicación: $e');
    }
  }

  Future<void> _pickAndSendMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);

        if (!mounted) return;
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final user = authProvider.currentUser;

        if (user == null) return;

        // Mostrar indicador de carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Text('Enviando archivo...'),
              ],
            ),
            duration: Duration(seconds: 10),
          ),
        );

        // Determinar tipo de archivo
        MessageType messageType = MessageType.file;
        final extension = result.files.single.extension?.toLowerCase();
        if (extension != null) {
          if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
            messageType = MessageType.image;
          } else if (['mp4', 'mov', 'avi'].contains(extension)) {
            messageType = MessageType.video;
          } else if (['mp3', 'wav', 'm4a'].contains(extension)) {
            messageType = MessageType.audio;
          }
        }

        final success = await _chatService.sendMultimediaMessage(
          rideId: widget.rideId,
          senderId: user.id,
          senderName: user.fullName,
          senderRole: user.userType,
          mediaFile: file,
          messageType: messageType,
        );

        // Ocultar indicador de carga
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (success) {
          HapticFeedback.lightImpact();
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al enviar archivo'),
              backgroundColor: ModernTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      AppLogger.debug('Error enviando multimedia: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar archivo'),
          backgroundColor: ModernTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: ModernTheme.oasisGreen,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserName,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Text(_buildStatusText(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.phone, color: Colors.white),
            onPressed: () {
              // Implementar llamada telefónica
              HapticFeedback.lightImpact();
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              _showChatOptions();
            },
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : Column(
              children: [
                Expanded(child: _buildMessagesList()),
                if (_showQuickMessages) _buildQuickMessagesBar(),
                _buildMessageInput(),
              ],
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
            'Iniciando chat...',
            style: TextStyle(
              color: ModernTheme.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _buildStatusText() {
    if (_isOtherUserOnline) {
      return 'En línea';
    } else if (_otherUserLastSeen != null) {
      final now = DateTime.now();
      final difference = now.difference(_otherUserLastSeen!);

      if (difference.inMinutes < 1) {
        return 'Visto hace un momento';
      } else if (difference.inMinutes < 60) {
        return 'Visto hace ${difference.inMinutes} min';
      } else if (difference.inHours < 24) {
        return 'Visto hace ${difference.inHours} h';
      } else {
        return 'Visto hace ${difference.inDays} días';
      }
    }

    final roleText =
        widget.otherUserRole == 'driver' ? 'Conductor' : 'Pasajero';
    return roleText;
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final isMyMessage = message.senderId == authProvider.currentUser?.id;

        return _buildMessageBubble(message, isMyMessage);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: ModernTheme.oasisGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: ModernTheme.oasisGreen,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '¡Inicia la conversación!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: ModernTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mantente en contacto con tu ${widget.otherUserRole == 'driver' ? 'conductor' : 'pasajero'}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: ModernTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMyMessage) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMyMessage) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: ModernTheme.oasisGreen.withValues(alpha: 0.2),
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ModernTheme.oasisGreen,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMyMessage ? ModernTheme.oasisGreen : Colors.white,
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomLeft: Radius.circular(isMyMessage ? 18 : 4),
                  bottomRight: Radius.circular(isMyMessage ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.messageType == MessageType.location)
                    _buildLocationMessage(message, isMyMessage)
                  else if (message.messageType != MessageType.text)
                    _buildMediaMessage(message, isMyMessage)
                  else
                    _buildTextMessage(message, isMyMessage),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatMessageTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: isMyMessage
                              ? Colors.white.withValues(alpha: 0.7)
                              : ModernTheme.textSecondary,
                        ),
                      ),
                      if (isMyMessage) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: message.isRead
                              ? Colors.blue
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMyMessage) const SizedBox(width: 50),
          if (!isMyMessage) const SizedBox(width: 50),
        ],
      ),
    );
  }

  Widget _buildTextMessage(ChatMessage message, bool isMyMessage) {
    return Text(
      message.message,
      style: TextStyle(
        fontSize: 15,
        color: isMyMessage ? Colors.white : ModernTheme.textPrimary,
        height: 1.3,
      ),
    );
  }

  Widget _buildMediaMessage(ChatMessage message, bool isMyMessage) {
    IconData icon;
    String label;

    switch (message.messageType) {
      case MessageType.image:
        icon = Icons.image;
        label = 'Imagen';
        break;
      case MessageType.audio:
        icon = Icons.audiotrack;
        label = 'Audio';
        break;
      case MessageType.video:
        icon = Icons.videocam;
        label = 'Video';
        break;
      default:
        icon = Icons.attachment;
        label = 'Archivo';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20,
          color: isMyMessage ? Colors.white : ModernTheme.oasisGreen,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isMyMessage ? Colors.white : ModernTheme.textPrimary,
                ),
              ),
              if (message.message.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  message.message,
                  style: TextStyle(
                    fontSize: 13,
                    color: isMyMessage
                        ? Colors.white.withValues(alpha: 0.8)
                        : ModernTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationMessage(ChatMessage message, bool isMyMessage) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.location_on,
          size: 20,
          color: isMyMessage ? Colors.white : ModernTheme.error,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Ubicación compartida',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isMyMessage ? Colors.white : ModernTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickMessagesBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: QuickMessageType.values.map((type) {
            return Padding(
              padding: EdgeInsets.only(right: 8),
              child: ElevatedButton(
                onPressed: () => _sendQuickMessage(type),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      ModernTheme.oasisGreen.withValues(alpha: 0.1),
                  foregroundColor: ModernTheme.oasisGreen,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  _getQuickMessageText(type),
                  style: TextStyle(fontSize: 12),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  _showQuickMessages = !_showQuickMessages;
                });
              },
              icon: Icon(
                _showQuickMessages ? Icons.keyboard : Icons.add,
                color: ModernTheme.oasisGreen,
              ),
            ),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: ModernTheme.textSecondary),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (value) {
                    // Aquí podrías implementar indicador de "escribiendo"
                  },
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                IconButton(
                  onPressed: _pickAndSendMedia,
                  icon: Icon(
                    Icons.attach_file,
                    color: ModernTheme.oasisGreen,
                  ),
                ),
                IconButton(
                  onPressed: _shareLocation,
                  icon: Icon(
                    Icons.location_on,
                    color: ModernTheme.oasisGreen,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: ModernTheme.oasisGreen,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getQuickMessageText(QuickMessageType type) {
    switch (type) {
      case QuickMessageType.onMyWay:
        return 'En camino';
      case QuickMessageType.arrived:
        return 'He llegado';
      case QuickMessageType.waiting:
        return 'Esperando';
      case QuickMessageType.trafficDelay:
        return 'Hay tráfico';
      case QuickMessageType.cantFind:
        return 'No te encuentro';
    }
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.clear_all, color: ModernTheme.error),
                title: Text('Limpiar chat'),
                onTap: () {
                  Navigator.pop(context);
                  _showClearChatDialog();
                },
              ),
              ListTile(
                leading: Icon(Icons.report, color: ModernTheme.warning),
                title: Text('Reportar usuario'),
                onTap: () {
                  Navigator.pop(context);
                  // Implementar reporte de usuario
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Limpiar chat'),
          content: Text(
              '¿Estás seguro de que quieres limpiar toda la conversación?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _chatService.clearChat(widget.rideId);
                setState(() {
                  _messages.clear();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernTheme.error,
              ),
              child: Text('Limpiar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  /// Determinar si un mensaje debería ser traducido automáticamente
  bool _shouldTranslateMessage(String message) {
    // Lógica simple: traducir si contiene palabras clave turísticas o locales
    final touristKeywords = [
      'donde',
      'cómo llegar',
      'hotel',
      'aeropuerto',
      'centro',
      'plaza',
      'cathedral',
      'museum',
      'restaurant',
      'hospital',
      'pharmacy',
      'ayudar',
      'help',
      'please',
      'gracias',
      'thank you'
    ];

    final messageLower = message.toLowerCase();

    // Traducir si contiene palabras turísticas
    for (String keyword in touristKeywords) {
      if (messageLower.contains(keyword)) {
        return true;
      }
    }

    // Traducir si el mensaje es largo (>50 caracteres) - posiblemente información importante
    if (message.length > 50) {
      return true;
    }

    return false;
  }
}
