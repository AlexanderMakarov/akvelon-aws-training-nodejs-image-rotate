import express, { Request, Response } from 'express';
import multer from 'multer';
import swaggerJsdoc from 'swagger-jsdoc';
import swaggerUi from 'swagger-ui-express';
import { handleGetTask, handlePostTask } from './controllers';

const app = express();
const port = 3000;

// Set up multer for file uploads
const upload = multer({ dest: 'uploads/' });

// Swagger configuration options
const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Node.js API',
      version: '1.0.0',
    },
  },
  apis: ['./src/server.ts'],
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);

app.use(express.json());

// Swagger UI endpoint
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

/**
 * @openapi
 * /tasks/{id}:
 *   get:
 *     description: Get task by ID
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         description: Task ID
 *         schema:
 *           type: string
 *     responses:
 *        200:
 *          description: OK
 */
app.get('/tasks/:id', handleGetTask);

/**
 * @openapi
 * /tasks/{id}/original:
 *   get:
 *     description: Get original image by task ID
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         description: Task ID
 *         schema:
 *           type: string
 *     responses:
 *        200:
 *          description: OK
 */
app.get('/tasks/:id/original', (req: Request, res: Response) => {
  const taskId = req.params.id;
  // Logic to retrieve original image by task ID
  const imagePath = `/tasks/${taskId}/original.jpg`;

  res.sendFile(imagePath, { root: __dirname });
});

/**
 * @openapi
 * /tasks/{id}/flipped:
 *   get:
 *     description: Get flipped image by task ID
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         description: Task ID
 *         schema:
 *           type: string
 *     responses:
 *        200:
 *          description: OK
 */
app.get('/tasks/:id/flipped', (req: Request, res: Response) => {
  const taskId = req.params.id;
  // Logic to retrieve flipped image by task ID
  const imagePath = `/tasks/${taskId}/flipped.jpg`;

  res.sendFile(imagePath, { root: __dirname });
});

/**
 * @openapi
 * /tasks:
 *   post:
 *     description: Create a new task with an image
 *     requestBody:
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               image:
 *                 type: string
 *                 format: binary
 *     responses:
 *        201:
 *          description: Created
 */
app.post('/tasks', upload.single('image'), handlePostTask);

// Start the server
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
