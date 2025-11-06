const express = require('express');
const cors = require('cors');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const PORT = process.env.PORT || 3000;

// Service URLs from environment variables
const USER_SERVICE_URL = process.env.USER_SERVICE_URL || 'http://localhost:3001';
const PRODUCT_SERVICE_URL = process.env.PRODUCT_SERVICE_URL || 'http://localhost:3002';
const ORDER_SERVICE_URL = process.env.ORDER_SERVICE_URL || 'http://localhost:3003';
const NOTIFICATION_SERVICE_URL = process.env.NOTIFICATION_SERVICE_URL || 'http://localhost:3004';

app.use(cors());
app.use(express.json());

// Health check for API Gateway
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'api-gateway',
    timestamp: new Date().toISOString(),
    services: {
      user: USER_SERVICE_URL,
      product: PRODUCT_SERVICE_URL,
      order: ORDER_SERVICE_URL,
      notification: NOTIFICATION_SERVICE_URL
    }
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to Microservices API Gateway v2',
    version: '1.0.0',
    endpoints: {
      users: '/api/users',
      products: '/api/products',
      orders: '/api/orders',
      notifications: '/api/notifications',
      health: '/health'
    }
  });
});

// Proxy configuration
const proxyOptions = {
  changeOrigin: true,
  logLevel: 'warn',
  onError: (err, req, res) => {
    console.error('Proxy Error:', err.message);
    res.status(502).json({
      success: false,
      error: 'Bad Gateway',
      message: 'Unable to connect to the service',
      service: req.baseUrl
    });
  }
};

// User Service routes
app.use(
  '/api/users',
  createProxyMiddleware({
    target: USER_SERVICE_URL,
    pathRewrite: { '^/api/users': '/users' },
    ...proxyOptions
  })
);

// Product Service routes
app.use(
  '/api/products',
  createProxyMiddleware({
    target: PRODUCT_SERVICE_URL,
    pathRewrite: { '^/api/products': '/products' },
    ...proxyOptions
  })
);

// Order Service routes
app.use(
  '/api/orders',
  createProxyMiddleware({
    target: ORDER_SERVICE_URL,
    pathRewrite: { '^/api/orders': '/orders' },
    ...proxyOptions
  })
);

// Notification Service routes
app.use(
  '/api/notifications',
  createProxyMiddleware({
    target: NOTIFICATION_SERVICE_URL,
    pathRewrite: { '^/api/notifications': '/notifications' },
    ...proxyOptions
  })
);

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    error: 'Not Found',
    message: 'The requested endpoint does not exist',
    path: req.originalUrl
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal Server Error',
    message: err.message
  });
});

app.listen(PORT, () => {
  console.log(`API Gateway running on port ${PORT}`);
  console.log('Service URLs:');
  console.log(`  User Service: ${USER_SERVICE_URL}`);
  console.log(`  Product Service: ${PRODUCT_SERVICE_URL}`);
  console.log(`  Order Service: ${ORDER_SERVICE_URL}`);
  console.log(`  Notification Service: ${NOTIFICATION_SERVICE_URL}`);
});
