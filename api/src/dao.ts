import { Task } from './models';
const { Upload } = require("@aws-sdk/lib-storage");
const { S3Client, S3 } = require("@aws-sdk/client-s3");

export async function getTask(id: number): Promise<Task> {
  // Implementation to fetch the task by ID from the data source (e.g., DynamoDB)
  // You can use any database or storage mechanism of your choice

  // Example implementation:
  const task: Task = new Task(id, "");//await fetchTaskFromDataSource(id);
  return task;
}

export async function createTask(image: Buffer): Promise<Task> {
  var id = new Date().getTime() // Not reliable in scale but still.

  // Example implementation:
  const task: Task = new Task(id, "");//await saveTaskToDataSource(image);
  return task;
}
