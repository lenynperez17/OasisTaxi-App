# 🚀 CONFIGURACIÓN MERCADOPAGO PARA OASIS TAXI PERÚ

## 📋 GUÍA COMPLETA DE CONFIGURACIÓN

### 🎯 PASO 1: CREAR CUENTA DESARROLLADOR MERCADOPAGO

1. **Ir al portal de desarrolladores:**
   ```
   https://www.mercadopago.com.pe/developers/
   ```

2. **Crear cuenta o iniciar sesión:**
   - Usar email corporativo: `dev@oasistaxi.com.pe`
   - Configurar perfil como "Desarrollador"

3. **Crear nueva aplicación:**
   - Nombre: `Oasis Taxi Peru`
   - Descripción: `Plataforma de taxi en Perú - Pagos seguros`
   - Rubro: `Transporte y logística`
   - País: `Perú`
   - Moneda: `PEN (Soles peruanos)`

### 🔧 PASO 2: CONFIGURAR APLICACIÓN

#### A) Configuración básica:
```json
{
  "nombre": "Oasis Taxi Peru",
  "descripcion": "Plataforma de taxi en Perú con pagos seguros",
  "sitio_web": "https://oasistaxi.com.pe",
  "logo": "https://oasistaxi.com.pe/logo-512.png",
  "categoria": "Transporte",
  "pais": "PE"
}
```

#### B) URLs importantes:
- **Webhook URL:** `https://api.oasistaxi.com.pe/api/v1/payments/webhook`
- **Success URL:** `https://app.oasistaxi.com.pe/payment/success`
- **Failure URL:** `https://app.oasistaxi.com.pe/payment/failure`
- **Pending URL:** `https://app.oasistaxi.com.pe/payment/pending`

#### C) Configurar métodos de pago para Perú:

**Tarjetas habilitadas:**
- ✅ Visa (crédito y débito)
- ✅ Mastercard (crédito y débito)
- ✅ American Express
- ✅ Diners Club

**Métodos locales Perú:**
- ✅ PagoEfectivo (efectivo)
- ✅ Transferencias bancarias (BCP, BBVA, Interbank, Scotiabank)
- ✅ Billeteras digitales (si disponible)

### 🔑 PASO 3: OBTENER CREDENCIALES

#### Sandbox (Testing):
1. Ir a "Credenciales de prueba"
2. Copiar:
   ```env
   MERCADOPAGO_PUBLIC_KEY=TEST-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   MERCADOPAGO_ACCESS_TOKEN=TEST-xxxxxxxxxxxxxxxx-xxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxx-xxxxxxxx
   ```

#### Producción:
1. Ir a "Credenciales de producción"  
2. Copiar:
   ```env
   MERCADOPAGO_PUBLIC_KEY=APP_USR-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   MERCADOPAGO_ACCESS_TOKEN=APP_USR-xxxxxxxxxxxxxxxx-xxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxx-xxxxxxxx
   ```

### 🔔 PASO 4: CONFIGURAR WEBHOOKS

#### A) URL del webhook:
```
https://api.oasistaxi.com.pe/api/v1/payments/webhook
```

#### B) Eventos a escuchar:
- ✅ `payment` - Estado del pago cambió
- ✅ `payment.created` - Pago creado
- ✅ `payment.updated` - Pago actualizado

#### C) Configurar secret para validación:
```env
MERCADOPAGO_WEBHOOK_SECRET=tu_webhook_secret_super_seguro_aqui
```

### 💳 PASO 5: TARJETAS DE PRUEBA PARA PERÚ

#### Tarjetas Visa - Testing:
```json
{
  "tarjetas_aprobadas": {
    "numero": "4009175332806176",
    "codigo_seguridad": "123",
    "mes_expiracion": "11",
    "año_expiracion": "25"
  },
  "tarjetas_rechazadas": {
    "numero": "4804980743570011", 
    "codigo_seguridad": "123",
    "mes_expiracion": "11",
    "año_expiracion": "25"
  }
}
```

#### Tarjetas Mastercard - Testing:
```json
{
  "tarjetas_aprobadas": {
    "numero": "5031433215406351",
    "codigo_seguridad": "123", 
    "mes_expiracion": "11",
    "año_expiracion": "25"
  }
}
```

### 🇵🇪 CONFIGURACIÓN ESPECÍFICA PERÚ

#### A) Datos de identificación:
```json
{
  "tipo_documento": "DNI",
  "numero_documento": "12345678",
  "codigo_pais": "PE",
  "codigo_area": "+51"
}
```

#### B) Moneda y formato:
```javascript
// Configuración regional Perú
const formatCurrency = (amount) => {
  return new Intl.NumberFormat('es-PE', {
    style: 'currency',
    currency: 'PEN',
    minimumFractionDigits: 2
  }).format(amount);
};
// Resultado: S/ 25.50
```

### 🔒 PASO 6: SEGURIDAD E IMPLEMENTACIÓN

#### A) Variables de entorno (.env):
```env
# MercadoPago - SANDBOX (Testing)
MERCADOPAGO_PUBLIC_KEY=TEST-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
MERCADOPAGO_ACCESS_TOKEN=TEST-xxxxxxxxxxxxxxxx-xxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxx-xxxxxxxx
MERCADOPAGO_WEBHOOK_SECRET=tu_webhook_secret_aqui

# URLs
API_BASE_URL=https://api.oasistaxi.com.pe/api/v1
FRONTEND_URL=https://app.oasistaxi.com.pe

# Configuración regional
DEFAULT_CURRENCY=PEN
DEFAULT_COUNTRY_CODE=PE
DEFAULT_LANGUAGE=es
```

#### B) Validación de webhooks (crítico para seguridad):
```typescript
// El código ya está implementado en mercadopago.config.js
validateWebhookSignature(xSignature, xRequestId, dataId, ts) {
  const manifest = `id:${dataId};request-id:${xRequestId};ts:${ts};`;
  const hmac = crypto.createHmac('sha256', process.env.MERCADOPAGO_WEBHOOK_SECRET);
  hmac.update(manifest);
  const sha = hmac.digest('hex');
  const signature = xSignature.split('v1=')[1];
  return sha === signature;
}
```

### 🧪 PASO 7: TESTING EN SANDBOX

#### A) Crear pago de prueba:
```bash
curl -X POST \
  https://api.oasistaxi.com.pe/api/v1/payments/create-preference \
  -H 'Content-Type: application/json' \
  -d '{
    "rideId": "ride_test_001",
    "amount": 25.50,
    "description": "Viaje de prueba Oasis Taxi",
    "payerEmail": "test@oasistaxi.com.pe",
    "payerName": "Usuario de Prueba"
  }'
```

#### B) Respuesta esperada:
```json
{
  "success": true,
  "data": {
    "preferenceId": "123456789-abcd-efgh-ijkl-mnopqrstuvwx",
    "initPoint": "https://www.mercadopago.com.pe/checkout/v1/redirect?pref_id=xxx",
    "publicKey": "TEST-xxx",
    "amount": 25.50,
    "platformCommission": 5.10,
    "driverEarnings": 20.40
  }
}
```

### 📱 PASO 8: CONFIGURAR MÉTODOS DE PAGO LOCALES

#### A) PagoEfectivo (Efectivo):
- Configurar en panel MercadoPago
- Habilitar cupones de pago
- Configurar vencimiento: 48 horas

#### B) Transferencias bancarias:
- BCP (Banco de Crédito del Perú)
- BBVA Continental
- Interbank
- Scotiabank

### 🚨 PASO 9: CONSIDERACIONES DE PRODUCCIÓN

#### A) Compliance y regulaciones:
- ✅ SUNAT: Facturación electrónica
- ✅ PCI DSS: Seguridad de datos de tarjetas
- ✅ Protección de datos personales (Ley 29733)

#### B) Monitoreo y alertas:
```typescript
// Analytics implementadas en PaymentService
await firebaseService.analytics.logEvent('mercadopago_payment_created', {
  ride_id: rideId,
  amount: amount,
  preference_id: preferenceId,
});
```

#### C) Manejo de errores:
```typescript
// Error handling ya implementado
catch (error) {
  logger.error('Error creando preferencia MercadoPago:', error);
  await firebaseService.crashlytics.recordError(error, null);
  return PaymentPreferenceResult.error('Error creando preferencia');
}
```

### ✅ CHECKLIST FINAL

- [ ] Cuenta MercadoPago Developer creada
- [ ] Aplicación "Oasis Taxi Peru" configurada
- [ ] Credenciales sandbox obtenidas
- [ ] Webhook URL configurada
- [ ] Variables de entorno actualizadas
- [ ] Testing con tarjetas de prueba completado
- [ ] Métodos de pago locales habilitados
- [ ] Validación de webhooks verificada
- [ ] Flujo end-to-end probado
- [ ] Credenciales de producción obtenidas (cuando esté listo)

### 🆘 SOPORTE

**MercadoPago Perú:**
- Documentación: https://www.mercadopago.com.pe/developers/es/docs
- Soporte: https://www.mercadopago.com.pe/ayuda
- Email: developers@mercadopago.com.pe
- Teléfono: +51 1 700-5000

### 📄 DOCUMENTACIÓN TÉCNICA

**Endpoints implementados en el backend:**
- `POST /api/v1/payments/create-preference` - Crear preferencia de pago
- `POST /api/v1/payments/webhook` - Webhook de notificaciones
- `GET /api/v1/payments/status/:id` - Verificar estado de pago
- `POST /api/v1/payments/refund` - Procesar reembolso

**SDK y librerías:**
- `mercadopago` v2.0.0+ (Node.js)
- Flutter: `http` package para API calls
- Validación: `crypto` para firmas de webhook

---

## 🎯 SIGUIENTE PASO

Una vez configuradas las credenciales reales, el sistema estará listo para procesar pagos reales de MercadoPago en Perú. El backend y frontend ya están completamente implementados y solo requieren las credenciales correctas.

**¡IMPORTANTE!** Comenzar siempre con el entorno SANDBOX para pruebas antes de usar producción.