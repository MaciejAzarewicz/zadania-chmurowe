import { Link, Route, Routes } from 'react-router-dom';
import { useEffect, useState } from 'react';

function Home() {
  return <h2>Home</h2>;
}

function Products() {
  const [items, setItems] = useState([]);
  const [name, setName] = useState('');

  const loadProducts = async () => {
    const res = await fetch('/api/items');
    const data = await res.json();
    setItems(data);
  };

  const addProduct = async () => {
    await fetch('/api/items', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name })
    });
    setName('');
    loadProducts();
  };

  useEffect(() => {
    loadProducts();
  }, []);

  return (
    <div>
      <h2>Products</h2>
      <input value={name} onChange={(e) => setName(e.target.value)} placeholder="name" />
      <button onClick={addProduct}>Add</button>
      <ul>{items.map((item) => <li key={item.id}>{item.name}</li>)}</ul>
    </div>
  );
}

function Stats() {
  const [stats, setStats] = useState(null);

  const loadStats = async () => {
    const res = await fetch('/api/stats');
    const data = await res.json();
    setStats(data);
  };

  useEffect(() => {
    loadStats();
  }, []);

  if (!stats) {
    return <p>Loading...</p>;
  }

  return (
    <div>
      <h2>Stats</h2>
      <p>Count: {stats.count}</p>
      <p>Instance: {stats.instance}</p>
      <p>Server time: {stats.serverTime}</p>
      <p>Uptime (s): {stats.uptime}</p>
      <p>Handled requests: {stats.requestCount}</p>
    </div>
  );
}

export default function App() {
  return (
    <div>
      <nav>
        <Link to="/">Home</Link> | <Link to="/products">Products</Link> | <Link to="/stats">Stats</Link>
      </nav>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/products" element={<Products />} />
        <Route path="/stats" element={<Stats />} />
      </Routes>
    </div>
  );
}
