const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 3003;
const NOTIFICATION_SERVICE_URL = process.env.NOTIFICATION_SERVICE_URL || 'http://localhost:3004';

app.use(cors());
app.use(express.json());

// In-memory data store
let orders = [
  {
    id: '1',
    userId: '1',
    productId: '1',
    quantity: 2,
    status: 'completed',
    totalAmount: 1999.98,
    createdAt: new Date().toISOString()
  }
];

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'order-service', timestamp: new Date().toISOString() });
});

// Get all orders
app.get('/orders', (req, res) => {
  const { userId, status } = req.query;
  let filteredOrders = orders;

  if (userId) {
    filteredOrders = filteredOrders.filter(o => o.userId === userId);
  }

  if (status) {
    filteredOrders = filteredOrders.filter(o => o.status === status);
  }

  res.json({ success: true, data: filteredOrders, count: filteredOrders.length });
});

// Get order by ID
app.get('/orders/:id', (req, res) => {
  const order = orders.find(o => o.id === req.params.id);
  if (!order) {
    return res.status(404).json({ success: false, error: 'Order not found' });
  }
  res.json({ success: true, data: order });
});

// Create new order
app.post('/orders', async (req, res) => {
  const { userId, productId, quantity, totalAmount } = req.body;

  if (!userId || !productId || !quantity) {
    return res.status(400).json({ success: false, error: 'userId, productId, and quantity are required' });
  }

  const newOrder = {
    id: String(orders.length + 1),
    userId,
    productId,
    quantity: parseInt(quantity),
    totalAmount: totalAmount || 0,
    status: 'pending',
    createdAt: new Date().toISOString()
  };

  orders.push(newOrder);

  // Send notification asynchronously
  try {
    await axios.post(`${NOTIFICATION_SERVICE_URL}/notifications/send`, {
      type: 'order_created',
      recipient: userId,
      message: `Your order #${newOrder.id} has been created successfully`,
      metadata: {
        orderId: newOrder.id,
        productId: newOrder.productId,
        quantity: newOrder.quantity
      }
    });
    console.log(`Notification sent for order ${newOrder.id}`);
  } catch (error) {
    console.error('Failed to send notification:', error.message);
    // Don't fail the order creation if notification fails
  }

  res.status(201).json({ success: true, data: newOrder });
});

// Update order status
app.patch('/orders/:id/status', (req, res) => {
  const { status } = req.body;
  const order = orders.find(o => o.id === req.params.id);

  if (!order) {
    return res.status(404).json({ success: false, error: 'Order not found' });
  }

  if (!['pending', 'processing', 'completed', 'cancelled'].includes(status)) {
    return res.status(400).json({ success: false, error: 'Invalid status' });
  }

  order.status = status;
  order.updatedAt = new Date().toISOString();

  res.json({ success: true, data: order });
});

// Cancel order
app.delete('/orders/:id', (req, res) => {
  const order = orders.find(o => o.id === req.params.id);

  if (!order) {
    return res.status(404).json({ success: false, error: 'Order not found' });
  }

  order.status = 'cancelled';
  order.cancelledAt = new Date().toISOString();

  res.json({ success: true, message: 'Order cancelled successfully', data: order });
});

app.listen(PORT, () => {
  console.log(`Order Service running on port ${PORT}`);
  console.log(`Notification Service URL: ${NOTIFICATION_SERVICE_URL}`);
});
