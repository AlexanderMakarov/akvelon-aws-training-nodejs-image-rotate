import { Task } from './models';
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import {
  DynamoDBClient, PutItemCommand, PutItemCommandOutput, GetItemCommand, AttributeValue
} from "@aws-sdk/client-dynamodb"
import { SQSClient, SendMessageCommand, SendMessageCommandOutput } from "@aws-sdk/client-sqs"

// Get data from env at start.
const REGION = process.env.AWS_REGION
const S3_IMAGES = process.env.S3_IMAGES
const DYNAMODB_TASKS = process.env.DYNAMODB_TASKS
const SQS_TASKS = process.env.SQS_TASKS
console.log(`ENV: Region=${REGION}, S3bucket=${S3_IMAGES}, DynamoDBtable=${DYNAMODB_TASKS}, SQSqueue=${SQS_TASKS}`)

// Instantiate AWS clients.
const s3 = new S3Client({ region: REGION });
const dynamodb = new DynamoDBClient({ region: REGION });
const sqs = new SQSClient({ region: REGION });

export async function getTask(taskId: number): Promise<Task> {
  return await getTaskFromDynamoDB(taskId);
}

export async function createTask(image: Express.Multer.File): Promise<Task> {
  var taskId = new Date().getTime() // Not reliable in scale but still.

  // Upload file to S3.
  const imageKeyInS3 = await uploadS3(image, taskId) // TODO fix - not available publicly.
  const task = new Task(taskId, imageKeyInS3)

  // Create DynamoDB record.
  const dynamodbResponse = await createTaskInDynamoDB(task)
  console.log("Uploaded to DynamoDB: ", dynamodbResponse)

  // Put into SQS.
  const sqsResponse = await senTaskInSQS(task)
  console.log("Sent to SQS: ", sqsResponse)

  return task;
}

export async function getTaskImage(taskId: number, isFlipped: boolean): Promise<string> {
  const task = await getTaskFromDynamoDB(taskId);
  if (task) {
    const key = isFlipped ? task.processedFilePath : task.originalFilePath;
    if (key) {
      return `https://${S3_IMAGES}.s3.${REGION}.amazonaws.com/${key}`
    }
    return new Promise((_, reject) => {
      reject(`Task ${taskId} doesn't have ${isFlipped ? "processedFilePath" : "originalFilePath"} attribute`);
    });
  }
  return new Promise((_, reject) => {
    reject(`Task ${taskId} doesn't exist`);
  });
}

async function uploadS3(file: Express.Multer.File, taskId: number): Promise<string> {
  const key = `${taskId}-${file.originalname}`;
  const command = new PutObjectCommand({
    Bucket: S3_IMAGES,
    Key: key,
    Body: file.buffer,
    ContentType: file.mimetype
  });
  const response = await s3.send(command);
  console.log("Uploaded to S3: ", response)
  return key;
}

async function createTaskInDynamoDB(task: Task): Promise<PutItemCommandOutput> {
  const command = new PutItemCommand({
    TableName: DYNAMODB_TASKS,
    Item: {
      "taskId": { N: task.taskId.toString() },
      "originalFilePath": { S: task.originalFilePath },
      "taskState": { S: task.taskState }
    }
  });
  return await dynamodb.send(command);
}

async function getTaskFromDynamoDB(taskId: number): Promise<Task> {
  const command = new GetItemCommand({
    TableName: DYNAMODB_TASKS,
    Key: { "taskId": { N: taskId.toString() } }
  });
  const response = await dynamodb.send(command);
  if (response.Item) {
    return mapToTask(response.Item);
  }
  return new Promise((_, reject) => {
    reject(`Task ${taskId} doesn't exist`);
  });
}

function mapToTask(item: Record<string, AttributeValue>): Task {
  return {
    taskId: Number(item.taskId.N),
    originalFilePath: item.originalFilePath?.S,
    processedFilePath: item.processedFilePath?.S,
    taskState: item.taskState?.S as 'Done' | 'InProgress' | 'Created'
  };
}

async function senTaskInSQS(task: Task): Promise<SendMessageCommandOutput> {
  const command = new SendMessageCommand({
    QueueUrl: SQS_TASKS,
    MessageBody: JSON.stringify(task)
  });
  return await sqs.send(command);
}
