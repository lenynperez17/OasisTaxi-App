#!/usr/bin/env node

/**
 * Firebase Remote Config Deployment Script for OasisTaxi
 * Deploy and manage Remote Config parameters for production
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Preflight check for credentials
function checkCredentials() {
  // Check for GOOGLE_APPLICATION_CREDENTIALS
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (!fs.existsSync(credPath)) {
      throw new Error(`Credential file not found at: ${credPath}`);
    }
    console.log('✅ Using GOOGLE_APPLICATION_CREDENTIALS');
    return;
  }

  // Check for individual environment variables
  const requiredEnvVars = [
    'FIREBASE_PROJECT_ID',
    'FIREBASE_CLIENT_EMAIL',
    'FIREBASE_PRIVATE_KEY'
  ];

  const missingVars = requiredEnvVars.filter(v => !process.env[v]);
  if (missingVars.length > 0) {
    throw new Error(`Missing required environment variables: ${missingVars.join(', ')}\n` +
      'Set either GOOGLE_APPLICATION_CREDENTIALS or individual Firebase credentials.');
  }

  console.log('✅ Using individual Firebase credentials from environment');
}

// Initialize Firebase Admin SDK
function initializeAdmin() {
  checkCredentials();

  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    // Use application default credentials
    admin.initializeApp({
      projectId: process.env.FIREBASE_PROJECT_ID || 'oasis-taxi-peru'
    });
  } else {
    // Use individual environment variables
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
      }),
      projectId: process.env.FIREBASE_PROJECT_ID
    });
  }

  console.log(`Project ID: ${process.env.FIREBASE_PROJECT_ID || 'oasis-taxi-peru'}`);
}

initializeAdmin();

// Load Remote Config template from file
function loadTemplate() {
  const templatePath = path.join(__dirname, 'remote-config-templates.json');

  if (!fs.existsSync(templatePath)) {
    throw new Error(`Template file not found at: ${templatePath}`);
  }

  console.log('📥 Loading template from:', templatePath);
  const templateContent = fs.readFileSync(templatePath, 'utf8');
  const template = JSON.parse(templateContent);

  // Validate template structure
  if (!template.parameters || !template.conditions) {
    throw new Error('Invalid template structure: missing parameters or conditions');
  }

  console.log(`✅ Template loaded: ${Object.keys(template.parameters).length} parameters`);
  return template;
}

// Do not define parameters inline. Edit `remote-config-templates.json` only.

// Removed deprecated template object to ensure single source of truth
// All Remote Config parameters must be defined in remote-config-templates.json

async function deployRemoteConfig(command = 'deploy') {
  try {
    const remoteConfig = admin.remoteConfig();
    const projectId = process.env.FIREBASE_PROJECT_ID || 'oasis-taxi-peru';

    switch (command) {
      case 'deploy':
      case 'publish':
        console.log('🚀 Deploying Remote Config to Firebase...');
        console.log(`Project: ${projectId}`);
        console.log('Environment: PRODUCTION');
        console.log('-----------------------------------');

        // Get current template for backup
        console.log('📥 Getting current Remote Config for backup...');
        try {
          const currentTemplate = await remoteConfig.getTemplate();
          const backupPath = path.join(__dirname, 'backups', `remote-config-backup-${Date.now()}.json`);
          fs.mkdirSync(path.dirname(backupPath), { recursive: true });
          fs.writeFileSync(backupPath, JSON.stringify(currentTemplate, null, 2));
          console.log(`✅ Backup saved to: ${backupPath}`);
        } catch (error) {
          console.log('⚠️ No existing Remote Config found (first deployment)');
        }

        // Load and validate template
        console.log('🔍 Validating Remote Config template...');
        const templateData = loadTemplate();
        const template = admin.remoteConfig.Template.fromJSON(JSON.stringify(templateData));

        // Publish new template
        console.log('📤 Publishing new Remote Config template...');
        const publishedTemplate = await remoteConfig.publishTemplate(template);

        console.log('✅ Remote Config deployed successfully!');
        console.log(`Version: ${publishedTemplate.version.versionNumber}`);
        console.log(`Updated at: ${publishedTemplate.version.updateTime}`);

        // Log parameter summary
        console.log('\n📊 Deployed Parameters Summary:');
        console.log('-----------------------------------');
        const params = Object.keys(templateData.parameters);
        console.log(`Total parameters: ${params.length}`);
        if (params.length <= 20) {
          params.forEach(param => {
            const value = templateData.parameters[param].defaultValue.value;
            console.log(`  ✓ ${param}: ${value}`);
          });
        } else {
          console.log(`  (showing first 10 of ${params.length} parameters)`);
          params.slice(0, 10).forEach(param => {
            const value = templateData.parameters[param].defaultValue.value;
            console.log(`  ✓ ${param}: ${value}`);
          });
          console.log('  ...');
        }

        console.log('\n🎉 Remote Config deployment completed successfully!');

        // Save deployment log
        const logPath = path.join(__dirname, 'deployment-logs', 'remote-config-deployment.log');
        fs.mkdirSync(path.dirname(logPath), { recursive: true });
        const logEntry = {
          timestamp: new Date().toISOString(),
          version: publishedTemplate.version.versionNumber,
          parameters: params.length,
          environment: 'production'
        };
        fs.appendFileSync(logPath, JSON.stringify(logEntry) + '\n');
        break;

      case 'list':
      case 'get':
        console.log('📋 Getting current Remote Config...');
        const currentTemplate = await remoteConfig.getTemplate();
        console.log(`\nVersion: ${currentTemplate.version.versionNumber}`);
        console.log(`Last updated: ${currentTemplate.version.updateTime}`);
        console.log(`Parameters: ${Object.keys(currentTemplate.parameters).length}`);
        console.log(`Conditions: ${currentTemplate.conditions.length}`);

        // Save to file
        const outputPath = path.join(__dirname, 'current-remote-config.json');
        fs.writeFileSync(outputPath, JSON.stringify(currentTemplate, null, 2));
        console.log(`\nSaved to: ${outputPath}`);
        break;

      case 'rollback':
        console.log('⏮️ Rolling back to previous version...');
        const versions = await remoteConfig.listVersions({ limit: 2 });
        if (versions.versions.length < 2) {
          console.log('❌ No previous version to rollback to');
          process.exit(1);
        }

        const previousVersion = versions.versions[1];
        console.log(`Rolling back to version: ${previousVersion.versionNumber}`);
        console.log(`From: ${previousVersion.updateTime}`);

        const rolledBackTemplate = await remoteConfig.rollback(previousVersion.versionNumber);
        console.log('✅ Rollback completed!');
        console.log(`Current version: ${rolledBackTemplate.version.versionNumber}`);
        break;

      default:
        console.log(`❌ Unknown command: ${command}`);
        console.log('Available commands: deploy, list, rollback');
        process.exit(1);
    }

  } catch (error) {
    console.error('❌ Error:', error.message || error);
    process.exit(1);
  }
}

// Run deployment
if (require.main === module) {
  const command = process.argv[2] || 'deploy';
  deployRemoteConfig(command);
}

module.exports = { deployRemoteConfig, loadTemplate };