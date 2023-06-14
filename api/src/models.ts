export class Task {
  taskId: number;
  originalFilePath: string;
  processedFilePath: string;
  taskState: 'Done' | 'InProgress' | 'Created';

  constructor(taskId: number, originalFilePath: string) {
    this.taskId = taskId;
    this.originalFilePath = originalFilePath;
    this.taskState = 'Created';
  }
}