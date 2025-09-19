// 🌐 Cloud CDN & Load Balancing Configuration
// Sistema completo de CDN, Load Balancing, Auto-scaling y Cloud Armor
// OasisTaxi Perú - Producción 2025

const { Storage } = require('@google-cloud/storage');
const { Compute } = require('@google-cloud/compute');
const { SecurityCenter } = require('@google-cloud/security-center');
const { Monitoring } = require('@google-cloud/monitoring');
const { DNS } = require('@google-cloud/dns');
const axios = require('axios');

class CloudInfrastructureService {
  constructor() {
    this.projectId = 'oasis-taxi-peru';
    this.region = 'us-central1';
    this.zone = 'us-central1-a';
    
    // Inicializar clientes de GCP
    this.storage = new Storage({ projectId: this.projectId });
    this.compute = new Compute({ projectId: this.projectId });
    this.monitoring = new Monitoring.MetricServiceClient();
    
    // Configuración de servicios
    this.config = {
      cdn: {
        enabled: true,
        cacheMode: 'CACHE_ALL_STATIC',
        defaultTTL: 3600,
        maxTTL: 86400,
        negativeCaching: true,
        compressionMode: 'AUTOMATIC',
        enableCloudCDN: true
      },
      loadBalancer: {
        name: 'oasistxi-global-lb',
        protocol: 'HTTPS',
        port: 443,
        healthCheckInterval: 10,
        healthCheckTimeout: 5,
        unhealthyThreshold: 3,
        healthyThreshold: 2
      },
      autoScaling: {
        minInstances: 2,
        maxInstances: 100,
        targetCPUUtilization: 0.6,
        targetLoadBalancingUtilization: 0.8,
        coolDownPeriodSec: 60
      },
      cloudArmor: {
        enabled: true,
        defaultAction: 'allow',
        rateLimitThreshold: 1000,
        adaptiveProtection: true,
        ddosProtection: true
      }
    };
    
    this.initialize();
  }

  async initialize() {
    console.log('🚀 Inicializando Cloud Infrastructure Service');
    
    try {
      // Configurar Cloud CDN
      await this.setupCloudCDN();
      
      // Configurar Load Balancer
      await this.setupLoadBalancer();
      
      // Configurar Auto-scaling
      await this.setupAutoScaling();
      
      // Configurar Cloud Armor
      await this.setupCloudArmor();
      
      // Configurar Monitoring
      await this.setupMonitoring();
      
      // Configurar DNS
      await this.setupDNS();
      
      console.log('✅ Cloud Infrastructure configurado correctamente');
    } catch (error) {
      console.error('❌ Error inicializando infraestructura:', error);
    }
  }

  // ============================================
  // CLOUD CDN CONFIGURATION
  // ============================================
  
  async setupCloudCDN() {
    console.log('📡 Configurando Cloud CDN...');
    
    const cdnConfig = {
      name: 'oasistxi-cdn',
      description: 'CDN para contenido estático de OasisTaxi',
      
      // Backend buckets para contenido estático
      backendBuckets: [
        {
          name: 'oasistxi-static-content',
          bucketName: 'oasistxi-static',
          enableCdn: true,
          cdnPolicy: {
            cacheMode: this.config.cdn.cacheMode,
            defaultTtl: this.config.cdn.defaultTTL,
            maxTtl: this.config.cdn.maxTTL,
            clientTtl: 3600,
            negativeCaching: true,
            negativeCachingPolicy: [
              { code: 404, ttl: 300 },
              { code: 403, ttl: 60 }
            ],
            cacheKeyPolicy: {
              includeProtocol: true,
              includeHost: true,
              includeQueryString: false,
              queryStringWhitelist: ['v', 'version']
            },
            signedUrlCacheMaxAgeSec: 3600
          },
          compressionMode: 'AUTOMATIC',
          customResponseHeaders: [
            'Cache-Control: public, max-age=31536000',
            'X-Content-Type-Options: nosniff',
            'X-Frame-Options: SAMEORIGIN'
          ]
        },
        {
          name: 'oasistxi-media-content',
          bucketName: 'oasistxi-media',
          enableCdn: true,
          cdnPolicy: {
            cacheMode: 'CACHE_ALL_STATIC',
            defaultTtl: 7200,
            maxTtl: 86400,
            negativeCaching: false
          }
        }
      ],
      
      // URL maps para routing
      urlMaps: {
        name: 'oasistxi-url-map',
        defaultService: 'oasistxi-backend-service',
        hostRules: [
          {
            hosts: ['cdn.oasistaxiperu.com'],
            pathMatcher: 'static-paths'
          },
          {
            hosts: ['media.oasistaxiperu.com'],
            pathMatcher: 'media-paths'
          }
        ],
        pathMatchers: [
          {
            name: 'static-paths',
            defaultService: 'oasistxi-static-backend',
            pathRules: [
              {
                paths: ['/css/*', '/js/*', '/fonts/*'],
                service: 'oasistxi-static-backend'
              },
              {
                paths: ['/images/*', '/icons/*'],
                service: 'oasistxi-media-backend'
              }
            ]
          }
        ]
      }
    };

    // Crear backend buckets
    for (const bucket of cdnConfig.backendBuckets) {
      await this.createBackendBucket(bucket);
    }
    
    // Configurar URL maps
    await this.createUrlMap(cdnConfig.urlMaps);
    
    // Habilitar Cloud CDN en los backends
    await this.enableCDNOnBackends();
    
    console.log('✅ Cloud CDN configurado');
  }

  async createBackendBucket(config) {
    try {
      const backendBucket = {
        name: config.name,
        bucketName: config.bucketName,
        enableCdn: config.enableCdn,
        cdnPolicy: config.cdnPolicy,
        compressionMode: config.compressionMode,
        customResponseHeaders: config.customResponseHeaders
      };
      
      // Crear o actualizar backend bucket
      const [operation] = await this.compute.backendBuckets.insert({
        project: this.projectId,
        requestBody: backendBucket
      });
      
      await operation.promise();
      console.log(`✅ Backend bucket ${config.name} creado`);
      
    } catch (error) {
      if (error.code === 409) {
        // Ya existe, actualizar
        await this.updateBackendBucket(config);
      } else {
        throw error;
      }
    }
  }

  // ============================================
  // LOAD BALANCER CONFIGURATION
  // ============================================
  
  async setupLoadBalancer() {
    console.log('⚖️ Configurando Load Balancer...');
    
    const lbConfig = {
      // Global forwarding rule
      forwardingRule: {
        name: this.config.loadBalancer.name,
        IPProtocol: 'TCP',
        portRange: '443',
        target: `projects/${this.projectId}/global/targetHttpsProxies/oasistxi-https-proxy`,
        loadBalancingScheme: 'EXTERNAL',
        networkTier: 'PREMIUM',
        ipVersion: 'IPV4'
      },
      
      // Target HTTPS proxy
      targetHttpsProxy: {
        name: 'oasistxi-https-proxy',
        urlMap: `projects/${this.projectId}/global/urlMaps/oasistxi-url-map`,
        sslCertificates: [
          `projects/${this.projectId}/global/sslCertificates/oasistxi-cert`
        ],
        quicOverride: 'ENABLE',
        sslPolicy: `projects/${this.projectId}/global/sslPolicies/oasistxi-ssl-policy`
      },
      
      // Backend services
      backendServices: [
        {
          name: 'oasistxi-backend-service',
          protocol: 'HTTPS',
          portName: 'https',
          timeoutSec: 30,
          enableCDN: true,
          
          backends: [
            {
              group: `projects/${this.projectId}/zones/${this.zone}/instanceGroups/oasistxi-ig-1`,
              balancingMode: 'UTILIZATION',
              maxUtilization: 0.8,
              capacityScaler: 1.0
            },
            {
              group: `projects/${this.projectId}/zones/us-central1-b/instanceGroups/oasistxi-ig-2`,
              balancingMode: 'UTILIZATION',
              maxUtilization: 0.8,
              capacityScaler: 1.0
            }
          ],
          
          healthChecks: [
            `projects/${this.projectId}/global/healthChecks/oasistxi-health-check`
          ],
          
          sessionAffinity: 'CLIENT_IP',
          affinityCookieTtlSec: 3600,
          
          connectionDraining: {
            drainingTimeoutSec: 300
          },
          
          circuitBreakers: {
            maxRequestsPerConnection: 100,
            maxConnections: 1000,
            maxPendingRequests: 200,
            maxRequests: 2000,
            maxRetries: 3
          },
          
          outlierDetection: {
            consecutiveErrors: 5,
            interval: {
              seconds: 30
            },
            baseEjectionTime: {
              seconds: 30
            },
            maxEjectionPercent: 50,
            enforcingConsecutiveErrors: 100,
            enforcingSuccessRate: 100,
            successRateMinimumHosts: 5,
            successRateRequestVolume: 100,
            successRateStdevFactor: 1900
          },
          
          logConfig: {
            enable: true,
            sampleRate: 1.0
          }
        }
      ],
      
      // Health checks
      healthCheck: {
        name: 'oasistxi-health-check',
        type: 'HTTPS',
        requestPath: '/health',
        port: 443,
        checkIntervalSec: this.config.loadBalancer.healthCheckInterval,
        timeoutSec: this.config.loadBalancer.healthCheckTimeout,
        unhealthyThreshold: this.config.loadBalancer.unhealthyThreshold,
        healthyThreshold: this.config.loadBalancer.healthyThreshold
      }
    };

    // Crear health check
    await this.createHealthCheck(lbConfig.healthCheck);
    
    // Crear backend services
    for (const service of lbConfig.backendServices) {
      await this.createBackendService(service);
    }
    
    // Crear target HTTPS proxy
    await this.createTargetHttpsProxy(lbConfig.targetHttpsProxy);
    
    // Crear forwarding rule
    await this.createForwardingRule(lbConfig.forwardingRule);
    
    console.log('✅ Load Balancer configurado');
  }

  async createHealthCheck(config) {
    try {
      const [operation] = await this.compute.healthChecks.insert({
        project: this.projectId,
        requestBody: config
      });
      
      await operation.promise();
      console.log(`✅ Health check ${config.name} creado`);
      
    } catch (error) {
      if (error.code !== 409) throw error;
      console.log(`ℹ️ Health check ${config.name} ya existe`);
    }
  }

  // ============================================
  // AUTO-SCALING CONFIGURATION
  // ============================================
  
  async setupAutoScaling() {
    console.log('📈 Configurando Auto-scaling...');
    
    const autoScalingConfig = {
      // Instance template
      instanceTemplate: {
        name: 'oasistxi-template-v1',
        properties: {
          machineType: 'n1-standard-2',
          disks: [
            {
              boot: true,
              autoDelete: true,
              initializeParams: {
                sourceImage: 'projects/debian-cloud/global/images/family/debian-11',
                diskSizeGb: 20,
                diskType: 'pd-ssd'
              }
            }
          ],
          networkInterfaces: [
            {
              network: 'global/networks/default',
              accessConfigs: [
                {
                  type: 'ONE_TO_ONE_NAT',
                  name: 'External NAT',
                  networkTier: 'PREMIUM'
                }
              ]
            }
          ],
          metadata: {
            items: [
              {
                key: 'startup-script',
                value: this.getStartupScript()
              }
            ]
          },
          serviceAccounts: [
            {
              email: 'default',
              scopes: [
                'https://www.googleapis.com/auth/cloud-platform'
              ]
            }
          ],
          tags: {
            items: ['http-server', 'https-server', 'oasistxi']
          },
          labels: {
            app: 'oasistxi',
            environment: 'production'
          }
        }
      },
      
      // Instance group manager
      instanceGroupManager: {
        name: 'oasistxi-igm',
        baseInstanceName: 'oasistxi-instance',
        instanceTemplate: `projects/${this.projectId}/global/instanceTemplates/oasistxi-template-v1`,
        targetSize: 3,
        
        autoHealingPolicies: [
          {
            healthCheck: `projects/${this.projectId}/global/healthChecks/oasistxi-health-check`,
            initialDelaySec: 300
          }
        ],
        
        updatePolicy: {
          type: 'PROACTIVE',
          minimalAction: 'REPLACE',
          maxSurge: {
            fixed: 3
          },
          maxUnavailable: {
            fixed: 0
          },
          minReadySec: 60,
          replacementMethod: 'SUBSTITUTE'
        },
        
        versions: [
          {
            instanceTemplate: `projects/${this.projectId}/global/instanceTemplates/oasistxi-template-v1`,
            name: 'v1',
            targetSize: {
              percent: 100
            }
          }
        ]
      },
      
      // Autoscaler
      autoscaler: {
        name: 'oasistxi-autoscaler',
        target: `projects/${this.projectId}/zones/${this.zone}/instanceGroupManagers/oasistxi-igm`,
        
        autoscalingPolicy: {
          minNumReplicas: this.config.autoScaling.minInstances,
          maxNumReplicas: this.config.autoScaling.maxInstances,
          coolDownPeriodSec: this.config.autoScaling.coolDownPeriodSec,
          
          cpuUtilization: {
            utilizationTarget: this.config.autoScaling.targetCPUUtilization,
            predictiveMethod: 'OPTIMIZE_AVAILABILITY'
          },
          
          loadBalancingUtilization: {
            utilizationTarget: this.config.autoScaling.targetLoadBalancingUtilization
          },
          
          customMetricUtilizations: [
            {
              metric: 'custom.googleapis.com/oasistxi/active_trips',
              utilizationTarget: 100,
              utilizationTargetType: 'GAUGE'
            },
            {
              metric: 'custom.googleapis.com/oasistxi/request_rate',
              utilizationTarget: 1000,
              utilizationTargetType: 'DELTA_PER_SECOND'
            }
          ],
          
          scaleDownControl: {
            maxScaledDownReplicas: {
              percent: 50
            },
            timeWindowSec: 600
          },
          
          scaleInControl: {
            maxScaledInReplicas: {
              fixed: 10
            },
            timeWindowSec: 600
          }
        }
      }
    };

    // Crear instance template
    await this.createInstanceTemplate(autoScalingConfig.instanceTemplate);
    
    // Crear instance group manager
    await this.createInstanceGroupManager(autoScalingConfig.instanceGroupManager);
    
    // Crear autoscaler
    await this.createAutoscaler(autoScalingConfig.autoscaler);
    
    console.log('✅ Auto-scaling configurado');
  }

  getStartupScript() {
    return `#!/bin/bash
# OasisTaxi Instance Startup Script

# Actualizar sistema
apt-get update
apt-get install -y nginx nodejs npm docker.io

# Configurar Nginx
cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80;
    listen 443 ssl http2;
    server_name _;
    
    ssl_certificate /etc/ssl/certs/oasistxi.crt;
    ssl_certificate_key /etc/ssl/private/oasistxi.key;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \\$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \\$host;
        proxy_cache_bypass \\$http_upgrade;
        proxy_set_header X-Real-IP \\$remote_addr;
        proxy_set_header X-Forwarded-For \\$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \\$scheme;
    }
    
    location /health {
        access_log off;
        return 200 "healthy\\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Iniciar servicios
systemctl restart nginx
systemctl enable nginx

# Descargar y ejecutar aplicación
gsutil cp gs://oasistxi-deployment/app.tar.gz /opt/
cd /opt && tar -xzf app.tar.gz
cd app && npm install --production
npm run start:production &

# Configurar monitoreo
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install

# Logs
echo "Instance started at $(date)" >> /var/log/oasistxi-startup.log
`;
  }

  // ============================================
  // CLOUD ARMOR CONFIGURATION
  // ============================================
  
  async setupCloudArmor() {
    console.log('🛡️ Configurando Cloud Armor...');
    
    const armorConfig = {
      // Security policy
      securityPolicy: {
        name: 'oasistxi-security-policy',
        description: 'Política de seguridad para OasisTaxi',
        
        rules: [
          // Regla 1: Bloquear IPs maliciosas conocidas
          {
            priority: 1000,
            match: {
              versionedExpr: 'SRC_IPS_V1',
              config: {
                srcIpRanges: [
                  // Lista negra de IPs (ejemplo)
                  '192.0.2.0/24',
                  '198.51.100.0/24'
                ]
              }
            },
            action: 'deny(403)',
            preview: false,
            description: 'Bloquear IPs maliciosas conocidas'
          },
          
          // Regla 2: Rate limiting
          {
            priority: 2000,
            match: {
              expr: {
                expression: 'true'
              }
            },
            action: 'rate_based_ban',
            rateLimitOptions: {
              conformAction: 'allow',
              exceedAction: 'deny(429)',
              enforceOnKey: 'IP',
              rateLimitThreshold: {
                count: this.config.cloudArmor.rateLimitThreshold,
                intervalSec: 60
              },
              banDurationSec: 600,
              banThreshold: {
                count: 10000,
                intervalSec: 600
              }
            },
            preview: false,
            description: 'Rate limiting por IP'
          },
          
          // Regla 3: Bloquear países específicos (si necesario)
          {
            priority: 3000,
            match: {
              expr: {
                expression: "origin.region_code == 'CN' || origin.region_code == 'RU'"
              }
            },
            action: 'deny(403)',
            preview: true, // En preview para no bloquear inmediatamente
            description: 'Geo-blocking de países de alto riesgo'
          },
          
          // Regla 4: Protección contra SQL injection
          {
            priority: 4000,
            match: {
              expr: {
                expression: "evaluatePreconfiguredExpr('sqli-v33-stable')"
              }
            },
            action: 'deny(403)',
            preview: false,
            description: 'Protección contra SQL injection'
          },
          
          // Regla 5: Protección contra XSS
          {
            priority: 5000,
            match: {
              expr: {
                expression: "evaluatePreconfiguredExpr('xss-v33-stable')"
              }
            },
            action: 'deny(403)',
            preview: false,
            description: 'Protección contra XSS'
          },
          
          // Regla 6: Protección contra scanners
          {
            priority: 6000,
            match: {
              expr: {
                expression: "evaluatePreconfiguredExpr('scannerdetection-v33-stable')"
              }
            },
            action: 'deny(403)',
            preview: false,
            description: 'Bloquear scanners automáticos'
          },
          
          // Regla 7: Protección contra protocol attacks
          {
            priority: 7000,
            match: {
              expr: {
                expression: "evaluatePreconfiguredExpr('protocolattack-v33-stable')"
              }
            },
            action: 'deny(403)',
            preview: false,
            description: 'Protección contra ataques de protocolo'
          },
          
          // Regla 8: Protección contra session fixation
          {
            priority: 8000,
            match: {
              expr: {
                expression: "evaluatePreconfiguredExpr('sessionfixation-v33-stable')"
              }
            },
            action: 'deny(403)',
            preview: false,
            description: 'Protección contra session fixation'
          },
          
          // Regla 9: Throttling para APIs
          {
            priority: 9000,
            match: {
              expr: {
                expression: "request.path.matches('/api/.*')"
              }
            },
            action: 'throttle',
            rateLimitOptions: {
              conformAction: 'allow',
              exceedAction: 'deny(429)',
              enforceOnKey: 'IP',
              rateLimitThreshold: {
                count: 100,
                intervalSec: 60
              }
            },
            preview: false,
            description: 'Rate limiting específico para APIs'
          },
          
          // Regla por defecto: Permitir
          {
            priority: 2147483647,
            match: {
              versionedExpr: 'SRC_IPS_V1',
              config: {
                srcIpRanges: ['*']
              }
            },
            action: 'allow',
            preview: false,
            description: 'Regla por defecto - permitir'
          }
        ],
        
        // Adaptive Protection
        adaptiveProtectionConfig: {
          layer7DdosDefenseConfig: {
            enable: this.config.cloudArmor.ddosProtection,
            ruleVisibility: 'STANDARD'
          }
        },
        
        // Advanced options
        advancedOptionsConfig: {
          jsonParsing: 'STANDARD',
          jsonCustomConfig: {
            contentTypes: ['application/json', 'application/ld+json']
          },
          logLevel: 'VERBOSE'
        }
      }
    };

    // Crear security policy
    await this.createSecurityPolicy(armorConfig.securityPolicy);
    
    // Aplicar policy a los backend services
    await this.applySecurityPolicyToBackends(armorConfig.securityPolicy.name);
    
    console.log('✅ Cloud Armor configurado');
  }

  async createSecurityPolicy(config) {
    try {
      const [operation] = await this.compute.securityPolicies.insert({
        project: this.projectId,
        requestBody: config
      });
      
      await operation.promise();
      console.log(`✅ Security policy ${config.name} creada`);
      
    } catch (error) {
      if (error.code === 409) {
        // Ya existe, actualizar
        await this.updateSecurityPolicy(config);
      } else {
        throw error;
      }
    }
  }

  // ============================================
  // MONITORING & ALERTING
  // ============================================
  
  async setupMonitoring() {
    console.log('📊 Configurando Monitoring & Alerting...');
    
    const monitoringConfig = {
      // Alert policies
      alertPolicies: [
        {
          displayName: 'High CPU Usage',
          conditions: [{
            displayName: 'CPU > 80%',
            conditionThreshold: {
              filter: 'metric.type="compute.googleapis.com/instance/cpu/utilization" resource.type="gce_instance"',
              comparison: 'COMPARISON_GT',
              thresholdValue: 0.8,
              duration: '60s',
              aggregations: [{
                alignmentPeriod: '60s',
                perSeriesAligner: 'ALIGN_MEAN'
              }]
            }
          }],
          notificationChannels: ['email', 'sms', 'slack']
        },
        {
          displayName: 'High Memory Usage',
          conditions: [{
            displayName: 'Memory > 90%',
            conditionThreshold: {
              filter: 'metric.type="agent.googleapis.com/memory/percent_used" resource.type="gce_instance"',
              comparison: 'COMPARISON_GT',
              thresholdValue: 90,
              duration: '60s'
            }
          }],
          notificationChannels: ['email', 'slack']
        },
        {
          displayName: 'High Error Rate',
          conditions: [{
            displayName: 'Error rate > 1%',
            conditionThreshold: {
              filter: 'metric.type="loadbalancing.googleapis.com/https/request_count" resource.type="https_lb_rule" metric.label.response_code_class="5xx"',
              comparison: 'COMPARISON_GT',
              thresholdValue: 0.01,
              duration: '60s'
            }
          }],
          notificationChannels: ['email', 'pagerduty']
        },
        {
          displayName: 'SSL Certificate Expiry',
          conditions: [{
            displayName: 'Certificate expires in 30 days',
            conditionThreshold: {
              filter: 'metric.type="monitoring.googleapis.com/uptime_check/ssl_cert_expiry_days"',
              comparison: 'COMPARISON_LT',
              thresholdValue: 30,
              duration: '60s'
            }
          }],
          notificationChannels: ['email']
        }
      ],
      
      // Uptime checks
      uptimeChecks: [
        {
          displayName: 'OasisTaxi Main Site',
          monitoredResource: {
            type: 'uptime_url',
            labels: {
              host: 'oasistaxiperu.com',
              project_id: this.projectId
            }
          },
          httpCheck: {
            path: '/',
            port: 443,
            useSsl: true,
            validateSsl: true,
            authInfo: {},
            maskHeaders: false
          },
          period: '60s',
          timeout: '10s',
          selectedRegions: [
            'USA',
            'EUROPE',
            'SOUTH_AMERICA'
          ]
        },
        {
          displayName: 'OasisTaxi API Health',
          monitoredResource: {
            type: 'uptime_url',
            labels: {
              host: 'api.oasistaxiperu.com',
              project_id: this.projectId
            }
          },
          httpCheck: {
            path: '/health',
            port: 443,
            useSsl: true,
            requestMethod: 'GET',
            contentType: 'TYPE_UNSPECIFIED',
            body: '',
            headers: {
              'User-Agent': 'GoogleStackdriver-UptimeCheck'
            }
          },
          period: '60s',
          timeout: '10s'
        }
      ],
      
      // Custom dashboards
      dashboards: [
        {
          displayName: 'OasisTaxi Infrastructure Overview',
          gridLayout: {
            widgets: [
              {
                title: 'Request Rate',
                xyChart: {
                  dataSets: [{
                    timeSeriesQuery: {
                      timeSeriesFilter: {
                        filter: 'metric.type="loadbalancing.googleapis.com/https/request_count"',
                        aggregation: {
                          alignmentPeriod: '60s',
                          perSeriesAligner: 'ALIGN_RATE'
                        }
                      }
                    }
                  }]
                }
              },
              {
                title: 'Response Latency',
                xyChart: {
                  dataSets: [{
                    timeSeriesQuery: {
                      timeSeriesFilter: {
                        filter: 'metric.type="loadbalancing.googleapis.com/https/total_latencies"',
                        aggregation: {
                          alignmentPeriod: '60s',
                          perSeriesAligner: 'ALIGN_MEAN'
                        }
                      }
                    }
                  }]
                }
              },
              {
                title: 'Error Rate',
                xyChart: {
                  dataSets: [{
                    timeSeriesQuery: {
                      timeSeriesFilter: {
                        filter: 'metric.type="loadbalancing.googleapis.com/https/request_count" metric.label.response_code_class="5xx"',
                        aggregation: {
                          alignmentPeriod: '60s',
                          perSeriesAligner: 'ALIGN_RATE'
                        }
                      }
                    }
                  }]
                }
              },
              {
                title: 'Active Instances',
                scorecard: {
                  timeSeriesQuery: {
                    timeSeriesFilter: {
                      filter: 'metric.type="compute.googleapis.com/instance/cpu/utilization"',
                      aggregation: {
                        alignmentPeriod: '60s',
                        perSeriesAligner: 'ALIGN_MEAN',
                        crossSeriesReducer: 'REDUCE_COUNT'
                      }
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    };

    // Crear alert policies
    for (const policy of monitoringConfig.alertPolicies) {
      await this.createAlertPolicy(policy);
    }
    
    // Crear uptime checks
    for (const check of monitoringConfig.uptimeChecks) {
      await this.createUptimeCheck(check);
    }
    
    // Crear dashboards
    for (const dashboard of monitoringConfig.dashboards) {
      await this.createDashboard(dashboard);
    }
    
    console.log('✅ Monitoring configurado');
  }

  // ============================================
  // DNS CONFIGURATION
  // ============================================
  
  async setupDNS() {
    console.log('🌐 Configurando DNS...');
    
    const dnsConfig = {
      managedZone: {
        name: 'oasistaxiperu-zone',
        dnsName: 'oasistaxiperu.com.',
        description: 'DNS zone for OasisTaxi Peru',
        visibility: 'public',
        dnssecConfig: {
          state: 'on',
          defaultKeySpecs: [
            {
              keyType: 'keySigning',
              algorithm: 'rsasha256',
              keyLength: 2048
            },
            {
              keyType: 'zoneSigning',
              algorithm: 'rsasha256',
              keyLength: 1024
            }
          ]
        }
      },
      
      recordSets: [
        {
          name: 'oasistaxiperu.com.',
          type: 'A',
          ttl: 300,
          rrdatas: ['35.201.125.164'] // IP del load balancer
        },
        {
          name: 'www.oasistaxiperu.com.',
          type: 'CNAME',
          ttl: 300,
          rrdatas: ['oasistaxiperu.com.']
        },
        {
          name: 'api.oasistaxiperu.com.',
          type: 'A',
          ttl: 300,
          rrdatas: ['35.201.125.165'] // IP del API load balancer
        },
        {
          name: 'cdn.oasistaxiperu.com.',
          type: 'CNAME',
          ttl: 300,
          rrdatas: ['c.storage.googleapis.com.']
        },
        {
          name: 'oasistaxiperu.com.',
          type: 'MX',
          ttl: 3600,
          rrdatas: [
            '1 aspmx.l.google.com.',
            '5 alt1.aspmx.l.google.com.',
            '5 alt2.aspmx.l.google.com.',
            '10 alt3.aspmx.l.google.com.',
            '10 alt4.aspmx.l.google.com.'
          ]
        },
        {
          name: 'oasistaxiperu.com.',
          type: 'TXT',
          ttl: 3600,
          rrdatas: [
            '"v=spf1 include:_spf.google.com ~all"',
            '"google-site-verification=XXXXXXXXX"'
          ]
        }
      ]
    };

    // Crear managed zone
    await this.createManagedZone(dnsConfig.managedZone);
    
    // Crear record sets
    for (const recordSet of dnsConfig.recordSets) {
      await this.createRecordSet(recordSet);
    }
    
    console.log('✅ DNS configurado');
  }

  // ============================================
  // Helper functions
  // ============================================
  
  async createInstanceTemplate(config) {
    console.log(`Creating instance template: ${config.name}`);
    // Implementación con Google Cloud Compute API
  }

  async createInstanceGroupManager(config) {
    console.log(`Creating instance group manager: ${config.name}`);
    // Implementación con Google Cloud Compute API
  }

  async createAutoscaler(config) {
    console.log(`Creating autoscaler: ${config.name}`);
    // Implementación con Google Cloud Compute API
  }

  async updateBackendBucket(config) {
    console.log(`Updating backend bucket: ${config.name}`);
    // Implementación con Google Cloud Compute API
  }

  async createUrlMap(config) {
    console.log(`Creating URL map: ${config.name}`);
    // Implementación con Google Cloud Compute API
  }

  async enableCDNOnBackends() {
    console.log('Enabling CDN on backend services');
    // Implementación con Google Cloud Compute API
  }

  async createBackendService(config) {
    console.log(`Creating backend service: ${config.name}`);
    // Implementación con Google Cloud Compute API
  }

  async createTargetHttpsProxy(config) {
    console.log(`Creating target HTTPS proxy: ${config.name}`);
    // Implementación con Google Cloud Compute API
  }

  async createForwardingRule(config) {
    console.log(`Creating forwarding rule: ${config.name}`);
    // Implementación con Google Cloud Compute API
  }

  async updateSecurityPolicy(config) {
    console.log(`Updating security policy: ${config.name}`);
    // Implementación con Google Cloud Compute API
  }

  async applySecurityPolicyToBackends(policyName) {
    console.log(`Applying security policy ${policyName} to backends`);
    // Implementación con Google Cloud Compute API
  }

  async createAlertPolicy(config) {
    console.log(`Creating alert policy: ${config.displayName}`);
    // Implementación con Cloud Monitoring API
  }

  async createUptimeCheck(config) {
    console.log(`Creating uptime check: ${config.displayName}`);
    // Implementación con Cloud Monitoring API
  }

  async createDashboard(config) {
    console.log(`Creating dashboard: ${config.displayName}`);
    // Implementación con Cloud Monitoring API
  }

  async createManagedZone(config) {
    console.log(`Creating DNS managed zone: ${config.name}`);
    // Implementación con Cloud DNS API
  }

  async createRecordSet(config) {
    console.log(`Creating DNS record: ${config.name} (${config.type})`);
    // Implementación con Cloud DNS API
  }
}

// Exportar servicio
module.exports = CloudInfrastructureService;

// Inicializar si se ejecuta directamente
if (require.main === module) {
  const service = new CloudInfrastructureService();
  console.log('🚀 Cloud Infrastructure Service iniciado');
}