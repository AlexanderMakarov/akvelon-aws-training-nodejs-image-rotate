import { getTask, createTask, getTaskImage } from './dao';
import { Request, Response } from 'express';

function parseTaskId(req: Request, res: Response): number {
    try {
        return parseInt(req.params.id, 10);
    } catch (error) {
        res.status(400).json(error);
    }
    return -1
}

export async function handleGetTask(req: Request, res: Response): Promise<void> {
    var taskId = parseTaskId(req, res)
    if (taskId < 0) {
        return;
    }
    getTask(taskId).then((task) => {
        res.json(task);
    }).catch((err) => {
        res.status(500).json(err);
    });
}

export async function handleGetTaskImage(req: Request, res: Response, isFlipped: boolean): Promise<void> {
    var taskId = parseTaskId(req, res)
    if (taskId < 0) {
        return;
    }
    getTaskImage(taskId, isFlipped).then((path) => {
        res.json(path);
    }).catch((err) => {
        res.status(500).json(err);
    });
}

export async function handlePostTask(req: Request, res: Response): Promise<void> {
    const file = req.file;
    console.dir("Got image", file)
    if (!file) {
        res.status(400).json({ error: 'Please attach a file' });
        return;
    }
    await createTask(file).then((task) => {
        res.status(201).json(task);
    }).catch((err) => {
        res.status(500).json(err);
    });
}
