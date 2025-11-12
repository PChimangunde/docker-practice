import express, { Request, Response } from "express";

const app = express();
// Use the port from the environment variable, or default to 5000
const PORT = process.env.PORT || 5000;

// Middleware to parse JSON bodies
app.use(express.json());

/**
 * @route GET /
 * @desc Root endpoint, returns a simple hello message.
 */
app.get("/", (req: Request, res: Response) => {
  res.send("Hello, World from the Dockerize App!");
});

/**
 * @route GET /products
 * @desc Returns a list of sample products.
 */
app.get("/products", (req: Request, res: Response) => {
  return res.json({
    products: [
      { id: 1, name: "Product A", price: 100 },
      { id: 2, name: "Product B", price: 150 },
      { id: 3, name: "Product C", price: 200 },
    ],
  });
});

// Start the server
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
