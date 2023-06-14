const AWS = require("aws-sdk")
const sharp = require("sharp")

// Read ENV variables
const REGION = process.env.AWS_REGION
const S3_IMAGES = process.env.S3_IMAGES
const DYNAMODB_TASKS = process.env.DYNAMODB_TASKS
console.log(`ENV: Region=${REGION}, S3bucket=${S3_IMAGES}, DynamoDBtable=${DYNAMODB_TASKS}`)

// Define AWS services to call.
const s3 = new AWS.S3({})
const dynamoDb = new AWS.DynamoDB.DocumentClient({ region: REGION })

function addFlippedToImagePath(imagePath) {
  const extensionIndex = imagePath.lastIndexOf('.');
  if (extensionIndex !== -1) {
    const extension = imagePath.substring(extensionIndex);
    const fileName = imagePath.substring(0, extensionIndex);
    return `${fileName}-flipped${extension}`;
  }
  return `${imagePath}-flipped`;
}

async function updateTask(taskId, expression, valuesMap) {
  const dynamoDBUpdateParams = {
    TableName: DYNAMODB_TASKS,
    Key: { taskId: taskId },
    UpdateExpression: expression,
    ExpressionAttributeValues: valuesMap,
  };
  await dynamoDb.update(dynamoDBUpdateParams).promise();
}

// {"taksId": int, "originalFilePath": "str", "processedFilePath": "str", "taskState": "Done/InProgress/Created"}
// Assumes that:
// 1. SQS message contains the whole task ^ and it is not processed yet.
// 2. originalFilePath is set and is valid.
// 3. DynamoDB contains specified item.
exports.handler = async (event) => {
  try {
    console.log(`Received ${event.Records.length} tasks.`);
    const updatedTasks = []
    for (const record of event.Records) {
      console.dir(`Starting to hande event with body`, record.body);
      const task = JSON.parse(record.body); // Whole task in SQS.

      // Get image from S3.
      const s3Params = {
        Bucket: S3_IMAGES,
        Key: task.originalFilePath,
      };
      const imageData = await s3.getObject(s3Params).promise();

      // Set "InProgress" state to task.
      await updateTask(task.taskId, 'SET taskState = :s', { ":s": "InProgress" })

      // Rotate image locally using sharp library.
      const flippedImageBytes = await sharp(imageData.Body).rotate(180).toBuffer();

      // Save rotated image into S3 near.
      const flippedImagePath = addFlippedToImagePath(task.originalFilePath);
      const s3PutParams = {
        Bucket: S3_IMAGES,
        Key: flippedImagePath,
        Body: flippedImageBytes,
      };
      await s3.putObject(s3PutParams).promise();

      // Update task in DynamoDB with processedFilePath and "Done" state.
      await updateTask(
        task.taskId,
        'SET processedFilePath = :p, taskState = :s',
        { ":p": flippedImagePath, ":s": "Done" }
      )
      updatedTasks.push(task.taskId)
    }

    return {
      statusCode: 200,
      body: `Successfully updated tasks: ${updatedTasks}`,
    };
  } catch (error) {
    console.error(error);
    return {
      statusCode: 500,
      body: 'Error',
    };
  }
};