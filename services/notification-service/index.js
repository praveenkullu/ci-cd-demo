const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3004;

app.use(cors());
app.use(express.json());

// In-memory data store
let notifications = [];

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'notification-service', timestamp: new Date().toISOString() });
});

// Get all notifications
app.get('/notifications', (req, res) => {
  res.json({ success: true, data: notifications, count: notifications.length });
});

// Get notification by ID
app.get('/notifications/:id', (req, res) => {
  const notification = notifications.find(n => n.id === req.params.id);
  if (!notification) {
    return res.status(404).json({ success: false, error: 'Notification not found' });
  }
  res.json({ success: true, data: notification });
});

// Send notification
app.post('/notifications/send', (req, res) => {
  const { type, recipient, message, metadata } = req.body;

  if (!type || !recipient || !message) {
    return res.status(400).json({ success: false, error: 'Type, recipient, and message are required' });
  }

  const newNotification = {
    id: String(notifications.length + 1),
    type,
    recipient,
    message,
    metadata: metadata || {},
    status: 'sent',
    sentAt: new Date().toISOString()
  };

  notifications.push(newNotification);

  // Simulate sending notification
  console.log(`[NOTIFICATION] Type: ${type} | To: ${recipient} | Message: ${message}`);

  res.status(201).json({ success: true, data: newNotification, message: 'Notification sent successfully' });
});

// Get notifications by recipient
app.get('/notifications/recipient/:recipient', (req, res) => {
  const recipientNotifications = notifications.filter(n => n.recipient === req.params.recipient);
  res.json({ success: true, data: recipientNotifications, count: recipientNotifications.length });
});

// Mark notification as read
app.patch('/notifications/:id/read', (req, res) => {
  const notification = notifications.find(n => n.id === req.params.id);

  if (!notification) {
    return res.status(404).json({ success: false, error: 'Notification not found' });
  }

  notification.status = 'read';
  notification.readAt = new Date().toISOString();

  res.json({ success: true, data: notification });
});

app.listen(PORT, () => {
  console.log(`Notification Service running on port ${PORT}`);
});
