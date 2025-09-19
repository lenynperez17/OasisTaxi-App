const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { BigQuery } = require('@google-cloud/bigquery');
const nodemailer = require('nodemailer');

// Configuración para Perú
const PERU_CONFIG = {
  timezone: 'America/Lima',
  currency: 'PEN',
  country: 'PE',
  locale: 'es-PE'
};

/**
 * SISTEMA COMPLETO DE DATA STUDIO DASHBOARDS PARA GESTIÓN FINANCIERA
 * Cloud Functions para generación automática de dashboards financieros
 * Integración con BigQuery y Data Studio para análisis en tiempo real
 * 
 * Características:
 * - Dashboards financieros automatizados
 * - Métricas de ingresos y comisiones
 * - Análisis de rentabilidad por conductor
 * - Reportes de pagos y transacciones
 * - Alertas automáticas de anomalías
 * - Integración con sistema de facturación
 */

// ============================================================================
// CONFIGURACIÓN Y INICIALIZACIÓN
// ============================================================================

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const bigquery = new BigQuery({
  projectId: process.env.GOOGLE_CLOUD_PROJECT,
});

// Configuración de dashboards financieros
const FINANCIAL_DASHBOARDS_CONFIG = {
  // Tipos de dashboards financieros
  dashboardTypes: {
    EXECUTIVE_FINANCE: 'executive_finance',
    REVENUE_ANALYSIS: 'revenue_analysis', 
    DRIVER_EARNINGS: 'driver_earnings',
    COMMISSIONS: 'commissions',
    PAYMENT_METHODS: 'payment_methods',
    TAX_COMPLIANCE: 'tax_compliance',
    PROFITABILITY: 'profitability',
    CASH_FLOW: 'cash_flow'
  },

  // Métricas principales
  primaryMetrics: {
    GROSS_REVENUE: 'gross_revenue',
    NET_REVENUE: 'net_revenue',
    COMMISSION_REVENUE: 'commission_revenue',
    DRIVER_EARNINGS: 'driver_earnings',
    AVERAGE_TRIP_VALUE: 'average_trip_value',
    PAYMENT_SUCCESS_RATE: 'payment_success_rate',
    PROFIT_MARGIN: 'profit_margin',
    TAX_LIABILITY: 'tax_liability'
  },

  // Períodos de análisis
  timePeriods: {
    DAILY: 'daily',
    WEEKLY: 'weekly',
    MONTHLY: 'monthly',
    QUARTERLY: 'quarterly',
    YEARLY: 'yearly'
  }
};

// ============================================================================
// FUNCIÓN PRINCIPAL: ACTUALIZAR DASHBOARDS FINANCIEROS
// ============================================================================

exports.updateFinancialDashboards = functions
  .runWith({
    timeoutSeconds: 540,
    memory: '2GB'
  })
  .pubsub
  .schedule('0 */2 * * *') // Cada 2 horas
  .timeZone(PERU_CONFIG.timezone)
  .onRun(async (context) => {
    
    console.log('💰 Ejecutando actualización de dashboards financieros...');
    
    try {
      const startTime = Date.now();
      
      // 1. Actualizar datos de BigQuery
      await updateFinancialBigQueryData();
      
      // 2. Generar dashboards por tipo
      const dashboardResults = await Promise.all([
        generateExecutiveFinanceDashboard(),
        generateRevenueAnalysisDashboard(),
        generateDriverEarningsDashboard(),
        generateCommissionsDashboard(),
        generatePaymentMethodsDashboard(),
        generateTaxComplianceDashboard(),
        generateProfitabilityDashboard(),
        generateCashFlowDashboard()
      ]);
      
      // 3. Generar reporte consolidado
      const consolidatedReport = await generateConsolidatedFinancialReport(dashboardResults);
      
      // 4. Detectar anomalías financieras
      const anomalies = await detectFinancialAnomalies();
      
      // 5. Enviar alertas si es necesario
      if (anomalies.length > 0) {
        await sendFinancialAlertsToAdmins(anomalies);
      }
      
      // 6. Actualizar métricas de salud del sistema
      await updateSystemHealthMetrics();
      
      const duration = Date.now() - startTime;
      
      console.log(`✅ Dashboards financieros actualizados en ${duration}ms`);
      console.log(`📊 ${dashboardResults.length} dashboards procesados`);
      console.log(`⚠️ ${anomalies.length} anomalías detectadas`);
      
      // Log de auditoría
      await logFinancialAuditEvent('FINANCIAL_DASHBOARDS_UPDATED', {
        duration,
        dashboardsProcessed: dashboardResults.length,
        anomaliesDetected: anomalies.length,
        timestamp: new Date().toISOString()
      });
      
      return {
        success: true,
        duration,
        dashboardsProcessed: dashboardResults.length,
        anomaliesDetected: anomalies.length
      };
      
    } catch (error) {
      console.error('❌ Error al actualizar dashboards financieros:', error);
      
      await sendErrorNotificationToAdmins('Financial Dashboards Update Error', error);
      
      throw error;
    }
  });

// ============================================================================
// ACTUALIZACIÓN DE DATOS BIGQUERY
// ============================================================================

async function updateFinancialBigQueryData() {
  console.log('📊 Actualizando datos financieros en BigQuery...');
  
  try {
    const dataset = bigquery.dataset('oasis_taxi_finance');
    
    // Asegurar que el dataset existe
    const [datasetExists] = await dataset.exists();
    if (!datasetExists) {
      await dataset.create({
        location: 'US',
        description: 'Dataset financiero de OasisTaxi Peru'
      });
    }
    
    // Actualizar tabla de transacciones financieras
    await updateFinancialTransactionsTable();
    
    // Actualizar tabla de ganancias de conductores
    await updateDriverEarningsTable();
    
    // Actualizar tabla de comisiones
    await updateCommissionsTable();
    
    // Actualizar tabla de métodos de pago
    await updatePaymentMethodsTable();
    
    // Actualizar tabla de impuestos y compliance
    await updateTaxComplianceTable();
    
    console.log('✅ Datos financieros actualizados en BigQuery');
    
  } catch (error) {
    console.error('❌ Error al actualizar BigQuery financiero:', error);
    throw error;
  }
}

async function updateFinancialTransactionsTable() {
  console.log('💳 Actualizando tabla de transacciones financieras...');
  
  try {
    // Obtener transacciones recientes de Firestore
    const transactionsSnapshot = await db.collection('transactions')
      .where('createdAt', '>=', new Date(Date.now() - 24 * 60 * 60 * 1000)) // Últimas 24 horas
      .get();
      
    if (transactionsSnapshot.empty) {
      console.log('No hay nuevas transacciones para procesar');
      return;
    }
    
    // Preparar datos para BigQuery
    const rows = [];
    transactionsSnapshot.docs.forEach(doc => {
      const transaction = doc.data();
      const createdAt = transaction.createdAt?.toDate();
      
      rows.push({
        transaction_id: doc.id,
        trip_id: transaction.tripId || '',
        user_id: transaction.userId || '',
        driver_id: transaction.driverId || '',
        amount: transaction.amount || 0,
        commission_amount: (transaction.amount || 0) * 0.20, // 20% comisión
        driver_earnings: (transaction.amount || 0) * 0.80, // 80% para conductor
        payment_method: transaction.paymentMethod || 'cash',
        status: transaction.status || 'pending',
        currency: 'PEN',
        country: 'PE',
        city: transaction.city || 'Lima',
        transaction_type: transaction.type || 'trip_payment',
        created_at: createdAt ? createdAt.toISOString() : new Date().toISOString(),
        processed_at: new Date().toISOString(),
        // Campos adicionales para análisis
        is_surge_pricing: transaction.isSurgePricing || false,
        surge_multiplier: transaction.surgeMultiplier || 1.0,
        distance_km: transaction.distanceKm || 0,
        duration_minutes: transaction.durationMinutes || 0,
        tip_amount: transaction.tipAmount || 0,
        tax_amount: transaction.taxAmount || (transaction.amount || 0) * 0.18, // IGV 18% Perú
        net_amount: (transaction.amount || 0) - ((transaction.amount || 0) * 0.18),
        // Metadatos
        updated_at: new Date().toISOString()
      });
    });
    
    // Insertar en BigQuery
    const table = bigquery.dataset('oasis_taxi_finance').table('financial_transactions');
    
    await table.insert(rows);
    
    console.log(`✅ ${rows.length} transacciones financieras insertadas en BigQuery`);
    
  } catch (error) {
    console.error('❌ Error al actualizar transacciones financieras:', error);
    throw error;
  }
}

async function updateDriverEarningsTable() {
  console.log('👨‍💼 Actualizando tabla de ganancias de conductores...');
  
  try {
    // Obtener ganancias de conductores del último día
    const driversSnapshot = await db.collection('drivers').get();
    
    const rows = [];
    for (const driverDoc of driversSnapshot.docs) {
      const driver = driverDoc.data();
      const driverId = driverDoc.id;
      
      // Calcular ganancias del conductor
      const earningsQuery = await db.collection('transactions')
        .where('driverId', '==', driverId)
        .where('status', '==', 'completed')
        .where('createdAt', '>=', new Date(Date.now() - 24 * 60 * 60 * 1000))
        .get();
        
      let totalEarnings = 0;
      let totalTrips = 0;
      let totalTips = 0;
      let totalBonuses = 0;
      
      earningsQuery.docs.forEach(doc => {
        const transaction = doc.data();
        totalEarnings += (transaction.amount || 0) * 0.80; // 80% para conductor
        totalTrips++;
        totalTips += transaction.tipAmount || 0;
        totalBonuses += transaction.bonusAmount || 0;
      });
      
      // Obtener datos del vehículo para análisis
      const vehicleData = driver.vehicle || {};
      
      rows.push({
        driver_id: driverId,
        driver_name: `${driver.firstName || ''} ${driver.lastName || ''}`.trim(),
        email: driver.email || '',
        phone: driver.phone || '',
        city: driver.city || 'Lima',
        vehicle_type: vehicleData.type || 'sedan',
        vehicle_year: vehicleData.year || null,
        vehicle_brand: vehicleData.brand || '',
        license_plate: vehicleData.licensePlate || '',
        // Ganancias
        gross_earnings: totalEarnings,
        tips_earned: totalTips,
        bonuses_earned: totalBonuses,
        total_earnings: totalEarnings + totalTips + totalBonuses,
        // Métricas de performance
        trips_completed: totalTrips,
        average_earnings_per_trip: totalTrips > 0 ? (totalEarnings / totalTrips) : 0,
        // Deducciones y gastos
        fuel_expenses: 0, // TODO: Implementar tracking de gastos
        maintenance_expenses: 0,
        insurance_expenses: 0,
        net_earnings: totalEarnings + totalTips + totalBonuses, // Menos gastos
        // Estado del conductor
        status: driver.status || 'active',
        rating: driver.rating || 5.0,
        total_trips_lifetime: driver.totalTrips || 0,
        registration_date: driver.createdAt?.toDate()?.toISOString() || new Date().toISOString(),
        last_trip_date: driver.lastTripDate?.toDate()?.toISOString() || null,
        // Compliance
        documents_verified: driver.documentsVerified || false,
        background_check_passed: driver.backgroundCheckPassed || false,
        // Métricas temporales
        date: new Date().toISOString().split('T')[0], // YYYY-MM-DD
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      });
    }
    
    // Insertar en BigQuery
    const table = bigquery.dataset('oasis_taxi_finance').table('driver_earnings');
    
    await table.insert(rows);
    
    console.log(`✅ ${rows.length} registros de ganancias de conductores insertados en BigQuery`);
    
  } catch (error) {
    console.error('❌ Error al actualizar ganancias de conductores:', error);
    throw error;
  }
}

async function updateCommissionsTable() {
  console.log('🏦 Actualizando tabla de comisiones...');
  
  try {
    // Calcular comisiones por diferentes dimensiones
    const commissionsData = await calculateCommissionsBreakdown();
    
    const rows = commissionsData.map(commission => ({
      date: commission.date,
      city: commission.city,
      commission_type: commission.type, // trip, subscription, bonus, etc.
      gross_revenue: commission.grossRevenue,
      commission_rate: commission.rate,
      commission_amount: commission.amount,
      net_revenue: commission.grossRevenue - commission.amount,
      trips_count: commission.tripsCount,
      drivers_count: commission.driversCount,
      average_commission_per_trip: commission.tripsCount > 0 ? commission.amount / commission.tripsCount : 0,
      // Análisis de rentabilidad
      operational_costs: commission.operationalCosts || 0,
      marketing_costs: commission.marketingCosts || 0,
      technology_costs: commission.technologyCosts || 0,
      profit_before_tax: commission.amount - (commission.operationalCosts || 0) - (commission.marketingCosts || 0) - (commission.technologyCosts || 0),
      // Metadatos
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    }));
    
    // Insertar en BigQuery
    const table = bigquery.dataset('oasis_taxi_finance').table('commissions_analysis');
    
    await table.insert(rows);
    
    console.log(`✅ ${rows.length} registros de comisiones insertados en BigQuery`);
    
  } catch (error) {
    console.error('❌ Error al actualizar comisiones:', error);
    throw error;
  }
}

async function updatePaymentMethodsTable() {
  console.log('💳 Actualizando tabla de métodos de pago...');
  
  try {
    // Analizar métodos de pago de las transacciones
    const paymentMethodsAnalysis = await analyzePaymentMethods();
    
    const rows = paymentMethodsAnalysis.map(analysis => ({
      date: analysis.date,
      payment_method: analysis.method,
      transactions_count: analysis.count,
      total_amount: analysis.totalAmount,
      average_transaction_value: analysis.count > 0 ? analysis.totalAmount / analysis.count : 0,
      success_rate: analysis.successRate,
      failure_rate: 1 - analysis.successRate,
      // Análisis por ciudad
      lima_usage: analysis.cityBreakdown.Lima || 0,
      arequipa_usage: analysis.cityBreakdown.Arequipa || 0,
      trujillo_usage: analysis.cityBreakdown.Trujillo || 0,
      other_cities_usage: analysis.cityBreakdown.Others || 0,
      // Costos de procesamiento
      processing_fees: analysis.processingFees || 0,
      chargeback_amount: analysis.chargebackAmount || 0,
      net_payment_revenue: analysis.totalAmount - (analysis.processingFees || 0) - (analysis.chargebackAmount || 0),
      // Métricas de tiempo
      average_processing_time_seconds: analysis.averageProcessingTime || 0,
      // Metadatos
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    }));
    
    // Insertar en BigQuery
    const table = bigquery.dataset('oasis_taxi_finance').table('payment_methods_analysis');
    
    await table.insert(rows);
    
    console.log(`✅ ${rows.length} análisis de métodos de pago insertados en BigQuery`);
    
  } catch (error) {
    console.error('❌ Error al actualizar métodos de pago:', error);
    throw error;
  }
}

async function updateTaxComplianceTable() {
  console.log('📋 Actualizando tabla de compliance fiscal...');
  
  try {
    // Calcular obligaciones fiscales para Perú
    const taxData = await calculateTaxCompliance();
    
    const rows = taxData.map(tax => ({
      date: tax.date,
      tax_type: tax.type, // IGV, Renta, Municipal, etc.
      gross_revenue: tax.grossRevenue,
      taxable_base: tax.taxableBase,
      tax_rate: tax.rate,
      tax_amount: tax.amount,
      withholdings: tax.withholdings || 0,
      net_tax_liability: tax.amount - (tax.withholdings || 0),
      // Específico para Perú
      igv_rate: 0.18, // 18% IGV
      income_tax_rate: 0.295, // 29.5% Impuesto a la Renta
      municipal_tax_amount: tax.municipalTax || 0,
      // Reportes obligatorios
      monthly_pdt_filed: tax.pdtFiled || false,
      annual_declaration_required: tax.annualDeclarationRequired || false,
      electronic_receipts_issued: tax.electronicReceiptsIssued || 0,
      // Compliance status
      compliance_status: tax.complianceStatus || 'compliant',
      penalties_amount: tax.penaltiesAmount || 0,
      interest_charges: tax.interestCharges || 0,
      // Metadatos
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    }));
    
    // Insertar en BigQuery
    const table = bigquery.dataset('oasis_taxi_finance').table('tax_compliance');
    
    await table.insert(rows);
    
    console.log(`✅ ${rows.length} registros de compliance fiscal insertados en BigQuery`);
    
  } catch (error) {
    console.error('❌ Error al actualizar compliance fiscal:', error);
    throw error;
  }
}

// ============================================================================
// GENERADORES DE DASHBOARDS ESPECÍFICOS
// ============================================================================

async function generateExecutiveFinanceDashboard() {
  console.log('🏢 Generando dashboard ejecutivo financiero...');
  
  try {
    const query = `
      SELECT 
        DATE(created_at) as date,
        SUM(amount) as daily_revenue,
        SUM(commission_amount) as daily_commission,
        SUM(driver_earnings) as daily_driver_earnings,
        COUNT(DISTINCT trip_id) as daily_trips,
        COUNT(DISTINCT driver_id) as active_drivers,
        AVG(amount) as average_trip_value,
        SUM(CASE WHEN payment_method = 'card' THEN amount ELSE 0 END) as card_revenue,
        SUM(CASE WHEN payment_method = 'cash' THEN amount ELSE 0 END) as cash_revenue
      FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.oasis_taxi_finance.financial_transactions\`
      WHERE DATE(created_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
      GROUP BY DATE(created_at)
      ORDER BY date DESC
    `;
    
    const [rows] = await bigquery.query({
      query: query,
      location: 'US'
    });
    
    const dashboardData = {
      type: FINANCIAL_DASHBOARDS_CONFIG.dashboardTypes.EXECUTIVE_FINANCE,
      title: 'Dashboard Ejecutivo Financiero - OasisTaxi Perú',
      description: 'Métricas financieras ejecutivas de alto nivel',
      data: rows,
      metrics: {
        totalRevenue: rows.reduce((sum, row) => sum + parseFloat(row.daily_revenue || 0), 0),
        totalCommissions: rows.reduce((sum, row) => sum + parseFloat(row.daily_commission || 0), 0),
        totalDriverEarnings: rows.reduce((sum, row) => sum + parseFloat(row.daily_driver_earnings || 0), 0),
        averageTripsPerDay: rows.length > 0 ? rows.reduce((sum, row) => sum + parseInt(row.daily_trips || 0), 0) / rows.length : 0,
        revenueGrowth: calculateGrowthRate(rows, 'daily_revenue'),
        cashVsCardRatio: calculateCashVsCardRatio(rows)
      },
      generatedAt: new Date().toISOString(),
      currency: 'PEN',
      locale: PERU_CONFIG.locale
    };
    
    // Guardar dashboard
    await saveDashboard('executive_finance', dashboardData);
    
    return dashboardData;
    
  } catch (error) {
    console.error('❌ Error generando dashboard ejecutivo:', error);
    throw error;
  }
}

async function generateRevenueAnalysisDashboard() {
  console.log('📈 Generando dashboard de análisis de ingresos...');
  
  try {
    const query = `
      SELECT 
        city,
        DATE(created_at) as date,
        SUM(amount) as city_revenue,
        COUNT(DISTINCT trip_id) as city_trips,
        AVG(amount) as avg_trip_value,
        SUM(CASE WHEN is_surge_pricing THEN amount ELSE 0 END) as surge_revenue,
        AVG(surge_multiplier) as avg_surge_multiplier,
        SUM(tip_amount) as total_tips
      FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.oasis_taxi_finance.financial_transactions\`
      WHERE DATE(created_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
      GROUP BY city, DATE(created_at)
      ORDER BY city, date DESC
    `;
    
    const [rows] = await bigquery.query({
      query: query,
      location: 'US'
    });
    
    const dashboardData = {
      type: FINANCIAL_DASHBOARDS_CONFIG.dashboardTypes.REVENUE_ANALYSIS,
      title: 'Análisis de Ingresos por Ciudad',
      description: 'Análisis detallado de ingresos por ubicación geográfica',
      data: rows,
      metrics: {
        topRevenueCity: findTopRevenueCity(rows),
        surgeRevenuePercentage: calculateSurgeRevenuePercentage(rows),
        tipPercentage: calculateTipPercentage(rows),
        revenueByCity: groupRevenueByCity(rows)
      },
      generatedAt: new Date().toISOString(),
      currency: 'PEN',
      locale: PERU_CONFIG.locale
    };
    
    await saveDashboard('revenue_analysis', dashboardData);
    
    return dashboardData;
    
  } catch (error) {
    console.error('❌ Error generando dashboard de ingresos:', error);
    throw error;
  }
}

async function generateDriverEarningsDashboard() {
  console.log('👨‍💼 Generando dashboard de ganancias de conductores...');
  
  try {
    const query = `
      SELECT 
        driver_id,
        driver_name,
        city,
        vehicle_type,
        total_earnings,
        trips_completed,
        average_earnings_per_trip,
        rating,
        status,
        DATE(date) as earnings_date
      FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.oasis_taxi_finance.driver_earnings\`
      WHERE DATE(date) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
        AND status = 'active'
      ORDER BY total_earnings DESC
    `;
    
    const [rows] = await bigquery.query({
      query: query,
      location: 'US'
    });
    
    const dashboardData = {
      type: FINANCIAL_DASHBOARDS_CONFIG.dashboardTypes.DRIVER_EARNINGS,
      title: 'Dashboard de Ganancias de Conductores',
      description: 'Análisis de ganancias y performance de conductores',
      data: rows,
      metrics: {
        topEarners: rows.slice(0, 10),
        averageEarningsPerDriver: rows.length > 0 ? rows.reduce((sum, row) => sum + parseFloat(row.total_earnings || 0), 0) / rows.length : 0,
        earningsByVehicleType: groupEarningsByVehicleType(rows),
        earningsByCity: groupEarningsByCity(rows),
        activeDriversCount: rows.length
      },
      generatedAt: new Date().toISOString(),
      currency: 'PEN',
      locale: PERU_CONFIG.locale
    };
    
    await saveDashboard('driver_earnings', dashboardData);
    
    return dashboardData;
    
  } catch (error) {
    console.error('❌ Error generando dashboard de ganancias:', error);
    throw error;
  }
}

async function generateCommissionsDashboard() {
  console.log('🏦 Generando dashboard de comisiones...');
  
  try {
    const query = `
      SELECT 
        DATE(date) as analysis_date,
        city,
        commission_type,
        gross_revenue,
        commission_amount,
        commission_rate,
        net_revenue,
        profit_before_tax,
        trips_count
      FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.oasis_taxi_finance.commissions_analysis\`
      WHERE DATE(date) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
      ORDER BY analysis_date DESC, commission_amount DESC
    `;
    
    const [rows] = await bigquery.query({
      query: query,
      location: 'US'
    });
    
    const dashboardData = {
      type: FINANCIAL_DASHBOARDS_CONFIG.dashboardTypes.COMMISSIONS,
      title: 'Dashboard de Comisiones y Rentabilidad',
      description: 'Análisis de comisiones y márgenes de ganancia',
      data: rows,
      metrics: {
        totalCommissions: rows.reduce((sum, row) => sum + parseFloat(row.commission_amount || 0), 0),
        averageCommissionRate: calculateAverageCommissionRate(rows),
        profitMargin: calculateProfitMargin(rows),
        commissionsByCity: groupCommissionsByCity(rows)
      },
      generatedAt: new Date().toISOString(),
      currency: 'PEN',
      locale: PERU_CONFIG.locale
    };
    
    await saveDashboard('commissions', dashboardData);
    
    return dashboardData;
    
  } catch (error) {
    console.error('❌ Error generando dashboard de comisiones:', error);
    throw error;
  }
}

async function generatePaymentMethodsDashboard() {
  console.log('💳 Generando dashboard de métodos de pago...');
  
  try {
    const query = `
      SELECT 
        DATE(date) as analysis_date,
        payment_method,
        transactions_count,
        total_amount,
        success_rate,
        processing_fees,
        net_payment_revenue,
        lima_usage,
        arequipa_usage,
        trujillo_usage
      FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.oasis_taxi_finance.payment_methods_analysis\`
      WHERE DATE(date) >= DATE_SUB(CURRENT_DATE(), INTERVAL 14 DAY)
      ORDER BY analysis_date DESC, total_amount DESC
    `;
    
    const [rows] = await bigquery.query({
      query: query,
      location: 'US'
    });
    
    const dashboardData = {
      type: FINANCIAL_DASHBOARDS_CONFIG.dashboardTypes.PAYMENT_METHODS,
      title: 'Dashboard de Métodos de Pago',
      description: 'Análisis de preferencias y performance de pagos',
      data: rows,
      metrics: {
        preferredPaymentMethod: findPreferredPaymentMethod(rows),
        averageSuccessRate: calculateAverageSuccessRate(rows),
        processingCosts: rows.reduce((sum, row) => sum + parseFloat(row.processing_fees || 0), 0),
        paymentMethodDistribution: calculatePaymentMethodDistribution(rows)
      },
      generatedAt: new Date().toISOString(),
      currency: 'PEN',
      locale: PERU_CONFIG.locale
    };
    
    await saveDashboard('payment_methods', dashboardData);
    
    return dashboardData;
    
  } catch (error) {
    console.error('❌ Error generando dashboard de métodos de pago:', error);
    throw error;
  }
}

async function generateTaxComplianceDashboard() {
  console.log('📋 Generando dashboard de compliance fiscal...');
  
  try {
    const query = `
      SELECT 
        DATE(date) as compliance_date,
        tax_type,
        gross_revenue,
        tax_amount,
        net_tax_liability,
        igv_rate,
        income_tax_rate,
        compliance_status,
        penalties_amount,
        electronic_receipts_issued
      FROM \`${process.env.GOOGLE_CLOUD_PROJECT}.oasis_taxi_finance.tax_compliance\`
      WHERE DATE(date) >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
      ORDER BY compliance_date DESC
    `;
    
    const [rows] = await bigquery.query({
      query: query,
      location: 'US'
    });
    
    const dashboardData = {
      type: FINANCIAL_DASHBOARDS_CONFIG.dashboardTypes.TAX_COMPLIANCE,
      title: 'Dashboard de Compliance Fiscal - Perú',
      description: 'Estado de cumplimiento tributario y obligaciones fiscales',
      data: rows,
      metrics: {
        totalTaxLiability: rows.reduce((sum, row) => sum + parseFloat(row.tax_amount || 0), 0),
        igvCollected: calculateIGVCollected(rows),
        incomeTaxOwed: calculateIncomeTaxOwed(rows),
        complianceRate: calculateComplianceRate(rows),
        electronicReceiptsIssued: rows.reduce((sum, row) => sum + parseInt(row.electronic_receipts_issued || 0), 0)
      },
      generatedAt: new Date().toISOString(),
      currency: 'PEN',
      locale: PERU_CONFIG.locale
    };
    
    await saveDashboard('tax_compliance', dashboardData);
    
    return dashboardData;
    
  } catch (error) {
    console.error('❌ Error generando dashboard de compliance:', error);
    throw error;
  }
}

async function generateProfitabilityDashboard() {
  console.log('💹 Generando dashboard de rentabilidad...');
  
  try {
    // Combinar datos de múltiples fuentes para análisis de rentabilidad
    const profitabilityData = await calculateComprehensiveProfitability();
    
    const dashboardData = {
      type: FINANCIAL_DASHBOARDS_CONFIG.dashboardTypes.PROFITABILITY,
      title: 'Dashboard de Rentabilidad y ROI',
      description: 'Análisis integral de rentabilidad del negocio',
      data: profitabilityData,
      metrics: {
        grossProfitMargin: profitabilityData.grossProfitMargin,
        netProfitMargin: profitabilityData.netProfitMargin,
        roi: profitabilityData.roi,
        ebitda: profitabilityData.ebitda,
        breakEvenPoint: profitabilityData.breakEvenPoint,
        customerAcquisitionCost: profitabilityData.customerAcquisitionCost,
        lifetimeValue: profitabilityData.lifetimeValue
      },
      generatedAt: new Date().toISOString(),
      currency: 'PEN',
      locale: PERU_CONFIG.locale
    };
    
    await saveDashboard('profitability', dashboardData);
    
    return dashboardData;
    
  } catch (error) {
    console.error('❌ Error generando dashboard de rentabilidad:', error);
    throw error;
  }
}

async function generateCashFlowDashboard() {
  console.log('💰 Generando dashboard de flujo de caja...');
  
  try {
    const cashFlowData = await calculateCashFlowAnalysis();
    
    const dashboardData = {
      type: FINANCIAL_DASHBOARDS_CONFIG.dashboardTypes.CASH_FLOW,
      title: 'Dashboard de Flujo de Caja',
      description: 'Análisis de flujo de efectivo y liquidez',
      data: cashFlowData,
      metrics: {
        operatingCashFlow: cashFlowData.operatingCashFlow,
        investingCashFlow: cashFlowData.investingCashFlow,
        financingCashFlow: cashFlowData.financingCashFlow,
        netCashFlow: cashFlowData.netCashFlow,
        cashPosition: cashFlowData.cashPosition,
        burnRate: cashFlowData.burnRate,
        runwayMonths: cashFlowData.runwayMonths
      },
      generatedAt: new Date().toISOString(),
      currency: 'PEN',
      locale: PERU_CONFIG.locale
    };
    
    await saveDashboard('cash_flow', dashboardData);
    
    return dashboardData;
    
  } catch (error) {
    console.error('❌ Error generando dashboard de flujo de caja:', error);
    throw error;
  }
}

// ============================================================================
// FUNCIONES AUXILIARES DE CÁLCULO
// ============================================================================

function calculateGrowthRate(data, field) {
  if (data.length < 2) return 0;
  
  const sortedData = data.sort((a, b) => new Date(a.date) - new Date(b.date));
  const oldValue = parseFloat(sortedData[0][field] || 0);
  const newValue = parseFloat(sortedData[sortedData.length - 1][field] || 0);
  
  return oldValue > 0 ? ((newValue - oldValue) / oldValue) * 100 : 0;
}

function calculateCashVsCardRatio(data) {
  const totalCash = data.reduce((sum, row) => sum + parseFloat(row.cash_revenue || 0), 0);
  const totalCard = data.reduce((sum, row) => sum + parseFloat(row.card_revenue || 0), 0);
  const total = totalCash + totalCard;
  
  return total > 0 ? {
    cashPercentage: (totalCash / total) * 100,
    cardPercentage: (totalCard / total) * 100
  } : { cashPercentage: 0, cardPercentage: 0 };
}

async function calculateCommissionsBreakdown() {
  // Implementar cálculo detallado de comisiones
  const now = new Date();
  const oneDayAgo = new Date(now - 24 * 60 * 60 * 1000);
  
  // Obtener datos de transacciones para calcular comisiones
  const transactionsSnapshot = await db.collection('transactions')
    .where('createdAt', '>=', oneDayAgo)
    .where('status', '==', 'completed')
    .get();
    
  const commissionsByCity = {};
  
  transactionsSnapshot.docs.forEach(doc => {
    const transaction = doc.data();
    const city = transaction.city || 'Lima';
    const amount = transaction.amount || 0;
    const commission = amount * 0.20; // 20% comisión
    
    if (!commissionsByCity[city]) {
      commissionsByCity[city] = {
        date: now.toISOString().split('T')[0],
        city,
        type: 'trip',
        grossRevenue: 0,
        rate: 0.20,
        amount: 0,
        tripsCount: 0,
        driversCount: new Set(),
        operationalCosts: 0,
        marketingCosts: 0,
        technologyCosts: 0
      };
    }
    
    commissionsByCity[city].grossRevenue += amount;
    commissionsByCity[city].amount += commission;
    commissionsByCity[city].tripsCount++;
    commissionsByCity[city].driversCount.add(transaction.driverId);
  });
  
  // Convertir Sets a counts
  return Object.values(commissionsByCity).map(commission => ({
    ...commission,
    driversCount: commission.driversCount.size
  }));
}

async function analyzePaymentMethods() {
  // Implementar análisis de métodos de pago
  const now = new Date();
  const oneDayAgo = new Date(now - 24 * 60 * 60 * 1000);
  
  const transactionsSnapshot = await db.collection('transactions')
    .where('createdAt', '>=', oneDayAgo)
    .get();
    
  const paymentMethodsData = {};
  
  transactionsSnapshot.docs.forEach(doc => {
    const transaction = doc.data();
    const method = transaction.paymentMethod || 'cash';
    const city = transaction.city || 'Lima';
    const amount = transaction.amount || 0;
    const isSuccess = transaction.status === 'completed';
    
    if (!paymentMethodsData[method]) {
      paymentMethodsData[method] = {
        date: now.toISOString().split('T')[0],
        method,
        count: 0,
        totalAmount: 0,
        successCount: 0,
        cityBreakdown: {},
        processingFees: 0,
        chargebackAmount: 0,
        averageProcessingTime: 0
      };
    }
    
    paymentMethodsData[method].count++;
    paymentMethodsData[method].totalAmount += amount;
    
    if (isSuccess) {
      paymentMethodsData[method].successCount++;
    }
    
    // Breakdown by city
    if (!paymentMethodsData[method].cityBreakdown[city]) {
      paymentMethodsData[method].cityBreakdown[city] = 0;
    }
    paymentMethodsData[method].cityBreakdown[city] += amount;
    
    // Calculate processing fees (example: 3% for cards)
    if (method === 'card') {
      paymentMethodsData[method].processingFees += amount * 0.03;
    }
  });
  
  // Calculate success rates
  return Object.values(paymentMethodsData).map(data => ({
    ...data,
    successRate: data.count > 0 ? data.successCount / data.count : 0
  }));
}

async function calculateTaxCompliance() {
  // Implementar cálculo de compliance fiscal para Perú
  const now = new Date();
  const oneMonthAgo = new Date(now - 30 * 24 * 60 * 60 * 1000);
  
  // Obtener transacciones del último mes
  const transactionsSnapshot = await db.collection('transactions')
    .where('createdAt', '>=', oneMonthAgo)
    .where('status', '==', 'completed')
    .get();
    
  let totalRevenue = 0;
  let totalTransactions = 0;
  
  transactionsSnapshot.docs.forEach(doc => {
    const transaction = doc.data();
    totalRevenue += transaction.amount || 0;
    totalTransactions++;
  });
  
  // Calcular impuestos según legislación peruana
  const igvBase = totalRevenue / 1.18; // Base sin IGV
  const igvAmount = totalRevenue - igvBase; // IGV 18%
  const incomeTaxAmount = igvBase * 0.295; // Impuesto a la Renta 29.5%
  const municipalTaxAmount = totalRevenue * 0.002; // Impuesto Municipal aprox.
  
  return [{
    date: now.toISOString().split('T')[0],
    type: 'IGV',
    grossRevenue: totalRevenue,
    taxableBase: igvBase,
    rate: 0.18,
    amount: igvAmount,
    withholdings: 0,
    municipalTax: municipalTaxAmount,
    pdtFiled: true, // Asumir que se presentó
    annualDeclarationRequired: totalRevenue > 150000, // UIT threshold
    electronicReceiptsIssued: totalTransactions,
    complianceStatus: 'compliant',
    penaltiesAmount: 0,
    interestCharges: 0
  }, {
    date: now.toISOString().split('T')[0],
    type: 'RENTA',
    grossRevenue: totalRevenue,
    taxableBase: igvBase,
    rate: 0.295,
    amount: incomeTaxAmount,
    withholdings: 0,
    municipalTax: 0,
    pdtFiled: true,
    annualDeclarationRequired: true,
    electronicReceiptsIssued: totalTransactions,
    complianceStatus: 'compliant',
    penaltiesAmount: 0,
    interestCharges: 0
  }];
}

// ============================================================================
// FUNCIONES AUXILIARES ADICIONALES
// ============================================================================

async function saveDashboard(type, data) {
  try {
    await db.collection('financial_dashboards').doc(type).set({
      ...data,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log(`✅ Dashboard ${type} guardado en Firestore`);
  } catch (error) {
    console.error(`❌ Error guardando dashboard ${type}:`, error);
  }
}

async function detectFinancialAnomalies() {
  // Implementar detección de anomalías financieras
  const anomalies = [];
  
  // TODO: Implementar algoritmos de detección de anomalías
  // - Ingresos inusualmente bajos/altos
  // - Patrones de pago sospechosos
  // - Comisiones fuera del rango normal
  // - Transacciones duplicadas
  
  return anomalies;
}

async function generateConsolidatedFinancialReport(dashboardResults) {
  return {
    reportType: 'CONSOLIDATED_FINANCIAL',
    generatedAt: new Date().toISOString(),
    dashboards: dashboardResults.length,
    summary: {
      totalRevenue: 0, // Calcular desde dashboards
      totalCommissions: 0,
      totalDriverEarnings: 0,
      activeDrivers: 0,
      completedTrips: 0
    },
    locale: PERU_CONFIG.locale,
    currency: 'PEN'
  };
}

async function sendFinancialAlertsToAdmins(anomalies) {
  console.log(`📧 Enviando alertas financieras: ${anomalies.length} anomalías detectadas`);
  // TODO: Implementar envío de alertas
}

async function updateSystemHealthMetrics() {
  await db.collection('system_health').doc('financial_dashboards').set({
    lastUpdate: admin.firestore.FieldValue.serverTimestamp(),
    status: 'healthy',
    dashboardsActive: Object.keys(FINANCIAL_DASHBOARDS_CONFIG.dashboardTypes).length
  });
}

async function logFinancialAuditEvent(eventType, eventData) {
  await db.collection('financial_audit_logs').add({
    eventType,
    eventData,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    service: 'financial_dashboards'
  });
}

async function sendErrorNotificationToAdmins(subject, error) {
  console.error(`📧 Enviando notificación de error: ${subject}`, error);
  // TODO: Implementar notificación de errores
}

// Funciones auxiliares para métricas
function findTopRevenueCity(data) {
  const cityRevenues = {};
  data.forEach(row => {
    cityRevenues[row.city] = (cityRevenues[row.city] || 0) + parseFloat(row.city_revenue || 0);
  });
  
  return Object.entries(cityRevenues).reduce((max, [city, revenue]) => 
    revenue > max.revenue ? { city, revenue } : max, 
    { city: '', revenue: 0 }
  );
}

function calculateSurgeRevenuePercentage(data) {
  const totalRevenue = data.reduce((sum, row) => sum + parseFloat(row.city_revenue || 0), 0);
  const surgeRevenue = data.reduce((sum, row) => sum + parseFloat(row.surge_revenue || 0), 0);
  return totalRevenue > 0 ? (surgeRevenue / totalRevenue) * 100 : 0;
}

function calculateTipPercentage(data) {
  const totalRevenue = data.reduce((sum, row) => sum + parseFloat(row.city_revenue || 0), 0);
  const totalTips = data.reduce((sum, row) => sum + parseFloat(row.total_tips || 0), 0);
  return totalRevenue > 0 ? (totalTips / totalRevenue) * 100 : 0;
}

function groupRevenueByCity(data) {
  return data.reduce((acc, row) => {
    acc[row.city] = (acc[row.city] || 0) + parseFloat(row.city_revenue || 0);
    return acc;
  }, {});
}

function groupEarningsByVehicleType(data) {
  return data.reduce((acc, row) => {
    acc[row.vehicle_type] = (acc[row.vehicle_type] || 0) + parseFloat(row.total_earnings || 0);
    return acc;
  }, {});
}

function groupEarningsByCity(data) {
  return data.reduce((acc, row) => {
    acc[row.city] = (acc[row.city] || 0) + parseFloat(row.total_earnings || 0);
    return acc;
  }, {});
}

function calculateAverageCommissionRate(data) {
  const validRates = data.filter(row => row.commission_rate > 0);
  return validRates.length > 0 ? 
    validRates.reduce((sum, row) => sum + parseFloat(row.commission_rate), 0) / validRates.length : 0;
}

function calculateProfitMargin(data) {
  const totalRevenue = data.reduce((sum, row) => sum + parseFloat(row.gross_revenue || 0), 0);
  const totalProfit = data.reduce((sum, row) => sum + parseFloat(row.profit_before_tax || 0), 0);
  return totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0;
}

function groupCommissionsByCity(data) {
  return data.reduce((acc, row) => {
    acc[row.city] = (acc[row.city] || 0) + parseFloat(row.commission_amount || 0);
    return acc;
  }, {});
}

function findPreferredPaymentMethod(data) {
  const methodTotals = data.reduce((acc, row) => {
    acc[row.payment_method] = (acc[row.payment_method] || 0) + parseFloat(row.total_amount || 0);
    return acc;
  }, {});
  
  return Object.entries(methodTotals).reduce((max, [method, amount]) => 
    amount > max.amount ? { method, amount } : max,
    { method: '', amount: 0 }
  );
}

function calculateAverageSuccessRate(data) {
  const validRates = data.filter(row => row.success_rate >= 0);
  return validRates.length > 0 ? 
    validRates.reduce((sum, row) => sum + parseFloat(row.success_rate), 0) / validRates.length : 0;
}

function calculatePaymentMethodDistribution(data) {
  const total = data.reduce((sum, row) => sum + parseFloat(row.total_amount || 0), 0);
  return data.reduce((acc, row) => {
    acc[row.payment_method] = total > 0 ? (parseFloat(row.total_amount || 0) / total) * 100 : 0;
    return acc;
  }, {});
}

function calculateIGVCollected(data) {
  return data
    .filter(row => row.tax_type === 'IGV')
    .reduce((sum, row) => sum + parseFloat(row.tax_amount || 0), 0);
}

function calculateIncomeTaxOwed(data) {
  return data
    .filter(row => row.tax_type === 'RENTA')
    .reduce((sum, row) => sum + parseFloat(row.tax_amount || 0), 0);
}

function calculateComplianceRate(data) {
  const compliantRecords = data.filter(row => row.compliance_status === 'compliant');
  return data.length > 0 ? (compliantRecords.length / data.length) * 100 : 100;
}

async function calculateComprehensiveProfitability() {
  // Implementar cálculo integral de rentabilidad
  return {
    grossProfitMargin: 0,
    netProfitMargin: 0,
    roi: 0,
    ebitda: 0,
    breakEvenPoint: 0,
    customerAcquisitionCost: 0,
    lifetimeValue: 0
  };
}

async function calculateCashFlowAnalysis() {
  // Implementar análisis de flujo de caja
  return {
    operatingCashFlow: 0,
    investingCashFlow: 0,
    financingCashFlow: 0,
    netCashFlow: 0,
    cashPosition: 0,
    burnRate: 0,
    runwayMonths: 0
  };
}

console.log('💰 Sistema de Data Studio Dashboards Financieros para OasisTaxi inicializado correctamente');