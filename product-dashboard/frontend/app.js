const app = document.getElementById("app");

async function loadProducts() {
  const res = await fetch("/api/items");
  const items = await res.json();

  app.innerHTML = `
    <h2>Products</h2>
    <input id="name" placeholder="name"/>
    <button onclick="addProduct()">Add</button>
    <ul>${items.map(i => `<li>${i.name}</li>`).join("")}</ul>
  `;
}

async function addProduct() {
  const name = document.getElementById("name").value;
  await fetch("/api/items", {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({ name })
  });
  loadProducts();
}

async function loadStats() {
  const res = await fetch("/api/stats");
  const stats = await res.json();

  app.innerHTML = `
    <h2>Stats</h2>
    <p>Count: ${stats.count}</p>
    <p>Instance: ${stats.instance}</p>
  `;
}

function router() {
  const path = window.location.pathname;

  if (path === "/products") loadProducts();
  else if (path === "/stats") loadStats();
  else app.innerHTML = "<h2>Home</h2>";
}

window.onpopstate = router;
document.addEventListener("click", e => {
  if (e.target.tagName === "A") {
    e.preventDefault();
    history.pushState({}, "", e.target.href);
    router();
  }
});

router();