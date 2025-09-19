#!/usr/bin/env node

/**
 * Firebase Cloud Functions Production Deployment Script
 * Automated deployment with validation and rollback capability
 */

const { execSync } = require('child_process');
const fs = require('fs');
const fsExtra = require('fs-extra');
const path = require('path');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Configuration
const PROJECT_ID = 'oasis-taxi-peru';
const FUNCTIONS_TO_DEPLOY = [
  'sendTripNotification',
  'sendDriverNotification',
  'sendPaymentNotification',
  'processPaymentWebhook',
  'sendEmergencyAlert',
  'updateDriverMetrics',
  'calculateTripPrice',
  'cleanupExpiredData',
  'generateReports',
  'sendBulkNotifications'
];

// Deployment checks
const preDeploymentChecks = [
  { name: 'Node.js version', command: 'node --version', expected: 'v18' },
  { name: 'Firebase CLI', command: 'firebase --version', expected: null },
  { name: 'TypeScript compilation', command: 'npm run build', expected: null },
  { name: 'ESLint', command: 'npm run lint', expected: null },
  { name: 'Tests', command: 'npm test', expected: null }
];

// Color codes for console output
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m'
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function logSection(title) {
  log('\n' + '='.repeat(50), 'cyan');
  log(title.toUpperCase(), 'cyan');
  log('='.repeat(50), 'cyan');
}

async function prompt(question) {
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      resolve(answer);
    });
  });
}

async function runPreDeploymentChecks() {
  logSection('Running Pre-Deployment Checks');

  for (const check of preDeploymentChecks) {
    process.stdout.write(`Checking ${check.name}... `);
    try {
      const result = execSync(check.command, { encoding: 'utf8', stdio: 'pipe' });
      if (check.expected && !result.includes(check.expected)) {
        log(`✗ (expected ${check.expected})`, 'red');
        return false;
      }
      log('✓', 'green');
    } catch (error) {
      log('✗', 'red');
      log(`  Error: ${error.message}`, 'red');
      return false;
    }
  }
  return true;
}

function backupCurrentFunctions() {
  logSection('Creating Backup');

  const backupDir = path.join(__dirname, 'backups', `backup-${Date.now()}`);
  fs.mkdirSync(backupDir, { recursive: true });

  try {
    // Save current function configurations
    log('Saving function configurations...', 'yellow');
    const functionsConfig = execSync(
      `firebase functions:config:get --project ${PROJECT_ID}`,
      { encoding: 'utf8' }
    );
    fs.writeFileSync(
      path.join(backupDir, 'functions-config.json'),
      functionsConfig
    );

    // Copy current source code
    log('Backing up source code...', 'yellow');
    fsExtra.copySync(path.join(__dirname, '..', 'src'), path.join(backupDir, 'src'));
    fsExtra.copySync(path.join(__dirname, '..', 'package.json'), path.join(backupDir, 'package.json'));
    fsExtra.copySync(path.join(__dirname, '..', 'package-lock.json'), path.join(backupDir, 'package-lock.json'));

    log(`✓ Backup created at: ${backupDir}`, 'green');
    return backupDir;
  } catch (error) {
    log(`✗ Backup failed: ${error.message}`, 'red');
    return null;
  }
}

async function setEnvironmentVariables() {
  logSection('Setting Environment Variables');

  const envVars = {
    // Payment Configuration
    'mercadopago.access_token': process.env.MERCADOPAGO_ACCESS_TOKEN_PROD,
    'mercadopago.webhook_secret': process.env.MERCADOPAGO_WEBHOOK_SECRET,
    'mercadopago.public_key': process.env.MERCADOPAGO_PUBLIC_KEY,

    // Communication Services
    'twilio.account_sid': process.env.TWILIO_ACCOUNT_SID,
    'twilio.auth_token': process.env.TWILIO_AUTH_TOKEN,
    'twilio.phone_number': process.env.TWILIO_PHONE_NUMBER,
    'sendgrid.api_key': process.env.SENDGRID_API_KEY,

    // SMTP Configuration
    'smtp.host': process.env.SMTP_HOST || 'smtp.sendgrid.net',
    'smtp.port': process.env.SMTP_PORT || '587',
    'smtp.user': process.env.SMTP_USER,
    'smtp.password': process.env.SMTP_PASSWORD,
    'smtp.from_email': process.env.SMTP_FROM_EMAIL || 'noreply@oasistaxiperu.com',

    // Security
    'jwt.secret': process.env.JWT_SECRET,
    'jwt.expiry': process.env.JWT_EXPIRY || '7d',
    'encryption.key': process.env.ENCRYPTION_KEY,
    'app.secret': process.env.APP_SECRET,

    // Google Services
    'google.maps_api_key': process.env.GOOGLE_MAPS_API_KEY,
    'google.places_api_key': process.env.GOOGLE_PLACES_API_KEY || process.env.GOOGLE_MAPS_API_KEY,

    // App Configuration
    'app.environment': 'production',
    'app.base_url': process.env.APP_BASE_URL || 'https://oasistaxiperu.com',
    'app.api_url': process.env.API_BASE_URL || 'https://api.oasistaxiperu.com',
    'app.support_email': process.env.SUPPORT_EMAIL || 'soporte@oasistaxiperu.com',
    'app.support_phone': process.env.SUPPORT_PHONE || '+51999999999',

    // Database Configuration
    'database.url': process.env.DATABASE_URL,
    'redis.url': process.env.REDIS_URL,

    // Feature Flags
    'features.price_negotiation': process.env.FEATURE_PRICE_NEGOTIATION || 'true',
    'features.emergency_sos': process.env.FEATURE_EMERGENCY_SOS || 'true',
    'features.wallet_payments': process.env.FEATURE_WALLET_PAYMENTS || 'true'
  };

  // Validate critical environment variables
  const criticalVars = [
    'jwt.secret',
    'encryption.key',
    'google.maps_api_key',
    'app.environment'
  ];

  const missingCritical = criticalVars.filter(key => !envVars[key]);
  if (missingCritical.length > 0) {
    log(`❌ Missing critical environment variables:`, 'red');
    missingCritical.forEach(key => log(`  - ${key}`, 'red'));
    log('\nPlease set these variables before deployment.', 'red');
    return false;
  }

  for (const [key, value] of Object.entries(envVars)) {
    if (!value) {
      log(`⚠️ Missing environment variable: ${key}`, 'yellow');
      continue;
    }

    try {
      process.stdout.write(`Setting ${key}... `);
      execSync(
        `firebase functions:config:set ${key}="${value}" --project ${PROJECT_ID}`,
        { stdio: 'pipe' }
      );
      log('✓', 'green');
    } catch (error) {
      log(`✗ ${error.message}`, 'red');
      return false;
    }
  }
  return true;
}

async function deployFunctions(functionsToDeploy = FUNCTIONS_TO_DEPLOY, deployAll = false) {
  logSection('Deploying Functions');

  const deploymentLog = [];
  const failedFunctions = [];

  if (deployAll) {
    // Deploy all functions at once
    process.stdout.write('Deploying all functions... ');
    const startTime = Date.now();

    try {
      execSync(
        `firebase deploy --only functions --project ${PROJECT_ID}`,
        { stdio: 'pipe', encoding: 'utf8' }
      );

      const deployTime = ((Date.now() - startTime) / 1000).toFixed(2);
      log(`✓ (${deployTime}s)`, 'green');

      functionsToDeploy.forEach(functionName => {
        deploymentLog.push({
          function: functionName,
          status: 'success',
          time: deployTime,
          batch: true
        });
      });
    } catch (error) {
      log('✗', 'red');
      log(`  Error: ${error.message}`, 'red');

      functionsToDeploy.forEach(functionName => {
        failedFunctions.push(functionName);
        deploymentLog.push({
          function: functionName,
          status: 'failed',
          error: error.message,
          batch: true
        });
      });
    }
  } else {
    // Deploy functions individually
    for (const functionName of functionsToDeploy) {
      process.stdout.write(`Deploying ${functionName}... `);
      const startTime = Date.now();

      try {
        execSync(
          `firebase deploy --only functions:${functionName} --project ${PROJECT_ID}`,
          { stdio: 'pipe', encoding: 'utf8' }
        );

        const deployTime = ((Date.now() - startTime) / 1000).toFixed(2);
        log(`✓ (${deployTime}s)`, 'green');

        deploymentLog.push({
          function: functionName,
          status: 'success',
          time: deployTime,
          batch: false
        });
      } catch (error) {
        log('✗', 'red');
        log(`  Error: ${error.message}`, 'red');

        failedFunctions.push(functionName);
        deploymentLog.push({
          function: functionName,
          status: 'failed',
          error: error.message,
          batch: false
        });
      }
    }
  }

  // Save deployment log
  const logPath = path.join(__dirname, 'deployment-logs', `deploy-${Date.now()}.json`);
  fs.mkdirSync(path.dirname(logPath), { recursive: true });
  fs.writeFileSync(logPath, JSON.stringify(deploymentLog, null, 2));

  return { failedFunctions, deploymentLog };
}

async function verifyDeployment() {
  logSection('Verifying Deployment');

  const verifications = [
    {
      name: 'Function health check',
      command: `firebase functions:list --project ${PROJECT_ID}`
    },
    {
      name: 'Firestore rules',
      command: `firebase deploy --only firestore:rules --project ${PROJECT_ID}`
    },
    {
      name: 'Storage rules',
      command: `firebase deploy --only storage:rules --project ${PROJECT_ID}`
    }
  ];

  for (const verification of verifications) {
    process.stdout.write(`${verification.name}... `);
    try {
      execSync(verification.command, { stdio: 'pipe' });
      log('✓', 'green');
    } catch (error) {
      log('✗', 'red');
      return false;
    }
  }
  return true;
}

async function rollback(backupDir) {
  logSection('Rolling Back Deployment');

  if (!backupDir) {
    log('No backup directory provided', 'red');
    return false;
  }

  try {
    log('Restoring from backup...', 'yellow');

    // Restore source code
    fsExtra.copySync(path.join(backupDir, 'src'), path.join(__dirname, '..', 'src'));
    fsExtra.copySync(path.join(backupDir, 'package.json'), path.join(__dirname, '..', 'package.json'));
    fsExtra.copySync(path.join(backupDir, 'package-lock.json'), path.join(__dirname, '..', 'package-lock.json'));

    // Restore function configs
    const configPath = path.join(backupDir, 'functions-config.json');
    if (fs.existsSync(configPath)) {
      const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      // Set each config value
      for (const [key, value] of Object.entries(config)) {
        execSync(
          `firebase functions:config:set ${key}="${value}" --project ${PROJECT_ID}`,
          { stdio: 'pipe' }
        );
      }
    }

    // Rebuild and redeploy
    execSync('npm run build', { cwd: path.join(__dirname, '..') });
    const { failedFunctions, deploymentLog } = await deployFunctions();
    await generateDeploymentReport(deploymentLog, failedFunctions);

    log('✓ Rollback completed', 'green');
    return true;
  } catch (error) {
    log(`✗ Rollback failed: ${error.message}`, 'red');
    return false;
  }
}

async function generateDeploymentReport(deploymentLog = [], failedFunctions = []) {
  logSection('Deployment Report');

  const report = {
    timestamp: new Date().toISOString(),
    project: PROJECT_ID,
    environment: 'production',
    totalFunctions: FUNCTIONS_TO_DEPLOY.length,
    deployedFunctions: FUNCTIONS_TO_DEPLOY.length - failedFunctions.length,
    failedFunctions: failedFunctions.length,
    details: deploymentLog
  };

  // Display summary
  log('\nDeployment Summary:', 'cyan');
  log(`  Project: ${report.project}`, 'white');
  log(`  Environment: ${report.environment}`, 'white');
  log(`  Total Functions: ${report.totalFunctions}`, 'white');
  log(`  ✓ Deployed: ${report.deployedFunctions}`, 'green');
  if (report.failedFunctions > 0) {
    log(`  ✗ Failed: ${report.failedFunctions}`, 'red');
    log('\nFailed Functions:', 'red');
    failedFunctions.forEach(fn => log(`    - ${fn}`, 'red'));
  }

  // Save report
  const reportPath = path.join(
    __dirname,
    'deployment-reports',
    `report-${Date.now()}.json`
  );
  fs.mkdirSync(path.dirname(reportPath), { recursive: true });
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));

  log(`\nFull report saved to: ${reportPath}`, 'cyan');
}

async function main() {
  log('🚀 Firebase Cloud Functions Production Deployment', 'magenta');
  log('Project: oasis-taxi-peru', 'magenta');
  log('Environment: PRODUCTION\n', 'magenta');

  // Confirmation
  const confirm = await prompt(
    'This will deploy functions to PRODUCTION. Continue? (yes/no): '
  );

  if (confirm.toLowerCase() !== 'yes') {
    log('Deployment cancelled', 'yellow');
    rl.close();
    return;
  }

  // Pre-deployment checks
  if (!await runPreDeploymentChecks()) {
    log('\nPre-deployment checks failed. Fix issues and try again.', 'red');
    rl.close();
    return;
  }

  // Create backup
  const backupDir = backupCurrentFunctions();
  if (!backupDir) {
    const continueWithoutBackup = await prompt(
      'Backup failed. Continue without backup? (yes/no): '
    );
    if (continueWithoutBackup.toLowerCase() !== 'yes') {
      log('Deployment cancelled', 'yellow');
      rl.close();
      return;
    }
  }

  // Set environment variables
  if (!await setEnvironmentVariables()) {
    log('\nFailed to set environment variables', 'red');
    rl.close();
    return;
  }

  // Check for --all flag
  const deployAll = process.argv.includes('--all');
  if (deployAll) {
    log('Using --all mode: deploying all functions at once', 'cyan');
  }

  // Deploy functions
  const { failedFunctions, deploymentLog } = await deployFunctions(FUNCTIONS_TO_DEPLOY, deployAll);

  // Verify deployment
  const verified = await verifyDeployment();

  if (failedFunctions.length > 0 || !verified) {
    log('\n⚠️ Deployment completed with errors', 'yellow');

    const shouldRollback = await prompt(
      'Do you want to rollback? (yes/no): '
    );

    if (shouldRollback.toLowerCase() === 'yes' && backupDir) {
      await rollback(backupDir);
    }
  } else {
    log('\n✅ Deployment completed successfully!', 'green');
  }

  // Generate report
  await generateDeploymentReport(deploymentLog, failedFunctions);

  rl.close();
}

// Handle errors
process.on('unhandledRejection', (error) => {
  log(`\n❌ Unhandled error: ${error.message}`, 'red');
  rl.close();
  process.exit(1);
});

// Run if executed directly
if (require.main === module) {
  main();
}

// Check if fs-extra is installed, if not provide a fallback
if (!fsExtra.copySync) {
  console.log('Note: fs-extra not found, install it for better cross-platform support');
  fsExtra.copySync = function(src, dest) {
    // Fallback to execSync for compatibility
    if (process.platform === 'win32') {
      execSync(`xcopy /E /I "${src}" "${dest}"`);
    } else {
      execSync(`cp -r "${src}" "${dest}"`);
    }
  };
}

module.exports = { deployFunctions, verifyDeployment };