import express, { Request, Response } from 'express';
import multer from 'multer';
import swaggerJsdoc from 'swagger-jsdoc';
import swaggerUi from 'swagger-ui-express';
import morgan from 'morgan'
import { handleGetTask, handlePostTask, handleGetTaskImage } from './controllers';

const app = express();
const port = 3000;

// Set up multer to reject files bigger than 5 MB.
const upload = multer({ limits: {fileSize: 5 * 1024 * 1024} });

// Set up requests logging.
app.use(morgan("[:date] :remote-addr :method :url -> :status with :res[content-length] bytes length body in :response-time ms"));

// Swagger configuration options
const swaggerOptions = {
  definition: {
    openapi: '3.1.0',
    info: {
      title: 'Server API',
      version: '1.0.0',
    },
  },
  apis: ['./dist/server.js'], // Use Swagger definitions from transpiled code.
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
 *           type: integer
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
 *           type: integer
 *     responses:
 *        200:
 *          description: OK
 */
app.get('/tasks/:id/original', (req: Request, res: Response) => { handleGetTaskImage(req, res, false) });

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
 *           type: integer
 *     responses:
 *        200:
 *          description: OK
 */
app.get('/tasks/:id/flipped', (req: Request, res: Response) => { handleGetTaskImage(req, res, true) });

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
