const lambdaFunction = require('./index');

const testEventData = {
    Records: [
        {
            "messageId": "19dd0b57-b21e-4ac1-bd88-01bbb068cb78",
            "receiptHandle": "MessageReceiptHandle",
            "body": JSON.stringify({
                "taskId": 1,
                "originalFilePath": "test.jpg",
                "taskState": "Created"
            }),
            "attributes": {
                "ApproximateReceiveCount": "1",
                "SentTimestamp": "1523232000000",
                "SenderId": "123456789012",
                "ApproximateFirstReceiveTimestamp": "1523232000001"
            },
            "messageAttributes": {},
            "md5OfBody": "{{{md5_of_body}}}",
            "eventSource": "aws:sqs",
            "eventSourceARN": "arn:aws:sqs:us-east-1:123456789012:MyQueue",
            "awsRegion": "us-east-1"
        }
    ],
};

lambdaFunction.handler(testEventData)
    .then((response) => {
        console.dir(`testLocally: done, response=`, response)
    })
    .catch((error) => {
        console.dir(`testLocally: error=`, error);
    });
