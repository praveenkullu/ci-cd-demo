const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3002;

app.use(cors());
app.use(express.json());

// In-memory data store
let products = [
  { id: '1', name: 'Laptop', price: 999.99, category: 'Electronics', stock: 50, createdAt: new Date().toISOString() },
  { id: '2', name: 'Desk Chair', price: 199.99, category: 'Furniture', stock: 30, createdAt: new Date().toISOString() },
  { id: '3', name: 'Coffee Maker', price: 79.99, category: 'Appliances', stock: 100, createdAt: new Date().toISOString() }
];

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'product-service', timestamp: new Date().toISOString() });
});

// Get all products
app.get('/products', (req, res) => {
  const { category } = req.query;
  let filteredProducts = products;

  if (category) {
    filteredProducts = products.filter(p => p.category.toLowerCase() === category.toLowerCase());
  }

  res.json({ success: true, data: filteredProducts, count: filteredProducts.length });
});

// Get product by ID
app.get('/products/:id', (req, res) => {
  const product = products.find(p => p.id === req.params.id);
  if (!product) {
    return res.status(404).json({ success: false, error: 'Product not found' });
  }
  res.json({ success: true, data: product });
});

// Create new product
app.post('/products', (req, res) => {
  const { name, price, category, stock } = req.body;

  if (!name || !price) {
    return res.status(400).json({ success: false, error: 'Name and price are required' });
  }

  const newProduct = {
    id: String(products.length + 1),
    name,
    price: parseFloat(price),
    category: category || 'General',
    stock: stock || 0,
    createdAt: new Date().toISOString()
  };

  products.push(newProduct);
  res.status(201).json({ success: true, data: newProduct });
});

// Update product
app.put('/products/:id', (req, res) => {
  const index = products.findIndex(p => p.id === req.params.id);
  if (index === -1) {
    return res.status(404).json({ success: false, error: 'Product not found' });
  }

  products[index] = { ...products[index], ...req.body, updatedAt: new Date().toISOString() };
  res.json({ success: true, data: products[index] });
});

// Delete product
app.delete('/products/:id', (req, res) => {
  const index = products.findIndex(p => p.id === req.params.id);
  if (index === -1) {
    return res.status(404).json({ success: false, error: 'Product not found' });
  }

  products.splice(index, 1);
  res.json({ success: true, message: 'Product deleted successfully' });
});

// Update product stock
app.patch('/products/:id/stock', (req, res) => {
  const { quantity } = req.body;
  const product = products.find(p => p.id === req.params.id);

  if (!product) {
    return res.status(404).json({ success: false, error: 'Product not found' });
  }

  product.stock += quantity;
  res.json({ success: true, data: product });
});

app.listen(PORT, () => {
  console.log(`Product Service running on port ${PORT}`);
});
