import fs from 'fs';
import { getTask, createTask } from './dao';
import { Request, Response } from 'express';
import formidable from 'formidable';

export async function handleGetTask(req: Request, res: Response): Promise<void> {
    const taskId = parseInt(req.params.id, 10);
    const taskData = getTask(taskId);
    res.json(taskData);
}

export async function handlePostTask(req: Request, res: Response): Promise<void> {
    const buffer = fs.readFileSync(req.file.path);
    const task = await createTask(buffer);

    res.status(201).json(task);
}

const parsefile = async (req) => {
    return new Promise((resolve, reject) => {
        let options = {
            maxFileSize: 100 * 1024 * 1024, //100 MBs converted to bytes,
            allowEmptyFiles: false
        }

        const form = formidable(options);
        
        form.parse(req, (err, fields, files) => {});
    })
}