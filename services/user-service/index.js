const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// In-memory data store
let users = [
  { id: '1', name: 'Alice Johnson', email: 'alice@example.com', createdAt: new Date().toISOString() },
  { id: '2', name: 'Bob Smith', email: 'bob@example.com', createdAt: new Date().toISOString() }
];

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'user-service', timestamp: new Date().toISOString() });
});

// Get all users
app.get('/users', (req, res) => {
  res.json({ success: true, data: users, count: users.length });
});

// Get user by ID
app.get('/users/:id', (req, res) => {
  const user = users.find(u => u.id === req.params.id);
  if (!user) {
    return res.status(404).json({ success: false, error: 'User not found' });
  }
  res.json({ success: true, data: user });
});

// Create new user
app.post('/users', (req, res) => {
  const { name, email } = req.body;

  if (!name || !email) {
    return res.status(400).json({ success: false, error: 'Name and email are required' });
  }

  const newUser = {
    id: String(users.length + 1),
    name,
    email,
    createdAt: new Date().toISOString()
  };

  users.push(newUser);
  res.status(201).json({ success: true, data: newUser });
});

// Update user
app.put('/users/:id', (req, res) => {
  const index = users.findIndex(u => u.id === req.params.id);
  if (index === -1) {
    return res.status(404).json({ success: false, error: 'User not found' });
  }

  users[index] = { ...users[index], ...req.body, updatedAt: new Date().toISOString() };
  res.json({ success: true, data: users[index] });
});

// Delete user
app.delete('/users/:id', (req, res) => {
  const index = users.findIndex(u => u.id === req.params.id);
  if (index === -1) {
    return res.status(404).json({ success: false, error: 'User not found' });
  }

  users.splice(index, 1);
  res.json({ success: true, message: 'User deleted successfully' });
});

app.listen(PORT, () => {
  console.log(`User Service running on port ${PORT}`);
});
